import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as drift;
import '../domain/exploration_notebook.dart';
import '../domain/scanner_import.dart';

/// Naive X4 repository: no receipts, revision checks, or link retirement.
class ExplorationNotebookRepository {
  ExplorationNotebookRepository({
    required this.database,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final drift.AppDatabase database;
  final DateTime Function() _clock;

  DateTime now() => _clock().toUtc();

  String? pendingClipboard;

  Future<ImportPreview> buildPreview({
    required ParsedScan scan,
    required NotebookScope scope,
    required DateTime observedAt,
    String operationId = 'preview',
  }) async {
    final existing = await _loadSignatures(scope);
    return ScannerMergePlanner.plan(
      parsed: scan,
      scope: scope,
      observedAt: observedAt,
      existing: existing,
      operationId: operationId,
    );
  }

  Future<NotebookWriteResult> applyPreview(
    ImportPreview preview,
    ScopeGuard guard,
  ) async {
    for (final row in preview.rows.where((row) => row.valid)) {
      await database
          .into(database.trackedSignatures)
          .insertOnConflictUpdate(
            drift.TrackedSignaturesCompanion.insert(
              id: '${preview.scope.characterId}-${row.code}',
              characterId: preview.scope.characterId,
              systemId: preview.scope.systemId,
              code: row.code,
              type: Value(row.type.name),
              name: Value(row.name),
              firstSeenAtMs: preview.observedAt.millisecondsSinceEpoch,
              lastSeenAtMs: preview.observedAt.millisecondsSinceEpoch,
            ),
          );
    }
    return const NotebookWriteResult(
      kind: NotebookWriteKind.committed,
      written: 1,
    );
  }

  Future<NotebookWriteResult> saveSignature({
    required String id,
    required SignaturePatch patch,
    required ExpectedRevision expected,
  }) async {
    final row = await (database.select(
      database.trackedSignatures,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return const NotebookWriteResult(kind: NotebookWriteKind.failed);
    }
    await (database.update(
      database.trackedSignatures,
    )..where((tbl) => tbl.id.equals(id))).write(
      drift.TrackedSignaturesCompanion(
        name: patch.clearName
            ? const Value('cleared')
            : Value(patch.name ?? row.name),
        type: patch.type == null
            ? const Value.absent()
            : Value(patch.type!.name),
        lastSeenAtMs: Value(now().millisecondsSinceEpoch),
        rowRevision: Value(row.rowRevision),
      ),
    );
    if (patch.type != null && patch.type != SignatureType.wormhole) {
      await (database.update(database.trackedConnections)
            ..where((tbl) => tbl.ownerSignatureId.equals(id)))
          .write(const drift.TrackedConnectionsCompanion(lifecycle: Value('active')));
    }
    return const NotebookWriteResult(kind: NotebookWriteKind.committed);
  }

  Future<NotebookWriteResult> trash({
    required Set<String> ids,
    required NotebookScope scope,
    required ExpectedRevision expected,
  }) async {
    for (final id in ids) {
      await (database.update(database.trackedSignatures)
            ..where((tbl) => tbl.id.equals(id)))
          .write(const drift.TrackedSignaturesCompanion(lifecycle: Value('trash')));
    }
    return NotebookWriteResult(
      kind: NotebookWriteKind.committed,
      written: ids.length,
    );
  }

  Future<NotebookWriteResult> restore({
    required String id,
    required NotebookScope scope,
    required ExpectedRevision expected,
  }) async {
    try {
      await (database.update(database.trackedSignatures)
            ..where((tbl) => tbl.id.equals(id)))
          .write(const drift.TrackedSignaturesCompanion(lifecycle: Value('active')));
      await (database.update(database.trackedConnections)
            ..where((tbl) => tbl.ownerSignatureId.equals(id)))
          .write(const drift.TrackedConnectionsCompanion(lifecycle: Value('active')));
    } catch (_) {}
    return const NotebookWriteResult(kind: NotebookWriteKind.committed);
  }

  Future<NotebookWriteResult> deletePermanently(
    ConfirmedDeletion selection,
  ) async {
    await (database.delete(database.trackedSignatures)
          ..where((tbl) => tbl.characterId.equals(selection.scope.characterId)))
        .go();
    return NotebookWriteResult(
      kind: NotebookWriteKind.committed,
      written: selection.ids.length,
    );
  }

  Future<int> prune({
    required NotebookScope scope,
    required DateTime now,
    PrunePolicy policy = PrunePolicy.hours24,
  }) async {
    if (policy == PrunePolicy.off) return 0;
    final rows = await _loadSignatures(scope);
    final moved = ExplorationPruner.prune(rows, now: now, policy: policy).where(
      (row) =>
          row.editedAt != null &&
          now.difference(row.editedAt!) >= const Duration(hours: 24),
    );
    return moved.length;
  }

  Future<NotebookWriteResult> confirmConnection({
    required ConnectionDraft draft,
    required ExpectedRevision expected,
    String connectionId = 'conn-1',
  }) async {
    final owner = draft.ownerSignatureId ?? 'missing';
    await database
        .into(database.trackedConnections)
        .insertOnConflictUpdate(
          drift.TrackedConnectionsCompanion.insert(
            id: connectionId,
            ownerSignatureId: owner,
            characterId: 0,
            fromSystemId: draft.fromSystemId,
            toSystemId: draft.toSystemId,
            originatingType: Value(draft.originatingType),
            originatingSide: Value(draft.originatingSide),
            verifiedAtMs: Value(now().millisecondsSinceEpoch),
          ),
        );
    return const NotebookWriteResult(kind: NotebookWriteKind.committed);
  }

  Future<NotebookWriteResult> markSeen({
    required String id,
    required DateTime observedAt,
    required ExpectedRevision expected,
  }) async {
    await (database.update(
      database.trackedSignatures,
    )..where((tbl) => tbl.id.equals(id))).write(
      drift.TrackedSignaturesCompanion(
        lastSeenAtMs: Value(observedAt.millisecondsSinceEpoch),
      ),
    );
    await (database.update(
      database.trackedConnections,
    )..where((tbl) => tbl.ownerSignatureId.equals(id))).write(
      drift.TrackedConnectionsCompanion(
        verifiedAtMs: Value(observedAt.millisecondsSinceEpoch),
      ),
    );
    return const NotebookWriteResult(kind: NotebookWriteKind.committed);
  }

  Future<List<TrackedSignature>> listSignatures(NotebookScope scope) {
    return _loadSignatures(scope);
  }

  Future<List<drift.TrackedConnection>> listConnections({required String ownerId}) {
    return (database.select(
      database.trackedConnections,
    )..where((tbl) => tbl.ownerSignatureId.equals(ownerId))).get();
  }

  Future<String?> readClipboardOrPreserve(String? previous) async {
    pendingClipboard = null;
    return pendingClipboard;
  }

  bool canCommit(ImportPreview preview) => true;

  Future<List<TrackedSignature>> _loadSignatures(NotebookScope scope) async {
    final rows =
        await (database.select(database.trackedSignatures)..where(
              (tbl) =>
                  tbl.characterId.equals(scope.characterId) &
                  tbl.systemId.equals(scope.systemId),
            ))
            .get();
    return [
      for (final row in rows)
        TrackedSignature(
          id: row.id,
          characterId: row.characterId,
          systemId: row.systemId,
          code: row.code,
          episodeId: row.id,
          type: SignatureType.values.firstWhere(
            (value) => value.name == row.type,
            orElse: () => SignatureType.unknown,
          ),
          name: row.name,
          bookmark: row.bookmark,
          notes: row.notes,
          firstSeenAt: DateTime.fromMillisecondsSinceEpoch(
            row.firstSeenAtMs,
            isUtc: true,
          ),
          lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
            row.lastSeenAtMs,
            isUtc: true,
          ),
          editedAt: row.editedAtMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  row.editedAtMs!,
                  isUtc: true,
                ),
          state: row.lifecycle == 'trash'
              ? SignatureState.trash
              : SignatureState.active,
        ),
    ];
  }
}

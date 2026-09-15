import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart' as drift;
import '../../../core/logging/logger.dart';
import '../domain/exploration_notebook.dart';
import '../domain/scanner_import.dart';

class ExplorationNotebookRepository {
  ExplorationNotebookRepository({
    required this.database,
    DateTime Function()? clock,
    Future<String?> Function()? clipboardRead,
  }) : _clock = clock ?? DateTime.now,
       _clipboardRead = clipboardRead;

  static const _log = 'EXPLORATION.NOTEBOOK';
  static const _linkTtl = Duration(hours: 24);
  static const _uuid = Uuid();

  final drift.AppDatabase database;
  final DateTime Function() _clock;
  final Future<String?> Function()? _clipboardRead;

  DateTime now() => _clock().toUtc();

  String? pendingClipboard;

  Stream<List<TrackedSignature>> watchNotebook(NotebookScope scope) {
    return (database.select(database.trackedSignatures)..where(
          (tbl) =>
              tbl.characterId.equals(scope.characterId) &
              tbl.systemId.equals(scope.systemId),
        ))
        .watch()
        .map(_toDomain);
  }

  Future<ImportPreview> buildPreview({
    required ParsedScan scan,
    required NotebookScope scope,
    required DateTime observedAt,
    String operationId = 'preview',
  }) async {
    final existing = await _loadSignatures(scope);
    Log.d(_log, 'buildPreview operation=$operationId system=${scope.systemId}');
    return ScannerMergePlanner.plan(
      parsed: scan,
      scope: scope,
      observedAt: observedAt,
      existing: existing,
      operationId: operationId,
    );
  }

  bool canCommit(ImportPreview preview) {
    return preview.wholeInputError == null &&
        preview.conflicts.isEmpty &&
        preview.added + preview.updated + preview.seenAgain > 0;
  }

  Future<NotebookWriteResult> applyPreview(
    ImportPreview preview,
    ScopeGuard guard,
  ) async {
    if (!canCommit(preview)) {
      Log.w(_log, 'import blocked: no valid signatures selected');
      return const NotebookWriteResult(kind: NotebookWriteKind.validation);
    }
    return database.transaction(() async {
      if (!await _characterExists(preview.scope.characterId)) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      final receipt = await _receipt(preview.operationId);
      if (receipt != null) {
        if (receipt.inputDigest == preview.inputDigest) {
          Log.d(_log, 'alreadyApplied operation=${preview.operationId}');
          return const NotebookWriteResult(
            kind: NotebookWriteKind.alreadyApplied,
          );
        }
        Log.w(_log, 'operation id reused with different digest');
        return const NotebookWriteResult(kind: NotebookWriteKind.validation);
      }
      final scopeRevision = await _scopeRevision(preview.scope);
      if (scopeRevision != guard.revision ||
          guard.scope.characterId != preview.scope.characterId ||
          guard.scope.systemId != preview.scope.systemId) {
        Log.w(
          _log,
          'import scope conflict expected=${guard.revision} actual=$scopeRevision',
        );
        return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
      }

      var written = 0;
      for (final candidate in preview.candidates) {
        if (candidate.conflict) continue;
        written += await _applyCandidate(preview, candidate);
      }

      await database
          .into(database.explorationImportOperations)
          .insert(
            drift.ExplorationImportOperationsCompanion.insert(
              id: preview.operationId,
              characterId: preview.scope.characterId,
              systemId: preview.scope.systemId,
              inputDigest: preview.inputDigest,
              committedAtMs: now().millisecondsSinceEpoch,
              addedCount: Value(preview.added),
              updatedCount: Value(preview.updated),
              skippedCount: Value(preview.seenAgain),
              conflictCount: Value(preview.conflicts.length),
            ),
          );
      await _bumpScope(preview.scope, scopeRevision);
      Log.i(
        _log,
        'import committed operation=${preview.operationId} written=$written',
      );
      return NotebookWriteResult(
        kind: NotebookWriteKind.committed,
        written: written,
      );
    });
  }

  Future<NotebookWriteResult> saveSignature({
    required String id,
    required SignaturePatch patch,
    required ExpectedRevision expected,
  }) {
    return database.transaction(() async {
      final row = await _signatureRow(id);
      if (row == null) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      if (!await _characterExists(row.characterId)) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      if (row.rowRevision != expected.value) {
        Log.w(
          _log,
          'saveSignature revision conflict id=$id expected=${expected.value} actual=${row.rowRevision}',
        );
        return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
      }

      final nextType = patch.type?.name ?? row.type;
      await (database.update(
        database.trackedSignatures,
      )..where((tbl) => tbl.id.equals(id))).write(
        drift.TrackedSignaturesCompanion(
          name: patch.clearName
              ? const Value(null)
              : patch.name == null
              ? const Value.absent()
              : Value(patch.name),
          bookmark: patch.bookmark == null
              ? const Value.absent()
              : Value(patch.bookmark),
          notes: patch.notes == null
              ? const Value.absent()
              : Value(patch.notes),
          type: patch.type == null
              ? const Value.absent()
              : Value(patch.type!.name),
          rowRevision: Value(row.rowRevision + 1),
        ),
      );
      if (row.type == SignatureType.wormhole.name &&
          nextType != SignatureType.wormhole.name) {
        await _retireLinks(id, reason: 'type_changed');
      }
      await _bumpScope(
        NotebookScope(characterId: row.characterId, systemId: row.systemId),
        await _scopeRevision(
          NotebookScope(characterId: row.characterId, systemId: row.systemId),
        ),
      );
      Log.d(_log, 'saveSignature committed id=$id');
      return const NotebookWriteResult(kind: NotebookWriteKind.committed);
    });
  }

  Future<NotebookWriteResult> markSeen({
    required String id,
    required DateTime observedAt,
    required ExpectedRevision expected,
  }) {
    return database.transaction(() async {
      final row = await _signatureRow(id);
      if (row == null) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      if (row.rowRevision != expected.value) {
        return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
      }
      final observedMs = observedAt.toUtc().millisecondsSinceEpoch;
      final nextLastSeen = observedMs > row.lastSeenAtMs
          ? observedMs
          : row.lastSeenAtMs;
      await (database.update(
        database.trackedSignatures,
      )..where((tbl) => tbl.id.equals(id))).write(
        drift.TrackedSignaturesCompanion(lastSeenAtMs: Value(nextLastSeen)),
      );
      Log.d(_log, 'markSeen id=$id lastSeenAtMs=$nextLastSeen');
      return const NotebookWriteResult(kind: NotebookWriteKind.committed);
    });
  }

  Future<NotebookWriteResult> trash({
    required Set<String> ids,
    required NotebookScope scope,
    required ExpectedRevision expected,
  }) {
    return database.transaction(() async {
      if (!await _characterExists(scope.characterId)) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      for (final id in ids) {
        final row = await _signatureRow(id);
        if (row == null ||
            row.characterId != scope.characterId ||
            row.systemId != scope.systemId) {
          return const NotebookWriteResult(kind: NotebookWriteKind.failed);
        }
        if (row.rowRevision != expected.value) {
          return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
        }
        await (database.update(
          database.trackedSignatures,
        )..where((tbl) => tbl.id.equals(id))).write(
          drift.TrackedSignaturesCompanion(
            lifecycle: const Value('trash'),
            retiredAtMs: Value(now().millisecondsSinceEpoch),
            retiredReason: const Value('trashed'),
            rowRevision: Value(row.rowRevision + 1),
          ),
        );
        await _retireLinks(id, reason: 'trashed');
      }
      await _bumpScope(scope, await _scopeRevision(scope));
      Log.i(_log, 'trashed ${ids.length} signatures');
      return NotebookWriteResult(
        kind: NotebookWriteKind.committed,
        written: ids.length,
      );
    });
  }

  Future<NotebookWriteResult> restore({
    required String id,
    required NotebookScope scope,
    required ExpectedRevision expected,
  }) {
    return database.transaction(() async {
      final row = await _signatureRow(id);
      if (row == null) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      if (row.rowRevision != expected.value) {
        return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
      }
      final active =
          await (database.select(database.trackedSignatures)..where(
                (tbl) =>
                    tbl.characterId.equals(scope.characterId) &
                    tbl.systemId.equals(scope.systemId) &
                    tbl.code.equals(row.code) &
                    tbl.lifecycle.equals('active') &
                    tbl.id.equals(id).not(),
              ))
              .get();
      if (active.isNotEmpty) {
        Log.w(_log, 'restore blocked: active code ${row.code}');
        return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
      }
      await (database.update(
        database.trackedSignatures,
      )..where((tbl) => tbl.id.equals(id))).write(
        drift.TrackedSignaturesCompanion(
          lifecycle: const Value('active'),
          rowRevision: Value(row.rowRevision + 1),
        ),
      );
      await _bumpScope(scope, await _scopeRevision(scope));
      Log.d(_log, 'restored id=$id; owned links remain retired');
      return const NotebookWriteResult(kind: NotebookWriteKind.committed);
    });
  }

  Future<NotebookWriteResult> deletePermanently(ConfirmedDeletion selection) {
    return database.transaction(() async {
      if (!await _characterExists(selection.scope.characterId)) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      for (final id in selection.ids) {
        final row = await _signatureRow(id);
        if (row == null ||
            row.characterId != selection.scope.characterId ||
            row.systemId != selection.scope.systemId) {
          return const NotebookWriteResult(kind: NotebookWriteKind.failed);
        }
        if (row.rowRevision != selection.revision) {
          return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
        }
        await (database.delete(
          database.trackedConnections,
        )..where((tbl) => tbl.ownerSignatureId.equals(id))).go();
        await (database.delete(
          database.trackedSignatures,
        )..where((tbl) => tbl.id.equals(id))).go();
      }
      await _bumpScope(selection.scope, await _scopeRevision(selection.scope));
      Log.i(_log, 'permanently deleted ${selection.ids.length} episodes');
      return NotebookWriteResult(
        kind: NotebookWriteKind.committed,
        written: selection.ids.length,
      );
    });
  }

  Future<int> prune({
    required NotebookScope scope,
    required DateTime now,
    PrunePolicy policy = PrunePolicy.hours24,
  }) {
    return database.transaction(() async {
      await _expireStaleLinks(scope, now);
      if (policy == PrunePolicy.off) {
        Log.d(_log, 'prune Off: signature retirement skipped');
        return 0;
      }
      final rows = await _loadSignatures(scope);
      final victims = ExplorationPruner.prune(
        rows,
        now: now,
        policy: policy,
      ).where((row) => row.state == SignatureState.active);
      var count = 0;
      for (final row in victims) {
        await (database.update(
          database.trackedSignatures,
        )..where((tbl) => tbl.id.equals(row.id))).write(
          drift.TrackedSignaturesCompanion(
            lifecycle: const Value('trash'),
            retiredAtMs: Value(now.toUtc().millisecondsSinceEpoch),
            retiredReason: const Value('pruned'),
            rowRevision: Value(
              ((await _signatureRow(row.id))?.rowRevision ?? 1) + 1,
            ),
          ),
        );
        await _retireLinks(row.id, reason: 'pruned');
        count += 1;
      }
      if (count > 0) {
        await _bumpScope(scope, await _scopeRevision(scope));
      }
      Log.i(_log, 'pruned signatures=$count policy=${policy.name}');
      return count;
    });
  }

  Future<NotebookWriteResult> confirmConnection({
    required ConnectionDraft draft,
    required ExpectedRevision expected,
    String? connectionId,
  }) {
    return database.transaction(() async {
      final ownerId = draft.ownerSignatureId;
      if (ownerId == null) {
        return const NotebookWriteResult(kind: NotebookWriteKind.validation);
      }
      final owner = await _signatureRow(ownerId);
      if (owner == null) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      if (owner.rowRevision != expected.value) {
        return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
      }
      if (owner.lifecycle != 'active' ||
          owner.type != SignatureType.wormhole.name) {
        return const NotebookWriteResult(kind: NotebookWriteKind.validation);
      }
      if (draft.fromSystemId != owner.systemId ||
          draft.fromSystemId == draft.toSystemId) {
        return const NotebookWriteResult(kind: NotebookWriteKind.validation);
      }

      final verifiedMs = now().millisecondsSinceEpoch;
      final existing =
          await (database.select(database.trackedConnections)
                ..where((tbl) => tbl.ownerSignatureId.equals(ownerId)))
              .getSingleOrNull();
      if (existing != null) {
        await (database.update(
          database.trackedConnections,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          drift.TrackedConnectionsCompanion(
            fromSystemId: Value(draft.fromSystemId),
            toSystemId: Value(draft.toSystemId),
            fromSignature: Value(draft.fromSignature),
            toSignature: Value(draft.toSignature),
            originatingType: Value(draft.originatingType),
            originatingSide: Value(draft.originatingSide),
            verifiedAtMs: Value(verifiedMs),
            lifecycle: const Value('active'),
            rowRevision: Value(existing.rowRevision + 1),
          ),
        );
      } else {
        await database
            .into(database.trackedConnections)
            .insert(
              drift.TrackedConnectionsCompanion.insert(
                id: connectionId ?? _uuid.v4(),
                ownerSignatureId: ownerId,
                characterId: owner.characterId,
                fromSystemId: draft.fromSystemId,
                toSystemId: draft.toSystemId,
                fromSignature: Value(draft.fromSignature),
                toSignature: Value(draft.toSignature),
                originatingType: Value(draft.originatingType),
                originatingSide: Value(draft.originatingSide),
                verifiedAtMs: Value(verifiedMs),
              ),
            );
      }
      Log.i(_log, 'confirmConnection owner=$ownerId verifiedAtMs=$verifiedMs');
      return const NotebookWriteResult(kind: NotebookWriteKind.committed);
    });
  }

  Future<NotebookWriteResult> markClosed({
    required String id,
    required ExpectedRevision expected,
  }) {
    return database.transaction(() async {
      final row = await (database.select(
        database.trackedConnections,
      )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return const NotebookWriteResult(kind: NotebookWriteKind.failed);
      }
      if (row.rowRevision != expected.value) {
        return const NotebookWriteResult(kind: NotebookWriteKind.conflict);
      }
      await (database.update(
        database.trackedConnections,
      )..where((tbl) => tbl.id.equals(id))).write(
        drift.TrackedConnectionsCompanion(
          lifecycle: const Value('closed'),
          rowRevision: Value(row.rowRevision + 1),
        ),
      );
      Log.d(_log, 'markClosed id=$id');
      return const NotebookWriteResult(kind: NotebookWriteKind.committed);
    });
  }

  Future<List<TrackedSignature>> listSignatures(NotebookScope scope) {
    return _loadSignatures(scope);
  }

  Future<List<drift.TrackedConnection>> listConnections({
    required String ownerId,
  }) {
    return (database.select(
      database.trackedConnections,
    )..where((tbl) => tbl.ownerSignatureId.equals(ownerId))).get();
  }

  Future<String?> readClipboardOrPreserve(String? previous) async {
    try {
      final reader = _clipboardRead;
      if (reader != null) {
        final text = await reader();
        Log.d(_log, 'clipboard read ok');
        return text ?? previous;
      }
      throw StateError('clipboard unavailable');
    } catch (error) {
      Log.w(_log, 'clipboard read failed; keeping previous input');
      return previous;
    }
  }

  Future<int> _applyCandidate(
    ImportPreview preview,
    MergeCandidate candidate,
  ) async {
    final observedMs = preview.observedAt.toUtc().millisecondsSinceEpoch;
    if (candidate.existingId != null && !candidate.newEpisode) {
      final row = await _signatureRow(candidate.existingId!);
      if (row == null) return 0;
      final nextLastSeen = observedMs > row.lastSeenAtMs
          ? observedMs
          : row.lastSeenAtMs;
      await (database.update(
        database.trackedSignatures,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        drift.TrackedSignaturesCompanion(
          type: Value(candidate.type.name),
          name: Value(candidate.preservedName),
          lastSeenAtMs: Value(nextLastSeen),
          rowRevision: Value(row.rowRevision + 1),
        ),
      );
      if (row.type == SignatureType.wormhole.name &&
          candidate.type != SignatureType.wormhole) {
        await _retireLinks(row.id, reason: 'type_changed');
      }
      return 1;
    }

    await database
        .into(database.trackedSignatures)
        .insert(
          drift.TrackedSignaturesCompanion.insert(
            id: _uuid.v4(),
            characterId: preview.scope.characterId,
            systemId: preview.scope.systemId,
            code: candidate.code,
            type: Value(candidate.type.name),
            name: Value(candidate.preservedName),
            notes: Value(candidate.preservedNotes),
            bookmark: Value(candidate.preservedBookmark),
            firstSeenAtMs: observedMs,
            lastSeenAtMs: observedMs,
          ),
        );
    return 1;
  }

  Future<void> _expireStaleLinks(NotebookScope scope, DateTime now) async {
    final cutoff = now.toUtc().subtract(_linkTtl).millisecondsSinceEpoch;
    final rows =
        await (database.select(database.trackedConnections)..where(
              (tbl) =>
                  tbl.characterId.equals(scope.characterId) &
                  tbl.lifecycle.equals('active'),
            ))
            .get();
    for (final row in rows) {
      final verified = row.verifiedAtMs;
      if (verified == null || verified > cutoff) continue;
      await (database.update(
        database.trackedConnections,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        const drift.TrackedConnectionsCompanion(
          lifecycle: Value('retired'),
          retiredReason: Value('verification_expired'),
        ),
      );
      Log.d(_log, 'expired link id=${row.id}');
    }
  }

  Future<void> _retireLinks(String ownerId, {required String reason}) async {
    await (database.update(database.trackedConnections)..where(
          (tbl) =>
              tbl.ownerSignatureId.equals(ownerId) &
              tbl.lifecycle.equals('active'),
        ))
        .write(
          drift.TrackedConnectionsCompanion(
            lifecycle: const Value('retired'),
            retiredReason: Value(reason),
          ),
        );
  }

  Future<drift.ExplorationImportOperation?> _receipt(String id) {
    return (database.select(
      database.explorationImportOperations,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> _scopeRevision(NotebookScope scope) async {
    final row =
        await (database.select(database.explorationNotebookScopes)..where(
              (tbl) =>
                  tbl.characterId.equals(scope.characterId) &
                  tbl.systemId.equals(scope.systemId),
            ))
            .getSingleOrNull();
    return row?.revision ?? 0;
  }

  Future<void> _bumpScope(NotebookScope scope, int current) async {
    await database
        .into(database.explorationNotebookScopes)
        .insertOnConflictUpdate(
          drift.ExplorationNotebookScopesCompanion.insert(
            characterId: scope.characterId,
            systemId: scope.systemId,
            revision: Value(current + 1),
          ),
        );
  }

  Future<bool> _characterExists(int characterId) async {
    return await database.getCharacter(characterId) != null;
  }

  Future<drift.TrackedSignature?> _signatureRow(String id) {
    return (database.select(
      database.trackedSignatures,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<TrackedSignature>> _loadSignatures(NotebookScope scope) async {
    final rows =
        await (database.select(database.trackedSignatures)..where(
              (tbl) =>
                  tbl.characterId.equals(scope.characterId) &
                  tbl.systemId.equals(scope.systemId),
            ))
            .get();
    return _toDomain(rows);
  }

  List<TrackedSignature> _toDomain(List<drift.TrackedSignature> rows) {
    return [
      for (final row in rows)
        TrackedSignature(
          id: row.id,
          characterId: row.characterId,
          systemId: row.systemId,
          code: row.code,
          episodeId: row.id,
          scanGroup: row.scanGroup,
          type: SignatureType.values.firstWhere(
            (value) => value.name == row.type,
            orElse: () => SignatureType.unknown,
          ),
          rawTypeLabel: row.rawTypeLabel,
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
          retiredAt: row.retiredAtMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  row.retiredAtMs!,
                  isUtc: true,
                ),
          retiredReason: row.retiredReason,
        ),
    ];
  }
}

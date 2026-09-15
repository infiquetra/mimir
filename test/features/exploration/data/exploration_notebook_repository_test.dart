// X4 RED contracts for ExplorationNotebookRepository (D15–D16, P10–P14).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §2.4:
// - P10: reapply is not alreadyApplied; zero-valid still commits.
// - P11: revision mismatches commit; clearName does not null the name.
// - P12: restore reactivates links; deletePermanent wipes the character.
// - D15: prune uses editedAt; Off skips work; repeat prune is not 0.
// - D16: markSeen refreshes verifiedAt; type change leaves the link active.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart'
    hide TrackedSignature;
import 'package:mimir/features/exploration/data/exploration_notebook_repository.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/scanner_import.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  late AppDatabase database;
  late ExplorationNotebookRepository repository;
  DateTime clock;

  const scope = NotebookScope(
    characterId: kCharacter7,
    systemId: kAlphaSystemId,
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    clock = kExplorationT0;
    repository = ExplorationNotebookRepository(
      database: database,
      clock: () => clock,
    );
    await database.upsertCharacter(
      CharactersCompanion.insert(
        characterId: const Value(kCharacter7),
        name: 'Pilot Seven',
        corporationId: 98000001,
        corporationName: 'Fixture Corp',
        portraitUrl: 'https://example.com/7',
        tokenExpiry: kExplorationT0.add(const Duration(hours: 1)),
        lastUpdated: kExplorationT0,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertSignature({
    required String id,
    required String code,
    String type = 'unknown',
    String lifecycle = 'active',
    DateTime? lastSeen,
    DateTime? firstSeen,
    DateTime? edited,
    String? name,
    String? notes,
    String? bookmark,
  }) {
    return database
        .into(database.trackedSignatures)
        .insert(
          TrackedSignaturesCompanion.insert(
            id: id,
            characterId: kCharacter7,
            systemId: kAlphaSystemId,
            code: code,
            type: Value(type),
            name: Value(name),
            notes: Value(notes),
            bookmark: Value(bookmark),
            lifecycle: Value(lifecycle),
            firstSeenAtMs: (firstSeen ?? kExplorationT0).millisecondsSinceEpoch,
            lastSeenAtMs: (lastSeen ?? kExplorationT0).millisecondsSinceEpoch,
            editedAtMs: edited == null
                ? const Value.absent()
                : Value(edited.millisecondsSinceEpoch),
          ),
        );
  }

  group('P10 preview apply cancel reapply', () {
    test('apply is idempotent; zero valid rows cannot commit', () async {
      final parsed = ScannerImportParser.parse(F5Fixtures.paste);
      final preview = await repository.buildPreview(
        scan: parsed,
        scope: scope,
        observedAt: kExplorationT0,
        operationId: 'op-1',
      );
      expect(preview.added, 3);
      final first = await repository.applyPreview(
        preview,
        const ScopeGuard(scope: scope, revision: 0),
      );
      expect(first.kind, NotebookWriteKind.committed);
      final second = await repository.applyPreview(
        preview,
        const ScopeGuard(scope: scope, revision: 1),
      );
      expect(second.kind, NotebookWriteKind.alreadyApplied);
      expect(await repository.listSignatures(scope), hasLength(3));

      final empty = ScannerImportParser.parse('not-a-row');
      final emptyPreview = await repository.buildPreview(
        scan: empty,
        scope: scope,
        observedAt: kExplorationT0,
      );
      expect(repository.canCommit(emptyPreview), isFalse);
      final appliedEmpty = await repository.applyPreview(
        emptyPreview,
        const ScopeGuard(scope: scope, revision: 1),
      );
      expect(appliedEmpty.kind, NotebookWriteKind.validation);
    });

    test('clipboard read error preserves the previous input', () async {
      repository.pendingClipboard = 'ABC-123\tCosmic Signature\tData Site\tX';
      final preserved = await repository.readClipboardOrPreserve(
        'DEF-456\tCosmic Signature\tWormhole\tY',
      );
      expect(preserved, 'DEF-456\tCosmic Signature\tWormhole\tY');
    });
  });

  group('P11 revision and nullable patches', () {
    test(
      'stale revision conflicts; clearName nulls without touching lastSeen',
      () async {
        await insertSignature(
          id: 'sig-abc',
          code: 'ABC-123',
          type: 'data',
          name: 'Sansha Data Site',
          lastSeen: DateTime.utc(2026, 9, 15, 11),
        );
        final stale = await repository.saveSignature(
          id: 'sig-abc',
          patch: const SignaturePatch(name: 'Nope'),
          expected: const ExpectedRevision(99),
        );
        expect(stale.kind, NotebookWriteKind.conflict);
        final cleared = await repository.saveSignature(
          id: 'sig-abc',
          patch: const SignaturePatch(clearName: true),
          expected: const ExpectedRevision(1),
        );
        expect(cleared.kind, NotebookWriteKind.committed);
        final rows = await repository.listSignatures(scope);
        expect(rows.single.name, isNull);
        expect(rows.single.lastSeenAt, DateTime.utc(2026, 9, 15, 11));
      },
    );
  });

  group('P12 trash restore permanent delete', () {
    test(
      'restore conflicts on active code; permanent delete is selection-only',
      () async {
        await insertSignature(id: 'old-abc', code: 'ABC-123', notes: 'old');
        await repository.trash(
          ids: {'old-abc'},
          scope: scope,
          expected: const ExpectedRevision(1),
        );
        await insertSignature(id: 'new-abc', code: 'ABC-123', notes: 'new');
        final restored = await repository.restore(
          id: 'old-abc',
          scope: scope,
          expected: const ExpectedRevision(1),
        );
        expect(restored.kind, NotebookWriteKind.conflict);

        await insertSignature(id: 'keep-me', code: 'KEP-001');
        final deleted = await repository.deletePermanently(
          const ConfirmedDeletion(ids: {'new-abc'}, scope: scope, revision: 1),
        );
        expect(deleted.kind, NotebookWriteKind.committed);
        final remaining = await repository.listSignatures(scope);
        final remainingIds = [for (final row in remaining) row.id];
        expect(remainingIds, contains('keep-me'));
        expect(remainingIds, isNot(contains('new-abc')));
      },
    );
  });

  group('D15/P14 prune and verification age', () {
    test(
      '24h uses lastSeenAt not editedAt; Off does not skip verification',
      () async {
        await insertSignature(
          id: 'age-001',
          code: 'AGE-001',
          lastSeen: kExplorationT0.subtract(const Duration(hours: 24)),
          edited: kExplorationT0.subtract(const Duration(minutes: 1)),
        );
        await insertSignature(
          id: 'age-002',
          code: 'AGE-002',
          lastSeen: kExplorationT0.subtract(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          ),
        );
        expect(await repository.prune(scope: scope, now: kExplorationT0), 1);
        expect(await repository.prune(scope: scope, now: kExplorationT0), 0);
        expect(
          await repository.prune(
            scope: scope,
            now: kExplorationT0,
            policy: PrunePolicy.off,
          ),
          0,
        );

        await insertSignature(id: 'wh-1', code: 'DEF-456', type: 'wormhole');
        await repository.confirmConnection(
          draft: const ConnectionDraft(
            ownerSignatureId: 'wh-1',
            fromSystemId: kAlphaSystemId,
            toSystemId: 9102,
            originatingType: 'B274',
            originatingSide: 'From',
          ),
          expected: const ExpectedRevision(1),
        );
        clock = kExplorationT0.add(const Duration(hours: 24));
        await repository.prune(
          scope: scope,
          now: clock,
          policy: PrunePolicy.off,
        );
        final links = await repository.listConnections(ownerId: 'wh-1');
        expect(links, hasLength(1));
        expect(links.single.lifecycle, isNot('active'));
      },
    );
  });

  group('D16/P13 link lifecycle', () {
    test(
      'only confirm stamps verifiedAt; type/trash retire; restore stays retired',
      () async {
        await insertSignature(id: 'wh-1', code: 'DEF-456', type: 'wormhole');
        await repository.confirmConnection(
          draft: const ConnectionDraft(
            ownerSignatureId: 'wh-1',
            fromSystemId: kAlphaSystemId,
            toSystemId: 9102,
            fromSignature: 'DEF-456',
            toSignature: 'DST-234',
            originatingType: 'B274',
            originatingSide: 'From',
          ),
          expected: const ExpectedRevision(1),
        );
        var links = await repository.listConnections(ownerId: 'wh-1');
        expect(links, hasLength(1));
        final verified = links.single.verifiedAtMs;
        expect(verified, kExplorationT0.millisecondsSinceEpoch);

        clock = kExplorationT0.add(const Duration(hours: 23));
        await repository.markSeen(
          id: 'wh-1',
          observedAt: clock,
          expected: const ExpectedRevision(1),
        );
        links = await repository.listConnections(ownerId: 'wh-1');
        expect(links.single.verifiedAtMs, verified);

        await repository.saveSignature(
          id: 'wh-1',
          patch: const SignaturePatch(type: SignatureType.data),
          expected: const ExpectedRevision(1),
        );
        links = await repository.listConnections(ownerId: 'wh-1');
        expect(links.single.lifecycle, isNot('active'));

        await insertSignature(id: 'wh-2', code: 'GHI-000', type: 'wormhole');
        await repository.confirmConnection(
          draft: const ConnectionDraft(
            ownerSignatureId: 'wh-2',
            fromSystemId: kAlphaSystemId,
            toSystemId: 9102,
            originatingType: 'B274',
            originatingSide: 'From',
          ),
          expected: const ExpectedRevision(1),
          connectionId: 'conn-2',
        );
        await repository.trash(
          ids: {'wh-2'},
          scope: scope,
          expected: const ExpectedRevision(1),
        );
        await repository.restore(
          id: 'wh-2',
          scope: scope,
          expected: const ExpectedRevision(1),
        );
        final restored = await repository.listConnections(ownerId: 'wh-2');
        expect(restored.single.lifecycle, isNot('active'));
      },
    );
  });
}

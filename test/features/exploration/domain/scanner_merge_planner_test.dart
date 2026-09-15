// X4 RED contracts for ScannerMergePlanner (D13).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §4.3:
// - Relic vs Data is a conflict, not an overwrite
// - blank incoming name/notes do not clear stored annotations
// - trashed matching codes start a new episode without inherited notes
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/scanner_import.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  const scope = NotebookScope(
    characterId: kCharacter7,
    systemId: kAlphaSystemId,
  );

  group('D13 F5 coalesce, conflict, preservation', () {
    test('F5 yields 3 unique valid, 1 duplicate, 1 invalid; 2/0/1 counts', () {
      final preview = F5Fixtures.preview();
      expect(
        preview.rows.where((row) => row.valid && !row.duplicate),
        hasLength(3),
      );
      expect(preview.duplicates, 1);
      expect(preview.invalid, 1);
      expect(preview.added, 2);
      expect(preview.updated, 0);
      expect(preview.seenAgain, 1);
      expect(preview.successMessage, F5Fixtures.successMessage);
    });

    test('incoming Relic vs stored Data is a conflict, not updated', () {
      final parsed = ScannerImportParser.parse(
        'ABC-123\tCosmic Signature\tRelic Site\tSansha Data Site',
      );
      final preview = ScannerMergePlanner.plan(
        parsed: parsed,
        scope: scope,
        observedAt: kExplorationT0,
        existing: [F5Fixtures.abcExisting()],
      );
      expect(preview.conflicts, isNotEmpty);
      expect(preview.updated, 0);
      expect(preview.candidates.single.conflict, isTrue);
      expect(preview.candidates.single.preservedName, 'Sansha Data Site');
    });

    test('blank incoming name/notes keep bookmark, notes, firstSeenAt', () {
      final parsed = ScannerImportParser.parse(
        'ABC-123\tCosmic Signature\tData Site\t',
      );
      final preview = ScannerMergePlanner.plan(
        parsed: parsed,
        scope: scope,
        observedAt: kExplorationT0,
        existing: [F5Fixtures.abcExisting()],
      );
      expect(preview.conflicts, isEmpty);
      expect(preview.candidates, isNotEmpty);
      final candidate = preview.candidates.single;
      expect(candidate.preservedNotes, 'Keep this note');
      expect(candidate.preservedBookmark, 'Safe spot');
      expect(candidate.preservedFirstSeenAt, DateTime.utc(2026, 9, 15, 10));
      expect(candidate.preservedName, 'Sansha Data Site');
    });

    test('trashed matching code is a new episode without inherited notes', () {
      final trashed = TrackedSignature(
        id: 'sig-abc',
        characterId: kCharacter7,
        systemId: kAlphaSystemId,
        code: 'ABC-123',
        episodeId: 'episode-abc',
        type: SignatureType.data,
        notes: 'Keep this note',
        firstSeenAt: DateTime.utc(2026, 9, 15, 10),
        lastSeenAt: DateTime.utc(2026, 9, 15, 11),
        state: SignatureState.trash,
      );
      final parsed = ScannerImportParser.parse(
        'ABC-123\tCosmic Signature\tData Site\tSansha Data Site',
      );
      final preview = ScannerMergePlanner.plan(
        parsed: parsed,
        scope: scope,
        observedAt: kExplorationT0,
        existing: [trashed],
      );
      expect(preview.added, 1);
      expect(preview.candidates.single.newEpisode, isTrue);
      expect(preview.candidates.single.preservedNotes, isNull);
    });
  });
}

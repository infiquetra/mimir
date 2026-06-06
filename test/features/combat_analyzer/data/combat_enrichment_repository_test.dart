import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';

void main() {
  group('CombatEnrichmentRepository', () {
    late AppDatabase database;
    late CombatEnrichmentRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = CombatEnrichmentRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('persists and loads enrichment by parsed encounter id', () async {
      final enrichment = CombatEnrichment(
        parsedEncounterId: 'encounter-1',
        status: CombatEnrichmentStatus.killmailMatched,
        source: CombatEnrichmentSource.zkillEsi,
        killmailId: 123,
        killmailHash: 'hash',
        killmailTime: DateTime.utc(2026, 5, 20, 20, 1),
        matchConfidence: 0.82,
        matchReason: 'selected character participated',
        limitations: const ['attacker fit unknown'],
      );

      await repository.saveEnrichment(enrichment);

      final loaded = await repository.loadEnrichment('encounter-1');
      expect(loaded, isNotNull);
      expect(loaded!.status, CombatEnrichmentStatus.killmailMatched);
      expect(loaded.killmailId, 123);
      expect(loaded.matchConfidence, 0.82);
      expect(loaded.limitations, contains('attacker fit unknown'));
    });
  });
}

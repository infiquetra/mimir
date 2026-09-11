import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_fit_derivation_service.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/fitting/presentation/fitting_providers.dart';
import 'package:mimir/features/skills/data/skill_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/sde/sde_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SdeDatabase sdeDb;
  late AppDatabase appDb;
  late CombatFitDerivationService service;

  setUp(() {
    sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
    appDb = AppDatabase.forTesting(NativeDatabase.memory());
    final sde = SdeService(database: sdeDb);
    final skills = SkillRepository(
      database: appDb,
      esiClient: EsiClient(
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        database: appDb,
      ),
    );
    service = CombatFitDerivationService(sde: sde, skills: skills);
  });

  tearDown(() async {
    await sdeDb.close();
    await appDb.close();
  });

  Future<void> seedRifter() async {
    await sdeDb.upsertCategories([
      SdeCategoriesCompanion.insert(
        categoryId: const Value(6),
        categoryName: 'Ship',
      ),
    ]);
    await sdeDb.upsertGroups([
      SdeGroupsCompanion.insert(
        groupId: const Value(25),
        groupName: 'Frigate',
        categoryId: 6,
      ),
    ]);
    await sdeDb.upsertTypes([
      SdeTypesCompanion.insert(
        typeId: const Value(587),
        typeName: 'Rifter',
        groupId: 25,
      ),
    ]);
    await sdeDb.upsertTypeAttributes([
      SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 14, value: 4),
      SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 13, value: 3),
      SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 12, value: 3),
      SdeTypeAttributesCompanion.insert(
        typeId: 587,
        attributeId: 263,
        value: 450,
      ),
      SdeTypeAttributesCompanion.insert(
        typeId: 587,
        attributeId: 265,
        value: 450,
      ),
      SdeTypeAttributesCompanion.insert(
        typeId: 587,
        attributeId: 9,
        value: 350,
      ),
    ]);
  }

  const allFive = AarSkillContext(basis: AarSkillBasis.allFive, skills: []);

  test(
    'T9.4 unknown ship typeId 999999 fails with Ship type not in SDE',
    () async {
      const evidence = FitEvidence(
        role: FitEvidenceRole.pilot,
        source: EvidenceSource.manualFitImport,
        confidence: EvidenceConfidence.confirmed,
        fitting: Fitting(
          id: 'bad',
          name: 'Ghost',
          shipTypeId: 999999,
          shipName: 'Unknown Hull',
        ),
      );
      final result = await service.deriveEvidence(
        evidence,
        subject: AarFitSubject.self,
        skills: allFive,
      );
      expect(result, isA<AarFitDerivationFailed>());
      final failed = result as AarFitDerivationFailed;
      expect(failed.unknown.label, 'Ship type not in SDE');
    },
  );

  test('T9.4b Rifter derivation stats match fittingStatsProvider', () async {
    await seedRifter();
    const fitting = Fitting(
      id: 'rifter',
      name: 'Rifter',
      shipTypeId: 587,
      shipName: 'Rifter',
    );
    const evidence = FitEvidence(
      role: FitEvidenceRole.pilot,
      source: EvidenceSource.manualFitImport,
      confidence: EvidenceConfidence.confirmed,
      fitting: fitting,
    );
    final result = await service.deriveEvidence(
      evidence,
      subject: AarFitSubject.self,
      skills: allFive,
    );
    expect(result, isA<AarFitDerived>());
    final derived = (result as AarFitDerived).derivation.stats;

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(appDb),
        sdeDatabaseProvider.overrideWithValue(sdeDb),
        sdeServiceProvider.overrideWithValue(SdeService(database: sdeDb)),
        activeFittingProvider.overrideWith(
          () => _FixedFittingController(fitting),
        ),
      ],
    );
    addTearDown(container.dispose);
    final providerStats = await container.read(fittingStatsProvider.future);
    expect(providerStats, isNotNull);
    expect(derived, providerStats);
  });

  test(
    'I.3 skillContextFor uses knownCharacter when skills are seeded, else allFive',
    () async {
      await appDb.replaceCharacterSkills(42, [
        CharacterSkillsCompanion.insert(
          characterId: 42,
          skillId: 3419,
          trainedSkillLevel: 5,
          activeSkillLevel: 5,
          skillpointsInSkill: 256000,
          lastUpdated: DateTime.now(),
        ),
      ]);
      await sdeDb.upsertCategories([
        SdeCategoriesCompanion.insert(
          categoryId: const Value(16),
          categoryName: 'Skill',
        ),
      ]);
      await sdeDb.upsertGroups([
        SdeGroupsCompanion.insert(
          groupId: const Value(255),
          groupName: 'Gunnery',
          categoryId: 16,
        ),
      ]);
      await sdeDb.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: const Value(3300),
          typeName: 'Gunnery',
          groupId: 255,
        ),
        SdeTypesCompanion.insert(
          typeId: const Value(3419),
          typeName: 'Shield Management',
          groupId: 255,
        ),
      ]);

      final known = await service.skillContextFor(
        subject: AarFitSubject.self,
        characterId: 42,
      );
      expect(known.basis, AarSkillBasis.knownCharacter);
      expect(known.skills, isNotEmpty);

      final none = await service.skillContextFor(
        subject: AarFitSubject.self,
        characterId: 99,
      );
      expect(none.basis, AarSkillBasis.allFive);
      expect(none.skills.length, 2);
    },
  );

  test(
    'T9.1 deriveForEncounter source calls CombatDamageMatchupAnalyzer.analyze',
    () {
      final source = File(
        'lib/features/combat_analyzer/data/combat_fit_derivation_service.dart',
      ).readAsStringSync();
      expect(source, contains('CombatDamageMatchupAnalyzer.analyze('));
    },
  );
}

class _FixedFittingController extends FittingController {
  _FixedFittingController(this._fitting);
  final Fitting _fitting;

  @override
  Fitting? build() => _fitting;
}

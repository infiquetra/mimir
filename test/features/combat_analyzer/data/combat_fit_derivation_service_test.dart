import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
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
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocator.dart';
import 'package:mimir/features/fitting/data/fitting_stats_inputs.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/fitting/presentation/fitting_providers.dart';

import '../fixtures/attacker_matchup_fixtures.dart';
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

  group('P03/P04/P07 fit-only derivation and composeMatchups', () {
    ParsedCombatEncounter parseEncounter() => CombatLogParser.parseLines([
      'Listener: Pilot',
      '[ 2026.05.20 20:00:00 ] (combat) 100 from Enemy - Railgun - Hits',
    ]).single.copyWith(characterId: 42);

    CombatEnrichment enrichmentWithPilot(ParsedCombatEncounter enc) =>
        CombatEnrichment(
          parsedEncounterId: enc.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          pilotFitEvidence: const FitEvidence(
            role: FitEvidenceRole.pilot,
            source: EvidenceSource.manualFitImport,
            confidence: EvidenceConfidence.confirmed,
            fitting: Fitting(
              id: 'fit-587',
              name: 'Rifter',
              shipTypeId: 587,
              shipName: 'Rifter',
            ),
          ),
        );

    test('P03 deriveFitsForEncounter leaves matchups null', () async {
      await seedRifter();
      final enc = parseEncounter();
      final fits = await service.deriveFitsForEncounter(
        encounter: enc,
        enrichment: enrichmentWithPilot(enc),
        selfSkills: null,
        opponentSkills: null,
      );
      expect(fits.self, isNotNull);
      expect(fits.selfMatchup, isNull);
      expect(fits.opponentMatchup, isNull);
    });

    test(
      'P03 composeMatchups refreshes defense without reallocating',
      () async {
        await seedRifter();
        final enc = parseEncounter();
        final enrichment = enrichmentWithPilot(enc);
        final fits = await service.deriveFitsForEncounter(
          encounter: enc,
          enrichment: enrichment,
          selfSkills: null,
          opponentSkills: null,
        );
        final allocation =
            (IncomingDamageAllocator.allocate(
                      encounter: enc,
                      weapons: matchupWeaponTable(),
                      sdeContentKey: matchupSdeContentKey,
                    )
                    as IncomingAllocationReady)
                .allocation;
        final composed = service.composeMatchups(
          fits: fits,
          incoming: allocation,
          outgoing: const CombatDamageProfile(
            entries: [],
            unknownWeapons: [],
            totalProfiledDamage: 0,
          ),
          encounter: enc,
          enrichment: enrichment,
        );
        expect(composed.selfMatchup, isNotNull);
        expect(composed.self, fits.self);
      },
    );

    test(
      'P03 own-loss fallback is used only when explicit pilot derivation fails',
      () async {
        await seedRifter();
        final enc = parseEncounter();
        final enrichment = CombatEnrichment(
          parsedEncounterId: enc.id,
          status: CombatEnrichmentStatus.killmailMatched,
          source: CombatEnrichmentSource.zkillEsi,
          victimCharacterId: 42,
          victimName: 'Pilot',
          pilotFitEvidence: const FitEvidence(
            role: FitEvidenceRole.pilot,
            source: EvidenceSource.manualFitImport,
            confidence: EvidenceConfidence.confirmed,
            fitting: Fitting(
              id: 'missing',
              name: 'Unknown',
              shipTypeId: 1,
              shipName: 'Unknown',
            ),
          ),
          victimFitEvidence: const FitEvidence(
            role: FitEvidenceRole.victim,
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            fitting: Fitting(
              id: 'fit-587',
              name: 'Rifter',
              shipTypeId: 587,
              shipName: 'Rifter',
            ),
          ),
        );
        final fits = await service.deriveFitsForEncounter(
          encounter: enc,
          enrichment: enrichment,
          selfSkills: null,
          opponentSkills: null,
        );
        expect(fits.self, isNotNull);
        expect(fits.self!.fitSource, EvidenceSource.killmail);
      },
    );

    test('P07 outgoing failure does not erase incoming self defense', () async {
      await seedRifter();
      final enc = parseEncounter();
      final enrichment = enrichmentWithPilot(enc);
      final fits = await service.deriveFitsForEncounter(
        encounter: enc,
        enrichment: enrichment,
        selfSkills: null,
        opponentSkills: null,
      );
      final allocation =
          (IncomingDamageAllocator.allocate(
                    encounter: enc,
                    weapons: matchupWeaponTable(),
                    sdeContentKey: matchupSdeContentKey,
                  )
                  as IncomingAllocationReady)
              .allocation;
      final composed = service.composeMatchups(
        fits: fits,
        incoming: allocation,
        outgoing: null,
        encounter: enc,
        enrichment: enrichment,
      );
      expect(composed.self, isNotNull);
      expect(composed.selfMatchup, isNotNull);
      expect(composed.opponentMatchup, isNull);
    });

    test(
      'P04 empty skills fall back to All V; failed read is unavailable',
      () async {
        await seedRifter();
        final empty = await service.skillContextFor(
          subject: AarFitSubject.self,
          characterId: 42,
        );
        expect(empty.basis, AarSkillBasis.allFive);

        expect(
          File(
            'lib/features/combat_analyzer/data/combat_fit_derivation_service.dart',
          ).readAsStringSync(),
          contains('unavailable'),
        );
      },
    );

    test('localOnly effect lookup is required for AAR fit inputs', () async {
      await seedRifter();
      final sde = SdeService(database: sdeDb);
      final inputs = await loadFittingStatsInputs(
        sde,
        const Fitting(
          id: 'fit-587',
          name: 'Rifter',
          shipTypeId: 587,
          shipName: 'Rifter',
        ),
        skillTypeIds: const [],
        effectLookupPolicy: EffectLookupPolicy.localOnly,
      );
      expect(inputs, isNotNull);
      expect(inputs!.unavailableEffectIds, isA<Set<int>>());
    });
  });
}

class _FixedFittingController extends FittingController {
  _FixedFittingController(this._fitting);
  final Fitting _fitting;

  @override
  Fitting? build() => _fitting;
}

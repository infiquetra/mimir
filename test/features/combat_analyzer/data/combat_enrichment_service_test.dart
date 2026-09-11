import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('CombatEnrichmentService.attachDerivedEvidence', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late CombatEnrichmentService service;

    setUp(() {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      service = CombatEnrichmentService(
        repository: CombatEnrichmentRepository(database: appDb),
        esiClient: EsiClient(
          tokenManager: TokenManager(database: appDb),
          oauthService: OAuthService(),
          database: appDb,
        ),
        discoveryClient: CombatKillmailDiscoveryClient(),
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        sdeService: SdeService(database: sdeDb),
      );
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    test(
      'G.7 attachDerivedEvidence twice does not duplicate facts or unknowns',
      () async {
        const enrichment = CombatEnrichment(
          parsedEncounterId: 'enc-1',
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
        );
        final derivation = AarFitDerivation(
          role: FitEvidenceRole.pilot,
          subject: AarFitSubject.self,
          fitSource: EvidenceSource.manualFitImport,
          shipTypeId: 587,
          shipName: 'Rifter',
          skills: const AarSkillContext(
            basis: AarSkillBasis.allFive,
            skills: [],
          ),
          stats: const FittingStats(defenses: DefenseProfile(totalEhp: 1809)),
          baseline: const FittingStats(),
          tank: const TankAssessment(
            layer: TankLayer.armor,
            mode: TankMode.unfitted,
            shieldBoostHps: 0,
            armorRepairHps: 0,
            hullRepairHps: 0,
            shieldGainEhp: 0,
            armorGainEhp: 0,
            hullGainEhp: 0,
            reasoning: 'Armor (unfitted)',
          ),
          coverage: const AarFitCoverage(
            highFitted: 0,
            highSlots: 4,
            medFitted: 0,
            medSlots: 3,
            lowFitted: 0,
            lowSlots: 3,
            rigFitted: 0,
            rigSlots: 3,
            subsystemFitted: 0,
            subsystemSlots: 0,
            unresolvedTypeIds: [],
            unresolvedNames: [],
          ),
          derivedAt: DateTime.utc(2026, 9, 11),
          limitations: const ['assumes All V'],
        );
        final bundle = AarDerivationBundle(
          self: derivation,
          unknowns: const [
            AarUnknown(
              category: AarUnknownCategory.opponentFit,
              label: 'Opponent defense profile',
              detail: 'No opponent fit evidence.',
            ),
            AarUnknown(
              category: AarUnknownCategory.skills,
              label: 'Pilot skills',
              detail: 'assumes All V',
            ),
          ],
        );

        final first = await service.attachDerivedEvidence(
          enrichment,
          bundle,
          encounterId: 'enc-1',
        );
        final derivedFacts = first.evidenceLedger.facts
            .where((f) => f.source == EvidenceSource.dogmaDerivation)
            .toList();
        expect(derivedFacts, isNotEmpty);

        final second = await service.attachDerivedEvidence(
          first,
          bundle,
          encounterId: 'enc-1',
        );
        expect(
          second.evidenceLedger.facts
              .where((f) => f.source == EvidenceSource.dogmaDerivation)
              .length,
          derivedFacts.length,
        );

        final unknownKeys = second.evidenceLedger.unknowns
            .map((u) => '${u.category.name}|${u.label}')
            .toList();
        expect(unknownKeys.toSet().length, unknownKeys.length);
      },
    );
  });
}

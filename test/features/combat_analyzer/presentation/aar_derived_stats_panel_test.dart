import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_derived_facts.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_derived_stats_panel.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_matchup_section.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group J — AarDerivedStatsPanel / AarMatchupSection', () {
    final derivedAt = DateTime.utc(2026, 9, 11, 12);

    AarFitDerivation derivation({
      AarFitSubject subject = AarFitSubject.self,
      AarSkillBasis basis = AarSkillBasis.allFive,
      FitEvidenceRole role = FitEvidenceRole.pilot,
      int shipTypeId = 587,
      String shipName = 'Rifter',
    }) {
      final skills = AarSkillContext(
        basis: basis,
        skills: const [],
        characterId: basis == AarSkillBasis.knownCharacter ? 42 : null,
      );
      return AarFitDerivation(
        role: role,
        subject: subject,
        fitSource: EvidenceSource.manualFitImport,
        shipTypeId: shipTypeId,
        shipName: shipName,
        skills: skills,
        stats: const FittingStats(
          cpuMax: 156.25,
          capacitorCapacity: 250,
          capacitorRecharge: 125000,
          capacitorStable: 41,
          isCapStable: true,
          dpsTotal: 312.4,
          dpsGuns: 210,
          dpsDrones: 102.4,
          volley: 890,
          maxVelocity: 1234,
          signatureRadius: 42,
          alignTime: 4.7,
          defenses: DefenseProfile(
            shieldHp: 1550,
            armorHp: 450,
            hullHp: 350,
            shieldEhp: 2137,
            armorEhp: 667,
            hullEhp: 522,
            totalEhp: 12345,
            effectiveArmorRepair: 84.3,
            peakShieldRecharge: 6.3,
            shieldResists: ResistProfile(
              em: 0,
              thermal: 20,
              kinetic: 40,
              explosive: 50,
            ),
          ),
        ),
        baseline: const FittingStats(),
        tank: const TankAssessment(
          layer: TankLayer.armor,
          mode: TankMode.active,
          shieldBoostHps: 0,
          armorRepairHps: 84.3,
          hullRepairHps: 0,
          shieldGainEhp: 3586,
          armorGainEhp: 0,
          hullGainEhp: 0,
          reasoning:
              'Armor (active): 84.3 HP/s armor repair vs 0.0 shield boost.',
        ),
        coverage: const AarFitCoverage(
          highFitted: 3,
          highSlots: 4,
          medFitted: 1,
          medSlots: 3,
          lowFitted: 1,
          lowSlots: 3,
          rigFitted: 0,
          rigSlots: 3,
          subsystemFitted: 0,
          subsystemSlots: 0,
          unresolvedTypeIds: [],
          unresolvedNames: [],
        ),
        derivedAt: derivedAt,
        limitations: [skills.label, 'Module states assumed active'],
      );
    }

    ParsedCombatEncounter encounter() => CombatLogParser.parseLines([
      'Listener: Pilot',
      '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
    ]).single;

    nameOverrides() => [
      itemNameProvider(587).overrideWith((ref) async => 'Rifter'),
      itemNameProvider(24700).overrideWith((ref) async => 'Myrmidon'),
    ];

    Future<void> pumpUntilSettled(WidgetTester tester) async {
      await tester.pump();
      await tester.pumpAndSettle();
    }

    Future<void> pumpPanel(
      WidgetTester tester, {
      required AarFitDerivation derived,
      CombatDamageMatchup? matchup,
      String title = 'Pilot Fit',
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: nameOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 2000,
                child: AarDerivedStatsPanel(
                  derivation: derived,
                  title: title,
                  matchup: matchup,
                ),
              ),
            ),
          ),
        ),
      );
      await pumpUntilSettled(tester);
    }

    Future<void> pumpHarness(
      WidgetTester tester, {
      required ParsedCombatEncounter enc,
      required AarDerivationBundle bundle,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...nameOverrides(),
            aarFitDerivationsProvider.overrideWith((ref, encounter) => bundle),
          ],
          child: MaterialApp(
            home: Scaffold(body: _DerivationHarness(encounter: enc)),
          ),
        ),
      );
      await pumpUntilSettled(tester);
    }

    testWidgets(
      'T10.1 panel shows EHP (omni), Tank chip with mode/layer, DPS, and capacitor status',
      (tester) async {
        await pumpPanel(tester, derived: derivation());
        expect(find.textContaining('EHP (omni)'), findsOneWidget);
        expect(find.textContaining('Tank'), findsWidgets);
        expect(find.textContaining('Armor (active)'), findsOneWidget);
        expect(find.textContaining('DPS'), findsWidgets);
        expect(
          find.textContaining('Stable').evaluate().isNotEmpty ||
              find.textContaining('Empty in').evaluate().isNotEmpty ||
              find.text('—').evaluate().isNotEmpty,
          isTrue,
          reason: 'capacitor row should show Stable, Empty in, or —',
        );
      },
    );

    testWidgets('T10.4 empty bundle renders no AarDerivedStatsPanel', (
      tester,
    ) async {
      final enc = encounter();
      await pumpHarness(
        tester,
        enc: enc,
        bundle: const AarDerivationBundle.empty(),
      );
      expect(find.byType(AarDerivedStatsPanel), findsNothing);
    });

    testWidgets('T10.5 self and opponent bundles render two panels', (
      tester,
    ) async {
      final enc = encounter();
      final self = derivation();
      final opponent = derivation(
        subject: AarFitSubject.opponent,
        role: FitEvidenceRole.victim,
        shipTypeId: 24700,
        shipName: 'Myrmidon',
        basis: AarSkillBasis.knownCharacter,
      );
      await pumpHarness(
        tester,
        enc: enc,
        bundle: AarDerivationBundle(self: self, opponent: opponent),
      );
      expect(find.byType(AarDerivedStatsPanel), findsNWidgets(2));
      expect(find.textContaining('EHP (omni)'), findsNWidgets(2));
    });

    testWidgets('T10.6 All V basis shows assumes All V badge', (tester) async {
      await pumpPanel(tester, derived: derivation());
      expect(find.text('assumes All V'), findsOneWidget);
    });

    testWidgets('T10.7 itemNameProvider override shows Rifter, not Item #', (
      tester,
    ) async {
      await pumpPanel(tester, derived: derivation(shipName: 'Item #587'));
      expect(find.text('Rifter'), findsWidgets);
      expect(find.textContaining('Item #'), findsNothing);
    });

    testWidgets(
      'J.8 matchup with defense == null shows Resist profile unknown and no percent rows',
      (tester) async {
        final matchup = CombatDamageMatchupAnalyzer.analyze(
          profile: const CombatDamageProfile(
            totalProfiledDamage: 100,
            unknownWeapons: [],
            entries: [
              CombatDamageTypeEstimate(
                type: 'Kinetic',
                amount: 100,
                percent: 1,
                confidence: CombatDamageConfidence.sdeExact,
                source: 'Scourge Rocket',
                evidence: 'SDE damage attributes',
              ),
            ],
          ),
          defense: null,
          targetLabel: 'Rifter',
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: AarMatchupSection(matchup: matchup)),
            ),
          ),
        );
        await pumpUntilSettled(tester);
        expect(find.textContaining('Resist profile unknown'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);
      },
    );

    testWidgets(
      'T7.5 every derived fact value appears in the rendered panel text',
      (tester) async {
        final derived = derivation();
        await pumpPanel(tester, derived: derived);
        final facts = AarDerivedFactsBuilder.facts(
          derived,
          encounterId: 'enc-1',
        );
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
            .join('\n');
        expect(facts, isNotEmpty);
        expect(texts, isNotEmpty, reason: 'panel rendered no Text widgets');
        for (final fact in facts) {
          for (final token in _numberTokens(fact.value)) {
            expect(
              _panelContainsNumber(texts, token),
              isTrue,
              reason:
                  'panel missing "$token" from fact ${fact.id}: ${fact.value}',
            );
          }
        }
      },
    );
  });
}

class _DerivationHarness extends ConsumerWidget {
  const _DerivationHarness({required this.encounter});

  final ParsedCombatEncounter encounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aarFitDerivationsProvider(encounter));
    return async.when(
      data: (bundle) => Column(
        children: [
          if (bundle.self != null)
            AarDerivedStatsPanel(derivation: bundle.self!, title: 'Pilot Fit'),
          if (bundle.opponent != null)
            AarDerivedStatsPanel(
              derivation: bundle.opponent!,
              title: 'Destroyed Ship Fit',
            ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Text('Error: $error'),
    );
  }
}

Iterable<String> _numberTokens(String value) {
  return RegExp(
    r'\d[\d,]*(?:\.\d+)?',
  ).allMatches(value).map((m) => m.group(0)!);
}

bool _panelContainsNumber(String texts, String token) {
  if (texts.contains(token)) return true;
  final stripped = token.replaceFirst(RegExp(r'\.0+$'), '');
  return stripped != token && texts.contains(stripped);
}

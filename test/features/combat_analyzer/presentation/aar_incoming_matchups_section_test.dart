import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup_deriver.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocator.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_incoming_matchups_section.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';

import '../fixtures/attacker_matchup_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AarIncomingMatchupsSection U01–U03 U07–U08 U10', () {
    nameOverrides() => [
      itemNameProvider.overrideWith((ref, id) async {
        return switch (id) {
          24702 => 'Hurricane',
          34828 => 'Jackdaw',
          587 => 'Rifter',
          30001 => 'Serpentis Watchman',
          _ => 'Unknown ship',
        };
      }),
    ];

    Future<void> pumpSection(
      WidgetTester tester, {
      required ParsedCombatEncounter encounter,
      required AarIncomingMatchupState state,
      Size size = const Size(1400, 1200),
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...nameOverrides(),
            aarIncomingMatchupsProvider.overrideWith((ref, enc) => state),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: AarIncomingMatchupsSection(encounter: encounter),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'U01 solo card is expanded, aggregate reference collapsed, no advisory',
      (tester) async {
        final s1 = s1Solo();
        final bundle = deriveUiBundle(s1);
        await pumpSection(
          tester,
          encounter: s1.encounter,
          state: readyState(bundle),
        );
        final source = bundle.attackers.single.source.allocation;
        expect(find.byKey(overviewKey(bundle.encounterId)), findsOneWidget);
        expect(
          find.byKey(sourceKey(bundle.encounterId, source.sourceId, 'card')),
          findsOneWidget,
        );
        expect(
          find.byKey(sourceKey(bundle.encounterId, source.sourceId, 'ehp')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('aar-incoming-${bundle.encounterId}-blend-advisory')),
          findsNothing,
        );
        expect(find.text('Incoming Sources'), findsNothing);
        expect(find.textContaining('4,000'), findsWidgets);
      },
    );

    testWidgets(
      'U02 Fixture A fleet cards, 60/40 shares, blend advisory in aggregate',
      (tester) async {
        final s2 = s2Fleet();
        final bundle = deriveUiBundle(s2);
        await pumpSection(
          tester,
          encounter: s2.encounter,
          state: readyState(bundle),
        );
        final kite = bundle.attackers.firstWhere(
          (a) => a.source.allocation.rawActorName == 'Kite Mondeo',
        );
        final artem = bundle.attackers.firstWhere(
          (a) => a.source.allocation.rawActorName == 'Artem S3',
        );
        expect(
          kite.source.allocation.loggedDamage,
          greaterThan(artem.source.allocation.loggedDamage),
        );
        final kiteCard = find.byKey(
          sourceKey(
            bundle.encounterId,
            kite.source.allocation.sourceId,
            'card',
          ),
        );
        final artemCard = find.byKey(
          sourceKey(
            bundle.encounterId,
            artem.source.allocation.sourceId,
            'card',
          ),
        );
        expect(kiteCard, findsOneWidget);
        expect(artemCard, findsOneWidget);
        expect(
          tester.getTopLeft(kiteCard).dy,
          lessThan(tester.getTopLeft(artemCard).dy),
        );
        expect(
          find.byKey(Key('aar-incoming-${bundle.encounterId}-blend-advisory')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            Key('aar-incoming-${bundle.encounterId}-aggregate-defense'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('60'), findsWidgets);
        expect(find.textContaining('40'), findsWidgets);
        expect(find.textContaining('1,176'), findsWidgets);
        expect(find.textContaining('1,429'), findsWidgets);
      },
    );

    testWidgets(
      'U03 Fixture B residuals: X/N groups, Possible only in X, U included',
      (tester) async {
        final s3 = s3Residuals();
        final bundle = deriveUiBundle(s3);
        await pumpSection(
          tester,
          encounter: s3.encounter,
          state: readyState(bundle),
        );
        expect(
          find.byKey(Key('aar-incoming-${bundle.encounterId}-unattributed')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('aar-incoming-${bundle.encounterId}-npc')),
          findsOneWidget,
        );
        expect(find.textContaining('Possible match to Bravo'), findsOneWidget);
        expect(find.textContaining('already included'), findsWidgets);
        expect(bundle.attackers, hasLength(1));
        expect(
          find.byKey(
            sourceKey(
              bundle.encounterId,
              bundle.unattributed.first.allocation.sourceId,
              'ehp',
            ),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('U07 state matrix: empty, loading, invalid, error, retry', (
      tester,
    ) async {
      final emptyEnc = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
      ]).single;
      final t0 = emptyEnc;
      await pumpSection(
        tester,
        encounter: t0,
        state: AarIncomingMatchupState(
          encounterId: t0.id,
          allocationRequestKey: 'empty',
          identityRequestKey: 'id',
          allocationStatus: AarIncomingDependencyStatus.ready,
          correlationStatus: AarIncomingDependencyStatus.ready,
          classificationStatus: AarIncomingDependencyStatus.ready,
          defenseStatus: AarIncomingDependencyStatus.ready,
        ),
      );
      expect(find.byKey(Key('aar-incoming-${t0.id}-empty')), findsOneWidget);
      expect(find.text('No incoming damage'), findsOneWidget);

      await pumpSection(
        tester,
        encounter: emptyEnc,
        state: AarIncomingMatchupState(
          encounterId: emptyEnc.id,
          allocationRequestKey: 'load',
          identityRequestKey: 'id',
          allocationStatus: AarIncomingDependencyStatus.loading,
          correlationStatus: AarIncomingDependencyStatus.loading,
          classificationStatus: AarIncomingDependencyStatus.loading,
          defenseStatus: AarIncomingDependencyStatus.loading,
        ),
      );
      expect(
        find.byKey(Key('aar-incoming-${emptyEnc.id}-loading')),
        findsOneWidget,
      );

      await pumpSection(
        tester,
        encounter: emptyEnc,
        state: AarIncomingMatchupState(
          encounterId: emptyEnc.id,
          allocationRequestKey: 'bad',
          identityRequestKey: 'id',
          allocationStatus: AarIncomingDependencyStatus.invalid,
          correlationStatus: AarIncomingDependencyStatus.ready,
          classificationStatus: AarIncomingDependencyStatus.ready,
          defenseStatus: AarIncomingDependencyStatus.ready,
          issueCodes: const ['eventTotalsMismatch'],
        ),
      );
      expect(
        find.byKey(Key('aar-incoming-${emptyEnc.id}-invalid')),
        findsOneWidget,
      );
      expect(find.text('Incoming totals are inconsistent'), findsOneWidget);

      await pumpSection(
        tester,
        encounter: emptyEnc,
        state: AarIncomingMatchupState(
          encounterId: emptyEnc.id,
          allocationRequestKey: 'err',
          identityRequestKey: 'id',
          allocationStatus: AarIncomingDependencyStatus.error,
          correlationStatus: AarIncomingDependencyStatus.ready,
          classificationStatus: AarIncomingDependencyStatus.ready,
          defenseStatus: AarIncomingDependencyStatus.ready,
        ),
      );
      expect(
        find.byKey(Key('aar-incoming-${emptyEnc.id}-error')),
        findsOneWidget,
      );
      expect(find.text('Incoming profile unavailable'), findsOneWidget);
      expect(
        find.byKey(Key('aar-incoming-${emptyEnc.id}-retry')),
        findsOneWidget,
      );

      await pumpSection(
        tester,
        encounter: emptyEnc,
        state: AarIncomingMatchupState(
          encounterId: emptyEnc.id,
          allocationRequestKey: 'attr',
          identityRequestKey: 'id',
          allocationStatus: AarIncomingDependencyStatus.ready,
          correlationStatus: AarIncomingDependencyStatus.unavailable,
          classificationStatus: AarIncomingDependencyStatus.ready,
          defenseStatus: AarIncomingDependencyStatus.unavailable,
        ),
      );
      expect(find.text('Attribution unavailable'), findsOneWidget);
      expect(find.text('Pilot defense unavailable'), findsOneWidget);
    });

    testWidgets(
      'U08 largest card starts open; user collapse survives refresh; encounter resets',
      (tester) async {
        final s2 = s2Fleet();
        final bundle = deriveUiBundle(s2);
        await pumpSection(
          tester,
          encounter: s2.encounter,
          state: readyState(bundle),
        );
        final kite = bundle.attackers.firstWhere(
          (a) => a.source.allocation.rawActorName == 'Kite Mondeo',
        );
        final artem = bundle.attackers.firstWhere(
          (a) => a.source.allocation.rawActorName == 'Artem S3',
        );
        final kiteEvidence = sourceKey(
          bundle.encounterId,
          kite.source.allocation.sourceId,
          'evidence',
        );
        final artemHeader = sourceKey(
          bundle.encounterId,
          artem.source.allocation.sourceId,
          'header',
        );
        expect(find.byKey(kiteEvidence), findsOneWidget);
        expect(
          find.byKey(
            sourceKey(
              bundle.encounterId,
              artem.source.allocation.sourceId,
              'evidence',
            ),
          ),
          findsNothing,
        );
        await tester.tap(find.byKey(artemHeader));
        await tester.pump();
        expect(
          find.byKey(
            sourceKey(
              bundle.encounterId,
              artem.source.allocation.sourceId,
              'evidence',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(artemHeader));
        await tester.pump();
        await pumpSection(
          tester,
          encounter: s2.encounter,
          state: readyState(bundle),
        );
        expect(
          find.byKey(
            sourceKey(
              bundle.encounterId,
              artem.source.allocation.sourceId,
              'evidence',
            ),
          ),
          findsNothing,
          reason: 'user-collapsed card must stay collapsed across refresh',
        );

        final s1 = s1Solo();
        await pumpSection(
          tester,
          encounter: s1.encounter,
          state: readyState(deriveUiBundle(s1)),
        );
        expect(
          find.byKey(
            sourceKey(
              bundle.encounterId,
              kite.source.allocation.sourceId,
              'card',
            ),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('U10 360px has no overflow; 720px shows split and EHP', (
      tester,
    ) async {
      final s2 = s2Fleet();
      final bundle = deriveUiBundle(s2);
      final kite = bundle.attackers.first.source.allocation;
      FlutterErrorDetails? overflow;
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflow = details;
        }
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      await pumpSection(
        tester,
        encounter: s2.encounter,
        state: readyState(bundle),
        size: const Size(360, 800),
        textScale: 2.0,
      );
      expect(overflow, isNull);
      final header = find.byKey(
        sourceKey(bundle.encounterId, kite.sourceId, 'header'),
      );
      expect(header, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      await pumpSection(
        tester,
        encounter: s2.encounter,
        state: readyState(bundle),
        size: const Size(720, 900),
      );
      expect(
        find.byKey(sourceKey(bundle.encounterId, kite.sourceId, 'split')),
        findsOneWidget,
      );
      expect(
        find.byKey(sourceKey(bundle.encounterId, kite.sourceId, 'ehp')),
        findsOneWidget,
      );
    });
  });
}

Key overviewKey(String encounterId) =>
    Key('aar-incoming-$encounterId-overview');

Key sourceKey(String encounterId, String sourceId, String part) =>
    Key('aar-incoming-$encounterId-$sourceId-$part');

AarIncomingMatchupState readyState(AarIncomingMatchupBundle bundle) {
  return AarIncomingMatchupState(
    encounterId: bundle.encounterId,
    allocationRequestKey: bundle.allocation.allocationKey,
    identityRequestKey: 'identity',
    fitRequestKey: 'fit-a',
    bundle: bundle,
    allocationStatus: AarIncomingDependencyStatus.ready,
    correlationStatus: AarIncomingDependencyStatus.ready,
    classificationStatus: AarIncomingDependencyStatus.ready,
    defenseStatus: AarIncomingDependencyStatus.ready,
  );
}

AarIncomingMatchupBundle deriveUiBundle(
  ({
    ParsedCombatEncounter encounter,
    EsiKillmailDetail detail,
    AttackerCorrelation correlation,
    CombatEnrichment enrichment,
  })
  scenario, {
  AarFitDerivation? fit,
  Map<String, IncomingWeaponResolution> extraWeapons = const {},
}) {
  final result = IncomingDamageAllocator.allocate(
    encounter: scenario.encounter,
    weapons: matchupWeaponTable(extraWeapons),
    sdeContentKey: matchupSdeContentKey,
  );
  final allocation = (result as IncomingAllocationReady).allocation;
  return AarAttackerMatchupDeriver.derive(
    allocation: allocation,
    correlation: matchupCorrelationContext(
      encounter: scenario.encounter,
      detail: scenario.detail,
      correlation: scenario.correlation,
    ),
    pilotFit: fit ?? fixtureAPilotFit(),
    pilotFitEvidence: fixtureAPilotFitEvidence(),
    pilotFitKey: 'fit-a',
    dependencyLimitations: const [],
  );
}

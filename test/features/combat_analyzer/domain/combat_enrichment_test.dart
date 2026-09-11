import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';

import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  group('Group D — CombatEnrichment killmailSearchCompleted', () {
    CombatEnrichment enrichment({
      CombatEnrichmentStatus status = CombatEnrichmentStatus.logOnly,
      String matchReason = '',
      bool killmailSearchCompleted = false,
    }) {
      return CombatEnrichment(
        parsedEncounterId: 'enc-1',
        status: status,
        source: CombatEnrichmentSource.none,
        matchReason: matchReason,
        killmailSearchCompleted: killmailSearchCompleted,
      );
    }

    Map<String, dynamic> legacyJson({
      required CombatEnrichmentStatus status,
      required String matchReason,
    }) {
      return {
        'parsedEncounterId': 'enc-1',
        'status': status.name,
        'source': CombatEnrichmentSource.none.name,
        'matchReason': matchReason,
        'matchConfidence': 0,
        'limitations': <String>[],
      };
    }

    test('D.4 killmailSearchCompleted round-trips', () {
      for (final flag in [true, false]) {
        final json = enrichment(killmailSearchCompleted: flag).toJson();
        expect(json['killmailSearchCompleted'], flag);
        expect(CombatEnrichment.fromJson(json).killmailSearchCompleted, flag);
      }
    });

    test(
      'D.5 legacy row without the key: logOnly + uncached reason → false',
      () {
        final decoded = CombatEnrichment.fromJson(
          legacyJson(
            status: CombatEnrichmentStatus.logOnly,
            matchReason: CombatEnrichment.uncachedMatchReason,
          ),
        );
        expect(decoded.killmailSearchCompleted, isFalse);
      },
    );

    test('D.6 legacy row without the key: logOnly + search reason → true', () {
      expect(
        CombatEnrichment.fromJson(
          legacyJson(
            status: CombatEnrichmentStatus.logOnly,
            matchReason: 'No ESI or zKill killmail matched this encounter.',
          ),
        ).killmailSearchCompleted,
        isTrue,
      );
      expect(
        CombatEnrichment.fromJson(
          legacyJson(
            status: CombatEnrichmentStatus.killmailMatched,
            matchReason: 'ESI recent killmail within the encounter window.',
          ),
        ).killmailSearchCompleted,
        isTrue,
      );
      expect(
        CombatEnrichment.fromJson(
          legacyJson(
            status: CombatEnrichmentStatus.needsReauth,
            matchReason: 'Killmail scope is missing.',
          ),
        ).killmailSearchCompleted,
        isTrue,
      );
    });

    test('D.6 copyWith preserves killmailSearchCompleted', () {
      final original = enrichment(killmailSearchCompleted: true);
      expect(original.copyWith().killmailSearchCompleted, isTrue);
      expect(
        original.copyWith(matchReason: 'updated').killmailSearchCompleted,
        isTrue,
      );
      expect(
        original
            .copyWith(killmailSearchCompleted: false)
            .killmailSearchCompleted,
        isFalse,
      );
    });

    test('D.7 toPromptJson never contains killmailSearchCompleted', () {
      final withoutSearch = enrichment(killmailSearchCompleted: false);
      final withSearch = withoutSearch.copyWith(killmailSearchCompleted: true);
      expect(withoutSearch.toPromptJson(), withSearch.toPromptJson());
      expect(
        withoutSearch.toPromptJson().containsKey('killmailSearchCompleted'),
        isFalse,
      );
      expect(
        withSearch.toPromptJson().containsKey('killmailSearchCompleted'),
        isFalse,
      );
    });
  });

  group('Group E — CombatEnrichment attackerCorrelation', () {
    CombatEnrichment base({AttackerCorrelation? attackerCorrelation}) {
      return CombatEnrichment(
        parsedEncounterId: 'enc-1',
        status: CombatEnrichmentStatus.killmailMatched,
        source: CombatEnrichmentSource.esiRecent,
        attackerCorrelation: attackerCorrelation,
      );
    }

    test(
      'T5.2 attackerCorrelation round-trips through CombatEnrichment JSON',
      () {
        final correlation = correlate(s2Loss());
        final enrichment = base(attackerCorrelation: correlation);
        expect(enrichment.toJson().containsKey('attackerCorrelation'), isTrue);
        final decoded = CombatEnrichment.fromJson(enrichment.toJson());
        expect(decoded.attackerCorrelation, isNotNull);
        expect(
          decoded.attackerCorrelation!.toJson(),
          enrichment.attackerCorrelation!.toJson(),
        );
      },
    );

    test('T5.3 pre-milestone JSON without the field loads with null', () {
      final decoded = CombatEnrichment.fromJson({
        'parsedEncounterId': 'enc-1',
        'status': CombatEnrichmentStatus.logOnly.name,
        'source': CombatEnrichmentSource.none.name,
        'matchReason': CombatEnrichment.uncachedMatchReason,
        'matchConfidence': 0,
        'limitations': <String>[],
      });
      expect(decoded.attackerCorrelation, isNull);
    });

    test(
      'attackerCorrelation is included in toPromptJson in compact form when present, omitted when null',
      () {
        final correlation = correlate(s2Loss());
        final withCorrelation = base(attackerCorrelation: correlation);
        expect(
          withCorrelation.toPromptJson().containsKey('attackerCorrelation'),
          isTrue,
        );
        final block =
            withCorrelation.toPromptJson()['attackerCorrelation']
                as Map<String, dynamic>;
        expect(block, correlation.toPromptJson());
        expect(block.keys.toSet(), {
          'selfIsVictim',
          'correlated',
          'unattributedIncomingDamage',
          'npcIncomingDamage',
          'uncorrelatedAttackerCount',
          'uncorrelatedAttackers',
        });
        expect(
          base().toPromptJson().containsKey('attackerCorrelation'),
          isFalse,
        );
      },
    );
  });
}

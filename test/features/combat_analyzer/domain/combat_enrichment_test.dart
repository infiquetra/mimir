import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';

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
}

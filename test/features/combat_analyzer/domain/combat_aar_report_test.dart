import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';

void main() {
  group('CombatAarReport', () {
    test('parses v2 key moments and damage analysis', () {
      final report = CombatAarReport.fromJson({
        'version': 2,
        'headline': 'Drone application decided the fight',
        'summary': 'Summary',
        'outcomeAssessment': 'Outcome',
        'keyMoments': [
          {
            'timestamp': '20:00:05',
            'relativeSecond': 5,
            'category': 'pressure',
            'severity': 'high',
            'title': 'Scram pressure established',
            'details': 'Control changed the engagement.',
            'eventIds': ['e2'],
          },
        ],
        'rankedMistakes': [],
        'recommendations': [],
        'fitAdvice': [],
        'trainingDrills': [],
        'damageAnalysis': {
          'summary': 'Thermal drones carried damage.',
          'evidence': 'e2-e4',
          'damageTypes': [
            {
              'type': 'Thermal',
              'percent': 1.0,
              'amount': 600,
              'confidence': 'sde_exact',
              'source': 'Hobgoblin II',
              'evidence': 'Exact SDE match',
            },
          ],
          'defenseNotes': [
            {
              'layer': 'unknown',
              'note': 'Layer depletion is not present in the combat log.',
              'confidence': 'unknown',
              'evidence': 'No killmail or fit data supplied',
            },
          ],
          'confidence': 0.8,
          'unknowns': ['Target fit'],
        },
        'resourceTopicIds': ['drone_application'],
        'confidence': 0.9,
        'unknowns': [],
      });

      expect(report.keyMoments.single.relativeSecond, 5);
      expect(report.keyMoments.single.category, 'pressure');
      expect(report.damageAnalysis.summary, contains('Thermal'));
      expect(report.damageAnalysis.damageTypes.single.type, 'Thermal');
      expect(report.damageAnalysis.defenseNotes.single.confidence, 'unknown');
      expect(report.toJson()['version'], CombatAarReport.version);
    });

    test('keeps legacy prose reports readable', () {
      final report = CombatAarReport.fromJson({
        'summary': 'Summary',
        'mistakes': 'Mistake',
        'improvements': 'Improve',
        'fits': 'Fit',
      });

      expect(report.headline, 'Combat Review');
      expect(report.mistakesText, 'Mistake');
      expect(report.damageAnalysis.isEmpty, isTrue);
    });
  });
}

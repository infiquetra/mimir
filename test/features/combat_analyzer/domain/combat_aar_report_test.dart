import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
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

  group('Group D — report provenance', () {
    final snapshot = AarEvidenceSnapshot(
      score: 49,
      band: AarEvidenceBand.partial,
      capped: false,
      statuses: const {
        AarEvidenceDimension.pilotFit: AarEvidenceStatus.missing,
        AarEvidenceDimension.combatLog: AarEvidenceStatus.complete,
        AarEvidenceDimension.opponentIdentity: AarEvidenceStatus.complete,
        AarEvidenceDimension.opponentFit: AarEvidenceStatus.inferred,
        AarEvidenceDimension.damageProfile: AarEvidenceStatus.partial,
      },
    );

    test('D.1 evidenceAtGeneration round-trips through toJson/fromJson', () {
      final report = _report(evidenceAtGeneration: snapshot);
      final json = report.toJson();
      expect(json['evidenceAtGeneration'], snapshot.toJson());
      expect(json['version'], 3);
      expect(CombatAarReport.version, 3);
      final decoded = CombatAarReport.fromJson(json);
      expect(decoded.evidenceAtGeneration, isNotNull);
      expect(decoded.evidenceAtGeneration!.toJson(), snapshot.toJson());
      expect(decoded.headline, report.headline);
      expect(decoded.summary, report.summary);
    });

    test('D.2 toJson omits the key when null', () {
      final report = _report();
      expect(report.evidenceAtGeneration, isNull);
      expect(report.toJson().containsKey('evidenceAtGeneration'), isFalse);
    });

    test('D.3 snapshot fromJson tolerates unknown names', () {
      final decoded = AarEvidenceSnapshot.fromJson({
        'score': 60,
        'band': 'good',
        'capped': false,
        'statuses': {
          'pilotFit': 'missing',
          'bogus': 'complete',
          'combatLog': 'weird',
        },
      });
      expect(decoded, isNotNull);
      expect(decoded!.score, 60);
      expect(decoded.band, AarEvidenceBand.good);
      expect(decoded.capped, isFalse);
      expect(decoded.statuses, {
        AarEvidenceDimension.pilotFit: AarEvidenceStatus.missing,
      });
      expect(AarEvidenceSnapshot.fromJson('nope'), isNull);
      expect(AarEvidenceSnapshot.fromJson({'band': 'good'}), isNull);
    });

    test('T4.3 report without a recorded score reads null, not 0', () {
      final decoded = CombatAarReport.fromJson(_structuredReportJson());
      expect(decoded.evidenceAtGeneration, isNull);
      final legacy = CombatAarReport.fromLegacy(
        summary: 'Summary',
        mistakes: 'Mistake',
        improvements: 'Improve',
        fits: 'Fit',
      );
      expect(legacy.evidenceAtGeneration, isNull);
    });

    test('T4.4 re-analysis offered at recorded + 10', () {
      const recorded = AarEvidenceSnapshot(
        score: 45,
        band: AarEvidenceBand.partial,
        capped: false,
        statuses: {},
      );
      expect(recorded.shouldOfferReanalysis(55), isTrue);
    });

    test(
      'T4.4 withEvidenceAtGeneration preserves all report fields while updating snapshot',
      () {
        final original = _report();
        final updated = original.withEvidenceAtGeneration(snapshot);
        expect(updated.headline, original.headline);
        expect(updated.summary, original.summary);
        expect(updated.outcomeAssessment, original.outcomeAssessment);
        expect(updated.keyMoments, original.keyMoments);
        expect(updated.rankedMistakes, original.rankedMistakes);
        expect(updated.recommendations, original.recommendations);
        expect(updated.fitAdvice, original.fitAdvice);
        expect(updated.trainingDrills, original.trainingDrills);
        expect(updated.damageAnalysis, original.damageAnalysis);
        expect(updated.resourceTopicIds, original.resourceTopicIds);
        expect(updated.confidence, original.confidence);
        expect(updated.unknowns, original.unknowns);
        expect(updated.evidenceAtGeneration!.toJson(), snapshot.toJson());
        expect(original.evidenceAtGeneration, isNull);
      },
    );

    test('T4.5 not offered at recorded + 9', () {
      const recorded = AarEvidenceSnapshot(
        score: 45,
        band: AarEvidenceBand.partial,
        capped: false,
        statuses: {},
      );
      expect(recorded.shouldOfferReanalysis(54), isFalse);
      expect(recorded.shouldOfferReanalysis(30), isFalse);
    });

    test('T4.5 report version stays 3', () {
      expect(CombatAarReport.version, 3);
      expect(_report(evidenceAtGeneration: snapshot).toJson()['version'], 3);
      expect(_report().toJson()['version'], 3);
    });
  });
}

CombatAarReport _report({AarEvidenceSnapshot? evidenceAtGeneration}) {
  return CombatAarReport(
    headline: 'Drone application decided the fight',
    summary: 'Summary',
    outcomeAssessment: 'Outcome',
    keyMoments: const [],
    rankedMistakes: const [],
    recommendations: const [],
    fitAdvice: const [],
    trainingDrills: const [],
    damageAnalysis: const AarDamageAnalysis.empty(),
    resourceTopicIds: const ['drone_application'],
    confidence: 0.9,
    unknowns: const ['Target fit'],
    evidenceAtGeneration: evidenceAtGeneration,
  );
}

Map<String, dynamic> _structuredReportJson() => {
  'version': 3,
  'headline': 'Drone application decided the fight',
  'summary': 'Summary',
  'outcomeAssessment': 'Outcome',
  'keyMoments': <Map<String, dynamic>>[],
  'rankedMistakes': <Map<String, dynamic>>[],
  'recommendations': <Map<String, dynamic>>[],
  'fitAdvice': <Map<String, dynamic>>[],
  'trainingDrills': <Map<String, dynamic>>[],
  'damageAnalysis': const AarDamageAnalysis.empty().toJson(),
  'resourceTopicIds': ['drone_application'],
  'confidence': 0.9,
  'unknowns': <String>[],
};

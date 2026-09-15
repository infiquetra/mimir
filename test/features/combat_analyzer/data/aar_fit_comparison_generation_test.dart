// W2 RED contracts for generation binding and proposal candidates.
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §3.5 / §4.1–§4.3:
// - D15: fromRaw/validator skips SDE/quantity/slot/version/baseline checks;
//   prose-only synthesizes a type-id-0 target; budget excess has no warning.
// - D16: CombatAarReport.toJson omits generation/candidates; fromJson
//   fabricates a type-id-0 generation record when the key is missing.
// - P02: analyzeEncounter never freezes PreparedAarComparisonInput, so
//   saved reports lack F-old fitComparisonAtGeneration.
// - P13: generated confirmed/attributes are copied; mismatched refs are
//   treated as validated; malformed fitCandidates throw (repair storm).
// - P14: re-analysis cannot bind a fresh generation record or revision.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_generation.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_proposal.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_snapshot.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_evidence_fixtures.dart';
import '../fixtures/aar_fit_import_fixtures.dart';
import '../fixtures/fit_evidence_harness.dart';

void main() {
  const validator = AarFitCandidateValidator();

  group('W2 D15 candidate matrix', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('full valid candidate is validated with local types', () async {
      expect(await harness.sdeDb.getType(2048), isNotNull);
      final proposal = validator.validate(
        _candidateRaw(
          groups: _groups(
            low: [
              {'typeId': 2048, 'slotIndex': 0, 'state': 'active'},
            ],
          ),
        ),
        encounterId: 'enc',
        proposalId: 'full',
        preparedBaselineId: 'base',
        preparedFingerprint: 'fp',
        preparedEncounterId: 'enc',
      );
      expect(proposal.status, AarProposalValidationStatus.validated);
      expect(proposal.target, isNotNull);
      expect(proposal.target!.fitting.lowSlots, isNotEmpty);
      expect(proposal.target!.fitting.lowSlots.single.typeId, 2048);
      expect(proposal.target!.fitting.shipTypeId, isNot(0));
    });

    test('omitted groups stay unknown; explicit empty is complete', () {
      final proposal = validator.validate(
        _candidateRaw(
          groups: _groups(high: const [], omit: {'mid', 'fighters'}),
        ),
        encounterId: 'enc',
        proposalId: 'omit',
        preparedEncounterId: 'enc',
      );
      expect(
        proposal.target!.knowledge.group(FitInventoryGroup.high).completeness,
        InventoryCompleteness.recordedComplete,
      );
      expect(
        proposal.target!.knowledge.group(FitInventoryGroup.mid).completeness,
        isNot(InventoryCompleteness.recordedComplete),
      );
      expect(proposal.status, isNot(AarProposalValidationStatus.validated));
    });

    test(
      'prose-only omits a structured target and does not synthesize type 0',
      () {
        final proposal = validator.validate(
          {
            'schemaVersion': 1,
            'candidateId': 'prose',
            'label': 'Fly better',
            'rationale': 'Generic advice with no fit.',
          },
          encounterId: 'enc',
          proposalId: 'prose',
          preparedEncounterId: 'enc',
        );
        expect(proposal.target, isNull);
        expect(proposal.status, AarProposalValidationStatus.invalid);
      },
    );

    test('unknown SDE type is not a complete candidate', () async {
      expect(await harness.sdeDb.getType(kAarMysteryTypeId), isNull);
      final proposal = validator.validate(
        _candidateRaw(
          groups: _groups(
            high: [
              {'typeId': kAarMysteryTypeId, 'slotIndex': 0},
            ],
          ),
        ),
        encounterId: 'enc',
        proposalId: 'unknown-type',
        preparedEncounterId: 'enc',
      );
      expect(
        proposal.status,
        anyOf(
          AarProposalValidationStatus.invalid,
          AarProposalValidationStatus.localDataUnavailable,
        ),
      );
      expect(proposal.status, isNot(AarProposalValidationStatus.validated));
    });

    test('bad quantity is invalid', () {
      final proposal = validator.validate(
        _candidateRaw(
          groups: _groups(
            drones: [
              {'typeId': 2456, 'quantity': 0},
            ],
          ),
        ),
        encounterId: 'enc',
        proposalId: 'qty',
        preparedEncounterId: 'enc',
      );
      expect(proposal.status, AarProposalValidationStatus.invalid);
    });

    test('slot collision is invalid', () {
      final proposal = validator.validate(
        _candidateRaw(
          groups: _groups(
            high: [
              {'typeId': 484, 'slotIndex': 0},
              {'typeId': 2048, 'slotIndex': 0},
            ],
          ),
        ),
        encounterId: 'enc',
        proposalId: 'collision',
        preparedEncounterId: 'enc',
      );
      expect(proposal.status, AarProposalValidationStatus.invalid);
    });

    test('unsupported schema version is unsupportedVersion', () {
      final proposal = validator.validate(
        _candidateRaw(schemaVersion: 99),
        encounterId: 'enc',
        proposalId: 'ver',
        preparedEncounterId: 'enc',
      );
      expect(proposal.status, AarProposalValidationStatus.unsupportedVersion);
      expect(proposal.target, isNull);
    });

    test('wrong baseline or encounter is rejected, not rebased', () {
      final proposal = validator.validate(
        _candidateRaw(
          encounterId: 'other-enc',
          baselineSnapshotId: 'wrong-base',
        ),
        encounterId: 'enc',
        proposalId: 'mismatch',
        preparedBaselineId: 'base',
        preparedFingerprint: 'fp',
        preparedEncounterId: 'enc',
      );
      expect(proposal.status, isNot(AarProposalValidationStatus.validated));
      expect(proposal.encounterId, 'enc');
      expect(proposal.baselineSnapshotId, 'base');
    });

    test('over-budget remains inspectable with a constraint warning', () {
      final proposal = validator.validate(
        _candidateRaw(
          groups: _groups(
            low: [
              {
                'typeId': 2048,
                'slotIndex': 0,
                'attributes': {'48': 10000.0},
              },
            ],
          ),
          extra: {
            'stats': {
              'cpuUsed': 10000,
              'cpuMax': 155,
              'powerUsed': 90,
              'powerMax': 40,
            },
          },
        ),
        encounterId: 'enc',
        proposalId: 'budget',
        preparedEncounterId: 'enc',
      );
      expect(proposal.status, isNot(AarProposalValidationStatus.invalid));
      expect(proposal.target, isNotNull);
      expect(
        proposal.limitations.join(' ').toLowerCase(),
        anyOf(contains('cpu'), contains('power'), contains('budget')),
      );
    });
  });

  group('W2 D16 snapshot and report JSON', () {
    test('new generation record and candidates round-trip', () {
      final snapshot = AarFitSnapshot.fromFitEvidence(
        encounterId: 'enc',
        evidence: const FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.confirmed,
          fitting: Fitting(
            id: 'f-old',
            name: 'F-old',
            shipTypeId: 587,
            shipName: 'Rifter',
            lowSlots: [
              FittedModule(
                typeId: 2048,
                typeName: 'Damage Control II',
                slotType: SlotType.low,
                slotIndex: 0,
                state: ModuleState.offline,
              ),
            ],
          ),
        ),
      );
      final candidate = validator.validate(
        _candidateRaw(
          groups: _groups(
            low: [
              {'typeId': 2048, 'slotIndex': 0},
            ],
          ),
        ),
        encounterId: 'enc',
        proposalId: 'alt-a',
        preparedEncounterId: 'enc',
      );
      final original = CombatAarReport.fromJson(_v3Json()).copyWith(
        fitComparisonAtGeneration: AarFitGenerationRecord(
          generationId: 'gen-1',
          encounterId: 'enc',
          preparedAt: DateTime.utc(2026, 9, 15, 12),
          selfBaseline: snapshot,
          selfBaselineSnapshotId: snapshot.snapshotId,
          suppliedPilotFingerprint: snapshot.contentFingerprint,
          calculatorRevision: 'calc-1',
          sdeContentKey: 'sde-decimal-v1',
        ),
        fitCandidates: [candidate],
      );
      final roundTrip = CombatAarReport.fromJson(original.toJson());
      expect(roundTrip.fitComparisonAtGeneration?.generationId, 'gen-1');
      expect(
        roundTrip.fitComparisonAtGeneration?.selfBaseline?.snapshotId,
        snapshot.snapshotId,
      );
      expect(
        roundTrip
            .fitComparisonAtGeneration
            ?.selfBaseline
            ?.fitting
            .lowSlots
            .single
            .state,
        ModuleState.offline,
      );
      expect(roundTrip.fitCandidates, hasLength(1));
      expect(roundTrip.fitCandidates.single.proposalId, 'alt-a');
    });

    test('legacy v3 without comparison keys does not fabricate snapshots', () {
      final legacy = CombatAarReport.fromJson({
        'summary': 'Legacy summary',
        'mistakes': 'Mistake',
        'improvements': 'Improve',
        'fits': 'Fit',
      });
      expect(legacy.summary, 'Legacy summary');
      expect(legacy.fitComparisonAtGeneration, isNull);
      expect(legacy.fitCandidates, isEmpty);

      final structured = CombatAarReport.fromJson(_v3Json());
      expect(structured.fitComparisonAtGeneration, isNull);
      expect(structured.fitCandidates, isEmpty);
      expect(structured.summary, 'Summary');
    });

    test(
      'candidate display-name change does not change equipment fingerprint',
      () {
        final a = validator.validate(
          _candidateRaw(
            label: 'Armor A',
            groups: _groups(
              low: [
                {
                  'typeId': 2048,
                  'slotIndex': 0,
                  'typeName': 'Damage Control II',
                },
              ],
            ),
          ),
          encounterId: 'enc',
          proposalId: 'alt',
          preparedEncounterId: 'enc',
        );
        final b = validator.validate(
          _candidateRaw(
            label: 'Resolved display name',
            groups: _groups(
              low: [
                {'typeId': 2048, 'slotIndex': 0, 'typeName': 'Resolved A'},
              ],
            ),
          ),
          encounterId: 'enc',
          proposalId: 'alt',
          preparedEncounterId: 'enc',
        );
        expect(a.target!.contentFingerprint, b.target!.contentFingerprint);
      },
    );
  });

  group('W2 P02/P13/P14 analysis binding', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
      await harness.seedKnownSkills();
      harness.scriptNoMatchKillmails();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('P02 report binds F-old while F-new attaches during AI', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      const foldFit = Fitting(
        id: 'f-old',
        name: 'F-old',
        shipTypeId: 587,
        shipName: 'Rifter',
        lowSlots: [
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            slotType: SlotType.low,
            slotIndex: 0,
          ),
        ],
      );
      await harness.repository.saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: encounter.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          killmailSearchCompleted: true,
          pilotFitEvidence: const FitEvidence(
            role: FitEvidenceRole.pilot,
            source: EvidenceSource.manualFitImport,
            confidence: EvidenceConfidence.confirmed,
            fitting: foldFit,
          ),
        ),
      );
      final foldSnapshot = AarFitSnapshot.fromFitEvidence(
        encounterId: encounter.id,
        evidence: const FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.confirmed,
          fitting: foldFit,
        ),
      );
      harness.codex.allowAnalyze = Completer<void>();
      harness.codex.result = CodexAnalysisResult(
        report: CombatAarReport.fromJson(_v3Json(summary: 'F-old advice')),
      );
      final pending = harness.analysisService.analyzeEncounter(encounter);
      await _waitUntil(() => harness.codex.calls >= 1);
      expect(
        harness.codex.lastEnrichment?.pilotFitEvidence?.fitting.id,
        'f-old',
      );
      final imported = await harness.enrichmentService.importPilotFit(
        encounter,
        kAarSupportedEft,
      );
      expect(imported.pilotFitEvidence?.fitting.id, isNot('f-old'));
      harness.codex.allowAnalyze!.complete();
      final stored = await pending;
      final report = _reportFromJson(stored.analysisJson);
      expect(report.summary, 'F-old advice');
      expect(
        report.fitComparisonAtGeneration?.selfBaseline?.contentFingerprint,
        foldSnapshot.contentFingerprint,
      );
      expect(
        report.fitComparisonAtGeneration?.suppliedPilotFingerprint,
        foldSnapshot.contentFingerprint,
      );
      final latest = await harness.repository.loadEnrichment(encounter.id);
      expect(latest?.pilotFitEvidence?.fitting.id, isNot('f-old'));
      expect(
        AarComparisonAdvice.isStale(
          currentPilot: latest?.pilotFitEvidence,
          generation: report.fitComparisonAtGeneration,
          encounterId: encounter.id,
        ),
        isTrue,
      );
    });

    test(
      'P02 failed-pilot own-victim fallback is not initially stale',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        const unknownPilot = Fitting(
          id: 'f-old-unknown',
          name: 'Unknown hull',
          shipTypeId: kAarMysteryTypeId,
          shipName: 'Mystery',
        );
        const victimFit = Fitting(
          id: 'victim-self',
          name: 'Rifter',
          shipTypeId: 587,
          shipName: 'Rifter',
        );
        await harness.repository.saveEnrichment(
          CombatEnrichment(
            parsedEncounterId: encounter.id,
            status: CombatEnrichmentStatus.killmailMatched,
            source: CombatEnrichmentSource.esiRecent,
            killmailId: kAarKillmailId,
            victimCharacterId: FitEvidenceHarness.characterAId,
            killmailSearchCompleted: true,
            pilotFitEvidence: const FitEvidence(
              role: FitEvidenceRole.pilot,
              source: EvidenceSource.manualFitImport,
              confidence: EvidenceConfidence.confirmed,
              fitting: unknownPilot,
            ),
            victimFitEvidence: const FitEvidence(
              role: FitEvidenceRole.victim,
              source: EvidenceSource.killmail,
              confidence: EvidenceConfidence.proven,
              fitting: victimFit,
            ),
          ),
        );
        final prepared = PreparedAarComparisonInput.fromEvidence(
          encounterId: encounter.id,
          pilotFitEvidence: const FitEvidence(
            role: FitEvidenceRole.pilot,
            source: EvidenceSource.manualFitImport,
            confidence: EvidenceConfidence.confirmed,
            fitting: unknownPilot,
          ),
          victimFitEvidence: const FitEvidence(
            role: FitEvidenceRole.victim,
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            fitting: victimFit,
          ),
        );
        expect(prepared.suppliedPilot?.fitting.shipTypeId, kAarMysteryTypeId);
        expect(prepared.derivationBaseline?.fitting.shipTypeId, 587);
        expect(prepared.derivationBaselineReason, contains('victim'));

        harness.codex.result = CodexAnalysisResult(
          report: CombatAarReport.fromJson(_v3Json(summary: 'fallback')),
        );
        final stored = await harness.analysisService.analyzeEncounter(
          encounter,
        );
        final report = _reportFromJson(stored.analysisJson);
        expect(
          report.fitComparisonAtGeneration?.derivationBaselineSnapshotId,
          prepared.derivationBaseline?.snapshotId,
        );
        expect(
          report.fitComparisonAtGeneration?.suppliedPilotFingerprint,
          prepared.suppliedPilot?.contentFingerprint,
        );
        final latest = await harness.repository.loadEnrichment(encounter.id);
        expect(
          AarComparisonAdvice.isStale(
            currentPilot: latest?.pilotFitEvidence,
            generation: report.fitComparisonAtGeneration,
            encounterId: encounter.id,
          ),
          isFalse,
        );
      },
    );

    test(
      'P13 generated confirmed/stats are ignored; mismatched refs rejected',
      () {
        final proposal = validator.validate(
          _candidateRaw(
            encounterId: 'other-enc',
            baselineSnapshotId: 'wrong',
            extra: {
              'confidence': 'confirmed',
              'stats': {'ehp': 12345, 'dps': 400},
            },
            groups: _groups(
              low: [
                {
                  'typeId': 2048,
                  'slotIndex': 0,
                  'attributes': {'9': 42.0},
                },
              ],
            ),
          ),
          encounterId: 'enc',
          proposalId: 'gen',
          preparedBaselineId: 'base',
          preparedFingerprint: 'fp',
          preparedEncounterId: 'enc',
        );
        expect(proposal.status, isNot(AarProposalValidationStatus.validated));
        expect(
          proposal.target?.confidence,
          isNot(EvidenceConfidence.confirmed),
        );
        expect(proposal.target?.fitting.lowSlots.single.attributes, isEmpty);
      },
    );

    test('P13 malformed optional candidate does not throw or repair', () {
      expect(
        () => CombatAarReport.fromJson({
          ..._v3Json(summary: 'Narrative kept'),
          'fitCandidates': 'not-a-list',
        }),
        returnsNormally,
      );
      final report = CombatAarReport.fromJson({
        ..._v3Json(summary: 'Narrative kept'),
        'fitCandidates': 'not-a-list',
      });
      expect(report.summary, 'Narrative kept');
      expect(report.fitAdvice, isNotEmpty);
      expect(report.fitCandidates, isEmpty);
    });

    test(
      'P13 generated candidate items do not become evidence facts',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.repository.saveEnrichment(
          CombatEnrichment(
            parsedEncounterId: encounter.id,
            status: CombatEnrichmentStatus.logOnly,
            source: CombatEnrichmentSource.none,
            killmailSearchCompleted: true,
          ),
        );
        harness.codex.result = CodexAnalysisResult(
          report: CombatAarReport.fromJson({
            ..._v3Json(summary: 'Advice'),
            'fitCandidates': [
              _candidateRaw(
                groups: _groups(
                  low: [
                    {'typeId': 2048, 'slotIndex': 0},
                  ],
                ),
              ),
            ],
          }),
        );
        await harness.analysisService.analyzeEncounter(encounter);
        final enrichment = await harness.repository.loadEnrichment(
          encounter.id,
        );
        expect(enrichment?.pilotFitEvidence, isNull);
        expect(
          enrichment?.evidenceLedger.facts.any(
            (fact) => fact.value.contains('2048') || fact.id.contains('2048'),
          ),
          isFalse,
        );
      },
    );

    test(
      'P14 re-analysis binds the new fit and keeps the old report copy',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        const foldFit = Fitting(
          id: 'f-old',
          name: 'F-old',
          shipTypeId: 587,
          shipName: 'Rifter',
          lowSlots: [
            FittedModule(
              typeId: 2048,
              typeName: 'Damage Control II',
              slotType: SlotType.low,
              slotIndex: 0,
            ),
          ],
        );
        await harness.repository.saveEnrichment(
          CombatEnrichment(
            parsedEncounterId: encounter.id,
            status: CombatEnrichmentStatus.logOnly,
            source: CombatEnrichmentSource.none,
            killmailSearchCompleted: true,
            pilotFitEvidence: const FitEvidence(
              role: FitEvidenceRole.pilot,
              source: EvidenceSource.manualFitImport,
              confidence: EvidenceConfidence.confirmed,
              fitting: foldFit,
            ),
          ),
        );
        harness.codex.result = CodexAnalysisResult(
          report: CombatAarReport.fromJson(_v3Json(summary: 'old advice')),
        );
        final first = await harness.analysisService.analyzeEncounter(encounter);
        final firstJson = first.analysisJson;
        final firstReport = _reportFromJson(firstJson);
        final foldFp = AarFitSnapshot.fromFitEvidence(
          encounterId: encounter.id,
          evidence: const FitEvidence(
            role: FitEvidenceRole.pilot,
            source: EvidenceSource.manualFitImport,
            confidence: EvidenceConfidence.confirmed,
            fitting: foldFit,
          ),
        ).contentFingerprint;
        expect(
          firstReport.fitComparisonAtGeneration?.suppliedPilotFingerprint,
          foldFp,
        );

        await harness.enrichmentService.importPilotFit(
          encounter,
          kAarSupportedEft,
        );
        final replaced = await harness.repository.loadEnrichment(encounter.id);
        expect(
          AarComparisonAdvice.isStale(
            currentPilot: replaced?.pilotFitEvidence,
            generation: firstReport.fitComparisonAtGeneration,
            encounterId: encounter.id,
          ),
          isTrue,
        );

        harness.codex.result = CodexAnalysisResult(
          report: CombatAarReport.fromJson(_v3Json(summary: 'new advice')),
        );
        final second = await harness.analysisService.analyzeEncounter(
          encounter,
          forceRefresh: true,
        );
        final secondReport = _reportFromJson(second.analysisJson);
        final preserved = _reportFromJson(firstJson);
        expect(
          preserved.fitComparisonAtGeneration?.suppliedPilotFingerprint,
          foldFp,
        );
        expect(
          secondReport.fitComparisonAtGeneration?.suppliedPilotFingerprint,
          isNot(foldFp),
        );
        expect(
          secondReport.fitComparisonAtGeneration?.calculatorRevision,
          isNot(firstReport.fitComparisonAtGeneration?.calculatorRevision),
        );
      },
    );
  });
}

CombatAarReport _reportFromJson(String? raw) {
  return CombatAarReport.fromJson(
    Map<String, dynamic>.from(jsonDecode(raw ?? '{}') as Map),
  );
}

Future<void> _waitUntil(bool Function() test, {int pumps = 200}) async {
  for (var i = 0; i < pumps; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Map<String, dynamic> _v3Json({String summary = 'Summary'}) {
  return {
    'version': 3,
    'headline': 'Combat Review',
    'summary': summary,
    'outcomeAssessment': 'Outcome',
    'keyMoments': <Map<String, dynamic>>[],
    'rankedMistakes': <Map<String, dynamic>>[],
    'recommendations': <Map<String, dynamic>>[],
    'fitAdvice': [
      {
        'title': 'Legacy Fit Advice',
        'details': 'Hold range.',
        'confidence': 'unknown',
        'observedItems': <String>[],
        'recommendedItems': <String>[],
        'limitations': '',
      },
    ],
    'trainingDrills': <Map<String, dynamic>>[],
    'damageAnalysis': {
      'summary': '',
      'evidence': '',
      'damageTypes': <Map<String, dynamic>>[],
      'defenseNotes': <Map<String, dynamic>>[],
      'confidence': 0.5,
      'unknowns': <String>[],
    },
    'resourceTopicIds': <String>[],
    'confidence': 0.9,
    'unknowns': <String>[],
  };
}

Map<String, dynamic> _candidateRaw({
  int schemaVersion = 1,
  String encounterId = 'enc',
  String baselineSnapshotId = 'base',
  String label = 'Armor alternative',
  Map<String, dynamic>? groups,
  Map<String, dynamic> extra = const {},
}) {
  return {
    'schemaVersion': schemaVersion,
    'candidateId': 'alternative-a',
    'baselineSnapshotId': baselineSnapshotId,
    'baselineFingerprint': 'fp',
    'encounterId': encounterId,
    'label': label,
    'rationale': 'Trade speed for the stated tank objective.',
    'target': {
      'shipTypeId': 587,
      'shipName': 'Rifter',
      'groups': groups ?? _groups(),
    },
    'replacements': <Map<String, dynamic>>[],
    'limitations': <String>[],
    ...extra,
  };
}

Map<String, dynamic> _groups({
  List<Map<String, dynamic>> high = const [],
  List<Map<String, dynamic>> mid = const [],
  List<Map<String, dynamic>> low = const [],
  List<Map<String, dynamic>> rigs = const [],
  List<Map<String, dynamic>> subsystems = const [],
  List<Map<String, dynamic>> drones = const [],
  List<Map<String, dynamic>> fighters = const [],
  List<Map<String, dynamic>> cargo = const [],
  Set<String> omit = const {},
}) {
  final groups = <String, dynamic>{};
  void add(String name, List<Map<String, dynamic>> items) {
    if (omit.contains(name)) return;
    groups[name] = {'status': 'complete', 'items': items};
  }

  add('high', high);
  add('mid', mid);
  add('low', low);
  add('rigs', rigs);
  add('subsystems', subsystems);
  add('drones', drones);
  add('fighters', fighters);
  add('cargo', cargo);
  return groups;
}

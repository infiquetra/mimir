import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/combat_analyzer/data/aar_fit_import_parser.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/fitting/domain/format_parser.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_evidence_fixtures.dart';
import '../fixtures/aar_fit_import_fixtures.dart';
import '../fixtures/fit_evidence_harness.dart';

Matcher _isFitFailure(AarFitImportFailureCode code) {
  return isA<AarFitImportException>().having((e) => e.code, 'code', code);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T04–T10 AarFitImportParser', () {
    late SdeDatabase sdeDb;
    late SdeService sde;
    late AarFitImportParser parser;

    setUp(() async {
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      await seedAarImportSde(sdeDb);
      sde = SdeService(database: sdeDb);
      parser = AarFitImportParser(sdeService: sde);
    });

    tearDown(() async {
      await sdeDb.close();
    });

    test(
      'T04 supported EFT keeps hull, modules, drones and fit name',
      () async {
        final fitting = await parser.parse(kAarSupportedEft);
        expect(fitting.shipTypeId, 587);
        expect(fitting.shipName, 'Rifter');
        expect(fitting.name, 'Fight Fit');
        expect(fitting.lowSlots.single.typeId, 2048);
        expect(fitting.medSlots.single.typeId, 5973);
        expect(fitting.highSlots.single.typeId, 484);
        expect(fitting.rigSlots.single.typeId, 3117);
        expect(fitting.drones.single.typeId, 2456);
        expect(fitting.drones.single.quantity, 5);
        expect(fitting.cargo, isEmpty);
        expect(fitting.allModules.every((m) => m.chargeTypeId == null), isTrue);
      },
    );

    test('T05 header-only EFT is a valid intentional empty fit', () async {
      final fitting = await parser.parse(kAarHeaderOnlyEft);
      expect(fitting.shipTypeId, 587);
      expect(fitting.allModules, isEmpty);
      expect(fitting.drones, isEmpty);
    });

    test(
      'T05 placeholders and CRLF whitespace do not drop real modules',
      () async {
        final placeholders = await parser.parse(kAarPlaceholderEft);
        expect(placeholders.lowSlots.single.typeId, 2048);
        expect(placeholders.medSlots, isEmpty);

        final spaced = await parser.parse(kAarWhitespaceCrlfEft);
        expect(spaced.shipName, 'Rifter');
        expect(spaced.name, 'Spaced');
        expect(spaced.lowSlots.single.typeId, 2048);
      },
    );

    test(
      'T05 empty adapter input fails validation without a fitting',
      () async {
        await expectLater(
          parser.parse('   \n'),
          throwsA(_isFitFailure(AarFitImportFailureCode.malformedFit)),
        );
      },
    );

    test('T06 malformed and unknown hulls are rejected', () async {
      await expectLater(
        parser.parse(kAarBrokenHeaderEft),
        throwsA(_isFitFailure(AarFitImportFailureCode.malformedFit)),
      );
      await expectLater(
        parser.parse(kAarUnknownHullEft),
        throwsA(_isFitFailure(AarFitImportFailureCode.malformedFit)),
      );
    });

    test(
      'T06 non-ship header is rejected rather than saved as a hull',
      () async {
        await expectLater(
          parser.parse(kAarNonShipHeaderEft),
          throwsA(_isFitFailure(AarFitImportFailureCode.malformedFit)),
        );
      },
    );

    test('T07 colon in EFT header routes to EFT not DNA', () async {
      final fitting = await parser.parse(kAarColonHeaderEft);
      expect(fitting.shipTypeId, 587);
      expect(fitting.shipName, 'Rifter');
      expect(fitting.name, 'PvP: Armor');
      expect(fitting.lowSlots.single.typeId, 2048);
    });

    test('T07 supported DNA remains faithful', () async {
      final fitting = await parser.parse(kAarSupportedDna);
      expect(fitting.shipTypeId, 587);
      expect(fitting.lowSlots.single.typeId, 2048);
    });

    test(
      'T08 mixed unknown modules are rejected, not silently dropped',
      () async {
        await expectLater(
          parser.parse(kAarMixedUnknownEft),
          throwsA(_isFitFailure(AarFitImportFailureCode.unresolvedEntries)),
        );
      },
    );

    test('T08 all-unknown modules are rejected', () async {
      await expectLater(
        parser.parse(kAarAllUnknownEft),
        throwsA(_isFitFailure(AarFitImportFailureCode.unresolvedEntries)),
      );
    });

    test('T08 invalid stacks are rejected', () async {
      await expectLater(
        parser.parse(kAarInvalidStackEft),
        throwsA(
          anyOf(
            _isFitFailure(AarFitImportFailureCode.malformedFit),
            _isFitFailure(AarFitImportFailureCode.unresolvedEntries),
          ),
        ),
      );
      await expectLater(
        parser.parse('[Rifter, Stack]\nHobgoblin II x-1\n'),
        throwsA(
          anyOf(
            _isFitFailure(AarFitImportFailureCode.malformedFit),
            _isFitFailure(AarFitImportFailureCode.unresolvedEntries),
          ),
        ),
      );
    });

    test('T08 shared parser still skips unknown modules by default', () async {
      final fitting = await FittingFormatParser(
        sde,
      ).parseEft(kAarMixedUnknownEft);
      expect(fitting, isNotNull);
      expect(fitting!.lowSlots.single.typeId, 2048);
      expect(fitting.allModules.length, 1);
    });

    test('T08 post-parse mismatch is unresolvedEntries', () async {
      final adapter = AarFitImportParser(
        sdeService: sde,
        parserFactory:
            ({
              required sdeService,
              resolveTypeIdByName,
              rethrowFailures = false,
            }) {
              return _HullOnlyParser(sdeService);
            },
      );
      await expectLater(
        adapter.parse(kAarSupportedEft),
        throwsA(_isFitFailure(AarFitImportFailureCode.unresolvedEntries)),
      );
    });

    test('T09 comma-separated loaded ammunition is rejected', () async {
      await expectLater(
        parser.parse(kAarAmmoSuffixEft),
        throwsA(
          _isFitFailure(AarFitImportFailureCode.unsupportedLoadedAmmunition),
        ),
      );
    });

    test(
      'T10 exact name beyond the 20-result partial search is resolved',
      () async {
        final fitting = await parser.parse(kAarUniqueBeyond20Eft);
        expect(fitting.shipTypeId, 9020);
        expect(fitting.shipName, 'UniqueShip');
      },
    );

    test(
      'T10 lookup exception is localDataUnavailable, not unknown input',
      () async {
        final failingDb = SdeDatabase.forTesting(NativeDatabase.memory());
        await seedAarImportSde(failingDb);
        await failingDb.close();
        final failing = AarFitImportParser(
          sdeService: SdeService(database: failingDb),
        );
        await expectLater(
          failing.parse(kAarSupportedEft),
          throwsA(_isFitFailure(AarFitImportFailureCode.localDataUnavailable)),
        );
      },
    );

    test('T10 unknown hull is not classified as local-data failure', () async {
      await expectLater(
        parser.parse(kAarUnknownHullEft),
        throwsA(_isFitFailure(AarFitImportFailureCode.malformedFit)),
      );
    });

    test(
      'T10 adapter supplies exact resolver and rethrowFailures to parser',
      () async {
        Future<int?> Function(String name)? capturedResolver;
        var capturedRethrow = false;
        final adapter = AarFitImportParser(
          sdeService: sde,
          parserFactory:
              ({
                required sdeService,
                resolveTypeIdByName,
                rethrowFailures = false,
              }) {
                capturedResolver = resolveTypeIdByName;
                capturedRethrow = rethrowFailures;
                return FittingFormatParser(sdeService);
              },
        );
        await adapter.parse(kAarHeaderOnlyEft);
        expect(capturedResolver, isNotNull);
        expect(capturedRethrow, isTrue);
      },
    );

    test('T10 FittingFormatParser grows exact-lookup and rethrow seams', () {
      final source = File(
        'lib/features/fitting/domain/format_parser.dart',
      ).readAsStringSync();
      expect(source, contains('resolveTypeIdByName'));
      expect(source, contains('rethrowFailures'));
    });

    test('T08 input larger than 256 KiB is malformed', () async {
      final raw = '[Rifter, Test]\n${'x' * (256 * 1024)}';
      await expectLater(
        parser.parse(raw),
        throwsA(_isFitFailure(AarFitImportFailureCode.malformedFit)),
      );
    });
  });

  group('T04–T10 importPilotFit storage', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('T04 importPilotFit persists metadata and inventory', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final saved = await harness.enrichmentService.importPilotFit(
        encounter,
        kAarSupportedEft,
      );
      expect(saved.pilotFitEvidence, isNotNull);
      expect(saved.pilotFitEvidence!.role, FitEvidenceRole.pilot);
      expect(saved.pilotFitEvidence!.source, EvidenceSource.manualFitImport);
      expect(saved.pilotFitEvidence!.confidence, EvidenceConfidence.confirmed);
      expect(saved.pilotFitEvidence!.evidenceTime?.isUtc, isTrue);
      expect(
        saved.pilotFitEvidence!.limitations,
        contains('User-confirmed manual fit import.'),
      );
      expect(saved.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(saved.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
      expect(saved.pilotFitEvidence!.fitting.drones.single.quantity, 5);

      final reloaded = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounter.id);
      expect(reloaded!.pilotFitEvidence!.fitting.highSlots.single.typeId, 484);
      expect(
        reloaded.evidenceLedger.facts.any(
          (f) => f.id == 'ev-pilot-fit-${encounter.id}',
        ),
        isTrue,
      );
      expect(harness.codex.calls, 0);
      expect(harness.discovery.fetches, isEmpty);
    });

    test(
      'T05 unauthenticated local import does not require a character',
      () async {
        final encounter = encounterWith(characterId: null);
        expect(encounter.characterId, isNull);
        final saved = await harness.enrichmentService.importPilotFit(
          encounter,
          kAarHeaderOnlyEft,
        );
        expect(saved.pilotFitEvidence!.fitting.shipTypeId, 587);
        expect(harness.esiAdapter.requests, isEmpty);
      },
    );

    test('T06 failed non-ship import leaves the prior row unchanged', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.enrichmentService.importPilotFit(
        encounter,
        kAarHeaderOnlyEft,
      );
      await expectLater(
        harness.enrichmentService.importPilotFit(
          encounter,
          kAarNonShipHeaderEft,
        ),
        throwsA(
          anyOf(
            _isFitFailure(AarFitImportFailureCode.malformedFit),
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(kAarDirectHullMessage),
            ),
          ),
        ),
      );
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(reloaded!.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(reloaded.pilotFitEvidence!.fitting.shipName, 'Rifter');
    });

    test('T07 colon header importPilotFit saves EFT name and module', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final saved = await harness.enrichmentService.importPilotFit(
        encounter,
        kAarColonHeaderEft,
      );
      expect(saved.pilotFitEvidence!.fitting.name, 'PvP: Armor');
      expect(saved.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
    });

    test('T07 DNA importPilotFit still attaches the module', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final saved = await harness.enrichmentService.importPilotFit(
        encounter,
        kAarSupportedDna,
      );
      expect(saved.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(saved.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
    });

    test('T08 mixed unknown import never writes confirmed evidence', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await expectLater(
        harness.enrichmentService.importPilotFit(
          encounter,
          kAarMixedUnknownEft,
        ),
        throwsA(_isFitFailure(AarFitImportFailureCode.unresolvedEntries)),
      );
      expect(await harness.repository.loadEnrichment(encounter.id), isNull);
    });

    test('T09 ammo suffix import never writes a stripped module', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await expectLater(
        harness.enrichmentService.importPilotFit(encounter, kAarAmmoSuffixEft),
        throwsA(
          _isFitFailure(AarFitImportFailureCode.unsupportedLoadedAmmunition),
        ),
      );
      expect(await harness.repository.loadEnrichment(encounter.id), isNull);
    });
  });
}

class _HullOnlyParser extends FittingFormatParser {
  _HullOnlyParser(SdeService sde) : super(sde);

  @override
  Future<Fitting?> parseEft(String eftString) async {
    return Fitting(
      id: 'dropped',
      name: 'Fight Fit',
      shipTypeId: 587,
      shipName: 'Rifter',
    );
  }
}

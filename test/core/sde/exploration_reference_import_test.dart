// X1 RED contracts for SDE exploration import (P01–P02).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §2.1–§2.2:
// - P01: no bundled catalog; placeholder System # names; unpublished
//   types dropped; failed import still stamps the new build.
// - P02: schema remains 6; older bundles replace a newer slice.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/exploration/data/exploration_reference_repository.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/domain/exploration_reference_deriver.dart';

import '../../features/exploration/fixtures/exploration_fixtures.dart';
import '../../features/exploration/fixtures/exploration_test_harness.dart'
    show ExplorationTestHarness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RawWormholeRecord rawFromF1(
    Map<String, dynamic> raw, {
    bool published = true,
  }) {
    return RawWormholeRecord(
      typeId: raw['typeId'] as int,
      code: raw['code'] as String,
      name: raw['name'] as String,
      published: published,
      rawTargetClass: raw['rawTargetClass'] as int?,
      rawTargetDistribution: raw['rawTargetDistribution'] as int?,
      rawMaxStableTimeMinutes: raw['rawMaxStableTimeMinutes'] as int?,
      rawTotalMassKg: (raw['rawTotalMassKg'] as num?)?.toDouble(),
      rawJumpMassKg: (raw['rawJumpMassKg'] as num?)?.toDouble(),
      rawRegenKg: (raw['rawRegenKg'] as num?)?.toDouble(),
    );
  }

  ExplorationReferenceBundle f1Bundle({
    int build = 3503375,
    String validation = 'ok',
    bool corrupt = false,
  }) {
    return ExplorationReferenceBundle(
      manifest: ReferenceManifest(
        sdeBuild: build,
        datasetSchema: 1,
        checksums: const {'exploration.json': 'sha256:fixture'},
        rowCounts: const {'wormholeTypes': 7, 'effects': 36},
        importedAt: kExplorationT0,
        coverage: 'fixture',
        validation: validation,
      ),
      types: [
        rawFromF1(F1Fixtures.b274Raw()),
        rawFromF1(F1Fixtures.k162Raw(), published: false),
        rawFromF1(F1Fixtures.i078Raw()),
        rawFromF1(F1Fixtures.c729V1Raw()),
        rawFromF1(F1Fixtures.c729V2AgreeRaw()),
        rawFromF1(F1Fixtures.q001Raw()),
        rawFromF1(F1Fixtures.q002Raw()),
      ],
      systems: [F2Fixtures.thera(), F2Fixtures.pochven()],
      checksum: 'sha256:fixture',
      corrupt: corrupt,
    );
  }

  late SdeDatabase database;
  late SdeService service;
  late ExplorationReferenceRepository repository;

  setUp(() {
    database = SdeDatabase.forTesting(NativeDatabase.memory());
    service = SdeService(database: database);
    repository = ExplorationReferenceRepository(
      database: database,
      service: service,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('P01 offline catalog completeness', () {
    test(
      'bundled import populates types without HTTP or raw-ID names',
      () async {
        final result = await repository.importBundle(f1Bundle());
        expect(result.success, isTrue);
        final manifest = await repository.readExplorationManifest();
        expect(manifest, isNotNull);
        expect(manifest!.sdeBuild, 3503375);
        expect(manifest.rowCounts['wormholeTypes'], 7);
        expect(manifest.rowCounts['effects'], 36);
        expect(manifest.checksums['exploration.json'], isNotEmpty);

        final types = await repository.loadWormholeTypes();
        expect(
          types.map((type) => type.code),
          containsAll(['B274', 'K162', 'I078']),
        );
        expect(types.where((type) => type.code == 'C729'), hasLength(2));
        expect(
          types.firstWhere((type) => type.code == 'K162').maxJumpMassKg,
          isNull,
        );
        expect(await repository.getSolarSystemName(kTheraSystemId), 'Thera');
        expect(
          await repository.getSolarSystemName(kTheraSystemId),
          isNot(contains('#')),
        );
      },
    );

    test('failed import retains the previous usable reference', () async {
      await repository.importBundle(f1Bundle(build: 3503375));
      final failed = await repository.importBundle(
        f1Bundle(build: 3503376, validation: 'invalid', corrupt: true),
      );
      expect(failed.success, isFalse);
      expect(failed.retainedPrevious, isTrue);
      expect(failed.stampedVersion, 3503375);
      final manifest = await repository.readExplorationManifest();
      expect(manifest!.sdeBuild, 3503375);
      final types = await repository.loadWormholeTypes();
      expect(types.map((type) => type.code), contains('B274'));
    });
  });

  group('P02 schema 6→7 migration and CAS', () {
    test('SDE schema is 7 and skills survive an exploration import', () async {
      expect(database.schemaVersion, 7);
      expect(
        database.schemaVersion,
        isNot(ExplorationTestHarness.baselineSdeSchema),
      );
      await database.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: const Value(587),
          typeName: 'Rifter',
          groupId: 25,
        ),
      ]);
      await repository.importBundle(f1Bundle());
      final skills = await database.getTypesByIds([587]);
      expect(skills.single.typeName, 'Rifter');
    });

    test('older bundle cannot replace a newer installed slice', () async {
      await repository.importBundle(f1Bundle(build: 3503376));
      final older = await repository.importBundle(f1Bundle(build: 3503375));
      expect(older.success, isFalse);
      expect(older.retainedPrevious, isTrue);
      final manifest = await repository.readExplorationManifest();
      expect(manifest!.sdeBuild, 3503376);
    });
  });
}

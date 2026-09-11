import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SdeDatabase database;

  setUp(() {
    database = SdeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedBundledDogma() async {
    final dogma =
        json.decode(File('assets/sde/dogma.json').readAsStringSync())
            as Map<String, dynamic>;

    final categories = (dogma['categories'] as List)
        .map(
          (c) => SdeCategoriesCompanion.insert(
            categoryId: Value((c as Map<String, dynamic>)['categoryId'] as int),
            categoryName: c['categoryName'] as String,
          ),
        )
        .toList();
    await database.upsertCategories(categories);

    final groups = (dogma['groups'] as List)
        .map(
          (g) => SdeGroupsCompanion.insert(
            groupId: Value((g as Map<String, dynamic>)['groupId'] as int),
            groupName: g['groupName'] as String,
            categoryId: g['categoryId'] as int,
          ),
        )
        .toList();
    await database.upsertGroups(groups);

    final types = (dogma['types'] as List)
        .map(
          (t) => SdeTypesCompanion.insert(
            typeId: Value((t as Map<String, dynamic>)['typeId'] as int),
            typeName: t['typeName'] as String,
            groupId: t['groupId'] as int,
          ),
        )
        .toList();
    await database.upsertTypes(types);

    final attributes = <SdeTypeAttributesCompanion>[];
    for (final raw in dogma['types'] as List) {
      final type = raw as Map<String, dynamic>;
      final typeId = type['typeId'] as int;
      final dogmaAttributes = type['dogmaAttributes'] as List? ?? const [];
      for (final attr in dogmaAttributes) {
        final map = attr as Map<String, dynamic>;
        attributes.add(
          SdeTypeAttributesCompanion.insert(
            typeId: typeId,
            attributeId: map['attributeId'] as int,
            value: (map['value'] as num).toDouble(),
          ),
        );
      }
    }
    if (attributes.isNotEmpty) {
      await database.upsertTypeAttributes(attributes);
    }
  }

  test(
    'U0.1 bundled dogma.json includes category 11 names',
    () async {
      await seedBundledDogma();
      final hits = await database.searchTypesByName('Serpentis Watchman');
      final match = hits.cast<SdeType?>().firstWhere(
        (type) => type!.typeName.trim().toLowerCase() == 'serpentis watchman',
        orElse: () => null,
      );
      expect(
        match,
        isNotNull,
        reason:
            'bundled dogma.json must include an exact-normalised '
            'Serpentis Watchman type',
      );
      final group = await database.getGroup(match!.groupId);
      expect(group, isNotNull);
      expect(group!.categoryId, 11);
      final attrs = await database.getTypeAttributes(match.typeId);
      expect(attrs, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('U0.2 bundledDogmaVersion is 3', () {
    expect(SdeService.bundledDogmaVersion, 3);
  });
}

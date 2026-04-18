import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/features/industry/data/bom_calculator.dart';
import 'package:mimir/features/industry/data/models/bom_node.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';

class MockSdeDatabase extends Mock implements SdeDatabase {}

/// A calculator subclass that allows injecting data.
class TestBomCalculator extends BomCalculator {
  final Map<int, BlueprintInfo> blueprints;
  final Map<int, List<MaterialRequirement>> materials;
  final Map<int, double> prices;

  TestBomCalculator({
    required super.sde,
    this.blueprints = const {},
    this.materials = const {},
    this.prices = const {},
  });

  @override
  Future<BlueprintInfo?> lookupBlueprint(int productId) async =>
      blueprints[productId];

  @override
  Future<List<MaterialRequirement>> lookupMaterials(int blueprintId) async =>
      materials[blueprintId] ?? [];

  @override
  Future<double> lookupPrice(int typeId) async => prices[typeId] ?? 0.0;
}

void main() {
  group('BomCalculator', () {
    late MockSdeDatabase mockSde;

    setUpAll(() {
      registerFallbackValue(0);
    });

    setUp(() {
      mockSde = MockSdeDatabase();

      when(() => mockSde.getTypeName(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as int;
        return 'Item $id';
      });
    });

    test('calculates raw material (base case)', () async {
      final calculator = TestBomCalculator(sde: mockSde);

      final node = await calculator.calculate(typeId: 34, quantity: 100);

      expect(node.typeId, 34);
      expect(node.quantity, 100);
      expect(node.isBuilding, false);
      expect(node.children, isEmpty);
    });

    test('calculates simple manufacturing (1 level)', () async {
      final calculator = TestBomCalculator(
        sde: mockSde,
        blueprints: {
          12005: BlueprintInfo(blueprintId: 12006, portionSize: 1),
        },
        materials: {
          12006: [
            MaterialRequirement(
                typeId: 34, typeName: 'Tritanium', baseQuantity: 1000),
          ],
        },
      );

      final node = await calculator.calculate(typeId: 12005, quantity: 2);

      expect(node.isBuilding, true);
      expect(node.children.length, 1);
      // For 2 units, 1 per run -> 2 runs.
      // Base qty 1000 * 2 runs = 2000.
      expect(node.children[0].typeId, 34);
      expect(node.children[0].quantity, 2000);
    });

    test('applies ME efficiency correctly', () async {
      final calculator = TestBomCalculator(
        sde: mockSde,
        blueprints: {
          12005: BlueprintInfo(blueprintId: 12006, portionSize: 1),
        },
        materials: {
          12006: [
            MaterialRequirement(
                typeId: 34, typeName: 'Tritanium', baseQuantity: 1000),
          ],
        },
      );

      // ME 10 should reduce materials by 10%.
      // 1000 * (1 - 0.10) = 900.
      final node =
          await calculator.calculate(typeId: 12005, quantity: 1, meLevel: 10);

      expect(node.children[0].quantity, 900);
    });

    test('handles recursive manufacturing (2 levels)', () async {
      final calculator = TestBomCalculator(
        sde: mockSde,
        blueprints: {
          601: BlueprintInfo(blueprintId: 602, portionSize: 1), // Caracal
          1111: BlueprintInfo(blueprintId: 1112, portionSize: 1), // Component
        },
        materials: {
          602: [
            MaterialRequirement(
                typeId: 1111, typeName: 'Component', baseQuantity: 10),
          ],
          1112: [
            MaterialRequirement(
                typeId: 34, typeName: 'Tritanium', baseQuantity: 5000),
          ],
        },
      );

      final node = await calculator.calculate(typeId: 601, quantity: 1);

      expect(node.isBuilding, true);
      expect(node.children[0].typeId, 1111);
      expect(node.children[0].isBuilding, true);
      expect(node.children[0].children[0].typeId, 34);
      // 1 Caracal -> 10 Components -> 10 * 5000 = 50000 Tritanium
      expect(node.children[0].children[0].quantity, 50000);
    });

    test('handles EVE minimum 1-unit-per-run rule', () async {
      final calculator = TestBomCalculator(
        sde: mockSde,
        blueprints: {
          12005: BlueprintInfo(blueprintId: 12006, portionSize: 1),
        },
        materials: {
          12006: [
            MaterialRequirement(
                typeId: 34, typeName: 'Tritanium', baseQuantity: 1),
          ],
        },
      );

      // Even with ME 10, 1 * (1 - 0.1) = 0.9, which should ceil to 1.
      final node =
          await calculator.calculate(typeId: 12005, quantity: 1, meLevel: 10);
      expect(node.children[0].quantity, 1);
    });
  });
}

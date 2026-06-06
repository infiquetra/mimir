import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/features/industry/domain/production_chain_builder.dart';

class MockSdeService extends Mock implements SdeService {}

void main() {
  late MockSdeService mockSdeService;
  late ProductionChainBuilder builder;

  setUp(() {
    mockSdeService = MockSdeService();
    builder = ProductionChainBuilder(mockSdeService);
  });

  group('ProductionChainBuilder', () {
    test('builds single raw material chain if no materials required', () async {
      when(() => mockSdeService.getSkillName(34)).thenAnswer((_) async => 'Tritanium');
      when(() => mockSdeService.getIndustryMaterials(34, 1)).thenAnswer((_) async => []);

      final node = await builder.buildChain(34, 1);

      expect(node.typeId, equals(34));
      expect(node.name, equals('Tritanium'));
      expect(node.quantityRequired, equals(1));
      expect(node.isRawMaterial, isTrue);
      expect(node.dependencies, isEmpty);
    });
  });
}

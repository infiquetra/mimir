import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/domain/esi_fitting_export.dart';
import 'package:mimir/features/fitting/domain/models.dart';

FittedModule module(int typeId, SlotType slotType, int index) => FittedModule(
  typeId: typeId,
  typeName: 'Module $typeId',
  slotType: slotType,
  slotIndex: index,
  state: ModuleState.online,
);

void main() {
  group('EsiFittingExporter', () {
    test('maps slots onto ESI flags', () {
      final export = EsiFittingExporter.export(
        Fitting(
          id: '1',
          name: 'Test',
          shipTypeId: 587,
          shipName: 'Rifter',
          highSlots: [module(1, SlotType.high, 0)],
          medSlots: [module(2, SlotType.med, 3)],
          lowSlots: [module(3, SlotType.low, 7)],
          rigSlots: [module(4, SlotType.rig, 2)],
          subsystems: [module(5, SlotType.subsystem, 3)],
        ),
      );

      expect(export.droppedModules, isEmpty);
      expect(export.items, hasLength(5));
      expect(export.items[0], {'type_id': 1, 'flag': 'HiSlot0', 'quantity': 1});
      expect(export.items[1]['flag'], 'MedSlot3');
      expect(export.items[2]['flag'], 'LoSlot7');
      expect(export.items[3]['flag'], 'RigSlot2');
      expect(export.items[4]['flag'], 'SubSystemSlot3');
    });

    test(
      'reports modules beyond the ESI flag enum instead of dropping them silently',
      () {
        final export = EsiFittingExporter.export(
          Fitting(
            id: '1',
            name: 'Test',
            shipTypeId: 587,
            shipName: 'Rifter',
            rigSlots: [module(4, SlotType.rig, 3)], // enum stops at RigSlot2
          ),
        );

        expect(export.items, isEmpty);
        expect(export.droppedModules, hasLength(1));
        expect(export.droppedModules.single.typeId, 4);
      },
    );

    test(
      'includes offline modules, since a saved fit stores what is fitted',
      () {
        final export = EsiFittingExporter.export(
          Fitting(
            id: '1',
            name: 'Test',
            shipTypeId: 587,
            shipName: 'Rifter',
            lowSlots: [
              FittedModule(
                typeId: 9,
                typeName: 'Offline module',
                slotType: SlotType.low,
                slotIndex: 0,
                state: ModuleState.offline,
              ),
            ],
          ),
        );

        expect(export.items, hasLength(1));
        expect(export.items.single['flag'], 'LoSlot0');
      },
    );
  });
}

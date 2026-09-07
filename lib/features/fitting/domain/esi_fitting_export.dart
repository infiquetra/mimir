import 'models.dart';

/// The item list ESI's `POST /characters/{character_id}/fittings/` expects,
/// mapped from a Mimir [Fitting].
class EsiFittingExport {
  const EsiFittingExport({required this.items, required this.droppedModules});

  /// Entries of `{type_id, flag, quantity}` ready for the ESI request body.
  final List<Map<String, dynamic>> items;

  /// Modules that could not be represented and were therefore left out.
  ///
  /// ESI's flag enum stops at HiSlot7/MedSlot7/LoSlot7, RigSlot2 and
  /// SubSystemSlot3. Sending an out-of-range slot as `Invalid` would make ESI
  /// discard it silently and ship a fit that differs from what the user
  /// confirmed, so those modules are surfaced here instead.
  final List<FittedModule> droppedModules;
}

/// Maps fittings onto ESI's slot-flag vocabulary.
class EsiFittingExporter {
  const EsiFittingExporter._();

  static const Map<SlotType, String> _flagPrefixes = {
    SlotType.high: 'HiSlot',
    SlotType.med: 'MedSlot',
    SlotType.low: 'LoSlot',
    SlotType.rig: 'RigSlot',
    SlotType.subsystem: 'SubSystemSlot',
  };

  /// Highest slot index ESI's flag enum defines per slot type.
  static const Map<SlotType, int> _maxSlotIndex = {
    SlotType.high: 7,
    SlotType.med: 7,
    SlotType.low: 7,
    SlotType.rig: 2,
    SlotType.subsystem: 3,
  };

  static EsiFittingExport export(Fitting fitting) {
    final items = <Map<String, dynamic>>[];
    final dropped = <FittedModule>[];

    for (final module in fitting.allModules) {
      final prefix = _flagPrefixes[module.slotType];
      final maxIndex = _maxSlotIndex[module.slotType];
      if (prefix == null || maxIndex == null || module.slotIndex > maxIndex) {
        dropped.add(module);
        continue;
      }
      items.add({
        'type_id': module.typeId,
        'flag': '$prefix${module.slotIndex}',
        'quantity': 1,
      });
    }

    return EsiFittingExport(items: items, droppedModules: dropped);
  }
}

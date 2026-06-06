import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../fitting/domain/models.dart';

class CombatFitSnapshotMapper {
  static Fitting mapCurrentShipAssets({
    required int characterId,
    required CharacterShip ship,
    required List<AssetItem> assets,
  }) {
    Log.d(
      'COMBAT.ENRICH',
      'CombatFitSnapshotMapper.mapCurrentShipAssets($characterId) - START',
    );
    final assetsByParent = <int, List<AssetItem>>{};
    for (final asset in assets) {
      assetsByParent
          .putIfAbsent(asset.locationId, () => <AssetItem>[])
          .add(asset);
    }

    final highSlots = <FittedModule>[];
    final medSlots = <FittedModule>[];
    final lowSlots = <FittedModule>[];
    final rigSlots = <FittedModule>[];
    final subsystems = <FittedModule>[];
    final drones = <DroneGroup>[];
    final cargo = <CargoItem>[];

    for (final asset
        in assetsByParent[ship.shipItemId] ?? const <AssetItem>[]) {
      final slot = _slotForFlag(asset.locationFlag);
      if (slot != null) {
        final module = _moduleFromAsset(asset, slot, assetsByParent);
        switch (slot.type) {
          case SlotType.high:
            highSlots.add(module);
          case SlotType.med:
            medSlots.add(module);
          case SlotType.low:
            lowSlots.add(module);
          case SlotType.rig:
            rigSlots.add(module);
          case SlotType.subsystem:
            subsystems.add(module);
        }
      } else if (_isDroneBayFlag(asset.locationFlag)) {
        drones.add(
          DroneGroup(
            typeId: asset.typeId,
            typeName: _typeName(asset.typeId),
            quantity: asset.quantity,
            inBay: asset.quantity,
          ),
        );
      } else if (_isCargoFlag(asset.locationFlag)) {
        cargo.add(
          CargoItem(
            typeId: asset.typeId,
            typeName: _typeName(asset.typeId),
            quantity: asset.quantity,
          ),
        );
      }
    }

    return Fitting(
      id: 'current-$characterId-${ship.shipItemId}',
      name: ship.shipName?.trim().isNotEmpty == true
          ? ship.shipName!.trim()
          : 'Current ${ship.shipTypeName ?? _typeName(ship.shipTypeId)}',
      description:
          'Current ship snapshot from ESI. User confirmation is required before treating this as historical fight evidence.',
      shipTypeId: ship.shipTypeId,
      shipName: ship.shipTypeName ?? _typeName(ship.shipTypeId),
      highSlots: highSlots..sort(_moduleSort),
      medSlots: medSlots..sort(_moduleSort),
      lowSlots: lowSlots..sort(_moduleSort),
      rigSlots: rigSlots..sort(_moduleSort),
      subsystems: subsystems..sort(_moduleSort),
      drones: drones,
      cargo: cargo,
    );
  }

  static FittedModule _moduleFromAsset(
    AssetItem asset,
    _SlotInfo slot,
    Map<int, List<AssetItem>> assetsByParent,
  ) {
    final charge = (assetsByParent[asset.itemId] ?? const <AssetItem>[])
        .where((item) => item.quantity > 0)
        .firstOrNull;
    return FittedModule(
      typeId: asset.typeId,
      typeName: _typeName(asset.typeId),
      slotType: slot.type,
      slotIndex: slot.index,
      chargeTypeId: charge?.typeId,
      chargeName: charge == null ? null : _typeName(charge.typeId),
    );
  }

  static _SlotInfo? _slotForFlag(String flag) {
    final normalized = flag.trim().toLowerCase();
    return _slotFromPrefix(normalized, 'hislot', SlotType.high) ??
        _slotFromPrefix(normalized, 'medslot', SlotType.med) ??
        _slotFromPrefix(normalized, 'loslot', SlotType.low) ??
        _slotFromPrefix(normalized, 'rigslot', SlotType.rig) ??
        _slotFromPrefix(normalized, 'subsystemslot', SlotType.subsystem);
  }

  static _SlotInfo? _slotFromPrefix(String flag, String prefix, SlotType type) {
    if (!flag.startsWith(prefix)) return null;
    final index = int.tryParse(flag.substring(prefix.length));
    return index == null ? null : _SlotInfo(type, index);
  }

  static bool _isDroneBayFlag(String flag) =>
      flag.trim().toLowerCase() == 'dronebay';

  static bool _isCargoFlag(String flag) {
    final normalized = flag.trim().toLowerCase();
    return normalized == 'cargo' || normalized == 'cargobay';
  }

  static int _moduleSort(FittedModule a, FittedModule b) {
    return a.slotIndex.compareTo(b.slotIndex);
  }

  static String _typeName(int typeId) => 'Type #$typeId';
}

class _SlotInfo {
  const _SlotInfo(this.type, this.index);

  final SlotType type;
  final int index;
}

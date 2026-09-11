import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../fitting/domain/models.dart';

class CombatKillmailFitMapper {
  static Fitting mapVictimFit(EsiKillmailDetail detail) {
    Log.d(
      'COMBAT.ENRICH',
      'CombatKillmailFitMapper.mapVictimFit(${detail.killmailId}) - START',
    );
    final highSlots = <FittedModule>[];
    final medSlots = <FittedModule>[];
    final lowSlots = <FittedModule>[];
    final rigSlots = <FittedModule>[];
    final subsystems = <FittedModule>[];
    final drones = <DroneGroup>[];
    final fightersByType = <int, FighterGroup>{};
    final cargo = <CargoItem>[];

    for (final item in detail.victim.items) {
      final slot = _slotForFlag(item.flag);
      if (slot != null) {
        final module = _moduleFromItem(item, slot);
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
      } else if (_isDroneBayFlag(item.flag)) {
        drones.add(
          DroneGroup(
            typeId: item.typeId,
            typeName: _typeName(item.typeId),
            quantity: item.totalQuantity,
            inBay: item.totalQuantity,
          ),
        );
      } else if (_isFighterBayFlag(item.flag) ||
          _isFighterTubeFlag(item.flag)) {
        final existing = fightersByType[item.typeId];
        final inSpace = _isFighterTubeFlag(item.flag) ? item.totalQuantity : 0;
        if (existing == null) {
          fightersByType[item.typeId] = FighterGroup(
            typeId: item.typeId,
            typeName: _typeName(item.typeId),
            quantity: item.totalQuantity,
            inSpace: inSpace,
          );
        } else {
          fightersByType[item.typeId] = existing.copyWith(
            quantity: existing.quantity + item.totalQuantity,
            inSpace: existing.inSpace + inSpace,
          );
        }
      } else {
        cargo.add(
          CargoItem(
            typeId: item.typeId,
            typeName: _typeName(item.typeId),
            quantity: item.totalQuantity,
          ),
        );
      }
    }

    final fighters = fightersByType.values.toList();
    Log.i(
      'COMBAT.ENRICH',
      'Mapped killmail ${detail.killmailId} victim fit: high=${highSlots.length} med=${medSlots.length} low=${lowSlots.length} rig=${rigSlots.length} drones=${drones.length} fighters=${fighters.length}',
    );
    return Fitting(
      id: 'killmail-${detail.killmailId}',
      name: 'Destroyed fit ${detail.killmailId}',
      description: 'Fit reconstructed from killmail victim items.',
      shipTypeId: detail.victim.shipTypeId,
      shipName: _typeName(detail.victim.shipTypeId),
      highSlots: highSlots..sort(_moduleSort),
      medSlots: medSlots..sort(_moduleSort),
      lowSlots: lowSlots..sort(_moduleSort),
      rigSlots: rigSlots..sort(_moduleSort),
      subsystems: subsystems..sort(_moduleSort),
      drones: drones,
      fighters: fighters,
      cargo: cargo,
    );
  }

  static FittedModule _moduleFromItem(EsiKillmailItem item, _SlotInfo slot) {
    final charge = item.items.isEmpty ? null : item.items.first;
    return FittedModule(
      typeId: item.typeId,
      typeName: _typeName(item.typeId),
      slotType: slot.type,
      slotIndex: slot.index,
      chargeTypeId: charge?.typeId,
      chargeName: charge == null ? null : _typeName(charge.typeId),
    );
  }

  static _SlotInfo? _slotForFlag(int flag) {
    if (flag >= 27 && flag <= 34) {
      return _SlotInfo(SlotType.high, flag - 27);
    }
    if (flag >= 19 && flag <= 26) {
      return _SlotInfo(SlotType.med, flag - 19);
    }
    if (flag >= 11 && flag <= 18) {
      return _SlotInfo(SlotType.low, flag - 11);
    }
    if (flag >= 92 && flag <= 99) {
      return _SlotInfo(SlotType.rig, flag - 92);
    }
    if (flag >= 125 && flag <= 132) {
      return _SlotInfo(SlotType.subsystem, flag - 125);
    }
    return null;
  }

  static bool _isDroneBayFlag(int flag) => flag == 87;

  /// invFlags FighterBay (confirmed from CCP SDE / carrier killmails).
  static bool _isFighterBayFlag(int flag) => flag == 158;

  /// invFlags FighterTube0..4.
  static bool _isFighterTubeFlag(int flag) => flag >= 159 && flag <= 163;

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

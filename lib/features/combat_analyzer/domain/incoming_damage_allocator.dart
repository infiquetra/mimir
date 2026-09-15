import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/logging/logger.dart';
import 'combat_attacker_correlation.dart';
import 'incoming_damage_allocation.dart';
import 'parsed_combat_encounter.dart';

const int incomingIntegerBound = 9007199254740991;
const String missingWeaponKey = '__missing_weapon__';

final class IncomingDamageAllocator {
  static IncomingAllocationResult allocate({
    required ParsedCombatEncounter encounter,
    required Map<String, IncomingWeaponResolution> weapons,
    required String sdeContentKey,
  }) {
    Log.d(
      'AAR.MATCHUP',
      'IncomingDamageAllocator.allocate encounter=${encounter.id}',
    );
    for (final event in encounter.events) {
      if (event.kind == CombatEventKind.damage &&
          event.direction == CombatEventDirection.incoming &&
          event.amount < 0) {
        return IncomingAllocationInvalid(
          encounterId: encounter.id,
          reasonCode: 'negativeIncomingDamage',
        );
      }
    }

    final included = [
      for (final event in encounter.events)
        if (event.isIncomingDamage) event,
    ];

    for (final entry in encounter.aggregates.incomingBySource.entries) {
      if (entry.value < 0) {
        return IncomingAllocationInvalid(
          encounterId: encounter.id,
          reasonCode: 'eventTotalsMismatch',
          affectedSourceIds: [entry.key],
        );
      }
    }

    var loggedTotal = BigInt.zero;
    final rebuilt = <String, BigInt>{};
    for (final event in included) {
      final amount = BigInt.from(event.amount);
      loggedTotal += amount;
      if (loggedTotal > BigInt.from(incomingIntegerBound) ||
          amount > BigInt.from(incomingIntegerBound)) {
        return IncomingAllocationInvalid(
          encounterId: encounter.id,
          reasonCode: 'integerOverflow',
        );
      }
      final rawKey = event.targetName ?? 'Unknown';
      rebuilt.update(rawKey, (value) => value + amount, ifAbsent: () => amount);
    }

    final aggregate = encounter.aggregates.incomingBySource;
    final aggregatePositive = <String, int>{
      for (final entry in aggregate.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    final rebuiltPositive = <String, int>{
      for (final entry in rebuilt.entries)
        if (entry.value > BigInt.zero) entry.key: entry.value.toInt(),
    };
    if (rebuiltPositive.length != aggregatePositive.length) {
      return IncomingAllocationInvalid(
        encounterId: encounter.id,
        reasonCode: 'eventTotalsMismatch',
      );
    }
    for (final entry in rebuiltPositive.entries) {
      if (aggregatePositive[entry.key] != entry.value) {
        return IncomingAllocationInvalid(
          encounterId: encounter.id,
          reasonCode: 'eventTotalsMismatch',
          affectedSourceIds: [entry.key],
        );
      }
    }
    if (loggedTotal.toInt() != encounter.totalDamageReceived) {
      return IncomingAllocationInvalid(
        encounterId: encounter.id,
        reasonCode: 'eventTotalsMismatch',
      );
    }

    final grouped = <String, List<CombatEvent>>{};
    for (final event in included) {
      grouped.putIfAbsent(event.targetName ?? 'Unknown', () => []).add(event);
    }

    final sources = <IncomingSourceAllocation>[];
    var resolvedTotal = BigInt.zero;
    var untypedTotal = BigInt.zero;
    var aggregateComponents = IncomingDamageVector.zero();

    for (final rawKey in grouped.keys) {
      final events = grouped[rawKey]!;
      events.sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
      final source = _sourceFor(
        encounter: encounter,
        rawKey: rawKey,
        events: events,
        weapons: weapons,
      );
      if (source == null) {
        return IncomingAllocationInvalid(
          encounterId: encounter.id,
          reasonCode: 'integerOverflow',
          affectedSourceIds: [rawKey],
        );
      }
      sources.add(source);
      resolvedTotal += BigInt.from(source.resolvedDamage);
      untypedTotal += BigInt.from(source.untypedDamage);
      aggregateComponents += source.components;
      if (resolvedTotal > BigInt.from(incomingIntegerBound) ||
          untypedTotal > BigInt.from(incomingIntegerBound)) {
        return IncomingAllocationInvalid(
          encounterId: encounter.id,
          reasonCode: 'integerOverflow',
          affectedSourceIds: [rawKey],
        );
      }
    }

    sources.sort((a, b) => a.sourceId.compareTo(b.sourceId));
    final allocation = IncomingDamageAllocation(
      encounterId: encounter.id,
      allocationKey: _allocationKey(
        encounter: encounter,
        sdeContentKey: sdeContentKey,
        included: included,
        weapons: weapons,
      ),
      sdeContentKey: sdeContentKey,
      pilotName: encounter.characterName,
      pilotCharacterId: encounter.characterId,
      encounterEnd: encounter.endTime,
      totalIncomingDamage: loggedTotal.toInt(),
      resolvedDamage: resolvedTotal.toInt(),
      untypedDamage: untypedTotal.toInt(),
      components: aggregateComponents,
      sources: sources,
    );
    Log.i(
      'AAR.MATCHUP',
      'allocated sources=${allocation.sources.length} '
          'resolved=${allocation.resolvedDamage} '
          'untyped=${allocation.untypedDamage} '
          'total=${allocation.totalIncomingDamage}',
    );
    return IncomingAllocationReady(allocation);
  }

  static IncomingSourceAllocation? _sourceFor({
    required ParsedCombatEncounter encounter,
    required String rawKey,
    required List<CombatEvent> events,
    required Map<String, IncomingWeaponResolution> weapons,
  }) {
    var logged = BigInt.zero;
    for (final event in events) {
      logged += BigInt.from(event.amount);
    }
    if (logged > BigInt.from(incomingIntegerBound)) return null;

    final byWeapon = <String, List<CombatEvent>>{};
    for (final event in events) {
      byWeapon.putIfAbsent(_weaponKey(event.weaponName), () => []).add(event);
    }
    final contributions = <IncomingWeaponContribution>[];
    var resolved = BigInt.zero;
    var untyped = BigInt.zero;
    var components = IncomingDamageVector.zero();
    for (final weaponKey in byWeapon.keys) {
      final group = byWeapon[weaponKey]!;
      final contribution = _weaponFor(
        weaponKey: weaponKey,
        events: group,
        weapons: weapons,
      );
      if (contribution == null) return null;
      contributions.add(contribution);
      resolved += BigInt.from(contribution.resolvedDamage);
      untyped += BigInt.from(contribution.untypedDamage);
      components += contribution.components;
    }
    contributions.sort((a, b) {
      final byKey = a.weaponKey.compareTo(b.weaponKey);
      if (byKey != 0) return byKey;
      return a.rawWeaponNames.join('|').compareTo(b.rawWeaponNames.join('|'));
    });
    final observed = <String?>[for (final event in events) event.targetName];
    return IncomingSourceAllocation(
      sourceId: _sourceId(encounter.id, rawKey),
      rawActorName: rawKey,
      normalizedActorName: normalizeCombatName(rawKey),
      observedActorNames: observed,
      loggedDamage: logged.toInt(),
      resolvedDamage: resolved.toInt(),
      untypedDamage: untyped.toInt(),
      components: components,
      weapons: contributions,
      firstSeen: events.first.timestamp,
      lastSeen: events.last.timestamp,
    );
  }

  static IncomingWeaponContribution? _weaponFor({
    required String weaponKey,
    required List<CombatEvent> events,
    required Map<String, IncomingWeaponResolution> weapons,
  }) {
    var logged = BigInt.zero;
    for (final event in events) {
      logged += BigInt.from(event.amount);
    }
    if (logged > BigInt.from(incomingIntegerBound)) return null;
    final d = logged.toInt();
    final lookupName = weaponKey == missingWeaponKey ? '' : weaponKey;
    final resolution =
        weapons[lookupName] ??
        IncomingWeaponResolution(
          normalizedName: lookupName,
          status: weaponKey == missingWeaponKey
              ? WeaponResolutionStatus.missingName
              : WeaponResolutionStatus.lookupFailed,
          reasonCode: weaponKey == missingWeaponKey
              ? 'missingName'
              : 'lookupFailed',
        );
    final attributes = resolution.attributes;
    final attributeSum = attributes?.total ?? DamageQuantity.fromInt(0);
    IncomingDamageVector components;
    var resolved = 0;
    var untyped = 0;
    var used = resolution;
    if (resolution.status == WeaponResolutionStatus.resolved &&
        attributes != null &&
        !attributeSum.isZero) {
      components = IncomingDamageVector(
        em: DamageQuantity.fromInt(d) * attributes.em / attributeSum,
        thermal: DamageQuantity.fromInt(d) * attributes.thermal / attributeSum,
        kinetic: DamageQuantity.fromInt(d) * attributes.kinetic / attributeSum,
        explosive:
            DamageQuantity.fromInt(d) * attributes.explosive / attributeSum,
      );
      resolved = d;
    } else {
      components = IncomingDamageVector.zero();
      untyped = d;
      if (resolution.status == WeaponResolutionStatus.resolved &&
          attributeSum.isZero) {
        used = IncomingWeaponResolution(
          normalizedName: resolution.normalizedName,
          typeId: resolution.typeId,
          typeName: resolution.typeName,
          status: WeaponResolutionStatus.noPositiveDamage,
          reasonCode: 'noPositiveDamage',
        );
      }
    }
    final rawNames = {
      for (final event in events) event.weaponName ?? '',
    }.toList()..sort();
    final eventIds = [for (final event in events) event.id];
    return IncomingWeaponContribution(
      weaponKey: weaponKey,
      rawWeaponNames: rawNames,
      eventIds: eventIds,
      firstSeen: events.first.timestamp,
      lastSeen: events.last.timestamp,
      loggedDamage: d,
      resolvedDamage: resolved,
      untypedDamage: untyped,
      components: components,
      resolution: used,
    );
  }

  static String _weaponKey(String? weaponName) {
    if (weaponName == null) return missingWeaponKey;
    final normalized = normalizeCombatName(weaponName);
    if (normalized.isEmpty || normalized == 'unknown') {
      return missingWeaponKey;
    }
    return normalized;
  }

  static String _sourceId(String encounterId, String rawKey) {
    final encoded = base64Url.encode(utf8.encode(rawKey)).replaceAll('=', '');
    return '$encounterId:$encoded';
  }

  static String _allocationKey({
    required ParsedCombatEncounter encounter,
    required String sdeContentKey,
    required List<CombatEvent> included,
    required Map<String, IncomingWeaponResolution> weapons,
  }) {
    final events = [...included]..sort((a, b) => a.id.compareTo(b.id));
    final weaponKeys = weapons.keys.toList()..sort();
    final sourceKeys = encounter.aggregates.incomingBySource.keys.toList()
      ..sort();
    final payload = {
      'encounterId': encounter.id,
      'pilotName': encounter.characterName,
      'pilotCharacterId': encounter.characterId,
      'start': encounter.startTime.toUtc().toIso8601String(),
      'end': encounter.endTime.toUtc().toIso8601String(),
      'sdeContentKey': sdeContentKey,
      'totalIncomingDamage': encounter.totalDamageReceived,
      'incomingBySource': {
        for (final key in sourceKeys)
          key: encounter.aggregates.incomingBySource[key],
      },
      'events': [
        for (final event in events)
          {
            'id': event.id,
            'amount': event.amount,
            'target': event.targetName,
            'weapon': event.weaponName,
            'time': event.timestamp.toUtc().toIso8601String(),
          },
      ],
      'weapons': [
        for (final key in weaponKeys)
          {
            'key': key,
            'status': weapons[key]!.status.name,
            'typeName': weapons[key]!.typeName,
            'attributes': weapons[key]!.attributes?.toJson(),
          },
      ],
    };
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }
}

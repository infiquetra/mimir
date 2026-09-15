import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_providers.dart';
import '../domain/combat_attacker_correlation.dart';
import '../domain/combat_damage_profile.dart';
import '../domain/incoming_damage_allocation.dart';
import '../domain/incoming_damage_allocator.dart';
import '../domain/parsed_combat_encounter.dart';

final combatDamageProfileResolverProvider =
    Provider<CombatDamageProfileResolver>((ref) {
      Log.d('COMBAT.DAMAGE', 'combatDamageProfileResolverProvider() - START');
      return CombatDamageProfileResolver(
        database: ref.watch(sdeDatabaseProvider),
      );
    });

final combatDamageProfileProvider =
    FutureProvider.family<CombatDamageProfile, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'COMBAT.DAMAGE',
        'combatDamageProfileProvider(encounter=${encounter.id}) - START',
      );
      await ref.watch(sdeInitializerProvider.future);
      final resolver = ref.watch(combatDamageProfileResolverProvider);
      return resolver.resolveOutgoingProfile(encounter);
    });

final combatIncomingDamageProfileProvider =
    FutureProvider.family<CombatDamageProfile, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'COMBAT.DAMAGE',
        'combatIncomingDamageProfileProvider(encounter=${encounter.id}) - START',
      );
      await ref.watch(sdeInitializerProvider.future);
      final resolver = ref.watch(combatDamageProfileResolverProvider);
      return resolver.resolveIncomingProfile(encounter);
    });

class CombatDamageProfileResolver {
  CombatDamageProfileResolver({required SdeDatabase database})
    : _database = database;

  static const int emDamageAttribute = 114;
  static const int explosiveDamageAttribute = 116;
  static const int kineticDamageAttribute = 117;
  static const int thermalDamageAttribute = 118;

  final SdeDatabase _database;

  Future<CombatDamageProfile> resolveOutgoingProfile(
    ParsedCombatEncounter encounter,
  ) => _resolve(encounter, incoming: false);

  Future<CombatDamageProfile> resolveIncomingProfile(
    ParsedCombatEncounter encounter,
  ) async {
    final result = await resolveIncomingAllocation(
      encounter,
      sdeContentKey: 'sde-decimal-v1',
    );
    if (result is IncomingAllocationReady) {
      return result.allocation.toLegacyProfile();
    }
    return _resolve(encounter, incoming: true);
  }

  Future<IncomingAllocationResult> resolveIncomingAllocation(
    ParsedCombatEncounter encounter, {
    required String sdeContentKey,
  }) async {
    Log.d(
      'AAR.MATCHUP',
      'resolveIncomingAllocation(encounter=${encounter.id}) - START',
    );
    final names = <String>{};
    for (final event in encounter.events) {
      if (!event.isIncomingDamage) continue;
      final weapon = event.weaponName;
      if (weapon == null) continue;
      final key = normalizeCombatName(weapon);
      if (key.isEmpty || key == 'unknown') continue;
      names.add(weapon);
    }
    final memo = <String, IncomingWeaponResolution>{};
    for (final name in names) {
      final key = normalizeCombatName(name);
      if (memo.containsKey(key)) continue;
      memo[key] = await _resolveIncomingWeapon(name);
    }
    final result = IncomingDamageAllocator.allocate(
      encounter: encounter,
      weapons: memo,
      sdeContentKey: sdeContentKey,
    );
    if (result is IncomingAllocationReady) {
      Log.i(
        'AAR.MATCHUP',
        'resolveIncomingAllocation sources=${result.allocation.sources.length} '
            'resolved=${result.allocation.resolvedDamage} '
            'untyped=${result.allocation.untypedDamage}',
      );
    } else if (result is IncomingAllocationInvalid) {
      Log.w(
        'AAR.MATCHUP',
        'resolveIncomingAllocation invalid ${result.reasonCode}',
      );
    }
    return result;
  }

  Future<IncomingWeaponResolution> _resolveIncomingWeapon(String name) async {
    final normalized = normalizeCombatName(name);
    try {
      final matches = await _database.searchTypesByName(name, limit: 20);
      final exact = [
        for (final match in matches)
          if (normalizeCombatName(match.typeName) == normalized) match,
      ];
      if (exact.length > 1) {
        return IncomingWeaponResolution(
          normalizedName: normalized,
          status: WeaponResolutionStatus.ambiguousType,
          reasonCode: 'ambiguousType',
        );
      }
      if (exact.isEmpty) {
        return IncomingWeaponResolution(
          normalizedName: normalized,
          status: WeaponResolutionStatus.noExactType,
          reasonCode: 'noExactType',
        );
      }
      final type = exact.single;
      try {
        final attributes = await _database.getTypeAttributes(type.typeId);
        final vector = IncomingDamageVector(
          em: DamageQuantity.fromSdeNumber(attributes[emDamageAttribute] ?? 0),
          thermal: DamageQuantity.fromSdeNumber(
            attributes[thermalDamageAttribute] ?? 0,
          ),
          kinetic: DamageQuantity.fromSdeNumber(
            attributes[kineticDamageAttribute] ?? 0,
          ),
          explosive: DamageQuantity.fromSdeNumber(
            attributes[explosiveDamageAttribute] ?? 0,
          ),
        );
        if (vector.total.isZero) {
          return IncomingWeaponResolution(
            normalizedName: normalized,
            typeId: type.typeId,
            typeName: type.typeName,
            status: WeaponResolutionStatus.noPositiveDamage,
            reasonCode: 'noPositiveDamage',
          );
        }
        return IncomingWeaponResolution(
          normalizedName: normalized,
          typeId: type.typeId,
          typeName: type.typeName,
          status: WeaponResolutionStatus.resolved,
          attributes: vector,
        );
      } catch (e, stack) {
        Log.e(
          'AAR.MATCHUP',
          'weapon attribute lookup failed for $name',
          e,
          stack,
        );
        return IncomingWeaponResolution(
          normalizedName: normalized,
          typeId: type.typeId,
          typeName: type.typeName,
          status: WeaponResolutionStatus.lookupFailed,
          reasonCode: 'lookupFailed',
        );
      }
    } catch (e, stack) {
      Log.e('AAR.MATCHUP', 'weapon type search failed for $name', e, stack);
      rethrow;
    }
  }

  Future<CombatDamageProfile> _resolve(
    ParsedCombatEncounter encounter, {
    required bool incoming,
  }) async {
    Log.d(
      'COMBAT.DAMAGE',
      '${incoming ? 'resolveIncomingProfile' : 'resolveOutgoingProfile'}'
          '(encounter=${encounter.id}) - START',
    );
    final damageByType = <String, double>{};
    final evidenceByType = <String, Set<String>>{};
    final unknownWeapons = <String>{};

    final damageByWeapon = <String, int>{};
    for (final event in encounter.events.where(
      (event) => incoming ? event.isIncomingDamage : event.isOutgoingDamage,
    )) {
      final weapon = event.weaponName?.trim();
      if (weapon == null || weapon.isEmpty || weapon == 'Unknown') {
        unknownWeapons.add('Unknown');
        continue;
      }
      damageByWeapon.update(
        weapon,
        (value) => value + event.amount,
        ifAbsent: () => event.amount,
      );
    }

    for (final entry in damageByWeapon.entries) {
      final weaponName = entry.key;
      final damageAmount = entry.value;
      final attributes = await _lookupDamageAttributes(weaponName);
      if (attributes == null || attributes.total <= 0) {
        unknownWeapons.add(weaponName);
        continue;
      }

      for (final damageEntry in attributes.damageByType.entries) {
        if (damageEntry.value <= 0) continue;
        final weightedAmount =
            damageAmount * (damageEntry.value / attributes.total);
        damageByType.update(
          damageEntry.key,
          (value) => value + weightedAmount,
          ifAbsent: () => weightedAmount,
        );
        evidenceByType
            .putIfAbsent(damageEntry.key, () => <String>{})
            .add(weaponName);
      }
    }

    final profiledTotal = damageByType.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final entries = damageByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final profile = CombatDamageProfile(
      totalProfiledDamage: profiledTotal.round(),
      unknownWeapons: unknownWeapons.toList()..sort(),
      resolvedWeapons:
          damageByWeapon.keys.where((k) => !unknownWeapons.contains(k)).toList()
            ..sort(),
      entries: entries
          .map(
            (entry) => CombatDamageTypeEstimate(
              type: entry.key,
              amount: entry.value.round(),
              percent: profiledTotal <= 0 ? 0 : entry.value / profiledTotal,
              confidence: CombatDamageConfidence.sdeExact,
              source: (evidenceByType[entry.key]?.toList() ?? const []).join(
                ', ',
              ),
              evidence: 'Resolved from exact SDE type damage attributes.',
            ),
          )
          .toList(),
    );

    Log.i(
      'COMBAT.DAMAGE',
      'Resolved ${profile.entries.length} damage types; unknown weapons=${profile.unknownWeapons.length}',
    );
    return profile;
  }

  Future<_DamageAttributes?> _lookupDamageAttributes(String weaponName) async {
    Log.d('COMBAT.DAMAGE', '_lookupDamageAttributes($weaponName) - START');
    final matches = await _database.searchTypesByName(weaponName, limit: 20);
    final normalized = _normalizeTypeName(weaponName);
    SdeType? exactMatch;
    for (final match in matches) {
      if (_normalizeTypeName(match.typeName) == normalized) {
        exactMatch = match;
        break;
      }
    }
    if (exactMatch == null) {
      Log.d('COMBAT.DAMAGE', 'No exact SDE type for $weaponName');
      return null;
    }

    final attributes = await _database.getTypeAttributes(exactMatch.typeId);
    final damageByType = <String, double>{
      'EM': attributes[emDamageAttribute] ?? 0,
      'Explosive': attributes[explosiveDamageAttribute] ?? 0,
      'Kinetic': attributes[kineticDamageAttribute] ?? 0,
      'Thermal': attributes[thermalDamageAttribute] ?? 0,
    };
    final total = damageByType.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    return _DamageAttributes(damageByType: damageByType, total: total);
  }

  String _normalizeTypeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

class _DamageAttributes {
  const _DamageAttributes({required this.damageByType, required this.total});

  final Map<String, double> damageByType;
  final double total;
}

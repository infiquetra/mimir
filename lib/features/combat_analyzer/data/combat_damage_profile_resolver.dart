import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_providers.dart';
import '../domain/combat_damage_profile.dart';
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
  ) async {
    Log.d(
      'COMBAT.DAMAGE',
      'resolveOutgoingProfile(encounter=${encounter.id}) - START',
    );
    final damageByType = <String, double>{};
    final evidenceByType = <String, Set<String>>{};
    final unknownWeapons = <String>{};

    final outgoingByWeapon = <String, int>{};
    for (final event in encounter.events.where(
      (event) => event.isOutgoingDamage,
    )) {
      final weapon = event.weaponName?.trim();
      if (weapon == null || weapon.isEmpty || weapon == 'Unknown') {
        unknownWeapons.add('Unknown');
        continue;
      }
      outgoingByWeapon.update(
        weapon,
        (value) => value + event.amount,
        ifAbsent: () => event.amount,
      );
    }

    for (final entry in outgoingByWeapon.entries) {
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

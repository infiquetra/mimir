import '../../../core/logging/logger.dart';
import '../../fitting/domain/damage_pattern.dart';
import 'combat_damage_profile.dart';

extension CombatDamageProfilePattern on CombatDamageProfile {
  /// Builds a [DamagePattern] from typed profile entries. Unknown weapons are
  /// already excluded from [CombatDamageProfile.entries].
  DamagePattern? toDamagePattern({String label = 'observed incoming'}) {
    double amountOf(String type) {
      var sum = 0.0;
      for (final entry in entries) {
        if (entry.type.toLowerCase() == type.toLowerCase()) {
          sum += entry.amount;
        }
      }
      return sum;
    }

    Log.d(
      'COMBAT',
      'CombatDamageProfile.toDamagePattern entries=${entries.length} label=$label',
    );
    return DamagePattern.fromAmounts(
      em: amountOf('EM'),
      thermal: amountOf('Thermal'),
      kinetic: amountOf('Kinetic'),
      explosive: amountOf('Explosive'),
      label: label,
    );
  }
}

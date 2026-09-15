import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../wallet/data/wallet_providers.dart';
import '../../domain/aar_attacker_matchup.dart';
import '../../domain/combat_attacker_correlation.dart';
import '../../domain/incoming_damage_allocation.dart';
import '../../domain/incoming_damage_matchup.dart';
import '../../domain/tank_classifier.dart';

class AarAttackerMatchupCard extends ConsumerWidget {
  const AarAttackerMatchupCard({
    super.key,
    required this.matchup,
    required this.encounterId,
    required this.expanded,
    required this.onToggle,
    this.totalIncomingDamage = 0,
  });

  final AarAttackerMatchup matchup;
  final String encounterId;
  final bool expanded;
  final VoidCallback onToggle;
  final int totalIncomingDamage;

  String get _sourceId => matchup.source.allocation.sourceId;

  Key _part(String part) => Key('aar-incoming-$encounterId-$_sourceId-$part');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('COMBAT.UI', 'AarAttackerMatchupCard $_sourceId expanded=$expanded');
    final allocation = matchup.source.allocation;
    final identity = matchup.source.identity;
    final characterName = _characterName(identity);
    final shipName = _shipName(ref, identity);
    final semanticsLabel = _semanticsLabel(characterName, shipName, allocation);

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Card(
        key: _part('card'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(characterName, shipName, allocation),
              const SizedBox(height: 8),
              _confidence(identity, characterName),
              const SizedBox(height: 8),
              _loggedAmount(allocation),
              const SizedBox(height: 8),
              _coverage(allocation),
              if (allocation.resolvedDamage > 0) ...[
                const SizedBox(height: 8),
                _split(context, allocation),
              ],
              if (_showEhp) ...[
                const SizedBox(height: 8),
                _defense(context, characterName),
              ],
              if (expanded) ...[
                const SizedBox(height: 8),
                _evidence(allocation),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _showEhp =>
      matchup.defense.ehp != null &&
      matchup.defense.status != IncomingDefenseStatus.noTypedDamage &&
      matchup.defense.status != IncomingDefenseStatus.pilotDefenseUnavailable;

  Widget _header(
    String characterName,
    String shipName,
    IncomingSourceAllocation allocation,
  ) {
    return FocusableActionDetector(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onToggle();
            return null;
          },
        ),
      },
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: _part('header'),
          onTap: onToggle,
          child: Semantics(
            button: true,
            expanded: expanded,
            label: '$characterName incoming damage details',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        characterName,
                        style: const TextStyle(
                          color: EveColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        shipName,
                        style: const TextStyle(color: EveColors.textSecondary),
                      ),
                      Text(
                        'Logged as ${allocation.rawActorName}',
                        style: const TextStyle(
                          color: EveColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _confidence(CorrelatedAttacker? identity, String characterName) {
    final confidence = identity?.confidence;
    if (confidence == null) return const SizedBox.shrink();
    final (icon, color) = switch (confidence) {
      AttackerCorrelationConfidence.confirmed => (
        Icons.check_circle,
        EveColors.success,
      ),
      AttackerCorrelationConfidence.probable => (
        Icons.help_outline,
        EveColors.warning,
      ),
      AttackerCorrelationConfidence.possible => (
        Icons.warning_amber,
        EveColors.warning,
      ),
    };
    return Column(
      key: _part('confidence'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(confidence.label, style: TextStyle(color: color)),
          ],
        ),
        if (confidence == AttackerCorrelationConfidence.probable)
          Text(
            'Assuming this actor is $characterName',
            style: const TextStyle(color: EveColors.warning, fontSize: 12),
          ),
      ],
    );
  }

  Widget _loggedAmount(IncomingSourceAllocation allocation) {
    final total = totalIncomingDamage <= 0
        ? 0.0
        : allocation.loggedDamage / totalIncomingDamage;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('${_formatInt(allocation.loggedDamage)} logged'),
        Text('${_percent(total)} of incoming'),
      ],
    );
  }

  Widget _coverage(IncomingSourceAllocation allocation) {
    final d = allocation.loggedDamage;
    final k = allocation.resolvedDamage;
    final u = allocation.untypedDamage;
    final children = <Widget>[];
    if (k <= 0) {
      children.add(const Text('Damage types unresolved'));
    } else {
      final coverage = d == 0 ? 0.0 : k / d;
      children.add(
        Text('${_formatInt(k)}/${_formatInt(d)} ${_percent(coverage)}'),
      );
      if (u > 0) {
        children.add(Text('U ${_formatInt(u)} already included'));
        children.add(const Text('Resolved portion only'));
      } else {
        children.add(const Text('SDE-derived from logged weapons'));
      }
    }
    return Wrap(
      key: _part('coverage'),
      spacing: 8,
      runSpacing: 4,
      children: children,
    );
  }

  Widget _split(BuildContext context, IncomingSourceAllocation allocation) {
    final total = allocation.components.total;
    final rows = <Widget>[
      for (final type in IncomingDamageType.values)
        Text(
          '${_typeLabel(type)} ${_percent1(_fraction(allocation.components[type], total))} '
          '(${_formatQuantity(allocation.components[type])})',
        ),
      const Text('100.0%'),
    ];
    return Container(
      key: _part('split'),
      width: double.infinity,
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _defense(BuildContext context, String characterName) {
    final defense = matchup.defense;
    final ehp = defense.ehp!;
    final partial = matchup.source.allocation.untypedDamage > 0;
    final twoCol = _useTwoColumns(context);
    final profile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your EHP vs $characterName',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(_formatInt(ehp.total.round())),
        Text(
          'shield ${_formatInt(ehp.shield.round())} / '
          'armor ${_formatInt(ehp.armor.round())} / '
          'hull ${_formatInt(ehp.hull.round())}',
        ),
        if (!partial && defense.omniEhp != null)
          Text('Omni reference ${_formatInt(defense.omniEhp!.total.round())}'),
      ],
    );
    final hole = _hole(defense);
    if (!twoCol) {
      return Column(
        key: _part('ehp'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [profile, ?hole],
      );
    }
    return Row(
      key: _part('ehp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: profile),
        const SizedBox(width: 12),
        if (hole != null) Expanded(child: hole) else const Spacer(),
      ],
    );
  }

  Widget? _hole(AarIncomingDefenseMatchup defense) {
    if (defense.layer == TankLayer.unknown) return null;
    if (defense.primaryHole == null) return null;
    if (defense.pressureStatus != IncomingPressureStatus.available) {
      return null;
    }
    final hole = defense.primaryHole!;
    IncomingResistResult? entry;
    for (final item in defense.entries) {
      if (item.type == hole) {
        entry = item;
        break;
      }
    }
    final layer = _layerLabel(defense.layer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: _part('hole'),
          'Primary pressured hole ${_typeLabel(hole)} ($layer)',
        ),
        Text(
          key: _part('pressure'),
          'Modeled share after $layer resists'
          '${entry?.modeledPressure == null ? '' : ' ${_percent1(entry!.modeledPressure!)}'}',
        ),
      ],
    );
  }

  Widget _evidence(IncomingSourceAllocation allocation) {
    return Column(
      key: _part('evidence'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weapons and evidence',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final weapon in allocation.weapons)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${weapon.rawWeaponNames.join(', ')} · '
              '${_formatInt(weapon.loggedDamage)} · '
              '${weapon.eventIds.length} events · '
              '${_timestamp(weapon.firstSeen)}–${_timestamp(weapon.lastSeen)}',
            ),
          ),
        for (final code in [
          ...matchup.source.limitationCodes,
          ...matchup.defense.limitationCodes,
        ])
          Text(code, style: const TextStyle(color: EveColors.textTertiary)),
      ],
    );
  }

  String _characterName(CorrelatedAttacker? identity) {
    final name = identity?.participant.characterName?.trim();
    if (name == null || name.isEmpty) return 'Character name unavailable';
    return name;
  }

  String _shipName(WidgetRef ref, CorrelatedAttacker? identity) {
    final typeId = identity?.participant.shipTypeId;
    if (typeId == null) return 'Unknown ship';
    final async = ref.watch(itemNameProvider(typeId));
    return async.when(
      data: (name) {
        if (name.trim().isEmpty) return 'Unknown ship';
        if (_leaksId(name, typeId)) return 'Unknown ship';
        return name;
      },
      loading: () => 'Loading…',
      error: (_, _) => 'Unknown ship',
    );
  }

  String _semanticsLabel(
    String characterName,
    String shipName,
    IncomingSourceAllocation allocation,
  ) {
    return '$characterName, $shipName, Logged as ${allocation.rawActorName}';
  }

  bool _useTwoColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return width >= 720 && scale <= 1.3;
  }
}

String _typeLabel(IncomingDamageType type) => switch (type) {
  IncomingDamageType.em => 'EM',
  IncomingDamageType.thermal => 'Thermal',
  IncomingDamageType.kinetic => 'Kinetic',
  IncomingDamageType.explosive => 'Explosive',
};

String _layerLabel(TankLayer layer) => switch (layer) {
  TankLayer.shield => 'shield',
  TankLayer.armor => 'armor',
  TankLayer.hull => 'hull',
  TankLayer.unknown => 'unknown',
};

double _fraction(DamageQuantity part, DamageQuantity total) {
  if (total.isZero) return 0;
  return (part / total).toFiniteDouble();
}

String _formatQuantity(DamageQuantity quantity) {
  return _formatInt(quantity.toFiniteDouble().round());
}

String _timestamp(DateTime value) {
  final utc = value.toUtc();
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  final ss = utc.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

bool _leaksId(String value, int typeId) {
  if (value.contains('Type #')) return true;
  if (RegExp(r'\ba\d+\b').hasMatch(value)) return true;
  return value.contains('$typeId');
}

String _formatInt(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buf = StringBuffer(sign);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

String _percent(double fraction) {
  if (!fraction.isFinite) return '0%';
  return '${(fraction * 100).round()}%';
}

String _percent1(double fraction) {
  if (!fraction.isFinite) return '0.0%';
  return '${(fraction * 100).toStringAsFixed(1)}%';
}

import 'package:flutter/material.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';

class WormholeDatabaseViewModel {
  const WormholeDatabaseViewModel({
    this.types = const [],
    this.systems = const [],
    this.groups = const [],
    this.selectedType,
    this.selectedSystem,
    this.selectedEffect,
    this.statusVersion = '',
  });

  final List<WormholeTypeReference> types;
  final List<SystemReference> systems;
  final List<WormholeCodeGroup> groups;
  final WormholeTypeReference? selectedType;
  final SystemReference? selectedSystem;
  final SystemEffect? selectedEffect;
  final String statusVersion;
}

/// Naive X8 database: minutes-as-lifetime, zeros for unknowns, Live status,
/// unfiltered lists, Nullsec for Thera/Pochven, raw IDs, overflowing chips.
class WormholeDatabaseView extends StatelessWidget {
  const WormholeDatabaseView({super.key, this.model});

  final WormholeDatabaseViewModel? model;

  @override
  Widget build(BuildContext context) {
    final data = model ?? const WormholeDatabaseViewModel();
    final type = data.selectedType;
    final minutes = (type?.reliableLifetimeSeconds ?? 0) ~/ 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          key: Key('reference-status-strip'),
          children: [Text('Live'), Icon(Icons.refresh)],
        ),
        const Row(
          children: [
            FilterChip(label: Text('Highsec'), onSelected: _noop),
            FilterChip(label: Text('Lowsec'), onSelected: _noop),
            FilterChip(label: Text('Nullsec'), onSelected: _noop),
            FilterChip(label: Text('Pochven'), onSelected: _noop),
            FilterChip(label: Text('J-space'), onSelected: _noop),
            FilterChip(label: Text('Other'), onSelected: _noop),
            FilterChip(label: Text('Capital'), onSelected: _noop),
          ],
        ),
        const TextField(decoration: InputDecoration(labelText: 'Search types')),
        const Row(children: [Text('Types'), Text('Systems')]),
        Expanded(
          child: ListView(
            children: [
              for (final row in data.types)
                ListTile(
                  title: Text(row.code),
                  subtitle: Text('Item #${row.typeId}'),
                ),
              if (type != null) ...[
                Text('${type.code} lifetime ${minutes}m'),
                Text('${type.maxJumpMassKg ?? 0} kg'),
                Text('${type.totalMassKg ?? 0} kg'),
                Text('${type.regenerationKgPerCycle ?? 0} kg/cycle'),
              ],
              for (final group in data.groups)
                Text(
                  '${group.code} ${group.sharedJumpMassKg ?? group.variants.first.maxJumpMassKg}',
                ),
              if (data.selectedSystem != null) ...[
                Text('${data.selectedSystem!.systemId}'),
                Text(
                  data.selectedSystem!.rawSecurity != null &&
                          data.selectedSystem!.rawSecurity! <= 0
                      ? 'Nullsec'
                      : 'Highsec',
                ),
              ],
              for (final modifier in data.selectedEffect?.modifiers ?? const [])
                Text('${modifier.label} ${modifier.percentChange}'),
              for (final assignment in data.selectedSystem?.statics ?? const [])
                Text(assignment.code ?? ''),
            ],
          ),
        ),
      ],
    );
  }
}

void _noop(bool _) {}

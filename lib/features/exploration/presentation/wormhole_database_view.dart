import 'package:flutter/material.dart';
import 'package:mimir/core/logging/logger.dart';
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

/// Offline wormhole/system reference browser (design §6.2–§6.4).
class WormholeDatabaseView extends StatefulWidget {
  const WormholeDatabaseView({super.key, this.model});

  final WormholeDatabaseViewModel? model;

  @override
  State<WormholeDatabaseView> createState() => _WormholeDatabaseViewState();
}

class _WormholeDatabaseViewState extends State<WormholeDatabaseView> {
  static const _log = 'EXPLORATION.UI';
  static const _detailBreakpoint = 1100.0;

  final _search = TextEditingController();
  var _query = '';
  var _showSystems = false;
  var _capitalOnly = false;
  String? _destination;

  WormholeDatabaseViewModel get _model =>
      widget.model ?? const WormholeDatabaseViewModel();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.d(_log, 'database view systems=$_showSystems query="$_query"');
    return LayoutBuilder(
      builder: (context, constraints) {
        final masterDetail = constraints.maxWidth >= _detailBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReferenceStatusStrip(version: _model.statusVersion),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Types'),
                    selected: !_showSystems,
                    onSelected: (_) => setState(() => _showSystems = false),
                  ),
                  ChoiceChip(
                    label: const Text('Systems'),
                    selected: _showSystems,
                    onSelected: (_) => setState(() => _showSystems = true),
                  ),
                ],
              ),
            ),
            if (!_showSystems) _typeFilters(),
            Expanded(
              child: masterDetail
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: ListView(children: _masterTiles())),
                        Expanded(
                          child: ColoredBox(
                            key: const Key('exploration-database-detail-pane'),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            child: ListView(
                              padding: const EdgeInsets.all(12),
                              children: _detailSlivers(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      children: [..._masterTiles(), ..._detailSlivers()],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _typeFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final label in const [
            'Highsec',
            'Lowsec',
            'Nullsec',
            'Pochven',
            'J-space',
          ])
            FilterChip(
              label: Text(label),
              selected: _destination == label,
              onSelected: (selected) {
                setState(() => _destination = selected ? label : null);
              },
            ),
          FilterChip(
            label: const Text('Capital'),
            selected: _capitalOnly,
            onSelected: (selected) {
              setState(() {
                _capitalOnly = selected;
                if (selected) {
                  _search.clear();
                  _query = '';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _masterTiles() {
    if (_showSystems) {
      return [
        for (final system in _filteredSystems())
          ListTile(
            title: Text(system.name, softWrap: true),
            subtitle: Text(_securityLabel(system), softWrap: true),
          ),
      ];
    }
    return [
      for (final type in _filteredTypes())
        ListTile(
          title: Text(type.code, softWrap: true),
          subtitle: Text(type.destinationLabel, softWrap: true),
        ),
      for (final group in _filteredGroups())
        ListTile(
          title: Text(group.code, softWrap: true),
          subtitle: Text('${group.variants.length} variants', softWrap: true),
        ),
    ];
  }

  List<Widget> _detailSlivers() {
    return [
      if (_model.selectedType != null) _typeDetail(_model.selectedType!),
      for (final group in _model.groups) _groupDetail(group),
      if (_model.selectedSystem != null) _systemDetail(_model.selectedSystem!),
      if (_model.selectedEffect != null) _effectDetail(_model.selectedEffect!),
    ];
  }

  Widget _typeDetail(WormholeTypeReference type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(type.code, style: Theme.of(context).textTheme.titleMedium),
        Text('Lifetime ${_formatLifetime(type.reliableLifetimeSeconds)}'),
        Text('Total mass ${_formatKg(type.totalMassKg)}'),
        Text('Jump mass ${_formatKg(type.maxJumpMassKg)}'),
        Text('Regen ${_formatRegen(type.regenerationKgPerCycle)}'),
        Text('Destination ${type.destinationLabel}'),
      ],
    );
  }

  Widget _groupDetail(WormholeCodeGroup group) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        group.jumpVaries
            ? '${group.code} Varies'
            : '${group.code} ${_formatKg(group.sharedJumpMassKg)}',
      ),
    );
  }

  Widget _systemDetail(SystemReference system) {
    final hierarchy = [
      system.name,
      if (system.constellationName != null &&
          system.constellationName!.isNotEmpty)
        system.constellationName,
      if (system.regionName != null && system.regionName!.isNotEmpty)
        system.regionName,
    ].join(' → ');
    final statics = system.statics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(hierarchy, style: Theme.of(context).textTheme.titleMedium),
        Text(_securityLabel(system)),
        Text('Security ${system.securityDisplay}'),
        if (statics.isEmpty)
          const Text('Static information unavailable')
        else
          for (final assignment in statics)
            Text(
              [
                assignment.code ?? 'Static information unavailable',
                if (assignment.source.isNotEmpty) assignment.source,
                if (assignment.meaning.isNotEmpty) assignment.meaning,
              ].join(' · '),
            ),
      ],
    );
  }

  Widget _effectDetail(SystemEffect effect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Effect ${effect.family.name} ${effect.strength}'),
        for (final modifier in effect.modifiers)
          Text(
            '${modifier.label} ${_formatPercent(modifier.percentChange)}'
            '${modifier.scope.isEmpty ? '' : ' ${modifier.scope}'}',
          ),
      ],
    );
  }

  List<WormholeTypeReference> _filteredTypes() {
    final query = _query.trim().toLowerCase();
    return [
      for (final type in _model.types)
        if (_matchesType(type, query)) type,
    ];
  }

  List<WormholeCodeGroup> _filteredGroups() {
    final query = _query.trim().toLowerCase();
    return [
      for (final group in _model.groups)
        if (_matchesGroup(group, query)) group,
    ];
  }

  List<SystemReference> _filteredSystems() {
    final query = _query.trim().toLowerCase();
    return [
      for (final system in _model.systems)
        if (query.isEmpty || system.name.toLowerCase().contains(query)) system,
    ];
  }

  bool _matchesType(WormholeTypeReference type, String query) {
    if (_capitalOnly && !type.isCapitalSize) return false;
    if (_destination != null && type.destinationLabel != _destination) {
      return false;
    }
    if (query.isEmpty) return true;
    return type.code.toLowerCase().contains(query) ||
        type.name.toLowerCase().contains(query);
  }

  bool _matchesGroup(WormholeCodeGroup group, String query) {
    if (_capitalOnly) {
      final jump = group.sharedJumpMassKg;
      if (jump == null || jump < WormholeTypeReference.capitalJumpThresholdKg) {
        return false;
      }
    }
    if (query.isEmpty) return true;
    return group.code.toLowerCase().contains(query);
  }

  static String _securityLabel(SystemReference system) {
    switch (system.category) {
      case SecurityCategory.highsec:
        return 'Highsec';
      case SecurityCategory.lowsec:
        return 'Lowsec';
      case SecurityCategory.nullsec:
        return 'Nullsec';
      case SecurityCategory.unknown:
        return 'Unknown';
      case SecurityCategory.special:
        return switch (system.rawClass) {
          12 => 'Thera',
          25 => 'Pochven',
          13 => 'Shattered',
          _ when (system.rawClass ?? 0) >= 1 && (system.rawClass ?? 0) <= 6 =>
            'J-space',
          _ => 'Special',
        };
    }
  }

  static String _formatLifetime(int? seconds) {
    if (seconds == null) return 'Unknown';
    return '${seconds}s';
  }

  static String _formatKg(double? kg) {
    if (kg == null) return 'Unknown';
    return '${_number(kg)} kg';
  }

  static String _formatRegen(double? kg) {
    if (kg == null) return 'Unknown';
    return '${_number(kg)} kg/cycle';
  }

  static String _formatPercent(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${_number(value)}%';
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) return '${value.round()}';
    return '$value';
  }
}

class _ReferenceStatusStrip extends StatelessWidget {
  const _ReferenceStatusStrip({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final label = version.isEmpty
        ? 'Reference data installed'
        : 'Reference data $version';
    return Padding(
      key: const Key('reference-status-strip'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Icon(
            Icons.offline_pin,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(label),
        ],
      ),
    );
  }
}

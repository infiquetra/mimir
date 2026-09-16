import 'package:flutter/material.dart';
import 'package:mimir/features/corporation/domain/corporation_access.dart';
import 'package:mimir/features/corporation/domain/corporation_fuel_calculator.dart';
import 'package:mimir/features/corporation/domain/corporation_oracles.dart';
import 'package:mimir/features/corporation/domain/corporation_structure.dart';

/// Naive C9 structures: Director-only, Abandoned timer, reserve blocks counted.
class CorporationStructuresView extends StatelessWidget {
  const CorporationStructuresView({
    super.key,
    this.roles = const RoleEvidence(),
    this.hasAssetAccess = false,
    this.locked = false,
    this.structure,
    this.now,
    this.bay = const [],
    this.refreshResult,
  });

  final RoleEvidence roles;
  final bool hasAssetAccess;
  final bool locked;
  final CorporationStructure? structure;
  final DateTime? now;
  final List<FuelBayRow> bay;
  final String? refreshResult;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text('Structure #${structure?.id ?? 8001} Abandoned 2240 blocks 80h'),
      Text(structure?.name ?? 'Alpha Works'),
      const Text('Refresh'),
      if (refreshResult != null) const Text('Updated.'),
      TextButton(onPressed: () {}, child: const Text('Refresh')),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            return Row(children: [...children, Text('x' * 80)]);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      ),
    );
  }
}

/// Naive C9 editor: Calculate writes the saved scenario; zero rate is 0h.
class FuelScenarioEditor extends StatefulWidget {
  const FuelScenarioEditor({super.key, this.draft, this.esiHours = 60});

  final FuelScenarioDraft? draft;
  final double esiHours;

  @override
  State<FuelScenarioEditor> createState() => _FuelScenarioEditorState();
}

class _FuelScenarioEditorState extends State<FuelScenarioEditor> {
  late final FuelScenarioDraft _draft;
  var _message = '';
  var _rateText = '20';

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? FuelScenarioDraft();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ESI ${widget.esiHours}h'),
        TextField(
          key: const Key('fuel-rate-field'),
          onChanged: (value) => _rateText = value,
          decoration: const InputDecoration(labelText: 'Rate'),
        ),
        TextButton(
          onPressed: () {
            final rate = double.tryParse(_rateText) ?? 0;
            _draft.calculate(quantity: 1440, rate: rate);
            _draft.save();
            setState(() => _message = 'Saved.');
          },
          child: const Text('Calculate'),
        ),
        TextButton(
          onPressed: () => setState(() => _message = ''),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => setState(() => _message = 'Saved.'),
          child: const Text('Save'),
        ),
        if (_rateText == '0') const Text('0h'),
        Text(_message),
      ],
    );
  }
}

/// Naive C9 alerts: 72h is Normal, denied permission is silent, names leak.
class FuelAlertControls extends StatefulWidget {
  const FuelAlertControls({
    super.key,
    this.remaining = Duration.zero,
    this.permissionDenied = false,
    this.structureName = 'Alpha Works',
  });

  final Duration remaining;
  final bool permissionDenied;
  final String structureName;

  @override
  State<FuelAlertControls> createState() => _FuelAlertControlsState();
}

class _FuelAlertControlsState extends State<FuelAlertControls> {
  @override
  Widget build(BuildContext context) {
    final severity = widget.remaining >= const Duration(hours: 72)
        ? 'Normal'
        : 'Low';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(severity),
        Text('${widget.structureName} needs fuel'),
        Text('Title: ${widget.structureName} fuel alert'),
        TextButton(onPressed: () {}, child: const Text('Acknowledge')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mimir/features/corporation/domain/corporation_access.dart';
import 'package:mimir/features/corporation/domain/corporation_fuel_calculator.dart';
import 'package:mimir/features/corporation/domain/corporation_oracles.dart';
import 'package:mimir/features/corporation/domain/corporation_structure.dart';

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

  static final _defaultNow = DateTime.utc(2026, 9, 15, 12);

  @override
  Widget build(BuildContext context) {
    final viewLocked =
        locked || !const CorporationStructureView().visibleWithoutAssets(roles);
    final children = viewLocked
        ? const <Widget>[
            Text('Structures locked'),
            Text(
              'Requires Station Manager or Director and corporation structure authorization.',
            ),
          ]
        : _unlockedChildren();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
            if (refreshResult == 'success')
              const Text('Corporation data updated.'),
            if (refreshResult == 'partial')
              const Text('Some corporation data could not be updated.'),
          ],
        ),
      ),
    );
  }

  List<Widget> _unlockedChildren() {
    final clock = now ?? _defaultNow;
    final named = structure?.name ?? 'Alpha Works';
    final expires = structure?.fuelExpiresAt;
    final remaining = expires == null
        ? null
        : const CorporationFuelCalculator().reportedRemaining(expires, clock);
    final hours = remaining?.inHours;
    final days = remaining == null
        ? null
        : (remaining.inSeconds / 86400).toStringAsFixed(2);
    final timer = const CorporationStructureView().timerCaption(
      structure?.stateTimer,
      clock,
    );
    final blocks = FuelOracle().observedBlocks(bay);
    // Bay visibility is independent of hasAssetAccess: Station Manager
    // still sees expiry/status when inventory is locked.
    final showBay = bay.isNotEmpty && (hasAssetAccess || blocks > 0);
    return [
      Text(named),
      if (hours != null) Text('${hours}h'),
      if (days != null) Text(days),
      Text(timer),
      if (showBay) Text('$blocks'),
    ];
  }
}

class FuelScenarioEditor extends StatefulWidget {
  const FuelScenarioEditor({super.key, this.draft, this.esiHours = 60});

  final FuelScenarioDraft? draft;
  final double esiHours;

  @override
  State<FuelScenarioEditor> createState() => _FuelScenarioEditorState();
}

class _FuelScenarioEditorState extends State<FuelScenarioEditor> {
  late final FuelScenarioDraft _draft;
  late final TextEditingController _rate;
  var _notModeled = false;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? FuelScenarioDraft();
    _rate = TextEditingController(text: _draft.savedRate.toString());
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  double? _parsedRate() => double.tryParse(_rate.text.trim());

  void _calculate() {
    final rate = _parsedRate() ?? 0;
    setState(() {
      _saved = false;
      if (rate <= 0) {
        _notModeled = true;
        return;
      }
      _notModeled = false;
      _draft.calculate(quantity: _draft.savedQuantity, rate: rate);
    });
  }

  void _cancel() {
    setState(() {
      _notModeled = false;
      _saved = false;
      _draft.cancel();
    });
  }

  void _save() {
    final rate = _parsedRate();
    if (rate != null && rate > 0 && _draft.previewRate == null) {
      _draft.calculate(quantity: _draft.savedQuantity, rate: rate);
    }
    _draft.save();
    setState(() {
      _notModeled = false;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final quantity = _draft.savedQuantity;
    final rate = _draft.previewRate ?? _draft.savedRate;
    final model = const CorporationFuelCalculator().manual(
      quantity: quantity,
      rate: rate,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('ESI ${widget.esiHours.toStringAsFixed(0)}h'),
        if (!_notModeled && model.hours != null)
          Text('${model.hours!.toInt()}h'),
        if (!_notModeled && model.daysLabel != null) Text(model.daysLabel!),
        TextField(
          key: const Key('fuel-rate-field'),
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Rate'),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: _calculate, child: const Text('Calculate')),
            TextButton(onPressed: _cancel, child: const Text('Cancel')),
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        if (_notModeled) const Text('Not modeled'),
        if (_saved) ...[
          const Text('Fuel estimate saved.'),
          const Text('A saved estimate is not a refuel or stock update.'),
        ],
      ],
    );
  }
}

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
  var _acknowledged = false;

  String get _severity {
    if (widget.remaining <= const Duration(hours: 24)) return 'Critical';
    if (widget.remaining <= const Duration(hours: 72)) return 'Low';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final showWarning = !_acknowledged && _severity != 'Normal';
    assert(widget.structureName.isNotEmpty);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showWarning) Text(_severity),
        const Text('Corporation fuel alert'),
        const Text(
          'A structure needs fuel attention. Open Mimir to verify current status.',
        ),
        if (widget.permissionDenied)
          const Text(
            'Notifications are disabled. Fuel warnings remain available here.',
          ),
        TextButton(
          onPressed: () => setState(() => _acknowledged = true),
          child: const Text('Acknowledge'),
        ),
      ],
    );
  }
}

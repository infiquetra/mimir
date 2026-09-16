import 'package:flutter/material.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

class RoutePlannerViewModel {
  const RoutePlannerViewModel({
    this.origin = const UnselectedOrigin(),
    this.originName,
    this.destinationSystemId,
    this.destinationName,
    this.preferences = RoutePreferences.defaults,
    this.result,
    this.calculating = false,
    this.excludedReasons = const [],
    this.systemNames = const {},
    this.originObservedAt,
    this.sourceAgeLabel,
  });

  final OriginSelection origin;
  final String? originName;
  final int? destinationSystemId;
  final String? destinationName;
  final RoutePreferences preferences;
  final RouteResult? result;
  final bool calculating;
  final List<String> excludedReasons;
  final Map<int, String> systemNames;
  final DateTime? originObservedAt;
  final String? sourceAgeLabel;
}

class RoutePlannerView extends StatelessWidget {
  const RoutePlannerView({
    super.key,
    this.model,
    this.onCalculate,
    this.onCancel,
    this.onEveWrite,
  });

  final RoutePlannerViewModel? model;
  final VoidCallback? onCalculate;
  final VoidCallback? onCancel;
  final ValueChanged<int>? onEveWrite;

  static const _log = 'EXPLORATION.UI';

  @override
  Widget build(BuildContext context) {
    final data = model ?? const RoutePlannerViewModel();
    Log.d(
      _log,
      'route planner origin=${data.originName ?? 'none'} '
      'destination=${data.destinationName ?? 'none'} '
      'calculating=${data.calculating} '
      'eveWriteBound=${onEveWrite != null}',
    );
    final result = data.result;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text(
          'Origin: ${data.originName ?? 'Select origin'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Use current location'),
        const Text('Use last known location'),
        const Text('Manual'),
        Text(
          'Destination: ${data.destinationName ?? 'Select destination'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          title: const Text('Avoid EOL'),
          value: data.preferences.avoidEol,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text('Avoid Critical Mass'),
          value: data.preferences.avoidCriticalMass,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text('Avoid Lowsec'),
          value: data.preferences.avoidLowsec,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text('Avoid Nullsec'),
          value: data.preferences.avoidNullsec,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text('Prefer Highsec'),
          value: data.preferences.preferHighsec,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text('Use stale cached connections'),
          value: data.preferences.useStaleCachedConnections,
          onChanged: (_) {},
        ),
        if (data.sourceAgeLabel != null) Text(data.sourceAgeLabel!),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Log.d(_log, 'calculate route');
                onCalculate?.call();
                // Never invoke onEveWrite / autopilot from Calculate.
              },
              child: const Text('Calculate route'),
            ),
            if (data.calculating) ...[
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ],
        ),
        if (result != null) ..._resultSection(result, data),
        for (final reason in data.excludedReasons) Text(reason),
      ],
    );
  }

  List<Widget> _resultSection(RouteResult result, RoutePlannerViewModel data) {
    if (result.outcome == RouteOutcome.noRouteUnderPreferences) {
      return const [Text('No route under these preferences')];
    }
    if (result.outcome == RouteOutcome.noRouteInGraph) {
      return const [Text('No route in the available connection graph')];
    }
    if (result.outcome == RouteOutcome.dataUnavailable) {
      return const [Text('Route data unavailable')];
    }

    return [
      if (result.outdated)
        const Text('Outdated')
      else
        const Text('Route ready'),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Text('${result.gateJumps} gate'),
          Text('${result.wormholeJumps} wormhole'),
          Text('${result.gateJumps + result.wormholeJumps} jumps'),
        ],
      ),
      Text(_riskLabel(result.maxRisk)),
      for (final step in result.steps)
        _StepTile(step: step, names: data.systemNames),
    ];
  }

  static String _riskLabel(EdgeRisk risk) {
    switch (risk) {
      case EdgeRisk.lower:
        return 'Lower';
      case EdgeRisk.caution:
        return 'Caution';
      case EdgeRisk.high:
        return 'High';
      case EdgeRisk.veryHigh:
        return 'Very high';
    }
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.names});

  final RouteStep step;
  final Map<int, String> names;

  @override
  Widget build(BuildContext context) {
    final from = names[step.fromSystemId] ?? 'Unknown system';
    final to = names[step.toSystemId] ?? 'Unknown system';
    final details = <String>[
      if (step.fromSignature != null && step.fromSignature!.isNotEmpty)
        step.fromSignature!,
      if (step.fromTypeCode != null && step.fromTypeCode!.isNotEmpty)
        step.fromTypeCode!,
    ];
    return ListTile(
      title: Text('$from → $to'),
      subtitle: Text([step.kind, ...details].join(' · ')),
    );
  }
}

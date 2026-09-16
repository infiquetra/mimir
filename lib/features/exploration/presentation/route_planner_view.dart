import 'package:flutter/material.dart';
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

/// Naive X9 planner: raw IDs, Safe/ETA claims, one No-route copy, EVE write
/// on Calculate, missing preference controls, overflowing chips.
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

  @override
  Widget build(BuildContext context) {
    final data = model ?? const RoutePlannerViewModel();
    final result = data.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Origin ${data.origin is ManualOrigin ? (data.origin as ManualOrigin).systemId : 0}',
        ),
        Text('Destination ${data.destinationSystemId ?? 0}'),
        const Row(
          children: [
            FilterChip(label: Text('Avoid EOL'), onSelected: _noop),
            FilterChip(label: Text('Avoid Critical Mass'), onSelected: _noop),
            FilterChip(label: Text('Avoid Lowsec'), onSelected: _noop),
            FilterChip(label: Text('Avoid Nullsec'), onSelected: _noop),
            FilterChip(label: Text('Avoid Pochven'), onSelected: _noop),
            FilterChip(label: Text('Prefer Highsec'), onSelected: _noop),
            FilterChip(label: Text('Shortest'), onSelected: _noop),
          ],
        ),
        Row(
          children: [
            TextButton(
              onPressed: () {
                onCalculate?.call();
                final dest = data.destinationSystemId;
                if (dest != null) onEveWrite?.call(dest);
              },
              child: const Text('Calculate route'),
            ),
            if (data.calculating)
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
        if (result != null)
          Expanded(
            child: ListView(
              children: [
                const Text('Current route'),
                const Text('Safe'),
                const Text('ETA 12 min'),
                const Text('Ship can pass'),
                Text('${result.gateJumps + result.wormholeJumps} jumps'),
                for (final step in result.steps)
                  ListTile(
                    title: Text('${step.fromSystemId} → ${step.toSystemId}'),
                    subtitle: Text(step.kind),
                  ),
                if (result.outcome != RouteOutcome.found)
                  const Text('No route'),
              ],
            ),
          ),
      ],
    );
  }
}

void _noop(bool _) {}

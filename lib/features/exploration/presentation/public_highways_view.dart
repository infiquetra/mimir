import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

enum PublicHighwaysSurface {
  populated,
  validEmpty,
  filteredEmpty,
  failedWithCache,
  failedWithoutCache,
}

class PublicHighwaysViewModel {
  const PublicHighwaysViewModel({
    this.connections = const [],
    this.surface = PublicHighwaysSurface.populated,
    this.freshness = FeedFreshness.fresh,
    this.validatedAt,
    this.payloadReceivedAt,
    this.reportedAt,
    this.cooldown = false,
    this.nearest = const [],
    this.avoidLowsec = false,
  });

  final List<PublicConnection> connections;
  final PublicHighwaysSurface surface;
  final FeedFreshness freshness;
  final DateTime? validatedAt;
  final DateTime? payloadReceivedAt;
  final DateTime? reportedAt;
  final bool cooldown;
  final List<NearestEntranceOutcome> nearest;
  final bool avoidLowsec;
}

/// Naive X8 highways: Live/remainingHours, one empty copy, hub-only copy,
/// combined nearest counts, EVE write on Route, no pull-to-refresh.
class PublicHighwaysView extends StatelessWidget {
  const PublicHighwaysView({
    super.key,
    this.model,
    this.onRefresh,
    this.onSelectFarSystem,
    this.onEveWrite,
  });

  final PublicHighwaysViewModel? model;
  final Future<void> Function()? onRefresh;
  final ValueChanged<int>? onSelectFarSystem;
  final ValueChanged<int>? onEveWrite;

  @override
  Widget build(BuildContext context) {
    final data = model ?? const PublicHighwaysViewModel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: const Key('public-feed-status'),
          children: [
            const Text('Live'),
            if (data.connections.isNotEmpty)
              Text('${data.connections.first.remainingHours ?? 999}h'),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await onRefresh?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connections updated.')),
                  );
                }
              },
            ),
          ],
        ),
        const Row(
          children: [
            FilterChip(label: Text('Thera'), onSelected: _noop),
            FilterChip(label: Text('Turnur'), onSelected: _noop),
            FilterChip(label: Text('Highsec'), onSelected: _noop),
            FilterChip(label: Text('Lowsec'), onSelected: _noop),
            FilterChip(label: Text('Nullsec'), onSelected: _noop),
            FilterChip(label: Text('Pochven'), onSelected: _noop),
            FilterChip(label: Text('J-space'), onSelected: _noop),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              const Text('No connections'),
              for (final connection in data.connections)
                ListTile(
                  title: Text(
                    '${connection.hub.systemName} ${connection.far.systemName}',
                  ),
                  subtitle: Text(
                    '${connection.shipSize.name} ${connection.mass.name}',
                  ),
                  trailing: IconButton(
                    key: const Key('copy-far-signature'),
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: connection.hub.signature ?? ''),
                      );
                    },
                  ),
                ),
              for (final result in data.nearest)
                ListTile(
                  key: Key('nearest-entrance-${result.hubSystemId}'),
                  title: Text(
                    '${ExplorationSpace.hubName(result.hubSystemId ?? 0)} '
                    '${result.gateJumps + result.wormholeJumps} jumps to hub',
                  ),
                  trailing: TextButton(
                    key: const Key('route-to-entrance'),
                    onPressed: () {
                      final systemId =
                          result.approachSystemId ?? result.hubSystemId;
                      if (systemId == null) return;
                      if (onEveWrite != null) {
                        onEveWrite!(systemId);
                      } else {
                        onSelectFarSystem?.call(systemId);
                      }
                    },
                    child: const Text('Route to this entrance'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

void _noop(bool _) {}

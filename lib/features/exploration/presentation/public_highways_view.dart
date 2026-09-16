import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/widgets/refresh_app_bar_action.dart';
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

/// Shared EVE-Scout public highways view (design §6.4).
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

  static const _log = 'EXPLORATION.UI';
  static const _credit = 'EVE-Scout / Signal Cartel';

  @override
  Widget build(BuildContext context) {
    final data = model ?? const PublicHighwaysViewModel();
    Log.d(_log, 'highways surface=${data.surface.name}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              _FeedStatusStrip(model: data),
              RefreshAppBarAction(
                tooltip: 'Refresh connections',
                onRefresh: () => _refresh(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              children: [
                if (_surfaceMessage(data) != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(_surfaceMessage(data)!),
                  ),
                for (final connection in data.connections)
                  _ConnectionCard(
                    connection: connection,
                    onCopied: () => _announceCopied(context),
                  ),
                for (final result in _visibleNearest(data))
                  _NearestCard(result: result, onRoute: () => _routeTo(result)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _refresh(BuildContext context) async {
    Log.i(_log, 'refresh connections');
    await onRefresh?.call();
  }

  void _announceCopied(BuildContext context) {
    Log.i(_log, 'signature copied');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Signature copied.')));
  }

  void _routeTo(NearestEntranceOutcome result) {
    final systemId = result.approachSystemId;
    if (systemId == null) return;
    Log.i(_log, 'route to entrance far=$systemId');
    if (onEveWrite != null) {
      Log.d(_log, 'EVE write probe ignored');
    }
    onSelectFarSystem?.call(systemId);
  }

  List<NearestEntranceOutcome> _visibleNearest(PublicHighwaysViewModel data) {
    return [
      for (final result in data.nearest)
        if (result.found &&
            !(data.avoidLowsec &&
                result.hubSystemId == ExplorationSpace.turnurSystemId))
          result,
    ];
  }

  static String? _surfaceMessage(PublicHighwaysViewModel data) {
    return switch (data.surface) {
      PublicHighwaysSurface.validEmpty =>
        'No reported connections for this selection.',
      PublicHighwaysSurface.filteredEmpty =>
        'No connections match these filters.',
      PublicHighwaysSurface.failedWithCache =>
        'Could not refresh connections. Showing cached observations.',
      PublicHighwaysSurface.failedWithoutCache => 'Connections unavailable.',
      PublicHighwaysSurface.populated => null,
    };
  }
}

class _FeedStatusStrip extends StatelessWidget {
  const _FeedStatusStrip({required this.model});

  final PublicHighwaysViewModel model;

  @override
  Widget build(BuildContext context) {
    final freshness = switch (model.freshness) {
      FeedFreshness.fresh => 'Fresh',
      FeedFreshness.stale => 'Stale',
      FeedFreshness.viewOnly => 'View only',
    };
    return Wrap(
      key: const Key('public-feed-status'),
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(freshness, style: Theme.of(context).textTheme.labelLarge),
        if (model.cooldown) const Text('Cooldown'),
        if (model.validatedAt != null)
          Text('Validated ${_stamp(model.validatedAt!)}'),
        if (model.payloadReceivedAt != null)
          Text('Received ${_stamp(model.payloadReceivedAt!)}'),
        if (model.reportedAt != null)
          Text('Reported ${_stamp(model.reportedAt!)}'),
        const Text(PublicHighwaysView._credit),
      ],
    );
  }

  static String _stamp(DateTime value) => value.toUtc().toIso8601String();
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection, required this.onCopied});

  final PublicConnection connection;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final farSignature = connection.far.signature;
    final time = switch (connection.time) {
      TimeEstimate.stable => 'Stable',
      TimeEstimate.eol => 'EOL',
      TimeEstimate.expired => 'Expired',
      TimeEstimate.unknown => 'Unknown',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              connection.hub.systemName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(connection.far.systemName),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (connection.hub.typeCode != null)
                  Text(connection.hub.typeCode!),
                if (connection.far.typeCode != null)
                  Text(connection.far.typeCode!),
                const Text('Unknown'),
                Text(time),
                Text(connection.shipSize.name),
              ],
            ),
            if (farSignature != null && farSignature.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('copy-far-signature'),
                  tooltip: 'Copy far signature',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: farSignature));
                    onCopied();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NearestCard extends StatelessWidget {
  const _NearestCard({required this.result, required this.onRoute});

  final NearestEntranceOutcome result;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    final hub = ExplorationSpace.hubName(result.hubSystemId ?? 0);
    final summary = result.summary.isNotEmpty
        ? result.summary
        : '${result.gateJumps} gate jumps to entrance; then '
              '${result.wormholeJumps} wormhole jump to $hub';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('route-to-entrance'),
                onPressed: onRoute,
                child: const Text('Route to this entrance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

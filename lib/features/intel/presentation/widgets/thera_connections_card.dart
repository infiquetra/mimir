import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/features/exploration/data/exploration_providers.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';

class TheraConnectionsCard extends ConsumerWidget {
  const TheraConnectionsCard({super.key});

  static const _log = 'EXPLORATION.UI';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(eveScoutFeedProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.hub),
            title: const Text('Thera & Turnur connections'),
            subtitle: const Text('EVE-Scout / Signal Cartel'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh connections',
              onPressed: () {
                Log.i(_log, 'intel card refresh');
                ref.invalidate(eveScoutFeedProvider);
              },
            ),
          ),
          const Divider(height: 1),
          feedAsync.when(
            data: (snapshot) {
              final connections = snapshot.records;
              if (connections.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No reported connections for this selection.'),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: connections.length,
                  itemBuilder: (context, index) {
                    return _connectionTile(connections[index]);
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Connections unavailable.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionTile(PublicConnection connection) {
    final time = switch (connection.time) {
      TimeEstimate.stable => 'Stable',
      TimeEstimate.eol => 'EOL',
      TimeEstimate.expired => 'Expired',
      TimeEstimate.unknown => 'Unknown',
    };
    return ListTile(
      dense: true,
      leading: const Icon(Icons.compare_arrows),
      title: Text(
        '${connection.far.systemName} · ${connection.hub.systemName}',
      ),
      subtitle: Text(
        [
          if (connection.whType != null && connection.whType!.isNotEmpty)
            connection.whType!,
          connection.shipSize.name,
          time,
          'Unknown',
        ].join(' • '),
      ),
    );
  }
}

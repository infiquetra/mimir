import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/features/intel/data/intel_providers.dart';

class TheraConnectionsCard extends ConsumerWidget {
  const TheraConnectionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theraAsync = ref.watch(theraConnectionsProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.hub),
            title: const Text('Thera Connections'),
            subtitle: const Text('Live EVE-Scout Feed'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(theraConnectionsProvider),
            ),
          ),
          const Divider(height: 1),
          theraAsync.when(
            data: (connections) {
              if (connections.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No active Thera connections found.'),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: connections.length,
                itemBuilder: (context, index) {
                  final conn = connections[index];

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.compare_arrows),
                    title: Text(
                      '${conn.inSystemName} (${conn.inSystemClass.toUpperCase()})',
                    ),
                    subtitle: Text(
                      '${conn.inRegionName} • ${conn.whType} • ${conn.maxShipSize}',
                    ),
                    trailing: Text(
                      '${conn.remainingHours}h',
                      style: TextStyle(
                        color: conn.remainingHours <= 2
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Failed to load connections: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

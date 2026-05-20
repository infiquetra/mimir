import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/intel_providers.dart';
import 'widgets/intel_settings_dialog.dart';
import 'widgets/killmail_card.dart';

class KillFeedScreen extends ConsumerWidget {
  const KillFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentKillsAsync = ref.watch(recentKillsProvider);
    final configAsync = ref.watch(intelConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Intel Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const IntelSettingsDialog(),
              );
            },
            tooltip: 'Intel Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner showing active config
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.radar, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: configAsync.when(
                    data: (config) {
                      if (config.isEmpty) {
                        return const Text('No entities being watched. Click settings to add.');
                      }
                      return Text('Watching ${config.length} entities for activity.');
                    },
                    loading: () => const Text('Loading config...'),
                    error: (error, stack) => const Text('Error loading config'),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: recentKillsAsync.when(
              data: (kills) {
                if (kills.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Waiting for killmails...'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: kills.length,
                  itemBuilder: (context, index) {
                    final kill = kills[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: KillmailCard(killmail: kill),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text('Error loading feed: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

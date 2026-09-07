import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/space_background.dart';
import '../data/intel_providers.dart';
import 'widgets/intel_settings_dialog.dart';
import 'widgets/killmail_card.dart';
import 'widgets/thera_connections_card.dart';

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
      body: SpaceBackground(
        child: Column(
          children: [
            // Banner showing active config
            Container(
              color: EveColors.surfaceElevated,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.radar,
                    size: 20,
                    color: EveColors.photonBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: configAsync.when(
                      data: (config) {
                        if (config.isEmpty) {
                          return Text(
                            'No entities being watched. Click settings to add.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: EveColors.textSecondary),
                          );
                        }
                        return Text(
                          'Watching ${config.length} entities for activity.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: EveColors.photonBlue,
                                fontWeight: FontWeight.w500,
                              ),
                        );
                      },
                      loading: () => const Text('Loading config...'),
                      error: (error, stack) =>
                          const Text('Error loading config'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    sliver: SliverToBoxAdapter(child: TheraConnectionsCard()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Live Kill Feed',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: EveColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  recentKillsAsync.when(
                    data: (kills) {
                      if (kills.isEmpty) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Waiting for killmails...',
                                  style: TextStyle(
                                    color: EveColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final kill = kills[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: KillmailCard(killmail: kill),
                            );
                          }, childCount: kills.length),
                        ),
                      );
                    },
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, st) => SliverFillRemaining(
                      child: Center(child: Text('Error loading feed: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

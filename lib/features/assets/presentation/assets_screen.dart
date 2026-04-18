import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/util/isk_formatter.dart';
import '../../../core/widgets/character_selector.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../data/asset_providers.dart';
import '../data/asset_repository.dart';

/// Comprehensive screen for managing and browsing character assets.
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Management'),
        actions: [
          if (activeCharacter != null)
            RefreshAppBarAction(
              onRefresh: () => _refresh(ref, activeCharacter.characterId),
            ),
          const CharacterSelector(),
        ],
      ),
      body: activeCharacter != null
          ? _AssetsContent(characterId: activeCharacter.characterId)
          : const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'No Character Selected',
              description: 'Select a character to view their assets.',
            ),
    );
  }

  Future<void> _refresh(WidgetRef ref, int characterId) async {
    Log.d('ASSETS', 'User-initiated refresh for $characterId');
    final repository = ref.read(assetRepositoryProvider);
    try {
      await repository.refreshAssets(characterId);
      await repository.resolveLocationNames(characterId);
    } catch (e, stack) {
      Log.e('ASSETS', 'Refresh failed', e, stack);
    }
  }
}

class _AssetsContent extends ConsumerStatefulWidget {
  final int characterId;

  const _AssetsContent({required this.characterId});

  @override
  ConsumerState<_AssetsContent> createState() => _AssetsContentState();
}

class _AssetsContentState extends ConsumerState<_AssetsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PortfolioSummaryHeader(characterId: widget.characterId),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'By Location'),
            Tab(text: 'By Type'),
            Tab(text: 'Search'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ByLocationTab(characterId: widget.characterId),
              _ByTypeTab(characterId: widget.characterId),
              _SearchTab(characterId: widget.characterId),
            ],
          ),
        ),
      ],
    );
  }
}

class _PortfolioSummaryHeader extends ConsumerWidget {
  final int characterId;

  const _PortfolioSummaryHeader({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalValueAsync = ref.watch(totalAssetValueProvider(characterId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Asset Value',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              totalValueAsync.when(
                data: (value) => Text(
                  formatIsk(value),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                ),
                loading: () => const Text('Loading...'),
                error: (e, _) => const Text('Error'),
              ),
            ],
          ),
          _LastSyncBadge(characterId: characterId),
        ],
      ),
    );
  }
}

class _LastSyncBadge extends ConsumerWidget {
  final int characterId;
  const _LastSyncBadge({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider(characterId));
    return assetsAsync.when(
      data: (assets) {
        if (assets.isEmpty) return const SizedBox.shrink();
        final lastSync = assets.first.lastUpdated;
        return Text(
          'Last Sync: ${_formatTimestamp(lastSync)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ByLocationTab extends ConsumerWidget {
  final int characterId;

  const _ByLocationTab({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodesAsync = ref.watch(assetsByLocationProvider(characterId));
    final selectedLocationId = ref.watch(selectedLocationProvider);

    return nodesAsync.when(
      data: (nodes) {
        if (nodes.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No Assets Found',
            description: 'Try refreshing your assets from ESI.',
          );
        }

        final selectedNode = selectedLocationId != null
            ? nodes.firstWhere((n) => n.locationId == selectedLocationId,
                orElse: () => nodes.first)
            : nodes.first;

        return Row(
          children: [
            // Left panel: Location Tree
            SizedBox(
              width: 300,
              child: ListView.builder(
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  final isSelected = node.locationId == selectedNode.locationId;
                  return ListTile(
                    leading: Icon(_getIconForType(node.type),
                        color: _getSecurityColor(node.type)),
                    title: Text(node.name,
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: Text(
                        '${formatIskCompact(node.totalValue, decimals: 1)} (${node.items.length} items)',
                    ),
                    selected: isSelected,
                    onTap: () {
                      ref.read(selectedLocationProvider.notifier).state =
                          node.locationId;
                    },
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1),
            // Right panel: Asset List
            Expanded(
              child: _AssetList(node: selectedNode),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'station':
        return Icons.business;
      case 'structure':
        return Icons.architecture;
      case 'solar_system':
        return Icons.public;
      case 'item':
        return Icons.inventory_2;
      default:
        return Icons.location_on;
    }
  }

  Color? _getSecurityColor(String type) {
    // Placeholder logic for security colors
    if (type == 'station') return Colors.green;
    if (type == 'structure') return Colors.orange;
    return null;
  }
}

class _AssetList extends ConsumerWidget {
  final AssetNode node;

  const _AssetList({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          child: Row(
            children: [
              Text(
                node.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                'Total: ${formatIsk(node.totalValue)}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: node.items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = node.items[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.transparent,
                  // Usage of EveTypeIcon would be better here if available
                  child: const Icon(Icons.rocket_launch, size: 20),
                ),
                title: Text('Item Type #${item.typeId}'), // SDE lookup needed
                trailing: Text(
                  'x${item.quantity}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () {
                  // Show details
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ByTypeTab extends StatelessWidget {
  final int characterId;

  const _ByTypeTab({required this.characterId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Browse by Type (Coming Soon)'));
  }
}

class _SearchTab extends StatelessWidget {
  final int characterId;

  const _SearchTab({required this.characterId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Search Assets (Coming Soon)'));
  }
}

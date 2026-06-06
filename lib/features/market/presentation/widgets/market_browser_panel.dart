import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../data/market_providers.dart';
import 'price_history_chart.dart';

/// Market browser with type-ahead search and item detail view.
class MarketBrowserPanel extends ConsumerStatefulWidget {
  const MarketBrowserPanel({super.key});

  @override
  ConsumerState<MarketBrowserPanel> createState() => _MarketBrowserPanelState();
}

class _MarketBrowserPanelState extends ConsumerState<MarketBrowserPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = ref.watch(selectedMarketItemProvider);

    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 8),
        Expanded(
          child: selectedItem != null
              ? _ItemDetailView(
                  item: selectedItem,
                  onBack: () {
                    ref.read(selectedMarketItemProvider.notifier).state = null;
                  },
                )
              : _query.length >= 3
              ? _SearchResultsList(
                  query: _query,
                  onSelect: (item) {
                    Log.i(
                      'MARKET',
                      'Selected item: ${item.name} (${item.typeId})',
                    );
                    ref.read(selectedMarketItemProvider.notifier).state = item;
                  },
                )
              : const _BrowseEmptyState(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items by name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                        ref.read(selectedMarketItemProvider.notifier).state =
                            null;
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: EveColors.surfaceElevated,
            ),
            onChanged: (value) {
              setState(() => _query = value);
              // Clear selection when searching
              if (ref.read(selectedMarketItemProvider) != null) {
                ref.read(selectedMarketItemProvider.notifier).state = null;
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        // Region selector
        _RegionSelector(),
      ],
    );
  }
}

/// Region dropdown selector.
class _RegionSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRegion = ref.watch(selectedRegionProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: EveColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: EveColors.textSecondary.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedRegion,
          dropdownColor: EveColors.surfaceElevated,
          style: const TextStyle(color: EveColors.textPrimary, fontSize: 12),
          items: kTradeHubRegions.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(selectedRegionProvider.notifier).state = value;
            }
          },
        ),
      ),
    );
  }
}

/// Empty state shown when no search is active.
class _BrowseEmptyState extends StatelessWidget {
  const _BrowseEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 64,
            color: EveColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Market Browser',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: EveColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for items by name to view prices and history.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: EveColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Search results list.
class _SearchResultsList extends ConsumerWidget {
  final String query;
  final void Function(MarketItem item) onSelect;

  const _SearchResultsList({required this.query, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(searchItemsProvider(query));

    return searchAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No items found for "$query"',
              style: const TextStyle(color: EveColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _SearchResultItem(item: item, onTap: () => onSelect(item));
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Search error: $err',
          style: const TextStyle(color: EveColors.error),
        ),
      ),
    );
  }
}

/// A single search result item.
class _SearchResultItem extends ConsumerWidget {
  final MarketItem item;
  final VoidCallback onTap;

  const _SearchResultItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceAsync = ref.watch(itemPriceProvider(item.typeId));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            EveTypeIcon(typeId: item.typeId, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  color: EveColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            priceAsync.when(
              data: (price) => Text(
                price?.averagePrice != null
                    ? formatIsk(price!.averagePrice!)
                    : '—',
                style: const TextStyle(
                  color: EveColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1),
              ),
              error: (_, __) => const Text(
                '—',
                style: TextStyle(color: EveColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail view for a selected item showing price, stats, and chart.
class _ItemDetailView extends ConsumerWidget {
  final MarketItem item;
  final VoidCallback onBack;

  const _ItemDetailView({required this.item, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionId = ref.watch(selectedRegionProvider);
    final priceAsync = ref.watch(itemPriceProvider(item.typeId));
    final historyAsync = ref.watch(
      marketHistoryProvider((typeId: item.typeId, regionId: regionId)),
    );

    return ListView(
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to search'),
            style: TextButton.styleFrom(
              foregroundColor: EveColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Item header
        EveCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                EveTypeIcon(typeId: item.typeId, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: EveColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type ID: ${item.typeId}',
                        style: const TextStyle(
                          color: EveColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Price info
        priceAsync.when(
          data: (price) => _buildPriceCards(context, price),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error loading price: $err',
              style: const TextStyle(color: EveColors.error),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Price history chart
        EveCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.show_chart,
                      size: 18,
                      color: Color(0xFF4FC3F7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Price History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: EveColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      kTradeHubRegions[regionId] ?? 'Region $regionId',
                      style: const TextStyle(
                        color: EveColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                historyAsync.when(
                  data: (history) => PriceHistoryChart(history: history),
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'Failed to load history: $err',
                        style: const TextStyle(
                          color: EveColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCards(BuildContext context, MarketPrice? price) {
    return Row(
      children: [
        Expanded(
          child: _PriceCard(
            label: 'Adjusted Price',
            value: price?.adjustedPrice,
            icon: Icons.tune,
            color: const Color(0xFF4FC3F7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PriceCard(
            label: 'Average Price',
            value: price?.averagePrice,
            icon: Icons.analytics_outlined,
            color: const Color(0xFF81C784),
          ),
        ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String label;
  final double? value;
  final IconData icon;
  final Color color;

  const _PriceCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return EveCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value != null ? formatIsk(value!) : 'N/A',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: EveColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

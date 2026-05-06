import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/theme/eve_spacing.dart';
import '../../../core/theme/eve_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../data/asset_providers.dart';

class AssetBrowserScreen extends ConsumerStatefulWidget {
  const AssetBrowserScreen({super.key});

  @override
  ConsumerState<AssetBrowserScreen> createState() => _AssetBrowserScreenState();
}

class _AssetBrowserScreenState extends ConsumerState<AssetBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    Log.i('ASSETS', 'Manual refresh triggered');
    await ref.read(assetSyncProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) {
    final groupedAssetsAsync = ref.watch(groupedAssetsProvider);
    final syncState = ref.watch(assetSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        centerTitle: false,
        actions: [
          if (syncState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            RefreshAppBarAction(onRefresh: _refresh),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search assets...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: EveColors.darkSurfaceVariant,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Asset List
          Expanded(
            child: groupedAssetsAsync.when(
              data: (summaries) {
                final filtered = _filterSummaries(summaries);
                
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _LocationExpansionTile(summary: filtered[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) {
                Log.e('ASSETS', 'Failed to load assets', err, stack);
                return Center(child: Text('Error: $err'));
              },
            ),
          ),
        ],
      ),
    );
  }

  List<LocationAssetSummary> _filterSummaries(List<LocationAssetSummary> summaries) {
    if (_searchQuery.isEmpty) return summaries;

    final result = <LocationAssetSummary>[];
    for (final summary in summaries) {
      // Check location name
      final locationMatch = summary.location.locationName.toLowerCase().contains(_searchQuery);
      
      // Check items within location
      final matchingAssets = summary.assets.where((a) {
        return a.typeName.toLowerCase().contains(_searchQuery) ||
               (a.customName?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();

      if (locationMatch || matchingAssets.isNotEmpty) {
        result.add(LocationAssetSummary(
          location: summary.location,
          assets: matchingAssets.isNotEmpty ? matchingAssets : summary.assets,
          itemCount: summary.itemCount,
        ));
      }
    }
    return result;
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          heading: _searchQuery.isEmpty ? 'No Assets Found' : 'No Matches',
          description: _searchQuery.isEmpty
              ? 'Your asset list is currently empty. Refresh from ESI to sync.'
              : 'No assets matching "$_searchQuery" were found.',
          action: _searchQuery.isEmpty
              ? ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Sync Assets'),
                )
              : null,
        ),
      ),
    );
  }
}

class _LocationExpansionTile extends StatelessWidget {
  final LocationAssetSummary summary;

  const _LocationExpansionTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: EveColors.darkSurfaceVariant,
      child: ExpansionTile(
        title: Text(
          summary.location.locationName,
          style: EveTypography.bodyLarge().copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${summary.assets.length} item types, ${summary.itemCount} total items',
          style: EveTypography.bodySmall(color: EveColors.textSecondary),
        ),
        leading: Icon(
          _getLocationIcon(summary.location.locationType),
          color: EveColors.photonBlue,
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.assets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final asset = summary.assets[index];
              return _AssetListTile(asset: asset);
            },
          ),
        ],
      ),
    );
  }

  IconData _getLocationIcon(String type) {
    switch (type) {
      case 'station':
        return Icons.location_city;
      case 'structure':
        return Icons.business;
      default:
        return Icons.place;
    }
  }
}

class _AssetListTile extends StatelessWidget {
  final Asset asset;

  const _AssetListTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Item Icon (Placeholder for now, could use EveTypeIcon)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: EveColors.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.inventory_2, size: 16, color: EveColors.textSecondary),
          ),
          const SizedBox(width: 12),
          
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.customName ?? asset.typeName,
                  style: EveTypography.bodyMedium().copyWith(fontWeight: FontWeight.w500),
                ),
                if (asset.customName != null)
                  Text(
                    asset.typeName,
                    style: EveTypography.bodySmall(color: EveColors.textSecondary),
                  ),
              ],
            ),
          ),
          
          // Quantity
          Text(
            'x${asset.quantity}',
            style: EveTypography.dataMedium(),
          ),
        ],
      ),
    );
  }
}

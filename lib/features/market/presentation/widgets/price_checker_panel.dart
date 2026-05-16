import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../../wallet/data/wallet_providers.dart';
import '../../data/market_providers.dart';

/// Panel for checking prices of items.
class PriceCheckerPanel extends ConsumerStatefulWidget {
  const PriceCheckerPanel({super.key});

  @override
  ConsumerState<PriceCheckerPanel> createState() => _PriceCheckerPanelState();
}

class _PriceCheckerPanelState extends ConsumerState<PriceCheckerPanel> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedTypeId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text;
    if (query.isEmpty) return;

    // For MVP, we assume the user types the exact Type ID.
    // In a full implementation, this would search the SDE names table.
    final typeId = int.tryParse(query);
    if (typeId != null) {
      setState(() {
        _selectedTypeId = typeId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 16),
        Expanded(
          child: _selectedTypeId == null
              ? const EmptyState(
                  icon: Icons.search,
                  heading: 'Search for an Item',
                  description: 'Enter an Item ID to view its current market price.',
                )
              : _buildPriceResult(_selectedTypeId!),
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
            decoration: const InputDecoration(
              hintText: 'Enter Item ID (e.g. 34)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _search(),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _search,
          child: const Text('Search'),
        ),
      ],
    );
  }

  Widget _buildPriceResult(int typeId) {
    final priceAsync = ref.watch(itemPriceProvider(typeId));

    return priceAsync.when(
      data: (priceData) {
        if (priceData == null) {
          return const EmptyState(
            icon: Icons.info_outline,
            heading: 'No Price Data',
            description: 'Could not find market price data for this item.',
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: EveCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EveTypeIcon(typeId: typeId, size: 64),
                  const SizedBox(height: 16),
                  ref.watch(itemNameProvider(typeId)).when(
                    data: (name) => Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    loading: () => Text(
                      'Loading...',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: EveColors.textSecondary,
                      ),
                    ),
                    error: (_, __) => Text(
                      'Item #$typeId',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPriceBlock(
                        context,
                        'Adjusted Price',
                        priceData.adjustedPrice,
                      ),
                      _buildPriceBlock(
                        context,
                        'Average Price',
                        priceData.averagePrice,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Error: $err', style: const TextStyle(color: EveColors.error)),
      ),
    );
  }

  Widget _buildPriceBlock(BuildContext context, String label, double? price) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: EveColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          price != null ? formatIsk(price) : 'N/A',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: EveColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eve_type_icon.dart';
import '../data/repositories/price_repository.dart';

/// A self-contained, accessible price-checker screen for EVE market data.
///
/// Supports single-region and all-regions lookups with screen-reader
/// announcements for dynamic state transitions.
class PriceCheckScreen extends ConsumerStatefulWidget {
  const PriceCheckScreen({super.key});

  @override
  ConsumerState<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends ConsumerState<PriceCheckScreen> {
  final _typeIdController = TextEditingController();
  final _typeNameController = TextEditingController();
  int _selectedRegionId = defaultMarketRegionId;
  bool _showAllRegions = true;
  String? _validationError;
  AsyncValue<List<MarketRegionPrice>>? _prices;

  @override
  void dispose() {
    _typeIdController.dispose();
    _typeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Price Checker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Type ID input ---
            TextField(
              controller: _typeIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Type ID'),
            ),
            const SizedBox(height: 12),

            // --- Optional type name ---
            TextField(
              controller: _typeNameController,
              decoration: const InputDecoration(labelText: 'Type name (optional)'),
            ),
            const SizedBox(height: 12),

            // --- All-regions toggle ---
            SwitchListTile(
              title: const Text('Check all regions'),
              value: _showAllRegions,
              onChanged: (v) => setState(() => _showAllRegions = v),
            ),
            const SizedBox(height: 4),

            // --- Single-region dropdown ---
            _RegionDropdown(
              selectedRegionId: _selectedRegionId,
              enabled: !_showAllRegions,
              regions: ref.read(priceRepositoryProvider).marketRegions,
              onChanged: (id) => setState(() => _selectedRegionId = id),
            ),
            const SizedBox(height: 16),

            // --- Validation error ---
            if (_validationError != null) ...[
              Semantics(
                liveRegion: true,
                label: 'Invalid Type ID: $_validationError',
                child: Text(
                  _validationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // --- Action button ---
            FilledButton(
              onPressed: _checkPrices,
              child: const Text('Check Prices'),
            ),
            const SizedBox(height: 16),

            // --- Results ---
            if (_prices != null) _buildResults(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Price fetching
  // ---------------------------------------------------------------------------

  Future<void> _checkPrices() async {
    final raw = _typeIdController.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      setState(() {
        _validationError = 'Enter a positive EVE Type ID.';
        _prices = null;
      });
      return;
    }

    setState(() {
      _validationError = null;
      _prices = const AsyncLoading();
    });

    final repo = ref.read(priceRepositoryProvider);
    final typeName = _typeNameController.text.trim().isEmpty
        ? null
        : _typeNameController.text.trim();

    try {
      if (_showAllRegions) {
        final results =
            await repo.getPricesAcrossAllRegions(parsed, typeName: typeName);
        setState(() => _prices = AsyncData(results));
      } else {
        final price =
            await repo.getPrice(parsed, _selectedRegionId, typeName: typeName);
        final name = repo.marketRegions[_selectedRegionId]!;
        setState(() {
          _prices = AsyncData([
            MarketRegionPrice(
              regionId: _selectedRegionId,
              regionName: name,
              price: price,
            ),
          ]);
        });
      }
    } catch (e) {
      setState(() => _prices = AsyncError(e, StackTrace.current));
    }
  }

  // ---------------------------------------------------------------------------
  // Results rendering
  // ---------------------------------------------------------------------------

  Widget _buildResults() {
    return _prices!.when(
      loading: () => Semantics(
        liveRegion: true,
        label: 'Loading market prices',
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Loading prices...'),
          ],
        ),
      ),
      error: (err, _) => Semantics(
        liveRegion: true,
        label: 'Failed to load market prices: $err',
        child: Text(
          'Failed to load prices: $err',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (prices) {
        if (prices.isEmpty) {
          return Semantics(
            liveRegion: true,
            label: 'No market regions returned',
            child: const Text('No market regions returned'),
          );
        }
        return Semantics(
          liveRegion: true,
          label: 'Market price results loaded',
          child: _PriceResultsList(prices: prices),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Region dropdown
// ---------------------------------------------------------------------------

class _RegionDropdown extends StatelessWidget {
  final int selectedRegionId;
  final bool enabled;
  final Map<int, String> regions;
  final ValueChanged<int> onChanged;

  const _RegionDropdown({
    required this.selectedRegionId,
    required this.enabled,
    required this.regions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = regions.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();

    return DropdownButtonFormField<int>(
      initialValue: items.any((i) => i.value == selectedRegionId)
          ? selectedRegionId
          : null,
      items: items,
      onChanged: enabled ? (v) => onChanged(v!) : null,
      decoration: const InputDecoration(labelText: 'Region'),
    );
  }
}

// ---------------------------------------------------------------------------
// Results list
// ---------------------------------------------------------------------------

class _PriceResultsList extends StatelessWidget {
  final List<MarketRegionPrice> prices;

  const _PriceResultsList({required this.prices});

  @override
  Widget build(BuildContext context) {
    // Sort a copy for display without mutating repository order.
    final sorted = List<MarketRegionPrice>.from(prices)..sort((a, b) {
      final sa = a.price.sellMin;
      final sb = b.price.sellMin;
      if (sa != null && sb != null) return sa.compareTo(sb);
      if (sa != null) return -1;
      if (sb != null) return 1;
      return a.regionName.compareTo(b.regionName);
    });

    return Column(
      children: sorted
          .map((rp) => _PriceResultTile(regionPrice: rp))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Single result tile
// ---------------------------------------------------------------------------

class _PriceResultTile extends StatelessWidget {
  final MarketRegionPrice regionPrice;

  const _PriceResultTile({required this.regionPrice});

  @override
  Widget build(BuildContext context) {
    final p = regionPrice.price;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Decorative item icon.
            ExcludeSemantics(
              child: EveTypeIcon(typeId: p.typeId, size: 48),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    regionPrice.regionName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  _PriceMetric(
                    label: 'Buy',
                    value: p.buyMax != null ? formatIskCompact(p.buyMax!) : 'No buy orders',
                  ),
                  _PriceMetric(
                    label: 'Sell',
                    value: p.sellMin != null ? formatIskCompact(p.sellMin!) : 'No sell orders',
                  ),
                  if (p.spread != null)
                    _PriceMetric(
                      label: 'Spread',
                      value: formatIskCompact(p.spread!),
                    ),
                  if (p.margin != null)
                    _PriceMetric(
                      label: 'Margin',
                      value: formatIskCompact(p.margin!),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceMetric(
                          label: 'Buy vol',
                          value: '${p.buyVolume}',
                        ),
                      ),
                      Expanded(
                        child: _PriceMetric(
                          label: 'Sell vol',
                          value: '${p.sellVolume}',
                        ),
                      ),
                    ],
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

/// A compact row showing a label and value.
class _PriceMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PriceMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Market transaction filter controls.
///
/// Provides toggle for buy/sell transactions and optional quantity/value filters.
class MarketFilters extends StatelessWidget {
  /// Current selected transaction type ('all', 'buy', 'sell').
  final String selectedType;

  /// Callback when transaction type changes.
  final ValueChanged<String> onTypeChanged;

  const MarketFilters({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Transaction Type Toggle (All / Buy / Sell)
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(77),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withAlpha(26),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton(
                label: 'All',
                value: 'all',
                isSelected: selectedType == 'all',
                onPressed: () => onTypeChanged('all'),
                isFirst: true,
              ),
              _buildToggleButton(
                label: 'Buy',
                value: 'buy',
                isSelected: selectedType == 'buy',
                onPressed: () => onTypeChanged('buy'),
              ),
              _buildToggleButton(
                label: 'Sell',
                value: 'sell',
                isSelected: selectedType == 'sell',
                onPressed: () => onTypeChanged('sell'),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a toggle button.
  Widget _buildToggleButton({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onPressed,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(8) : Radius.zero,
        right: isLast ? const Radius.circular(8) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withAlpha(26)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(8) : Radius.zero,
            right: isLast ? const Radius.circular(8) : Radius.zero,
          ),
          border: isSelected
              ? Border.all(
                  color: Colors.white.withAlpha(77),
                  width: 1,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white.withAlpha(179),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/wallet_providers.dart';

/// Transaction filter controls for type and date range.
///
/// Provides dropdowns for filtering wallet journal transactions.
class TransactionFilters extends StatelessWidget {
  /// Current selected transaction type filter.
  final String? selectedType;

  /// Current selected date range filter.
  final String selectedDateRange;

  /// Callback when type filter changes.
  final ValueChanged<String?> onTypeChanged;

  /// Callback when date range filter changes.
  final ValueChanged<String> onDateRangeChanged;

  const TransactionFilters({
    super.key,
    required this.selectedType,
    required this.selectedDateRange,
    required this.onTypeChanged,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Type Filter Dropdown
        _buildFilterDropdown(
          context: context,
          label: 'Type',
          value: selectedType ?? 'all',
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Types')),
            ..._transactionTypes.map(
              (type) => DropdownMenuItem(
                value: type.value,
                child: Text(type.label),
              ),
            ),
          ],
          onChanged: (value) {
            onTypeChanged(value == 'all' ? null : value);
          },
        ),

        // Date Range Filter Dropdown
        _buildFilterDropdown(
          context: context,
          label: 'Date Range',
          value: selectedDateRange,
          items: _dateRanges
              .map(
                (range) => DropdownMenuItem(
                  value: range.value,
                  child: Text(range.label),
                ),
              )
              .toList(),
          onChanged: onDateRangeChanged,
        ),
      ],
    );
  }

  /// Builds a styled dropdown with label.
  Widget _buildFilterDropdown({
    required BuildContext context,
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // Label
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(179),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),

          // Dropdown
          Flexible(
            child: DropdownButton<String>(
              value: value,
              items: items,
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
              underline: const SizedBox.shrink(),
              isDense: true,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              dropdownColor: const Color(0xFF1A1A1A),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Common EVE Online transaction types (static list).
final _transactionTypes = [
  _FilterOption('bounty_prizes', 'Bounty Prizes'),
  _FilterOption('market_transaction', 'Market Transaction'),
  _FilterOption('skill_purchase', 'Skill Purchase'),
  _FilterOption('insurance', 'Insurance'),
  _FilterOption('contract_reward', 'Contract Reward'),
  _FilterOption('contract_price', 'Contract Price'),
  _FilterOption('manufacturing', 'Manufacturing'),
  _FilterOption('planetary_import_tax', 'Planetary Import Tax'),
  _FilterOption('planetary_export_tax', 'Planetary Export Tax'),
  _FilterOption('mission_reward', 'Mission Reward'),
  _FilterOption('mission_completion', 'Mission Completion'),
  _FilterOption('corporate_reward_payout', 'Corp Reward Payout'),
  _FilterOption('office_rental_fee', 'Office Rental Fee'),
  _FilterOption('reprocessing_tax', 'Reprocessing Tax'),
  _FilterOption('asset_safety_recovery_tax', 'Asset Safety Tax'),
  _FilterOption('agent_services_rendered', 'Agent Services'),
];

/// Date range options.
final _dateRanges = [
  _FilterOption('7', 'Last 7 Days'),
  _FilterOption('30', 'Last 30 Days'),
  _FilterOption('90', 'Last 90 Days'),
  _FilterOption('all', 'All Time'),
];

/// Filter option model.
class _FilterOption {
  final String value;
  final String label;

  _FilterOption(this.value, this.label);
}

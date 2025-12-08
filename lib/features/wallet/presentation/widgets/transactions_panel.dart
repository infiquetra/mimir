import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/data_row.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/wallet_providers.dart';
import 'transaction_filters.dart';
import 'transaction_list_item.dart';

/// Transactions panel with filters and paginated list.
///
/// Displays wallet journal transactions with type and date range filtering.
class TransactionsPanel extends ConsumerStatefulWidget {
  const TransactionsPanel({super.key});

  @override
  ConsumerState<TransactionsPanel> createState() => _TransactionsPanelState();
}

class _TransactionsPanelState extends ConsumerState<TransactionsPanel> {
  // Filter state
  String? _selectedType;
  String _selectedDateRange = '30'; // Default: Last 30 days

  // Pagination state
  static const int _itemsPerPage = 20;
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(walletJournalProvider);

    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: TransactionFilters(
            selectedType: _selectedType,
            selectedDateRange: _selectedDateRange,
            onTypeChanged: (type) {
              setState(() {
                _selectedType = type;
                _currentPage = 0; // Reset to first page
              });
            },
            onDateRangeChanged: (range) {
              setState(() {
                _selectedDateRange = range;
                _currentPage = 0; // Reset to first page
              });
            },
          ),
        ),

        // Divider
        Divider(
          color: Colors.white.withAlpha(26),
          height: 1,
        ),

        // Transaction List
        Expanded(
          child: journal.when(
            data: (entries) {
              final filteredEntries = _applyFilters(entries);

              if (filteredEntries.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  heading: 'No Transactions',
                  description: 'No transactions match the selected filters.',
                );
              }

              // Pagination
              final totalPages = (filteredEntries.length / _itemsPerPage).ceil();
              final startIndex = _currentPage * _itemsPerPage;
              final endIndex = (startIndex + _itemsPerPage)
                  .clamp(0, filteredEntries.length);
              final pageEntries = filteredEntries.sublist(startIndex, endIndex);

              return Column(
                children: [
                  // Table header
                  const DataHeaderRow(
                    columns: ['Date', 'Type', 'Amount', 'Balance'],
                    flexValues: [2, 3, 2, 2],
                  ),

                  // Transaction list
                  Expanded(
                    child: ListView.builder(
                      itemCount: pageEntries.length,
                      itemBuilder: (context, index) {
                        return TransactionListItem(
                          entry: pageEntries[index],
                        );
                      },
                    ),
                  ),

                  // Pagination controls (if more than 1 page)
                  if (totalPages > 1)
                    _buildPaginationControls(totalPages),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => EmptyState(
              icon: Icons.error_outline,
              heading: 'Failed to Load Transactions',
              description: error.toString(),
              action: ElevatedButton(
                onPressed: () => ref.refresh(walletJournalProvider),
                child: const Text('Retry'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Applies type and date range filters to journal entries.
  List<WalletJournalEntry> _applyFilters(List<WalletJournalEntry> entries) {
    var filtered = entries;

    // Apply type filter
    if (_selectedType != null) {
      filtered = filtered
          .where((entry) => entry.refType == _selectedType)
          .toList();
    }

    // Apply date range filter
    if (_selectedDateRange != 'all') {
      final days = int.parse(_selectedDateRange);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      filtered = filtered
          .where((entry) => entry.date.isAfter(cutoffDate))
          .toList();
    }

    return filtered;
  }

  /// Builds pagination controls with page numbers.
  Widget _buildPaginationControls(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withAlpha(26),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            color: Colors.white70,
            disabledColor: Colors.white24,
          ),

          const SizedBox(width: 16),

          // Page numbers
          Wrap(
            spacing: 8,
            children: List.generate(totalPages, (index) {
              final isCurrentPage = index == _currentPage;

              // Show first page, last page, current page, and ±2 around current
              final showPage = index == 0 ||
                  index == totalPages - 1 ||
                  (index >= _currentPage - 2 && index <= _currentPage + 2);

              // Show ellipsis between gaps
              final showEllipsis =
                  (index == _currentPage - 3 && _currentPage > 3) ||
                  (index == _currentPage + 3 && _currentPage < totalPages - 4);

              if (showEllipsis) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '...',
                    style: TextStyle(
                      color: Colors.white.withAlpha(128),
                    ),
                  ),
                );
              }

              if (!showPage) {
                return const SizedBox.shrink();
              }

              return InkWell(
                onTap: () => setState(() => _currentPage = index),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentPage
                        ? Colors.white.withAlpha(26)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCurrentPage
                          ? Colors.white.withAlpha(77)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrentPage
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isCurrentPage
                          ? Colors.white
                          : Colors.white.withAlpha(179),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(width: 16),

          // Next button
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            color: Colors.white70,
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

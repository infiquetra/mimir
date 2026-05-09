import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../../../core/database/app_database.dart';
import '../../data/industry_providers.dart';

/// Panel displaying the character's blueprints.
class BlueprintListPanel extends ConsumerStatefulWidget {
  const BlueprintListPanel({super.key});

  @override
  ConsumerState<BlueprintListPanel> createState() => _BlueprintListPanelState();
}

class _BlueprintListPanelState extends ConsumerState<BlueprintListPanel> {
  String _searchQuery = '';
  bool _showOriginalsOnly = false;
  bool _showCopiesOnly = false;

  @override
  Widget build(BuildContext context) {
    final blueprintsAsync = ref.watch(characterBlueprintsProvider);

    return Column(
      children: [
        _buildFilters(),
        const SizedBox(height: 16),
        Expanded(
          child: blueprintsAsync.when(
            data: (blueprints) {
              final filtered = _applyFilters(blueprints);

              if (filtered.isEmpty) {
                return const EmptyState(
                  icon: Icons.architecture,
                  heading: 'No Blueprints Found',
                  description:
                      'You do not have any blueprints matching your filters.',
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final blueprint = filtered[index];
                  return _BlueprintListItem(blueprint: blueprint);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => EmptyState(
              icon: Icons.error_outline,
              heading: 'Failed to Load Blueprints',
              description: err.toString(),
              action: ElevatedButton(
                onPressed: () => ref.refresh(characterBlueprintsProvider),
                child: const Text('Retry'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search blueprints...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),
        const SizedBox(width: 16),
        FilterChip(
          label: const Text('BPO'),
          selected: _showOriginalsOnly,
          onSelected: (selected) {
            setState(() {
              _showOriginalsOnly = selected;
              if (selected) _showCopiesOnly = false;
            });
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('BPC'),
          selected: _showCopiesOnly,
          onSelected: (selected) {
            setState(() {
              _showCopiesOnly = selected;
              if (selected) _showOriginalsOnly = false;
            });
          },
        ),
      ],
    );
  }

  List<Blueprint> _applyFilters(List<Blueprint> blueprints) {
    return blueprints.where((bp) {
      if (_showOriginalsOnly && !bp.isOriginal) return false;
      if (_showCopiesOnly && bp.isOriginal) return false;

      // In a full implementation we would resolve the name of typeId using SDE.
      // For this MVP, since we don't have the resolved name string in the db easily searchable without joins,
      // we'll filter by ID or let it pass if query is empty.
      if (_searchQuery.isNotEmpty) {
        if (!bp.typeId.toString().contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

class _BlueprintListItem extends ConsumerWidget {
  final Blueprint blueprint;

  const _BlueprintListItem({required this.blueprint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Original = Blue/Default, Copy = Green/Teal highlight
    final typeColor =
        blueprint.isOriginal ? Colors.blue.shade300 : Colors.teal.shade300;
    final typeLabel = blueprint.isOriginal ? 'Original (BPO)' : 'Copy (BPC)';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: EveCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: typeColor.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(2),
                child: EveTypeIcon(
                  typeId: blueprint.typeId,
                  size: 48,
                  variant: blueprint.isOriginal ? 'bp' : 'bpc',
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          // Resolving names dynamically is standard but out of scope for pure UI
                          // We would use itemNameProvider here realistically.
                          child: Text(
                            'Blueprint Type #${blueprint.typeId}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: typeColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            typeLabel,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: typeColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          label: 'ME',
                          value: '${blueprint.materialEfficiency}%',
                          color: _getEfficiencyColor(
                              blueprint.materialEfficiency, 10),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: 'TE',
                          value: '${blueprint.timeEfficiency}%',
                          color:
                              _getEfficiencyColor(blueprint.timeEfficiency, 20),
                        ),
                        const SizedBox(width: 16),
                        if (!blueprint.isOriginal)
                          Text(
                            'Runs: ${blueprint.runs}',
                            style: theme.textTheme.bodySmall,
                          )
                        else
                          Text(
                            'Infinite Runs',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: EveColors.textSecondary,
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
      ),
    );
  }

  Color _getEfficiencyColor(int value, int max) {
    if (value == 0) return EveColors.textSecondary;
    if (value == max) return EveColors.success;
    return Colors.blue;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: EveColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

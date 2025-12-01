import 'package:flutter/material.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/characters/presentation/widgets/implant_row.dart';

/// Displays information about a single jump clone.
///
/// Shows clone name, location, and implants.
/// Used in both Overview tab (compact) and Jump Clones sub-tab (detailed).
class CloneCard extends StatelessWidget {
  /// The jump clone to display.
  final JumpClone clone;

  /// Optional resolved location name.
  /// If null, shows "Unknown Location".
  final String? locationName;

  /// Whether to show implants.
  /// Default: true
  final bool showImplants;

  /// Whether to use compact layout (for Overview tab).
  /// Default: false
  final bool compact;

  const CloneCard({
    super.key,
    required this.clone,
    this.locationName,
    this.showImplants = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cloneName = clone.name?.isNotEmpty == true
        ? clone.name!
        : 'Jump Clone #${clone.jumpCloneId}';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.all(12.0)
            : const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clone name
            Text(
              cloneName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Location
            Row(
              children: [
                Icon(
                  clone.locationType == 'station'
                      ? Icons.location_city_outlined
                      : Icons.place_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationName ?? 'Unknown Location',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Implants
            if (showImplants) ...[
              const SizedBox(height: 12),
              if (clone.implants.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'No implants',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ImplantRow(
                  implants: _buildImplantMap(clone.implants),
                  iconSize: compact ? 28.0 : 32.0,
                  spacing: compact ? 3.0 : 4.0,
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Converts list of implant type IDs to a map of slot number -> type ID.
  ///
  /// EVE Online implants have slot numbers encoded in their type ID ranges:
  /// - Slot 1: 10000-10999 range
  /// - Slot 2: 11000-11999 range
  /// - etc.
  ///
  /// For now, we use a simplified approach where we just assign implants
  /// to sequential slots. The proper mapping requires SDE data.
  Map<int, int> _buildImplantMap(List<int> implantTypeIds) {
    final Map<int, int> implantMap = {};
    for (int i = 0; i < implantTypeIds.length && i < 10; i++) {
      implantMap[i + 1] = implantTypeIds[i];
    }
    return implantMap;
  }
}

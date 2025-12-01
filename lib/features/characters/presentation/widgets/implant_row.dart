import 'package:flutter/material.dart';
import 'package:mimir/core/widgets/eve_type_icon.dart';

/// Displays a row of 10 implant slots with icons.
///
/// Shows filled slots with implant icons and empty slots as placeholders.
/// EVE Online characters have 10 implant slots (numbered 1-10).
class ImplantRow extends StatelessWidget {
  /// Map of slot number (1-10) to implant type ID.
  final Map<int, int> implants;

  /// Map of implant type ID to implant name (for tooltips).
  /// If provided, implant icons will show tooltips on hover.
  final Map<int, String>? implantNames;

  /// Size of each implant icon.
  final double iconSize;

  /// Spacing between implant slots.
  final double spacing;

  /// Whether to show slot numbers.
  final bool showSlotNumbers;

  const ImplantRow({
    super.key,
    required this.implants,
    this.implantNames,
    this.iconSize = 32.0,
    this.spacing = 4.0,
    this.showSlotNumbers = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: List.generate(10, (index) {
        final slotNumber = index + 1;
        final implantTypeId = implants[slotNumber];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSlotNumbers)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '$slotNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _buildSlot(context, slotNumber, implantTypeId),
          ],
        );
      }),
    );
  }

  Widget _buildSlot(BuildContext context, int slotNumber, int? implantTypeId) {
    if (implantTypeId != null) {
      // Show implant icon
      final implantIcon = EveTypeIcon(
        typeId: implantTypeId,
        size: iconSize,
        borderRadius: 4.0,
      );

      // Wrap with tooltip if name is available
      final implantName = implantNames?[implantTypeId];
      if (implantName != null && implantName.isNotEmpty) {
        return Tooltip(
          message: implantName,
          waitDuration: const Duration(milliseconds: 300),
          child: implantIcon,
        );
      }

      return implantIcon;
    } else {
      // Show empty slot placeholder
      return Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: iconSize * 0.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
      );
    }
  }
}

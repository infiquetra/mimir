import 'package:flutter/material.dart';

import '../theme/eve_colors.dart';
import '../theme/eve_spacing.dart';
import '../theme/eve_typography.dart';

/// Compact data row for table-like displays.
///
/// Standardizes the 28px row height across the app for:
/// - Skill queue items
/// - Wallet transactions
/// - Character standings
/// - Any other dense data tables
///
/// ```dart
/// DataRow(
///   leading: Icon(Icons.trending_up, size: 20),
///   title: 'Market Transaction',
///   subtitle: 'Dec 08, 2025',
///   trailing: Text('+50M ISK'),
/// )
/// ```
class DataRow extends StatelessWidget {
  const DataRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  /// Leading widget (typically an icon or small avatar).
  final Widget? leading;

  /// Primary text (required).
  final String title;

  /// Optional secondary text below title.
  final String? subtitle;

  /// Trailing widget (typically a value, badge, or action).
  final Widget? trailing;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Whether to use ultra-compact mode (24px height instead of 28px).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final rowHeight = dense ? 24.0 : EveSpacing.rowHeight;

    Widget row = Container(
      height: rowHeight,
      padding: EdgeInsets.symmetric(
        horizontal: EveSpacing.lg,
        vertical: EveSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: EveColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Leading
          if (leading != null) ...[
            SizedBox(
              width: EveSpacing.iconSm,
              height: EveSpacing.iconSm,
              child: leading,
            ),
            SizedBox(width: EveSpacing.md),
          ],

          // Title/Subtitle
          Expanded(
            child: subtitle != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: dense
                            ? EveTypography.labelSmall(
                                color: EveColors.textPrimary,
                              )
                            : EveTypography.labelMedium(
                                color: EveColors.textPrimary,
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle!,
                        style: EveTypography.labelSmall(
                          color: EveColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: dense
                          ? EveTypography.bodySmall(
                              color: EveColors.textPrimary,
                            )
                          : EveTypography.bodyMedium(
                              color: EveColors.textPrimary,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),

          // Trailing
          if (trailing != null) ...[
            SizedBox(width: EveSpacing.md),
            trailing!,
          ],
        ],
      ),
    );

    // Wrap with InkWell if tappable
    if (onTap != null) {
      row = InkWell(
        onTap: onTap,
        child: row,
      );
    }

    return row;
  }
}

/// Header row for data tables.
///
/// Typically used above a list of DataRow widgets to provide column labels.
///
/// ```dart
/// DataHeaderRow(
///   columns: ['Name', 'Type', 'Amount', 'Balance'],
///   flexValues: [3, 2, 2, 2],
/// )
/// ```
class DataHeaderRow extends StatelessWidget {
  const DataHeaderRow({
    super.key,
    required this.columns,
    this.flexValues,
  });

  /// Column labels.
  final List<String> columns;

  /// Optional flex values for each column (defaults to equal width).
  final List<int>? flexValues;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: EdgeInsets.symmetric(
        horizontal: EveSpacing.lg,
        vertical: EveSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: EveColors.surfaceElevated,
        border: Border(
          bottom: BorderSide(
            color: EveColors.borderActive,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(columns.length, (index) {
          final label = columns[index];
          final flex = flexValues != null && index < flexValues!.length
              ? flexValues![index]
              : 1;

          return Expanded(
            flex: flex,
            child: Text(
              label.toUpperCase(),
              style: EveTypography.labelSmall(
                color: EveColors.textSecondary,
              ).copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_card.dart';

/// Specialized dashboard card widget extending EveCard with common
/// dashboard patterns for loading, error, empty, and content states.
///
/// This widget provides:
/// - Consistent title header with icon
/// - Optional expand button for navigation
/// - Loading state with shimmer effect
/// - Error state with retry functionality
/// - Glow effect support from EveCard
///
/// Example usage:
/// ```dart
/// DashboardCard(
///   title: 'Wallet Balance',
///   icon: Icons.account_balance_wallet,
///   glowColor: EveColors.evePrimary,
///   child: BalanceWidget(),
/// )
/// ```
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.glowColor,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onExpand,
  });

  /// Card title displayed in header.
  final String title;

  /// Icon displayed next to title.
  final IconData icon;

  /// Content to display when not in loading or error state.
  final Widget child;

  /// Optional glow color for the card border.
  final Color? glowColor;

  /// Whether to show loading state.
  final bool isLoading;

  /// Error message to display. If null, shows content.
  final String? errorMessage;

  /// Callback when retry button is pressed (only shown in error state).
  final VoidCallback? onRetry;

  /// Callback when expand button is pressed (shows arrow icon in header).
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return EveCard(
      glowColor: glowColor,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title, icon, and optional expand button
          _buildHeader(context),

          // Divider between header and content
          const Divider(height: 1),

          // Content area (loading, error, or actual content)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  /// Builds the card header with title, icon, and optional expand button.
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            icon,
            color: glowColor ?? EveColors.evePrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (onExpand != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 20),
              onPressed: onExpand,
              tooltip: 'View details',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  /// Builds the content area based on current state.
  Widget _buildContent(BuildContext context) {
    // Show error state
    if (errorMessage != null) {
      return _buildErrorState(context);
    }

    // Show loading state
    if (isLoading) {
      return _buildLoadingState();
    }

    // Show actual content
    return child;
  }

  /// Builds the loading state with shimmer effect.
  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: EveColors.darkSurfaceVariant,
      highlightColor: EveColors.darkSurfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the error state with message and retry button.
  Widget _buildErrorState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: EveColors.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: EveColors.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          errorMessage!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(204),
              ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: EveColors.evePrimary,
              side: const BorderSide(color: EveColors.evePrimary),
            ),
          ),
        ],
      ],
    );
  }
}

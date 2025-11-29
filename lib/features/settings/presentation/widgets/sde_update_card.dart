import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sde/sde_update_providers.dart';

/// Card widget displaying SDE data status and update controls.
///
/// Shows:
/// - Current installed version
/// - Last update check time
/// - Update availability status
/// - Check for updates button
/// - Apply update button (when available)
class SdeUpdateCard extends ConsumerWidget {
  const SdeUpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sdeStatusProvider);
    final updateState = ref.watch(sdeUpdateControllerProvider);
    final controller = ref.read(sdeUpdateControllerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.storage),
                const SizedBox(width: 8),
                Text(
                  'Static Data (SDE)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                _buildStatusIcon(updateState),
              ],
            ),
            const SizedBox(height: 16),

            // Version info
            status.when(
              data: (s) => _buildStatusInfo(context, s),
              loading: () => const _LoadingRow(),
              error: (e, _) => Text('Error loading status: $e'),
            ),

            const SizedBox(height: 16),

            // Update state message
            _buildUpdateMessage(context, updateState),

            const SizedBox(height: 16),

            // Action buttons
            _buildActionButtons(context, updateState, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SdeUpdateUiState state) {
    return switch (state) {
      SdeUpdateIdle() => const Icon(
          Icons.check_circle_outline,
          color: Colors.grey,
        ),
      SdeUpdateChecking() => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      SdeUpdateHasUpdate() => const Icon(
          Icons.download,
          color: Colors.blue,
        ),
      SdeUpdateApplying() => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      SdeUpdateSuccess() => const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
      SdeUpdateError() => const Icon(
          Icons.error_outline,
          color: Colors.red,
        ),
    };
  }

  Widget _buildStatusInfo(BuildContext context, SdeStatus status) {
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.onSurface.withAlpha(153);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: 'Version',
          value: status.version ?? 'Not installed',
        ),
        const SizedBox(height: 4),
        _InfoRow(
          label: 'Last checked',
          value: status.lastCheckDisplay ?? 'Never',
          valueColor: secondaryColor,
        ),
        if (status.skillCount != null) ...[
          const SizedBox(height: 4),
          _InfoRow(
            label: 'Skills',
            value: '${status.skillCount}',
            valueColor: secondaryColor,
          ),
        ],
      ],
    );
  }

  Widget _buildUpdateMessage(BuildContext context, SdeUpdateUiState state) {
    final theme = Theme.of(context);

    return switch (state) {
      SdeUpdateIdle() => const SizedBox.shrink(),
      SdeUpdateChecking() => Text(
          'Checking for updates...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
      SdeUpdateHasUpdate(
        newVersion: final newV,
        skillCount: final count,
      ) =>
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.new_releases,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Update available: v$newV ($count skills)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      SdeUpdateApplying() => Text(
          'Downloading and installing update...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
      SdeUpdateSuccess(message: final msg) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      SdeUpdateError(message: final msg) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
    };
  }

  Widget _buildActionButtons(
    BuildContext context,
    SdeUpdateUiState state,
    SdeUpdateController controller,
  ) {
    final isLoading = state is SdeUpdateChecking || state is SdeUpdateApplying;

    return Row(
      children: [
        // Check for updates button
        OutlinedButton.icon(
          onPressed: isLoading ? null : () => controller.checkForUpdates(),
          icon: const Icon(Icons.refresh),
          label: const Text('Check for Updates'),
        ),

        // Apply update button (shown when update available)
        if (state is SdeUpdateHasUpdate) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: isLoading ? null : () => controller.applyUpdate(),
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
          ),
        ],

        // Dismiss button (shown on success/error)
        if (state is SdeUpdateSuccess || state is SdeUpdateError) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => controller.reset(),
            child: const Text('Dismiss'),
          ),
        ],
      ],
    );
  }
}

/// Row widget for displaying label-value pairs.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                ),
          ),
        ),
      ],
    );
  }
}

/// Loading placeholder for status info.
class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading status...'),
        ],
      ),
    );
  }
}

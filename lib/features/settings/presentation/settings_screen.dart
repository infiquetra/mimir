import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import 'widgets/sde_update_card.dart';

/// Settings screen for app configuration.
///
/// Currently includes:
/// - SDE (Static Data Export) update management
///
/// Future additions may include:
/// - Theme settings
/// - Account management
/// - Data sync options
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Startup Section
          _buildSectionHeader(context, 'Startup'),
          settingsAsync.when(
            data: (settings) => _buildStartupCard(context, ref, settings),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Failed to load settings'),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SDE Update Section
          _buildSectionHeader(context, 'Data'),
          const SdeUpdateCard(),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildAboutCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildStartupCard(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.power_settings_new),
                const SizedBox(width: 8),
                Text(
                  'When Mimir launches',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RadioListTile<StartupBehavior>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open Dashboard'),
              subtitle: const Text('Show the Dashboard window automatically'),
              value: StartupBehavior.openDashboard,
              groupValue: settings.startupBehavior,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsRepositoryProvider)
                      .setStartupBehavior(value);
                }
              },
            ),
            RadioListTile<StartupBehavior>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show tray icon only'),
              subtitle: const Text('Launch silently in the menu bar'),
              value: StartupBehavior.trayOnly,
              groupValue: settings.startupBehavior,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsRepositoryProvider)
                      .setStartupBehavior(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Text(
                  'Mimir',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'EVE Online companion app for tracking your characters, '
              'skills, and wallet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 0.1.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'EVE Online and the EVE logo are registered trademarks of CCP hf.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(102),
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

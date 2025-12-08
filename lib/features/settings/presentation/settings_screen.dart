import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/theme/eve_spacing.dart';
import '../../../core/theme/eve_typography.dart';
import '../../../core/widgets/eve_card.dart';
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
        padding: const EdgeInsets.all(EveSpacing.lg),
        children: [
          // Startup Section
          _buildSectionHeader(context, 'Startup'),
          settingsAsync.when(
            data: (settings) => _buildStartupCard(context, ref, settings),
            loading: () => EveCard(
              child: SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => EveCard(
              glowColor: EveColors.error,
              child: Text(
                'Failed to load settings',
                style: EveTypography.bodyMedium(color: EveColors.error),
              ),
            ),
          ),

          SizedBox(height: EveSpacing.lg),

          // SDE Update Section
          _buildSectionHeader(context, 'Data'),
          const SdeUpdateCard(),

          SizedBox(height: EveSpacing.lg),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildAboutCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: EveSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: EveTypography.labelMedium(
          color: EveColors.photonBlue,
        ).copyWith(
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildStartupCard(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return EveCard(
      child: Padding(
        padding: const EdgeInsets.all(EveSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: EveColors.photonBlue,
                  size: EveSpacing.iconSm,
                ),
                SizedBox(width: EveSpacing.md),
                Text(
                  'When Mimir launches',
                  style: EveTypography.titleMedium(
                    color: EveColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: EveSpacing.lg),
            RadioListTile<StartupBehavior>(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Open Dashboard',
                style: EveTypography.bodyMedium(color: EveColors.textPrimary),
              ),
              subtitle: Text(
                'Show the Dashboard window automatically',
                style: EveTypography.bodySmall(color: EveColors.textSecondary),
              ),
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
              title: Text(
                'Show tray icon only',
                style: EveTypography.bodyMedium(color: EveColors.textPrimary),
              ),
              subtitle: Text(
                'Launch silently in the menu bar',
                style: EveTypography.bodySmall(color: EveColors.textSecondary),
              ),
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
    return EveCard(
      child: Padding(
        padding: const EdgeInsets.all(EveSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: EveColors.photonBlue,
                  size: EveSpacing.iconSm,
                ),
                SizedBox(width: EveSpacing.md),
                Text(
                  'Mimir',
                  style: EveTypography.titleMedium(
                    color: EveColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: EveSpacing.md),
            Text(
              'EVE Online companion app for tracking your characters, '
              'skills, and wallet.',
              style: EveTypography.bodyMedium(color: EveColors.textSecondary),
            ),
            SizedBox(height: EveSpacing.md),
            Text(
              'Version 0.1.0',
              style: EveTypography.bodySmall(color: EveColors.textSecondary),
            ),
            SizedBox(height: EveSpacing.sm),
            Text(
              'EVE Online and the EVE logo are registered trademarks of CCP hf.',
              style: EveTypography.captionSmall(color: EveColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tray icon introduction step for onboarding (Step 3).
library;

import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings.dart';

/// Step 3: Tray icon guide and startup preference.
///
/// Explains how to access the app from the menu bar and lets users
/// choose whether to open the Dashboard on startup or stay in tray-only mode.
class TrayIntroStep extends StatelessWidget {
  const TrayIntroStep({
    required this.selectedBehavior,
    required this.onBehaviorChanged,
    super.key,
  });

  final StartupBehavior selectedBehavior;
  final ValueChanged<StartupBehavior> onBehaviorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.more_vert,
                  size: 64,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Always Available in Your Menu Bar',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Mimir lives in your menu bar for quick access to your '
                'character information. Click the icon to view your skills, '
                'wallet, and more.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Startup preference section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When Mimir launches',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Radio options
                    RadioGroup<StartupBehavior>(
                      value: selectedBehavior,
                      onChanged: (value) {
                        if (value != null) {
                          onBehaviorChanged(value);
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile<StartupBehavior>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Open Dashboard'),
                            subtitle: const Text(
                              'Show the Dashboard window automatically',
                            ),
                            value: StartupBehavior.openDashboard,
                          ),
                          RadioListTile<StartupBehavior>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show tray icon only'),
                            subtitle: const Text(
                              'Launch silently in the menu bar',
                            ),
                            value: StartupBehavior.trayOnly,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'You can change this later in Settings',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

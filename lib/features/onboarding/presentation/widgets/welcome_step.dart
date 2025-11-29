/// Welcome step for onboarding (Step 1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../characters/data/character_providers.dart';

/// Step 1: Welcome message and optional character addition.
///
/// Introduces the app and offers to add the first character via OAuth.
class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final charactersAsync = ref.watch(allCharactersProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              Image.asset(
                'assets/icons/eve/app_icon.png',
                width: 120,
                height: 120,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 32),

              // Welcome title
              Text(
                'Welcome to Mimir',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Your EVE Online companion for tracking characters, '
                'skills, and wallet information.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Character status
              charactersAsync.when(
                data: (characters) {
                  if (characters.isEmpty) {
                    return Column(
                      children: [
                        Text(
                          'Add your first character to get started',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _addCharacter(context, ref),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Character'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You can also skip and add characters later',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  } else {
                    // Characters already added
                    return Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${characters.length} character(s) configured',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can add more characters anytime from the Characters window',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => Text(
                  'Error loading characters',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Triggers the OAuth flow to add a new character.
  void _addCharacter(BuildContext context, WidgetRef ref) {
    // Trigger OAuth flow via auth controller
    ref.read(authControllerProvider.notifier).startAuthFlow();

    // Characters list will automatically refresh via stream when auth completes
  }
}

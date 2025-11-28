import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/config/eve_config.dart';

/// Screen for adding a new EVE Online character.
///
/// Initiates the OAuth flow and shows progress feedback.
class AddCharacterScreen extends ConsumerWidget {
  const AddCharacterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Character'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(authControllerProvider.notifier).cancelAuth();
            context.pop();
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildContent(context, ref, authState, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    ThemeData theme,
  ) {
    switch (authState.flowState) {
      case AuthFlowState.idle:
        return _buildIdleState(context, ref, theme);

      case AuthFlowState.awaitingCallback:
        return _buildAwaitingState(context, ref, theme);

      case AuthFlowState.exchangingTokens:
        return _buildExchangingState(theme);

      case AuthFlowState.success:
        // Navigate back after success.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authControllerProvider.notifier).reset();
          context.pop();
        });
        return _buildSuccessState(theme);

      case AuthFlowState.error:
        return _buildErrorState(context, ref, authState, theme);
    }
  }

  Widget _buildIdleState(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.person_add_outlined,
          size: 80,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Add EVE Character',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Connect your EVE Online character to view your skill queue, wallet, and more.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You will be redirected to EVE Online to authorize Mimir.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        _buildScopesList(theme),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () {
            ref.read(authControllerProvider.notifier).startAuthFlow();
          },
          icon: const Icon(Icons.login),
          label: const Text('Sign in with EVE Online'),
        ),
      ],
    );
  }

  Widget _buildScopesList(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requested Permissions',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...EveConfig.phase1Scopes.map((scope) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatScope(scope),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _formatScope(String scope) {
    // Convert scope like 'esi-skills.read_skills.v1' to 'Read Skills'
    final parts = scope.split('.');
    if (parts.length < 2) return scope;

    final action = parts[1]
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return action;
  }

  Widget _buildAwaitingState(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Waiting for Authorization',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Complete the sign-in process in your browser.\nThis window will update automatically.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () {
            ref.read(authControllerProvider.notifier).cancelAuth();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildExchangingState(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Completing Authentication',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Securing your connection...',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          size: 80,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Character Added!',
          style: theme.textTheme.headlineSmall,
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 80,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 24),
        Text(
          'Authentication Failed',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          authState.errorMessage ?? 'An unknown error occurred.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).reset();
                context.pop();
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).reset();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/skills/presentation/skills_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../sde/sde_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/character_header_bar.dart';
import 'standalone_characters_screen.dart';
import 'standalone_dashboard_screen.dart';
import 'window_types.dart';

/// Entry point for sub-windows (non-main windows).
///
/// Each sub-window is fully independent and self-sufficient:
/// - Has its own Flutter engine and Riverpod scope
/// - Directly accesses the shared SQLite database
/// - Initializes SDE for skill name lookups
/// - Can refresh data from ESI independently
///
/// This architecture is simpler than IPC because:
/// - No synchronization complexity between windows
/// - Each window uses the same providers as the main app
/// - Database changes are visible to all windows via Drift streams
/// - OAuth tokens are shared via keychain
class SubWindowApp extends ConsumerStatefulWidget {
  const SubWindowApp({
    required this.windowArgs,
    super.key,
  });

  /// JSON-encoded arguments passed when creating the window.
  ///
  /// Expected format: `{"windowType": 1}` where the number is
  /// the [WindowType.windowId].
  final String windowArgs;

  @override
  ConsumerState<SubWindowApp> createState() => _SubWindowAppState();
}

class _SubWindowAppState extends ConsumerState<SubWindowApp> {
  late final WindowType _windowType;

  @override
  void initState() {
    super.initState();
    _windowType = _parseWindowArgs(widget.windowArgs);
    debugPrint('SubWindow: Initializing ${_windowType.title}');
  }

  /// Parses the window arguments to get the window type.
  ///
  /// Note: Database path is now set in main.dart BEFORE ProviderScope creation.
  WindowType _parseWindowArgs(String args) {
    try {
      final decoded = jsonDecode(args) as Map<String, dynamic>;
      final windowId = decoded['windowType'] as int? ?? 1;
      return WindowTypeExtension.fromId(windowId);
    } catch (e) {
      debugPrint(
          'SubWindow: Failed to parse args: $e, defaulting to dashboard');
      return WindowType.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize SDE for skill name lookups
    final sdeAsync = ref.watch(sdeInitializerProvider);

    return MaterialApp(
      title: _windowType.title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: sdeAsync.when(
        data: (_) => _SubWindowScaffold(child: _buildScreen(_windowType)),
        loading: () => const _LoadingScreen(message: 'Loading skill data...'),
        error: (error, _) => _ErrorScreen(
          message: 'Failed to load skill data',
          error: error.toString(),
          onRetry: () => ref.invalidate(sdeInitializerProvider),
        ),
      ),
    );
  }

  /// Builds the appropriate screen based on window type.
  ///
  /// Uses the same screens as the main app (with regular providers),
  /// except for Dashboard and Characters which need standalone versions
  /// without router dependencies.
  Widget _buildScreen(WindowType type) {
    switch (type) {
      case WindowType.dashboard:
        // Standalone version without "View All" navigation
        return const StandaloneDashboardScreen();
      case WindowType.skills:
        // Skills screen has no router dependencies
        return const SkillsScreen();
      case WindowType.wallet:
        // Wallet screen has no router dependencies
        return const WalletScreen();
      case WindowType.characters:
        // Standalone version with OAuth capability
        return const StandaloneCharactersScreen();
      case WindowType.main:
      case WindowType.settings:
        // Main window and Settings shouldn't be opened as sub-windows
        return const StandaloneDashboardScreen();
    }
  }
}

/// Loading screen shown while SDE is initializing.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({this.message = 'Loading...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown when SDE initialization fails.
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scaffold wrapper for all sub-window screens.
///
/// Adds the character header bar above all content, with proper
/// spacing for macOS traffic light buttons.
class _SubWindowScaffold extends StatelessWidget {
  const _SubWindowScaffold({required this.child});

  final Widget child;

  /// Height of the macOS traffic light buttons safe area.
  static const double _macOSTrafficLightHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final isMacOS = !kIsWeb && Platform.isMacOS;

    return Scaffold(
      body: Column(
        children: [
          // macOS traffic light buttons safe area.
          if (isMacOS) const SizedBox(height: _macOSTrafficLightHeight),
          // Character header bar (full width).
          const CharacterHeaderBar(),
          // Screen content.
          Expanded(child: child),
        ],
      ),
    );
  }
}

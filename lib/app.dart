import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/deep_link_handler.dart';
import 'core/di/providers.dart';
import 'core/sde/sde_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/characters/data/character_repository.dart';
import 'features/skills/data/skill_repository.dart';
import 'features/wallet/data/wallet_repository.dart';

/// Provider that refreshes all data for the active character on app startup.
///
/// Initializes:
/// - SDE (Static Data Export) for skill names and type data
///
/// Refreshes:
/// - Character info (always refresh active character)
/// - Skill queue
/// - Wallet balance and journal
///
/// This ensures users see fresh data when they launch the app.
final startupRefreshProvider = FutureProvider<void>((ref) async {
  // Initialize SDE first so skill names are available when UI renders.
  try {
    await ref.read(sdeInitializerProvider.future);
    debugPrint('Startup: SDE initialized');
  } catch (e) {
    debugPrint('Startup: SDE initialization failed: $e');
    // Continue - the app can function without SDE, just shows skill IDs.
  }

  final characterRepo = ref.read(characterRepositoryProvider);
  final skillRepo = ref.read(skillRepositoryProvider);
  final walletRepo = ref.read(walletRepositoryProvider);

  final characters = await characterRepo.getAllCharacters();
  if (characters.isEmpty) {
    debugPrint('Startup refresh: No characters to refresh');
    return;
  }

  // Find the active character, or use the first one.
  final active = characters.firstWhere(
    (c) => c.isActive,
    orElse: () => characters.first,
  );

  debugPrint('Startup refresh: Refreshing data for ${active.name}');

  // Refresh all data types in parallel.
  try {
    await Future.wait([
      characterRepo.refreshCharacter(active.characterId),
      skillRepo.refreshSkillQueue(active.characterId),
      walletRepo.refreshWalletBalance(active.characterId),
      walletRepo.refreshWalletJournal(active.characterId),
    ]);
    debugPrint('Startup refresh: All data refreshed for ${active.name}');
  } catch (e) {
    debugPrint('Startup refresh: Failed to refresh data: $e');
    // Don't rethrow - startup should continue even if refresh fails.
  }
});

/// The root widget of the Mimir application.
///
/// This widget sets up:
/// - Material app with go_router for navigation
/// - Theme switching (light/dark/system)
/// - Riverpod state management
/// - Deep link handling for OAuth callbacks
class MimirApp extends ConsumerWidget {
  const MimirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Initialize deep link handler for OAuth callbacks.
    // Reading the provider causes it to be created and start listening.
    ref.watch(deepLinkHandlerProvider);

    // Refresh stale character data on app startup.
    // This runs in the background and updates characters that have
    // placeholder corporation names.
    ref.watch(startupRefreshProvider);

    return MaterialApp.router(
      title: 'Mimir',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _toThemeMode(themeMode),

      // Router configuration
      routerConfig: router,
    );
  }

  ThemeMode _toThemeMode(ThemeModeOption option) {
    switch (option) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }
}

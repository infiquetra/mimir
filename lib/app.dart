import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/auth/deep_link_handler.dart';
import 'core/logging/logger.dart';
import 'core/sde/sde_providers.dart';
import 'core/sde/sde_update_providers.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_providers.dart';
import 'core/window/window_service.dart';
import 'core/window/window_types.dart';
import 'features/intel/domain/intel_alert_service.dart';
import 'features/characters/data/character_repository.dart';
import 'features/skills/data/skill_repository.dart';
import 'features/wallet/data/wallet_repository.dart';
import 'features/assets/data/asset_sync_service.dart';
import 'features/pi/data/planetary_sync_service.dart';
import 'features/industry/data/industry_sync_service.dart';
import 'features/market/data/market_sync_service.dart';

/// Provider that handles app startup initialization.
///
/// Initializes:
/// - SDE (Static Data Export) for skill names and type data
///
/// Refreshes:
/// - Character info (always refresh active character)
/// - Skill queue
/// - Wallet balance, journal, transactions, loyalty points, and PLEX
///
/// Opens windows:
/// - Onboarding (if first launch)
/// - Dashboard (if user preference is set to openDashboard)
/// - Nothing (if user preference is tray-only mode)
final startupRefreshProvider = FutureProvider<void>((ref) async {
  // Initialize SDE first so skill names are available when UI renders.
  try {
    await ref.read(sdeInitializerProvider.future);
    Log.i('STARTUP', 'SDE initialized');

    // Check for SDE updates in background (fire-and-forget).
    // This doesn't block startup - it just logs results and updates
    // state if an update is available.
    unawaited(
      ref
          .read(sdeUpdateControllerProvider.notifier)
          .checkForUpdatesInBackground(),
    );
  } catch (e, stack) {
    Log.e('STARTUP', 'SDE initialization failed', e, stack);
    // Continue - the app can function without SDE, just shows skill IDs.
  }

  // Migrate tokens from secure storage to database (one-time migration).
  // This only runs in main window and only for characters that don't
  // have tokens in the database yet.
  try {
    final tokenManager = ref.read(tokenManagerProvider);
    await tokenManager.migrateFromSecureStorage();
  } catch (e, stack) {
    Log.e('STARTUP', 'Token migration failed', e, stack);
    // Continue - migration failures shouldn't block app startup.
  }

  final characterRepo = ref.read(characterRepositoryProvider);
  final skillRepo = ref.read(skillRepositoryProvider);
  final walletRepo = ref.read(walletRepositoryProvider);
  final assetSync = ref.read(assetSyncServiceProvider);
  final piSync = ref.read(planetarySyncServiceProvider);
  final industrySync = ref.read(industrySyncServiceProvider);
  final marketSync = ref.read(marketSyncServiceProvider);

  final characters = await characterRepo.getAllCharacters();
  if (characters.isEmpty) {
    Log.i('STARTUP', 'No characters to refresh');
    return;
  }

  // Find the active character, or use the first one.
  final active = characters.firstWhere(
    (c) => c.isActive,
    orElse: () => characters.first,
  );

  Log.i('STARTUP', 'Refreshing data for ${active.name}');

  // Refresh all data types in parallel. Trained skills are included: without
  // them the Skill Catalogue and every Skill Plan render as 0% trained.
  try {
    await Future.wait([
      characterRepo.refreshCharacter(active.characterId),
      skillRepo.refreshSkillQueue(active.characterId),
      skillRepo.refreshCharacterSkills(active.characterId),
      walletRepo.refreshWalletBalance(active.characterId),
      walletRepo.refreshWalletJournal(active.characterId),
      walletRepo.refreshWalletTransactions(active.characterId),
      walletRepo.refreshLoyaltyPoints(active.characterId),
      walletRepo.refreshPlexCount(active.characterId),
      assetSync.syncAssets(active.characterId),
      piSync.syncColonies(active.characterId),
      industrySync.syncBlueprints(active.characterId),
      industrySync.syncIndustryJobs(active.characterId),
      marketSync.syncOrders(active.characterId),
      marketSync.syncPrices(),
    ]);
    Log.i('STARTUP', 'All data refreshed for ${active.name}');
  } catch (e, stack) {
    Log.e('STARTUP', 'Failed to refresh data', e, stack);
    // Don't rethrow - startup should continue even if refresh fails.
  }

  // Check startup settings and open appropriate window
  try {
    final settings = await ref.read(appSettingsProvider.future);

    if (!settings.onboardingComplete) {
      // First launch - show onboarding
      Log.i('STARTUP', 'Opening onboarding (first launch)');
      await WindowService.instance.openWindow(WindowType.onboarding);
    } else if (settings.startupBehavior == StartupBehavior.openDashboard) {
      // Open Dashboard on startup (user preference)
      Log.i('STARTUP', 'Opening Dashboard (user preference)');
      await WindowService.instance.openWindow(WindowType.dashboard);
    } else {
      // Tray only mode - do nothing
      Log.i('STARTUP', 'Tray only mode (user preference)');
    }
  } catch (e, stack) {
    Log.e('STARTUP', 'Failed to check settings', e, stack);
    // Continue - if settings check fails, just stay in tray mode
  }
});

/// The root widget of the Mimir application.
///
/// This is a minimal container for the hidden main window.
/// The actual UI is displayed in standalone sub-windows opened from the tray menu.
///
/// This widget:
/// - Initializes deep link handler for OAuth callbacks
/// - Runs startup refresh for character data
/// - Provides a minimal (hidden) 1x1 window
class MimirApp extends ConsumerWidget {
  const MimirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize deep link handler for OAuth callbacks.
    // Reading the provider causes it to be created and start listening.
    ref.watch(deepLinkHandlerProvider);

    // Refresh stale character data on app startup.
    // This runs in the background and updates characters that have
    // placeholder corporation names.
    ref.watch(startupRefreshProvider);

    // Initialize global Intel Alert Service
    ref.watch(intelAlertServiceProvider).initialize();

    // Return minimal container - the main window is hidden and never shown.
    // All actual UI happens in standalone sub-windows.
    return const SizedBox.shrink();
  }
}

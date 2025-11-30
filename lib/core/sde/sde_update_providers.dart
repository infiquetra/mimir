import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'sde_providers.dart';
import 'sde_update_service.dart';

// Re-export update service types for convenience.
export 'sde_update_service.dart'
    show
        SdeUpdateResult,
        SdeUpToDate,
        SdeUpdateAvailable,
        SdeUpdateCheckFailed,
        SdeApplyResult,
        SdeUpdateApplied,
        SdeUpdateFailed,
        SdeStatus;

/// Provider for the SDE update service.
final sdeUpdateServiceProvider = Provider<SdeUpdateService>((ref) {
  final database = ref.watch(sdeDatabaseProvider);
  return SdeUpdateService(database: database);
});

/// Provider for current SDE status (version, last check, etc.).
final sdeStatusProvider = FutureProvider<SdeStatus>((ref) async {
  final service = ref.watch(sdeUpdateServiceProvider);
  return service.getStatus();
});

/// State for the SDE update UI.
sealed class SdeUpdateUiState {
  const SdeUpdateUiState();
}

/// Initial/idle state - no update operation in progress.
class SdeUpdateIdle extends SdeUpdateUiState {
  const SdeUpdateIdle();
}

/// Currently checking for updates.
class SdeUpdateChecking extends SdeUpdateUiState {
  const SdeUpdateChecking();
}

/// Update is available.
class SdeUpdateHasUpdate extends SdeUpdateUiState {
  const SdeUpdateHasUpdate({
    required this.currentVersion,
    required this.newVersion,
    required this.skillCount,
  });

  final String? currentVersion;
  final String newVersion;
  final int skillCount;
}

/// Currently applying update.
class SdeUpdateApplying extends SdeUpdateUiState {
  const SdeUpdateApplying();
}

/// Update check or apply completed successfully.
class SdeUpdateSuccess extends SdeUpdateUiState {
  const SdeUpdateSuccess({required this.message});

  final String message;
}

/// Update check or apply failed.
class SdeUpdateError extends SdeUpdateUiState {
  const SdeUpdateError({required this.message});

  final String message;
}

/// Controller for managing SDE update state.
class SdeUpdateController extends StateNotifier<SdeUpdateUiState> {
  SdeUpdateController({
    required this.updateService,
    required this.ref,
  }) : super(const SdeUpdateIdle());

  final SdeUpdateService updateService;
  final Ref ref;

  /// Check for available updates.
  ///
  /// Updates state to reflect check progress and result.
  Future<void> checkForUpdates() async {
    state = const SdeUpdateChecking();

    final result = await updateService.checkForUpdates();

    state = switch (result) {
      SdeUpToDate(currentVersion: final v) => SdeUpdateSuccess(
          message: 'Up to date (v$v)',
        ),
      SdeUpdateAvailable(
        currentVersion: final current,
        newVersion: final newV,
        skillCount: final count
      ) =>
        SdeUpdateHasUpdate(
          currentVersion: current,
          newVersion: newV,
          skillCount: count,
        ),
      SdeUpdateCheckFailed(error: final e) => SdeUpdateError(
          message: 'Check failed: $e',
        ),
    };
  }

  /// Apply the available update.
  Future<void> applyUpdate() async {
    state = const SdeUpdateApplying();

    final result = await updateService.applyUpdate();

    state = switch (result) {
      SdeUpdateApplied(version: final v, skillCount: final count) =>
        SdeUpdateSuccess(
          message: 'Updated to v$v ($count skills)',
        ),
      SdeUpdateFailed(error: final e) => SdeUpdateError(
          message: 'Update failed: $e',
        ),
    };

    // If update was applied, invalidate SDE providers to reload data
    if (result is SdeUpdateApplied) {
      // Force SDE service to reload with fresh data
      ref.invalidate(sdeInitializerProvider);
      ref.invalidate(sdeStatusProvider);
    }
  }

  /// Reset to idle state.
  void reset() {
    state = const SdeUpdateIdle();
  }

  /// Check for updates in background (fire-and-forget).
  ///
  /// Logs result but doesn't update UI state.
  /// Use this for startup checks.
  Future<void> checkForUpdatesInBackground() async {
    try {
      final result = await updateService.checkForUpdates();

      switch (result) {
        case SdeUpToDate(currentVersion: final v):
          debugPrint('SDE: Up to date (v$v)');
        case SdeUpdateAvailable(newVersion: final v, skillCount: final count):
          debugPrint('SDE: Update available - v$v ($count skills)');
          // Optionally: Update state to notify user
          state = SdeUpdateHasUpdate(
            currentVersion: null,
            newVersion: v,
            skillCount: count,
          );
        case SdeUpdateCheckFailed(error: final e):
          debugPrint('SDE: Background check failed: $e');
      }
    } catch (e) {
      debugPrint('SDE: Background check error: $e');
    }
  }
}

/// Provider for the SDE update controller.
final sdeUpdateControllerProvider =
    StateNotifierProvider<SdeUpdateController, SdeUpdateUiState>((ref) {
  final service = ref.watch(sdeUpdateServiceProvider);
  return SdeUpdateController(
    updateService: service,
    ref: ref,
  );
});

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/eve_config.dart';
import '../../core/database/app_database.dart' show Character, isSubWindow;
import '../../core/logging/logger.dart';
import '../../features/characters/data/character_providers.dart';
import '../../features/wallet/data/wallet_repository.dart';
import 'corporation_logo.dart';
import 'faction_logo.dart';

/// Panel displaying a character portrait with info overlay.
///
/// Layout:
/// - Character portrait as background (square image, fills panel)
/// - Corporation logo in top-right corner (48px)
/// - Faction logo in bottom-left corner (48px)
/// - Info overlay at bottom with character stats:
///   - Name
///   - Birth date
///   - Wallet balance (ISK)
///   - Security status
///   - Total skill points
/// - Delete button in bottom-right corner (if callback provided)
///
/// Matches EVE Online's character sheet portrait panel design.
class CharacterPortraitPanel extends ConsumerWidget {
  /// The character to display.
  final Character character;

  /// Callback when the delete button is pressed.
  /// If null, delete button is not shown.
  final VoidCallback? onDeleteCharacter;

  const CharacterPortraitPanel({
    super.key,
    required this.character,
    this.onDeleteCharacter,
  });

  /// Returns the character portrait URL.
  String get _portraitUrl {
    return '${EveConfig.imageServerUrl}/characters/${character.characterId}/portrait?size=512';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Fetch wallet balance and total SP.
    final walletBalance = ref.watch(_walletBalanceProvider(character.characterId));
    final totalSp = ref.watch(characterTotalSpProvider(character.characterId));

    // Fetch home location.
    final clones = ref.watch(characterClonesProvider(character.characterId));
    final locationNames = ref.watch(characterCloneLocationNamesProvider(character.characterId));

    // Debug logging
    Log.d('CHAR', 'CharacterPortraitPanel: Loading portrait from $_portraitUrl');

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Character portrait (use CachedNetworkImage for main window).
          Positioned.fill(
            child: isSubWindow
                ? Image.network(
                    _portraitUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _LoadingPlaceholder(colorScheme: colorScheme);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      Log.e('CHAR', 'Failed to load character portrait (sub-window)', error, stackTrace);
                      return _ErrorPlaceholder(colorScheme: colorScheme);
                    },
                  )
                : CachedNetworkImage(
                    imageUrl: _portraitUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _LoadingPlaceholder(colorScheme: colorScheme),
                    errorWidget: (context, url, error) {
                      Log.e('CHAR', 'Failed to load character portrait (main window)', error);
                      return _ErrorPlaceholder(colorScheme: colorScheme);
                    },
                  ),
          ),
          // Corporation logo (top-right).
          Positioned(
            top: 16,
            right: 16,
            child: CorporationLogo(
              id: character.corporationId,
              size: 48,
            ),
          ),
          // Faction logo (bottom-left).
          if (character.factionId != null)
            Positioned(
              bottom: 16,
              left: 16,
              child: FactionLogo(
                factionId: character.factionId!,
                size: 48,
              ),
            ),
          // Info overlay (bottom).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _InfoOverlay(
              character: character,
              walletBalance: walletBalance,
              totalSp: totalSp,
              clones: clones,
              locationNames: locationNames,
            ),
          ),
          // Delete button (upper-left).
          if (onDeleteCharacter != null)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: IconButton.filled(
                  onPressed: onDeleteCharacter,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Remove Character',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade900.withValues(alpha: 0.7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(32, 32),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Info overlay showing character stats at the bottom of the portrait panel.
class _InfoOverlay extends StatelessWidget {
  final Character character;
  final AsyncValue<double?> walletBalance;
  final AsyncValue<int> totalSp;
  final AsyncValue<dynamic> clones;
  final AsyncValue<Map<int, String>> locationNames;

  const _InfoOverlay({
    required this.character,
    required this.walletBalance,
    required this.totalSp,
    required this.clones,
    required this.locationNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Character name.
          Text(
            character.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Stats grid.
          _StatsGrid(
            character: character,
            walletBalance: walletBalance,
            totalSp: totalSp,
            clones: clones,
            locationNames: locationNames,
          ),
        ],
      ),
    );
  }
}

/// Grid displaying character stats (birth date, wallet, security status, SP).
class _StatsGrid extends StatelessWidget {
  final Character character;
  final AsyncValue<double?> walletBalance;
  final AsyncValue<int> totalSp;
  final AsyncValue<dynamic> clones;
  final AsyncValue<Map<int, String>> locationNames;

  const _StatsGrid({
    required this.character,
    required this.walletBalance,
    required this.totalSp,
    required this.clones,
    required this.locationNames,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Wallet',
          value: walletBalance.when(
            data: (balance) => balance != null
                ? '${NumberFormat('#,##0.00').format(balance)} ISK'
                : 'No data',
            loading: () => 'Loading...',
            error: (_, __) => 'Error',
          ),
        ),
        const SizedBox(height: 6),
        _StatRow(
          icon: Icons.security_outlined,
          label: 'Security Status',
          value: character.securityStatus.toStringAsFixed(2),
        ),
        const SizedBox(height: 6),
        // Home station row
        _StatRow(
          icon: Icons.home_outlined,
          label: 'Home Station',
          value: _getHomeLocationValue(),
        ),
        const SizedBox(height: 6),
        _StatRow(
          icon: Icons.stars_outlined,
          label: 'Total SP',
          value: totalSp.when(
            data: (sp) => NumberFormat('#,###').format(sp),
            loading: () => 'Loading...',
            error: (_, __) => 'Error',
          ),
        ),
      ],
    );
  }

  /// Get the home location value, handling async states.
  String _getHomeLocationValue() {
    return clones.when(
      data: (cloneData) {
        final homeLocation = cloneData?.homeLocation;
        if (homeLocation == null) return 'Unknown';

        final locationId = homeLocation.locationId;
        if (locationId == null) return 'Unknown';

        return locationNames.when(
          data: (nameMap) => nameMap[locationId] ?? 'Unknown',
          loading: () => 'Loading...',
          error: (_, __) => 'Unknown',
        );
      },
      loading: () => 'Loading...',
      error: (_, __) => 'Unknown',
    );
  }
}

/// Single stat row with icon, label, and value.
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white70,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Loading placeholder for character render.
class _LoadingPlaceholder extends StatelessWidget {
  final ColorScheme colorScheme;

  const _LoadingPlaceholder({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: colorScheme.primary,
      ),
    );
  }
}

/// Error placeholder for character render.
class _ErrorPlaceholder extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ErrorPlaceholder({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.person_outline,
        size: 120,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    );
  }
}

/// Provider for wallet balance (read-only for this character).
final _walletBalanceProvider =
    FutureProvider.family<double?, int>((ref, characterId) async {
  final walletRepo = ref.watch(walletRepositoryProvider);
  return walletRepo.getLatestWalletBalance(characterId);
});

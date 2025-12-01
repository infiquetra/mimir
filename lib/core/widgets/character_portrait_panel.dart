import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/eve_config.dart';
import '../../core/database/app_database.dart' show Character;
import '../../features/characters/data/character_providers.dart';
import '../../features/wallet/data/wallet_repository.dart';
import 'corporation_logo.dart';
import 'faction_logo.dart';

/// Panel displaying a full-body character render with info overlay.
///
/// Layout:
/// - Full-body character render as background
/// - Corporation logo in top-right corner (48px)
/// - Faction logo in bottom-left corner (48px)
/// - Info overlay at bottom with character stats:
///   - Name
///   - Birth date
///   - Wallet balance (ISK)
///   - Security status
///   - Total skill points
///   - Skills button
///
/// Matches EVE Online's character sheet portrait panel design.
class CharacterPortraitPanel extends ConsumerWidget {
  /// The character to display.
  final Character character;

  /// Optional callback when Skills button is pressed.
  final VoidCallback? onSkillsPressed;

  const CharacterPortraitPanel({
    super.key,
    required this.character,
    this.onSkillsPressed,
  });

  /// Returns the full-body character render URL.
  String get _renderUrl {
    return '${EveConfig.imageServerUrl}/characters/${character.characterId}/render?size=512';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Fetch wallet balance and total SP.
    final walletBalance = ref.watch(_walletBalanceProvider(character.characterId));
    final totalSp = ref.watch(characterTotalSpProvider(character.characterId));

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
          // Full-body character render.
          Positioned.fill(
            child: Image.network(
              _renderUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 120,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                );
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
              onSkillsPressed: onSkillsPressed,
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
  final VoidCallback? onSkillsPressed;

  const _InfoOverlay({
    required this.character,
    required this.walletBalance,
    required this.totalSp,
    this.onSkillsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          ),
          const SizedBox(height: 12),
          // Skills button.
          if (onSkillsPressed != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSkillsPressed,
                icon: const Icon(Icons.psychology_outlined, size: 18),
                label: const Text('Skills'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: colorScheme.primary),
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
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

  const _StatsGrid({
    required this.character,
    required this.walletBalance,
    required this.totalSp,
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

/// Provider for wallet balance (read-only for this character).
final _walletBalanceProvider =
    FutureProvider.family<double?, int>((ref, characterId) async {
  final walletRepo = ref.watch(walletRepositoryProvider);
  return walletRepo.getLatestWalletBalance(characterId);
});

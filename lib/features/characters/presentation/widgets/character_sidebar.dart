import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/corporation_logo.dart';
import '../../../../core/widgets/online_indicator.dart';
import '../../data/character_providers.dart';
import '../../data/character_status_providers.dart';
import '../../../wallet/data/wallet_providers.dart';
import '../../../skills/data/skill_providers.dart';
import 'implant_row.dart';

/// Persistent character sidebar for desktop layout.
///
/// Displays:
/// - Character portrait and basic info
/// - Real-time status (online, location, ship)
/// - Quick stats (wallet, skills, implants)
///
/// Only shown on desktop (width >= 600px).
class CharacterSidebar extends ConsumerWidget {
  const CharacterSidebar({super.key});

  static const double width = 240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: EveColors.darkSurface,
        border: Border(
          right: BorderSide(
            color: EveColors.evePrimary.withAlpha(51),
            width: 1,
          ),
        ),
      ),
      child: activeCharacter.when(
        data: (character) {
          if (character == null) {
            return _buildNoCharacterState(context);
          }
          return _buildCharacterSidebar(context, ref, character.characterId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildNoCharacterState(context),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 12),
            Text(
              'No Character',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterSidebar(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCharacterHeader(context, ref, characterId),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildStatusSection(context, ref, characterId),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildQuickStatsSection(context, ref, characterId),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterHeader(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final characterAsync = ref.watch(activeCharacterProvider);
    final character = characterAsync.value;
    if (character == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      children: [
        // Portrait
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: EveColors.evePrimary.withAlpha(128),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: EveColors.evePrimary.withAlpha(51),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: character.portraitUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Name
        Text(
          character.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: EveColors.evePrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Corporation
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CorporationLogo.corporation(
              corporationId: character.corporationId,
              size: 24,
              borderRadius: 2,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                character.corporationName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // Alliance (if exists)
        if (character.allianceId != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CorporationLogo.alliance(
                allianceId: character.allianceId!,
                size: 24,
                borderRadius: 2,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  character.allianceName ?? 'Unknown Alliance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final theme = Theme.of(context);
    final onlineStatus = ref.watch(characterOnlineStatusProvider(characterId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATUS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: EveColors.evePrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // Online status
        onlineStatus.when(
          data: (status) => Row(
            children: [
              OnlineIndicator(isOnline: status.online),
              const SizedBox(width: 8),
              Text(
                status.online ? 'Online' : 'Offline',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          loading: () => _buildLoadingRow(context, 'Status'),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildQuickStatsSection(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final theme = Theme.of(context);
    final walletBalance = ref.watch(walletBalanceProvider);
    final skillQueue = ref.watch(skillQueueProvider);
    final implants = ref.watch(characterImplantsProvider(characterId));

    final numberFormat = NumberFormat.decimalPattern();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK STATS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: EveColors.evePrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // Wallet balance
        walletBalance.when(
          data: (balance) {
            if (balance == null) {
              return _buildStatRow(
                context,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Wallet',
                value: 'Unknown',
              );
            }
            return _buildStatRow(
              context,
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet',
              value: '${numberFormat.format(balance.toInt())} ISK',
            );
          },
          loading: () => _buildLoadingRow(context, 'Wallet'),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 8),

        // Skill queue
        skillQueue.when(
          data: (skills) {
            if (skills.isEmpty) {
              return _buildStatRow(
                context,
                icon: Icons.school_outlined,
                label: 'Training',
                value: 'Empty',
              );
            }
            final firstSkill = skills.first;
            if (firstSkill.finishDate == null) {
              return _buildStatRow(
                context,
                icon: Icons.school_outlined,
                label: 'Training',
                value: 'Paused',
              );
            }
            final remaining = firstSkill.finishDate!.difference(DateTime.now());
            final daysRemaining = remaining.inDays;
            final hoursRemaining = remaining.inHours % 24;

            return _buildStatRow(
              context,
              icon: Icons.school_outlined,
              label: 'Training',
              value: '${daysRemaining}d ${hoursRemaining}h',
            );
          },
          loading: () => _buildLoadingRow(context, 'Training'),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // Implants
        implants.when(
          data: (implantMap) {
            if (implantMap.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Implants',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'None active',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              );
            }

            // Convert Map<int, String> to Map<int, int> (slot -> typeId)
            // The implantMap from the provider is typeId -> name
            // We need to infer slot numbers from the typeIds
            final implantSlots = <int, int>{};
            int slot = 1;
            for (final typeId in implantMap.keys) {
              if (slot <= 10) {
                implantSlots[slot] = typeId;
                slot++;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Implants',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ImplantRow(
                  implants: implantSlots,
                  iconSize: 20,
                  spacing: 2,
                ),
              ],
            );
          },
          loading: () => _buildLoadingRow(context, 'Implants'),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: EveColors.evePrimary.withAlpha(204),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingRow(BuildContext context, String label) {
    return Row(
      children: [
        const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

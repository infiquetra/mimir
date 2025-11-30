import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/widgets/character_avatar.dart';
import '../../../data/fleet_providers.dart';
import '../dashboard_card.dart';

/// Dashboard card showing real-time fleet status for all characters.
///
/// Displays:
/// - Online/offline count across all characters
/// - Per-character breakdown with location, ship, and status
/// - Security status color-coding (highsec green, lowsec yellow, nullsec red)
/// - Last seen time for offline characters
///
/// Handles loading, error, and empty states gracefully.
/// Missing OAuth scopes are handled with helpful error messages.
class FleetStatusCard extends ConsumerWidget {
  const FleetStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleetStatusAsync = ref.watch(allCharacterFleetStatusProvider);

    return DashboardCard(
      title: 'FLEET STATUS',
      icon: Icons.groups_outlined,
      glowColor: EveColors.evePrimary,
      isLoading: fleetStatusAsync.isLoading,
      errorMessage: fleetStatusAsync.hasError
          ? _getErrorMessage(fleetStatusAsync.error)
          : null,
      onRetry: () => ref.invalidate(allCharacterFleetStatusProvider),
      child: fleetStatusAsync.when(
        data: (status) => _buildContent(context, ref, status),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  String _getErrorMessage(Object? error) {
    if (error == null) return 'Failed to load fleet status';

    final errorStr = error.toString();
    if (errorStr.contains('403') || errorStr.contains('scope')) {
      return 'Missing permissions. Please re-authenticate to grant location scopes.';
    }

    return 'Failed to load fleet status from ESI';
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AggregateFleetStatus status,
  ) {
    if (status.totalCharacters == 0) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Online/Offline summary
        _buildSummary(context, status),

        const SizedBox(height: 24),

        // Section header - CHARACTERS
        Text(
          'CHARACTERS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withAlpha(179),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 12),

        // Per-character status
        ...status.characterStatuses.map((charStatus) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCharacterRow(context, charStatus),
          );
        }),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, AggregateFleetStatus status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: EveColors.evePrimary.withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Online count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: EveColors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ONLINE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withAlpha(179),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${status.onlineCharacters}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: EveColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withAlpha(26),
          ),
          const SizedBox(width: 16),

          // Offline count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: Colors.white.withAlpha(128),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'OFFLINE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withAlpha(179),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${status.offlineCharacters}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white.withAlpha(179),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withAlpha(26),
          ),
          const SizedBox(width: 16),

          // Total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withAlpha(179),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${status.totalCharacters}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: EveColors.evePrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterRow(BuildContext context, CharacterStatusData status) {
    // Determine status indicator color.
    Color statusColor;
    if (!status.isOnline) {
      statusColor = Colors.white.withAlpha(128);
    } else if (status.isInDangerousSpace) {
      statusColor = EveColors.error; // Red for dangerous space
    } else {
      statusColor = EveColors.success; // Green for safe space
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Character avatar with status indicator
          Stack(
            children: [
              CharacterAvatar(
                portraitUrl: '', // Will use placeholder
                size: CharacterAvatarSize.small,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: EveColors.darkSurfaceVariant,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Character info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Character name with online indicator
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.characterName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!status.isOnline) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OFFLINE',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withAlpha(179),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                if (status.isOnline) ...[
                  // Location (for online characters)
                  if (status.solarSystemName != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: _getSecurityStatusColor(status.securityStatus),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            status.solarSystemName!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _getSecurityStatusColor(
                                          status.securityStatus),
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (status.securityStatus != null)
                          Text(
                            '(${status.securityStatus!.toStringAsFixed(1)})',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _getSecurityStatusColor(
                                          status.securityStatus),
                                      fontSize: 11,
                                    ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Ship (for online characters)
                  if (status.shipTypeName != null)
                    Row(
                      children: [
                        Icon(
                          Icons.rocket_launch_outlined,
                          size: 14,
                          color: Colors.white.withAlpha(179),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            status.shipTypeName!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withAlpha(179),
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  // Last seen (for offline characters)
                  if (status.lastLogout != null)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: Colors.white.withAlpha(128),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Last seen ${timeago.format(status.lastLogout!)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withAlpha(128),
                                  ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 48,
              color: Colors.white.withAlpha(77),
            ),
            const SizedBox(height: 12),
            Text(
              'No Fleet Data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add characters to see fleet status',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(128),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getSecurityStatusColor(double? secStatus) {
    if (secStatus == null) return Colors.white.withAlpha(179);

    if (secStatus >= 0.5) {
      return EveColors.success; // High sec (green)
    } else if (secStatus > 0.0) {
      return EveColors.warning; // Low sec (yellow/orange)
    } else {
      return EveColors.error; // Null sec (red)
    }
  }
}

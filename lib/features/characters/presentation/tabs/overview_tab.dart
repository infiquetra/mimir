import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_spacing.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../../../core/widgets/character_avatar.dart';
import '../../../../core/widgets/corporation_logo.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/online_indicator.dart';
import '../../data/character_providers.dart';
import '../../data/character_status_providers.dart';
import '../widgets/implant_row.dart';

/// RIFT-style overview tab showing character vitals at a glance.
///
/// Layout:
/// - Character vitals card (portrait, name, location, ship, online status)
/// - Active clone summary card
/// - Top 3 standings card
///
/// Compact, information-dense design inspired by RIFT.
class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return activeCharacter.when(
      data: (character) {
        if (character == null) {
          return _buildNoCharacterState(context);
        }
        return _buildOverview(context, ref, character.characterId);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading character: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No Character Selected',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a character to view details',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context, WidgetRef ref, int characterId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(EveSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVitalsCard(context, ref, characterId),
          SizedBox(height: EveSpacing.lg),
          _buildActiveCloneCard(context, ref, characterId),
          SizedBox(height: EveSpacing.lg),
          _buildStandingsCard(context, ref, characterId),
        ],
      ),
    );
  }

  Widget _buildVitalsCard(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final characterAsync = ref.watch(activeCharacterProvider);
    final character = characterAsync.value;
    final onlineStatus = ref.watch(characterOnlineStatusProvider(characterId));
    final attributes = ref.watch(characterAttributesProvider(characterId));

    return EveCard(
      glowColor: EveColors.photonBlue,
      glowIntensity: 0.3,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact portrait (80px hero size)
          if (character != null)
            CharacterAvatar(
              portraitUrl: character.portraitUrl,
              size: CharacterAvatarSize.hero,
            ),

          SizedBox(width: EveSpacing.lg),

          // Vitals
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and online status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        character?.name ?? 'Unknown',
                        style: EveTypography.titleLarge(
                          color: EveColors.photonBlue,
                        ),
                      ),
                    ),
                    onlineStatus.when(
                      data: (status) =>
                          OnlineIndicator(isOnline: status.online, size: 10),
                      loading: () => SizedBox(width: 10, height: 10),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),

                SizedBox(height: EveSpacing.sm),

                // Corporation
                if (character != null)
                  Row(
                    children: [
                      CorporationLogo.corporation(
                        corporationId: character.corporationId,
                        size: EveSpacing.iconSm,
                        borderRadius: 2,
                      ),
                      SizedBox(width: EveSpacing.sm),
                      Expanded(
                        child: Text(
                          character.corporationName,
                          style: EveTypography.bodySmall(
                            color: EveColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                // Alliance (if exists)
                if (character?.allianceId != null) ...[
                  SizedBox(height: EveSpacing.xs),
                  Row(
                    children: [
                      CorporationLogo.alliance(
                        allianceId: character!.allianceId!,
                        size: EveSpacing.iconSm,
                        borderRadius: 2,
                      ),
                      SizedBox(width: EveSpacing.sm),
                      Expanded(
                        child: Text(
                          character.allianceName ?? 'Unknown Alliance',
                          style: EveTypography.bodySmall(
                            color: EveColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: EveSpacing.md),

                // Attributes (inline, compact)
                attributes.when(
                  data: (attrs) => Text(
                    'INT ${attrs.intelligence} • MEM ${attrs.memory} • PER ${attrs.perception} • WIL ${attrs.willpower} • CHA ${attrs.charisma}',
                    style: EveTypography.labelSmall(
                      color: EveColors.textTertiary,
                    ),
                  ),
                  loading: () => SizedBox(
                    height: 16,
                    child: Center(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCloneCard(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final theme = Theme.of(context);
    final clones = ref.watch(characterClonesProvider(characterId));
    final implants = ref.watch(characterImplantsProvider(characterId));
    final locationNames = ref.watch(
      characterCloneLocationNamesProvider(characterId),
    );

    return Card(
      elevation: 0,
      color: EveColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: EveColors.evePrimary.withAlpha(51), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_pin_outlined,
                  size: 20,
                  color: EveColors.evePrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Clone',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: EveColors.evePrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Home location
            clones.when(
              data: (cloneData) {
                final home = cloneData.homeLocation;
                final locationId = home.locationId;

                return locationNames.when(
                  data: (nameMap) {
                    final locationName =
                        nameMap[locationId] ?? 'Unknown location';
                    return Row(
                      children: [
                        Icon(
                          home.locationType == 'station'
                              ? Icons.location_city_outlined
                              : Icons.place_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Home: $locationName',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => Row(
                    children: [
                      Icon(
                        home.locationType == 'station'
                            ? Icons.location_city_outlined
                            : Icons.place_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ),
                  error: (_, _) => Row(
                    children: [
                      Icon(
                        home.locationType == 'station'
                            ? Icons.location_city_outlined
                            : Icons.place_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Home: Unknown location',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 20,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // Active implants
            implants.when(
              data: (implantMap) {
                if (implantMap.isEmpty) {
                  return Text(
                    'No implants active',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }

                // Convert Map<int, String> to Map<int, int> (slot -> typeId)
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
                      'Implants:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ImplantRow(
                      implants: implantSlots,
                      iconSize: 28,
                      spacing: 4,
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 32,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingsCard(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final theme = Theme.of(context);
    final standings = ref.watch(characterStandingsProvider(characterId));

    return Card(
      elevation: 0,
      color: EveColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: EveColors.evePrimary.withAlpha(51), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  size: 20,
                  color: EveColors.evePrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top Standings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: EveColors.evePrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            standings.when(
              data: (standingsList) {
                if (standingsList.isEmpty) {
                  return Text(
                    'No standings data available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }

                // Show top 3 standings (sorted by absolute value)
                final top3 = standingsList.take(3).toList();

                return Column(
                  children: top3.map((standing) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              standing.name,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStandingBadge(context, standing.standing),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => Text(
                'Failed to load standings',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingBadge(BuildContext context, double standing) {
    final theme = Theme.of(context);
    Color color;
    if (standing >= 5.0) {
      color = Colors.blue.shade700;
    } else if (standing >= 0.0) {
      color = Colors.green.shade700;
    } else if (standing >= -5.0) {
      color = Colors.orange.shade700;
    } else {
      color = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        standing.toStringAsFixed(1),
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

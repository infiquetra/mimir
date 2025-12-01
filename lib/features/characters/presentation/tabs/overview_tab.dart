import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart' show isSubWindow;
import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/corporation_logo.dart';
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(153),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVitalsCard(context, ref, characterId),
          const SizedBox(height: 16),
          _buildActiveCloneCard(context, ref, characterId),
          const SizedBox(height: 16),
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
    final theme = Theme.of(context);
    final characterAsync = ref.watch(activeCharacterProvider);
    final character = characterAsync.value;
    final onlineStatus = ref.watch(characterOnlineStatusProvider(characterId));
    final attributes = ref.watch(characterAttributesProvider(characterId));

    return Card(
      elevation: 0,
      color: EveColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: EveColors.evePrimary.withAlpha(51),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portrait
            if (character != null)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: EveColors.evePrimary.withAlpha(128),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: EveColors.evePrimary.withAlpha(51),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildPortraitImage(context, character.portraitUrl),
                ),
              ),

            const SizedBox(width: 16),

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
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: EveColors.evePrimary,
                          ),
                        ),
                      ),
                      onlineStatus.when(
                        data: (status) => OnlineIndicator(
                          isOnline: status.online,
                          size: 12,
                        ),
                        loading: () => const SizedBox(width: 12, height: 12),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Corporation
                  if (character != null)
                    Row(
                      children: [
                        CorporationLogo.corporation(
                          corporationId: character.corporationId,
                          size: 24,
                          borderRadius: 2,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            character.corporationName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Alliance (if exists)
                  if (character?.allianceId != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CorporationLogo.alliance(
                          allianceId: character!.allianceId!,
                          size: 24,
                          borderRadius: 2,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            character.allianceName ?? 'Unknown Alliance',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Attributes
                  attributes.when(
                    data: (attrs) => Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildAttributeChip(
                          context,
                          'INT',
                          attrs.intelligence.toString(),
                          Icons.psychology_outlined,
                        ),
                        _buildAttributeChip(
                          context,
                          'MEM',
                          attrs.memory.toString(),
                          Icons.storage_outlined,
                        ),
                        _buildAttributeChip(
                          context,
                          'PER',
                          attrs.perception.toString(),
                          Icons.visibility_outlined,
                        ),
                        _buildAttributeChip(
                          context,
                          'WIL',
                          attrs.willpower.toString(),
                          Icons.favorite_border,
                        ),
                        _buildAttributeChip(
                          context,
                          'CHA',
                          attrs.charisma.toString(),
                          Icons.chat_bubble_outline,
                        ),
                      ],
                    ),
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
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant.withAlpha(128),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: EveColors.evePrimary.withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: EveColors.evePrimary,
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
    final locationNames = ref.watch(characterCloneLocationNamesProvider(characterId));

    return Card(
      elevation: 0,
      color: EveColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: EveColors.evePrimary.withAlpha(51),
          width: 1,
        ),
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
                if (cloneData.homeLocation != null) {
                  final home = cloneData.homeLocation!;
                  final locationId = home.locationId;

                  return locationNames.when(
                    data: (nameMap) {
                      final locationName = locationId != null
                          ? nameMap[locationId] ?? 'Location $locationId'
                          : 'Unknown';
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
                    error: (_, __) => Row(
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
                            'Home: Location ${home.locationId}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Text(
                  'No home location set',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                    fontStyle: FontStyle.italic,
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
              error: (_, __) => const SizedBox.shrink(),
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
              error: (_, __) => const SizedBox.shrink(),
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
        side: BorderSide(
          color: EveColors.evePrimary.withAlpha(51),
          width: 1,
        ),
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
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => Text(
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

  /// Builds character portrait image with isSubWindow awareness.
  ///
  /// Uses [Image.network] for sub-windows (since [CachedNetworkImage] uses
  /// path_provider which isn't available in sub-window isolates).
  Widget _buildPortraitImage(BuildContext context, String portraitUrl) {
    final theme = Theme.of(context);
    final placeholder = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 60,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    // Use Image.network for sub-windows to avoid path_provider issues.
    if (isSubWindow) {
      Log.d('OVERVIEW', 'Using Image.network for portrait (sub-window context)');
      return Image.network(
        portraitUrl,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder;
        },
        errorBuilder: (context, error, stackTrace) {
          Log.e('OVERVIEW', 'Failed to load portrait: $portraitUrl', error, stackTrace);
          return placeholder;
        },
      );
    }

    // Use CachedNetworkImage for main window (disk caching available).
    return CachedNetworkImage(
      imageUrl: portraitUrl,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) {
        Log.e('OVERVIEW', 'Failed to load cached portrait: $portraitUrl', error, null);
        return placeholder;
      },
    );
  }
}

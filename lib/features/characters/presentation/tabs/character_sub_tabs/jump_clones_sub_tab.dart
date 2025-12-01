import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../data/character_providers.dart';
import '../../../data/character_status_providers.dart';
import '../../widgets/clone_card.dart';

/// Jump Clones sub-tab showing all character jump clones.
///
/// Displays:
/// - Home clone location
/// - List of all jump clones with locations and implants
/// - Last clone jump date
/// - Last station change date
class JumpClonesSubTab extends ConsumerWidget {
  const JumpClonesSubTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return activeCharacter.when(
      data: (character) {
        if (character == null) {
          return _buildNoCharacterState(context);
        }
        return _buildClonesView(context, ref, character.characterId);
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
        ],
      ),
    );
  }

  Widget _buildClonesView(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final theme = Theme.of(context);
    final clones = ref.watch(characterClonesProvider(characterId));

    return clones.when(
      data: (cloneData) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clone activity card
              if (cloneData.lastCloneJumpDate != null ||
                  cloneData.lastStationChangeDate != null)
                Card(
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
                              Icons.history_outlined,
                              size: 20,
                              color: EveColors.evePrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Clone Activity',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: EveColors.evePrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (cloneData.lastCloneJumpDate != null)
                          _buildActivityRow(
                            context,
                            'Last Clone Jump',
                            cloneData.lastCloneJumpDate!,
                          ),
                        if (cloneData.lastStationChangeDate != null) ...[
                          const SizedBox(height: 8),
                          _buildActivityRow(
                            context,
                            'Last Station Change',
                            cloneData.lastStationChangeDate!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              if (cloneData.lastCloneJumpDate != null ||
                  cloneData.lastStationChangeDate != null)
                const SizedBox(height: 16),

              // Home clone card
              Card(
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
                            Icons.home_outlined,
                            size: 20,
                            color: EveColors.evePrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Home Clone',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: EveColors.evePrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (cloneData.homeLocation != null)
                        Row(
                          children: [
                            Icon(
                              cloneData.homeLocation!.locationType == 'station'
                                  ? Icons.location_city_outlined
                                  : Icons.place_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Location ID: ${cloneData.homeLocation!.locationId}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'No home location set',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Jump clones header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.content_copy_outlined,
                      size: 20,
                      color: EveColors.evePrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Jump Clones',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: EveColors.evePrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: EveColors.evePrimary.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cloneData.jumpClones.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: EveColors.evePrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Jump clones list
              if (cloneData.jumpClones.isEmpty)
                Card(
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
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No jump clones available',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...cloneData.jumpClones.map((clone) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CloneCard(
                      clone: clone,
                      locationName: 'Location ${clone.locationId}',
                      showImplants: true,
                      compact: false,
                    ),
                  );
                }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load clones',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityRow(
    BuildContext context,
    String label,
    DateTime date,
  ) {
    final theme = Theme.of(context);
    final formatter = DateFormat('MMM d, yyyy HH:mm');

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          formatter.format(date.toLocal()),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: EveColors.evePrimary.withAlpha(204),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

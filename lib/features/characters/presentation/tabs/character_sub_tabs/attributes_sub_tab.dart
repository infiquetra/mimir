import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/widgets/attribute_bar.dart';
import '../../../data/character_providers.dart';
import '../../../data/character_status_providers.dart';
import '../../widgets/implant_row.dart';

/// Attributes sub-tab showing detailed character attributes.
///
/// Displays:
/// - 5 core attributes (INT, MEM, PER, WIL, CHA) with progress bars
/// - Active implants affecting attributes
/// - Bonus from implants (if applicable)
class AttributesSubTab extends ConsumerWidget {
  const AttributesSubTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return activeCharacter.when(
      data: (character) {
        if (character == null) {
          return _buildNoCharacterState(context);
        }
        return _buildAttributesView(context, ref, character.characterId);
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

  Widget _buildAttributesView(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final theme = Theme.of(context);
    final attributes = ref.watch(characterAttributesProvider(characterId));
    final implants = ref.watch(characterImplantsProvider(characterId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Attributes card
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
                        Icons.analytics_outlined,
                        size: 20,
                        color: EveColors.evePrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Character Attributes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: EveColors.evePrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Attributes
                  attributes.when(
                    data: (attrs) => Column(
                      children: [
                        AttributeBar(
                          name: 'Intelligence',
                          value: attrs.intelligence,
                          icon: Icons.psychology_outlined,
                          color: Colors.blue.shade600,
                        ),
                        AttributeBar(
                          name: 'Memory',
                          value: attrs.memory,
                          icon: Icons.storage_outlined,
                          color: Colors.purple.shade600,
                        ),
                        AttributeBar(
                          name: 'Perception',
                          value: attrs.perception,
                          icon: Icons.visibility_outlined,
                          color: Colors.green.shade600,
                        ),
                        AttributeBar(
                          name: 'Willpower',
                          value: attrs.willpower,
                          icon: Icons.favorite_border,
                          color: Colors.red.shade600,
                        ),
                        AttributeBar(
                          name: 'Charisma',
                          value: attrs.charisma,
                          icon: Icons.chat_bubble_outline,
                          color: Colors.orange.shade600,
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Failed to load attributes: $error',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Implants card
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
                        Icons.memory_outlined,
                        size: 20,
                        color: EveColors.evePrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Active Implants',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: EveColors.evePrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Implants
                  implants.when(
                    data: (implantMap) {
                      if (implantMap.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No implants currently active',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
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
                          ImplantRow(
                            implants: implantSlots,
                            implantNames: implantMap,
                            iconSize: 40,
                            spacing: 8,
                            showSlotNumbers: true,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${implantMap.length} implant${implantMap.length != 1 ? 's' : ''} active',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Failed to load implants: $error',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

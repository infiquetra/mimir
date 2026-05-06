import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';
import '../data/pi_providers.dart';
import 'widgets/colony_card.dart';

class PiOverviewScreen extends ConsumerStatefulWidget {
  const PiOverviewScreen({super.key});

  @override
  ConsumerState<PiOverviewScreen> createState() => _PiOverviewScreenState();
}

class _PiOverviewScreenState extends ConsumerState<PiOverviewScreen> {
  int? _selectedCharacterId;

  @override
  void initState() {
    super.initState();
    Log.d('PI', 'PiOverviewScreen.initState()');
  }

  @override
  void dispose() {
    Log.d('PI', 'PiOverviewScreen.dispose()');
    super.dispose();
  }

  Future<void> _refresh() async {
    final activeChar = ref.read(activeCharacterProvider).value;
    final characterId = _selectedCharacterId ?? activeChar?.characterId;
    if (characterId != null) {
      await ref.read(piSyncProvider.notifier).sync(characterId);
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.d('PI',
        'PiOverviewScreen.build() - selectedCharacterId: $_selectedCharacterId');
    final charactersAsync = ref.watch(allCharactersProvider);
    final activeCharacterAsync = ref.watch(activeCharacterProvider);
    final syncState = ref.watch(piSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planetary Industry'),
        centerTitle: false,
        actions: [
          if (syncState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          charactersAsync.when(
            data: (characters) => _buildCharacterFilter(characters),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SpaceBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: _buildColonyGrid(_selectedCharacterId),
        ),
      ),
    );
  }

  Widget _buildCharacterFilter(List<Character> characters) {
    if (characters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedCharacterId,
          hint: const Text('All Characters'),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          dropdownColor: EveColors.darkSurfaceElevated,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          onChanged: (value) {
            Log.i('PI', 'Character filter changed to: $value');
            setState(() => _selectedCharacterId = value);
          },
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All Characters'),
            ),
            ...characters.map((c) => DropdownMenuItem<int?>(
                  value: c.characterId,
                  child: Text(c.name),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildColonyGrid(int? filterCharacterId) {
    Log.d('PI', 'Building colony grid with filter: $filterCharacterId');

    final coloniesAsync = filterCharacterId == null
        ? ref.watch(allColoniesProvider)
        : ref.watch(coloniesProvider(filterCharacterId));

    return coloniesAsync.when(
      data: (colonies) {
        if (colonies.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: EmptyState(
                icon: Icons.public_off_outlined,
                heading: 'No Colonies Found',
                description: filterCharacterId == null
                    ? 'None of your characters have active PI colonies.'
                    : 'This character has no active PI colonies.',
                action: ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Refresh from ESI'),
                ),
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 450,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            mainAxisExtent: 220,
          ),
          itemCount: colonies.length,
          itemBuilder: (context, index) {
            final colony = colonies[index];
            return ColonyCard(
              colony: colony,
              onTap: () {
                Log.i('PI', 'ColonyCard tapped: ${colony.planetName}');
                // TODO: Navigate to colony details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Details for ${colony.planetName} coming soon!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        Log.e('PI', 'Failed to load colonies', err, stack);
        return Center(child: Text('Error: $err'));
      },
    );
  }
}

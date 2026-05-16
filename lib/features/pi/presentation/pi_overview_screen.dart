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
  bool _showAllCharacters = false;

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
    if (_showAllCharacters) {
      final characters = ref.read(allCharactersProvider).value ?? [];
      for (final char in characters) {
        await ref.read(piSyncProvider.notifier).sync(char.characterId);
      }
    } else if (activeChar != null) {
      await ref.read(piSyncProvider.notifier).sync(activeChar.characterId);
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.d('PI', 'PiOverviewScreen.build() - showAllCharacters: $_showAllCharacters');
    final syncState = ref.watch(piSyncProvider);
    final activeChar = ref.watch(activeCharacterProvider).value;
    
    final int? filterCharacterId = _showAllCharacters ? null : activeChar?.characterId;

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
          _buildAllCharactersToggle(),
          const SizedBox(width: 16),
        ],
      ),
      body: SpaceBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: _buildColonyGrid(filterCharacterId),
        ),
      ),
    );
  }

  Widget _buildAllCharactersToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _showAllCharacters ? EveColors.photonBlue.withOpacity(0.2) : EveColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _showAllCharacters ? EveColors.photonBlue : Colors.white.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _showAllCharacters = !_showAllCharacters;
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showAllCharacters ? Icons.group : Icons.person,
              size: 20,
              color: _showAllCharacters ? EveColors.photonBlue : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'All Characters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _showAllCharacters ? EveColors.photonBlue : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColonyGrid(int? filterCharacterId) {
    Log.d('PI', 'Building colony grid with filter: $filterCharacterId');

    final activeChar = ref.watch(activeCharacterProvider).value;

    if (filterCharacterId == null && !_showAllCharacters && activeChar == null) {
      return Center(
        child: EmptyState(
          icon: Icons.person_off_outlined,
          heading: 'No Character Selected',
          description: 'Select a character or enable "All Characters" to view PI.',
          action: ElevatedButton(
            onPressed: () => setState(() => _showAllCharacters = true),
            child: const Text('View All Characters'),
          ),
        ),
      );
    }

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
                // Navigate to colony details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Details for ${colony.planetName} coming soon!'),
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

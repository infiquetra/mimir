import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';
import '../data/models/colony.dart';
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

  @override
  Widget build(BuildContext context) {
    Log.d('PI', 'PiOverviewScreen.build() - selectedCharacterId: $_selectedCharacterId');
    final charactersAsync = ref.watch(allCharactersProvider);
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planetary Industry'),
        centerTitle: false,
        actions: [
          charactersAsync.when(
            data: (characters) => _buildCharacterFilter(characters),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SpaceBackground(
        child: activeCharacterAsync.when(
          data: (activeChar) {
            final currentId = _selectedCharacterId ?? activeChar?.characterId;
            return _buildColonyGrid(currentId);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) {
            Log.e('PI', 'Failed to load active character', err, stack);
            return Center(child: Text('Error: $err'));
          },
        ),
      ),
    );
  }

  Widget _buildCharacterFilter(List<dynamic> characters) {
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
    // This will eventually come from a colonyProvider
    final colonies = _getMockColonies(filterCharacterId);

    if (colonies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.public_off_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Colonies Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              filterCharacterId == null
                  ? 'None of your characters have active PI colonies.'
                  : 'This character has no active PI colonies.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
            ),
          ],
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
        return ColonyCard(
          colony: colonies[index],
          onTap: () {
            Log.i('PI', 'ColonyCard tapped: ${colonies[index].planetName}');
            // TODO: Navigate to colony details
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Details for ${colonies[index].planetName} coming soon!'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }

  List<Colony> _getMockColonies(int? filterCharacterId) {
    final now = DateTime.now();
    final allMock = [
      Colony(
        planetId: 40000001,
        planetName: 'Jita IV - Moon 4',
        planetType: 'Temperate',
        ownerId: 1, // Assume 1 is an ID
        lastUpdate: now,
        upgradeLevel: 5,
        numPins: 12,
        pins: [
          Pin(
            pinId: 101,
            typeId: 1, // Command Center
            latitude: 0,
            longitude: 0,
            installDate: now,
          ),
          Pin(
            pinId: 102,
            typeId: 2, // Extractor
            latitude: 10,
            longitude: 10,
            installDate: now,
            extractorDetails: const Extractor(
              productId: 2393, // Noble Metals
              productName: 'Noble Metals',
              quantityPerCycle: 4500,
              cycleTime: 3600,
              headCount: 10,
            ),
          ),
        ],
      ),
      Colony(
        planetId: 40000002,
        planetName: 'Amarr VIII',
        planetType: 'Barren',
        ownerId: 1,
        lastUpdate: now,
        upgradeLevel: 4,
        numPins: 8,
        pins: [
          Pin(
            pinId: 201,
            typeId: 1,
            latitude: 0,
            longitude: 0,
            installDate: now,
          ),
          Pin(
            pinId: 202,
            typeId: 2,
            latitude: 10,
            longitude: 10,
            installDate: now,
            extractorDetails: const Extractor(
              productId: 2390, // Reactive Metals
              productName: 'Reactive Metals',
              quantityPerCycle: 3200,
              cycleTime: 3600,
              headCount: 8,
            ),
          ),
        ],
      ),
      Colony(
        planetId: 40000003,
        planetName: 'Dodixie VI',
        planetType: 'Oceanic',
        ownerId: 2, // Another character
        lastUpdate: now,
        upgradeLevel: 3,
        numPins: 6,
        pins: [
          Pin(
            pinId: 301,
            typeId: 1,
            latitude: 0,
            longitude: 0,
            installDate: now,
          ),
        ],
      ),
    ];

    if (filterCharacterId == null) return allMock;
    
    // In a real app, ownerId would match characterId
    // For mock, we'll just check if it's the first or second mock character
    // This logic is just for demonstration
    if (filterCharacterId == 1) return allMock.where((c) => c.ownerId == 1).toList();
    if (filterCharacterId == 2) return allMock.where((c) => c.ownerId == 2).toList();
    
    // Fallback if character ID doesn't match our hardcoded mocks
    return allMock.isEmpty ? [] : [allMock.first];
  }
}

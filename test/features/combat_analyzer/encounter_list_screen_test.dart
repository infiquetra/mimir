import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/presentation/encounter_list_screen.dart';

void main() {
  group('EncounterListScreen', () {
    testWidgets('renders UTC AAR titles and cached AAR marker', (tester) async {
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Hobgoblin II - Hits',
      ]).single.copyWith(characterId: 42);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rawEncountersProvider.overrideWith((ref) async => [encounter]),
            combatAarStatusesProvider.overrideWith(
              (ref) async => {encounter.id: CombatAarStatus.ready},
            ),
            activeCharacterProvider.overrideWith(
              (ref) => Stream.value(_testCharacter()),
            ),
          ],
          child: const MaterialApp(home: EncounterListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-05-20 20:00 UTC Pilot - AAR'), findsOneWidget);
      expect(find.text('AAR Ready'), findsOneWidget);
    });
  });
}

Character _testCharacter() {
  final now = DateTime.utc(2026, 5, 20);
  return Character(
    characterId: 42,
    name: 'Pilot',
    corporationId: 1,
    corporationName: 'Corp',
    securityStatus: 0,
    portraitUrl: '',
    tokenExpiry: now,
    lastUpdated: now,
    isActive: true,
  );
}

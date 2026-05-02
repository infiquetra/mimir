import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/characters/presentation/widgets/clone_card.dart';

void main() {
  group('CloneCard Golden Tests', () {
    testGoldens('CloneCard renders correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario('With Implants', CloneCard(
          clone: JumpClone(
            jumpCloneId: 1,
            locationId: 10000001,
            locationType: 'station',
            implants: [1, 2, 3],
            name: 'Test Clone',
          ),
          locationName: 'Jita IV - Moon 4 - Caldari Navy Assembly Plant',
          implantNames: {
            1: 'Ocular Filter - Basic',
            2: 'Memory Augmentation - Basic',
            3: 'Neural Boost - Basic',
          },
        ))
        ..addScenario('Without Implants', CloneCard(
          clone: JumpClone(
            jumpCloneId: 2,
            locationId: 10000002,
            locationType: 'station',
            implants: [],
            name: 'Empty Clone',
          ),
          locationName: 'Amarr VIII (Oris) - Emperor Family Academy',
        ))
        ..addScenario('Compact View', CloneCard(
          clone: JumpClone(
            jumpCloneId: 3,
            locationId: 10000003,
            locationType: 'structure',
            implants: [1],
          ),
          locationName: 'Citadel - Test',
          compact: true,
        ));

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'clone_card_states');
    });
  });
}

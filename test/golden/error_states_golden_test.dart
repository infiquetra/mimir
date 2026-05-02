import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mimir/core/widgets/eve_skill_icon.dart';
import 'package:mimir/core/widgets/eve_type_icon.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  group('Icon Error Fallbacks (Golden Tests)', () {
    testGoldens('EveSkillIcon error state renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        final builder = GoldenBuilder.grid(columns: 3, widthToHeightRatio: 1)
          ..addScenario('Small (32)', const EveSkillIcon(typeId: -1, size: 32, useCache: false))
          ..addScenario('Medium (64)', const EveSkillIcon(typeId: -1, size: 64, useCache: false))
          ..addScenario('Large (128)', const EveSkillIcon(typeId: -1, size: 128, useCache: false));

        await tester.pumpWidgetBuilder(builder.build());
        await tester.pump(const Duration(milliseconds: 100));
        await screenMatchesGolden(tester, 'eve_skill_icon_error', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 100));
        });
      });
    });

    testGoldens('EveTypeIcon error state renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        final builder = GoldenBuilder.grid(columns: 3, widthToHeightRatio: 1)
          ..addScenario('Small (32)', const EveTypeIcon(typeId: -1, size: 32))
          ..addScenario('Medium (64)', const EveTypeIcon(typeId: -1, size: 64))
          ..addScenario('Large (128)', const EveTypeIcon(typeId: -1, size: 128));

        await tester.pumpWidgetBuilder(builder.build());
        await tester.pump(const Duration(milliseconds: 100));
        await screenMatchesGolden(tester, 'eve_type_icon_error', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 100));
        });
      });
    });
  });
}

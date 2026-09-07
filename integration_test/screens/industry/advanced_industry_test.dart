import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/industry/presentation/industry_overview_screen.dart';

import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Industry Integration Tests', () {
    testWidgets(
      'TC-IND-001: Renders all advanced industry tabs without errors',
      (tester) async {
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const IndustryOverviewScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // We start on Industry Jobs tab
        expect(find.text('Industry Jobs'), findsWidgets);

        // Tap Invention tab
        await tester.tap(find.text('Invention'));
        await tester.pumpAndSettle();
        expect(find.text('INVENTION CHANCE'), findsOneWidget);

        // Tap Reactions tab
        await tester.tap(find.text('Reactions'));
        await tester.pumpAndSettle();
        expect(find.text('INPUT MATERIALS'), findsOneWidget);

        // Tap Production Chains tab
        await tester.tap(find.text('Production Chains'));
        await tester.pumpAndSettle();
        expect(find.text('2D Canvas'), findsOneWidget);
      },
    );
  });
}

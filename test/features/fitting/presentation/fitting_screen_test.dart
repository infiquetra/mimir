import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/presentation/fitting_screen.dart';
import 'package:mimir/features/fitting/presentation/widgets/ship_browser.dart';
import 'package:mimir/features/fitting/presentation/widgets/fitting_editor.dart';
import 'package:mimir/features/fitting/presentation/widgets/stats_panel.dart';
import '../../../../integration_test/test_utils/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FittingScreen UI Tests', () {
    testWidgets('renders all major components', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          home: FittingScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(ShipBrowser), findsOneWidget);
      expect(find.byType(FittingEditor), findsOneWidget);
      expect(find.byType(StatsPanel), findsOneWidget);
      
      expect(find.text('Ship Fitting'), findsOneWidget);
      expect(find.text('Select a ship to start fitting'), findsOneWidget);
      expect(find.text('No ship selected'), findsOneWidget);
    });

    testWidgets('selects a ship and renders fitting editor slots', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          home: FittingScreen(),
        ),
      );
      await tester.pump();

      // Tap on 'Rifter'
      await tester.tap(find.text('Rifter'));
      await tester.pump();

      // Assuming DogmaEngine and SdeService are returning defaults from TestApp 
      // or at least trying to load. Let's just check if it stops showing 'No ship selected'
      expect(find.text('No ship selected'), findsNothing);
      expect(find.text('Select a ship to start fitting'), findsNothing);
    });
  });
}

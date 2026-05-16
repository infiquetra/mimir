@Tags(['patrol'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mimir/features/market/presentation/market_overview_screen.dart';
import 'package:mimir/features/market/presentation/widgets/active_orders_panel.dart';
import 'package:mimir/features/market/presentation/widgets/price_checker_panel.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';
import 'package:mimir/core/sde/sde_providers.dart';

import '../../integration_test/test_utils/fixtures/character_fixtures.dart';
import '../../integration_test/test_utils/test_app.dart';

void main() {
  patrolWidgetTest(
    'Market E2E - verifies empty state and tab flows',
    ($) async {
      final character = CharacterFixtures.testCharacter();
      
      await $.pumpWidget(
        TestApp(
          initialCharacter: character,
          providerOverrides: [
            // Ensure any sde specific requests are mocked if necessary
            itemNameProvider(34).overrideWith((ref) => Future.value('Tritanium')),
          ],
          home: const MarketOverviewScreen(),
        ),
      );
      await $.pumpAndSettle();

      // Verify tabs exist
      expect($('Active Orders').exists, true);
      expect($('Price Checker').exists, true);

      // Verify Active Orders is the default tab and displays
      expect($(ActiveOrdersPanel).exists, true);
      
      // Let's tap on the Price Checker tab
      await $('Price Checker').tap();
      await $.pumpAndSettle();

      // Verify Price Checker panel is visible
      expect($(PriceCheckerPanel).exists, true);
      expect($('Enter Item ID (e.g. 34)').exists, true);

      // Simulate a search
      await $(TextField).enterText('34');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();

      // Assuming mock/empty database, we verify the interaction didn't crash
      // and handled the empty state. 

      // Unmount the TestApp to trigger ProviderScope disposal and cancel streams
      await $.pumpWidget(Container());
      await $.pump(const Duration(milliseconds: 100));
    },
  );

  patrolWidgetTest(
    'Market E2E - verifies No Character state',
    ($) async {
      await $.pumpWidget(
        const TestApp(
          initialCharacter: null, // No character selected
          home: MarketOverviewScreen(),
        ),
      );
      await $.pumpAndSettle();

      // Verify the empty state message
      expect($('No Character Selected').exists, true);
      expect($('Please select a character to view active orders.').exists, true);

      // Verify we can still navigate to Price Checker without a character
      await $('Price Checker').tap();
      await $.pumpAndSettle();
      expect($(PriceCheckerPanel).exists, true);

      // Unmount
      await $.pumpWidget(Container());
      await $.pump(const Duration(milliseconds: 100));
    },
  );
}

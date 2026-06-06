@Tags(['patrol'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mimir/features/market/presentation/market_overview_screen.dart';
import 'package:mimir/features/market/presentation/widgets/active_orders_panel.dart';
import 'package:mimir/features/market/presentation/widgets/market_browser_panel.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';
import 'package:mimir/core/sde/sde_providers.dart';

import '../../integration_test/test_utils/fixtures/character_fixtures.dart';
import '../../integration_test/test_utils/test_app.dart';

void main() {
  patrolWidgetTest('Market E2E - verifies empty state and tab flows', (
    $,
  ) async {
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
    expect($('My Orders').exists, true);
    expect($('Browser').exists, true);

    // Verify Browser is the default tab and displays
    expect($(MarketBrowserPanel).exists, true);
    expect($('Search items by name...').exists, true);

    // Let's tap on the My Orders tab
    await $('My Orders').tap();
    await $.pumpAndSettle();

    // Verify Active Orders panel is visible
    expect($(ActiveOrdersPanel).exists, true);

    // Let's tap on the Browser tab to do a search
    await $('Browser').tap();
    await $.pumpAndSettle();

    // Simulate a search
    await $(TextField).enterText('Tritanium');
    await $.pumpAndSettle();
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await $.pumpAndSettle();

    // Assuming mock/empty database, we verify the interaction didn't crash
    // and handled the empty state.

    // Unmount the TestApp to trigger ProviderScope disposal and cancel streams
    await $.pumpWidget(Container());
    await $.pump(const Duration(milliseconds: 100));
  });

  patrolWidgetTest('Market E2E - verifies No Character state', ($) async {
    await $.pumpWidget(
      const TestApp(
        initialCharacter: null, // No character selected
        home: MarketOverviewScreen(),
      ),
    );
    await $.pumpAndSettle();

    // Tap 'My Orders' tab
    await $('My Orders').tap();
    await $.pumpAndSettle();

    // Verify the empty state message
    expect($('No Character Selected').exists, true);
    expect($('Please select a character to view active orders.').exists, true);

    // Verify we can still navigate to Browser without a character
    await $('Browser').tap();
    await $.pumpAndSettle();
    expect($(MarketBrowserPanel).exists, true);

    // Unmount
    await $.pumpWidget(Container());
    await $.pump(const Duration(milliseconds: 100));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/wallet/presentation/wallet_screen.dart';
import 'package:mimir/features/wallet/presentation/widgets/balance_cards_row.dart';

import '../test_utils/fixtures/character_fixtures.dart';
import '../test_utils/test_app.dart';

/// Bug regression tests for layout overflow errors.
///
/// These tests prevent recurring bugs from commits:
/// - 62a6320: fix(wallet): fix TabBarView rendering and overflow errors
/// - 89fd3ba: fix(wallet): remove fixed height constraint from balance cards row
///
/// Historical issues:
/// - TabBarView pushed below viewport causing RenderFlex overflow
/// - Fixed height constraints caused overflow on narrow screens
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Layout Overflow Regression Tests', () {
    testWidgets(
      'TC-OVERFLOW-001: Wallet TabBarView renders without overflow',
      (tester) async {
        // GIVEN: WalletScreen with test character
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const WalletScreen(),
          ),
        );

        // WHEN: Screen loads with TabBarView
        await tester.pumpAndSettle();

        // THEN: TabBarView should be visible and not overflow
        // The TabBarView is wrapped in Expanded, which prevents overflow
        expect(find.byType(TabBarView), findsOneWidget);

        // Verify the layout structure (Column > [BalanceCardsRow, TabBar, Expanded(TabBarView)])
        final column = tester.widget<Column>(
          find.ancestor(
            of: find.byType(TabBarView),
            matching: find.byType(Column),
          ),
        );

        // TabBarView should be the 3rd child (index 2) wrapped in Expanded
        final tabBarViewParent = column.children[4]; // [BalanceCards, SizedBox, TabBar, SizedBox, Expanded(TabBarView)]
        expect(tabBarViewParent, isA<Expanded>());

        // REGRESSION CHECK: Before fix (commit 62a6320), TabBarView was NOT
        // wrapped in Expanded, causing "RenderFlex overflowed by X pixels" errors.
        // The test ensures this doesn't regress.
      },
    );

    testWidgets(
      'TC-OVERFLOW-003: Balance cards row handles narrow screens',
      (tester) async {
        // GIVEN: WalletScreen with narrow viewport (simulates small window)
        await tester.binding.setSurfaceSize(const Size(600, 800));

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const WalletScreen(),
          ),
        );

        // WHEN: Screen loads on narrow viewport
        await tester.pumpAndSettle();

        // THEN: Balance cards row should render without overflow
        expect(find.byType(BalanceCardsRow), findsOneWidget);

        // Verify the row is present and rendered
        final balanceRow = tester.widget<BalanceCardsRow>(
          find.byType(BalanceCardsRow),
        );
        expect(balanceRow, isNotNull);

        // REGRESSION CHECK: Before fix (commit 89fd3ba), BalanceCardsRow had
        // a fixed height constraint that caused overflow on narrow screens.
        // The Row would exceed available space, causing RenderFlex overflow.
        // After fix, IntrinsicHeight or flexible constraints allow proper wrapping.

        // Reset surface size for other tests
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'TC-OVERFLOW-005: Wallet screen survives window resize',
      (tester) async {
        // GIVEN: WalletScreen at normal size
        await tester.binding.setSurfaceSize(const Size(1200, 800));

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const WalletScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // WHEN: Window is resized to narrow
        await tester.binding.setSurfaceSize(const Size(600, 800));
        await tester.pumpAndSettle();

        // THEN: Layout should adapt without overflow
        expect(find.byType(WalletScreen), findsOneWidget);
        expect(find.byType(TabBarView), findsOneWidget);

        // WHEN: Window is resized to very narrow
        await tester.binding.setSurfaceSize(const Size(375, 667)); // iPhone size
        await tester.pumpAndSettle();

        // THEN: Layout should still render without overflow
        expect(find.byType(WalletScreen), findsOneWidget);
        expect(find.byType(TabBarView), findsOneWidget);

        // REGRESSION CHECK: Dynamic window resizing (common in macOS desktop apps)
        // should not cause overflow errors. Responsive breakpoints must handle
        // all viewport sizes gracefully.

        // Reset surface size
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}

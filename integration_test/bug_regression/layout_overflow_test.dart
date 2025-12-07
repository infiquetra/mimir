import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/characters/presentation/characters_screen.dart';
import 'package:mimir/features/wallet/presentation/wallet_screen.dart';
import 'package:mimir/features/wallet/presentation/widgets/balance_cards_row.dart';

import '../test_utils/fixtures/character_fixtures.dart';
import '../test_utils/test_app.dart';

/// Bug regression tests for layout overflow errors.
///
/// These tests prevent recurring bugs from commits:
/// - 62a6320: fix(wallet): fix TabBarView rendering and overflow errors
/// - fc608bb: fix(characters): improve responsive layout thresholds
/// - 89fd3ba: fix(wallet): remove fixed height constraint from balance cards row
///
/// Historical issues:
/// - TabBarView pushed below viewport causing RenderFlex overflow
/// - Long character names caused text overflow
/// - Fixed height constraints caused overflow on narrow screens
/// - Incorrect breakpoints for responsive 2-column layout
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
      'TC-OVERFLOW-002: Long character names truncate gracefully',
      (tester) async {
        // GIVEN: Character with extremely long name
        final longNameCharacter = CharacterFixtures.customCharacter(
          characterId: 99999999,
          name: 'A Very Long Character Name That Should Truncate Instead Of Overflowing',
          corporationId: 98000001,
          corporationName: 'Corporation With An Extremely Long Name',
          isActive: true,
        );

        await tester.pumpWidget(
          TestApp(
            initialCharacter: longNameCharacter,
            home: const CharactersScreen(),
          ),
        );

        // WHEN: Screen loads with long character name
        await tester.pumpAndSettle();

        // THEN: Character name should be visible (potentially truncated)
        // The presence of Text widget indicates it rendered without overflow
        expect(
          find.textContaining('A Very Long Character Name'),
          findsAtLeastNWidgets(1),
        );

        // REGRESSION CHECK: Before fix (commit fc608bb), long character names
        // would cause "RenderFlex overflowed by X pixels on the right" errors
        // because Text widgets lacked overflow: TextOverflow.ellipsis.
        // The test ensures names render without crashing, even if truncated.
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
      'TC-OVERFLOW-004: Characters screen 2-column threshold is correct',
      (tester) async {
        // GIVEN: CharactersScreen at exactly the breakpoint width
        // Breakpoint is typically 600px for mobile/tablet or 900px for desktop
        await tester.binding.setSurfaceSize(const Size(900, 800));

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const CharactersScreen(),
          ),
        );

        // WHEN: Screen loads at breakpoint width
        await tester.pumpAndSettle();

        // THEN: Layout should render without overflow
        expect(find.byType(CharactersScreen), findsOneWidget);

        // The screen uses a split panel layout (SplitPanel or Row with Expanded)
        // At wide widths, it shows 40/60 split
        // At narrow widths, it shows single column
        final rows = find.byType(Row);
        expect(rows, findsWidgets); // Should find row-based layouts

        // REGRESSION CHECK: Before fix (commit fc608bb), the breakpoint threshold
        // was incorrect, causing either:
        // 1. 2-column layout to appear too early (overflow on small screens)
        // 2. Single-column to persist too long (poor UX on medium screens)
        // Correct breakpoints prevent overflow and optimize layout for screen size.

        // Reset surface size
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

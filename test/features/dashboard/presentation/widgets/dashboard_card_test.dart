import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/theme/eve_colors.dart';
import 'package:mimir/features/dashboard/presentation/widgets/dashboard_card.dart';

void main() {
  group('DashboardCard', () {
    testWidgets('renders title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Card'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('displays child widget in content state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('shows loading state when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              isLoading: true,
              child: Text('Content'),
            ),
          ),
        ),
      );

      // Content should not be visible
      expect(find.text('Content'), findsNothing);

      // Shimmer effect containers should be present
      final shimmerContainers = find.byType(Container);
      expect(shimmerContainers, findsWidgets);
    });

    testWidgets('shows error state with error message',
        (WidgetTester tester) async {
      const errorMessage = 'Something went wrong';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              errorMessage: errorMessage,
              child: Text('Content'),
            ),
          ),
        ),
      );

      // Content should not be visible
      expect(find.text('Content'), findsNothing);

      // Error message should be visible
      expect(find.text('Error'), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error state shows retry button when onRetry is provided',
        (WidgetTester tester) async {
      var retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              errorMessage: 'Error occurred',
              onRetry: () => retryPressed = true,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryPressed, isTrue);
    });

    testWidgets('error state does not show retry button when onRetry is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              errorMessage: 'Error occurred',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('retry button triggers callback when pressed',
        (WidgetTester tester) async {
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              errorMessage: 'Error occurred',
              onRetry: () => retryCount++,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(retryCount, 0);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryCount, 1);
    });

    testWidgets('shows expand button when onExpand is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              onExpand: () {},
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('expand button triggers callback when pressed',
        (WidgetTester tester) async {
      var expandPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              onExpand: () => expandPressed = true,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(expandPressed, isTrue);
    });

    testWidgets('does not show expand button when onExpand is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('applies glow color to icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              glowColor: EveColors.success,
              child: Text('Content'),
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(iconWidget.color, EveColors.success);
    });

    testWidgets('uses default color when glowColor is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              child: Text('Content'),
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(iconWidget.color, EveColors.evePrimary);
    });

    testWidgets('loading state takes precedence over content',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              isLoading: true,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsNothing);
    });

    testWidgets('error state takes precedence over loading and content',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Card',
              icon: Icons.star,
              isLoading: true,
              errorMessage: 'Error occurred',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsNothing);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Error occurred'), findsOneWidget);
    });
  });
}

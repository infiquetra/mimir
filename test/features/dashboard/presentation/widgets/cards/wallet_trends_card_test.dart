import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/wallet_trends_card.dart';

void main() {
  group('WalletTrendsCard', () {
    testWidgets('displays loading state initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WalletTrendsCard(),
            ),
          ),
        ),
      );

      // Should show loading state
      expect(find.byType(WalletTrendsCard), findsOneWidget);
    });

    testWidgets('displays empty state when no data', (tester) async {
      final emptyData = WalletTrendsData(
        chartPoints: [],
        income: 0.0,
        expenses: 0.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletTrendsProvider.overrideWith((_) async => emptyData),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WalletTrendsCard(),
            ),
          ),
        ),
      );

      // Wait for provider to load
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.text('No trend data available'), findsOneWidget);
      expect(
        find.text('Balance history will appear here over time'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('displays chart with trend data', (tester) async {
      final mockData = WalletTrendsData(
        chartPoints: [
          WalletTrendsPoint(
            date: DateTime(2024, 1, 1),
            balance: 10000000000.0, // 10B
          ),
          WalletTrendsPoint(
            date: DateTime(2024, 1, 2),
            balance: 12000000000.0, // 12B
          ),
          WalletTrendsPoint(
            date: DateTime(2024, 1, 3),
            balance: 15000000000.0, // 15B
          ),
        ],
        income: 7000000000.0, // 7B
        expenses: 2000000000.0, // 2B
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletTrendsProvider.overrideWith((_) async => mockData),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WalletTrendsCard(),
            ),
          ),
        ),
      );

      // Wait for provider to load
      await tester.pumpAndSettle();

      // Should show summary stats
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Net'), findsOneWidget);

      // Should show formatted ISK values (compact format)
      expect(find.textContaining('7.00B'), findsOneWidget); // Income
      expect(find.textContaining('2.00B'), findsOneWidget); // Expenses
      expect(find.textContaining('5.00B'), findsOneWidget); // Net
    });

    testWidgets('displays error state on failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletTrendsProvider.overrideWith(
              (_) async => throw Exception('Database error'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WalletTrendsCard(),
            ),
          ),
        ),
      );

      // Wait for error
      await tester.pumpAndSettle();

      // Should show error state
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Exception: Database error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calculates net correctly', (tester) async {
      final mockData = WalletTrendsData(
        chartPoints: [
          WalletTrendsPoint(
            date: DateTime(2024, 1, 1),
            balance: 1000000.0,
          ),
        ],
        income: 500000.0,
        expenses: 300000.0,
      );

      expect(mockData.net, equals(200000.0)); // 500k - 300k = 200k
    });

    testWidgets('handles negative net correctly', (tester) async {
      final mockData = WalletTrendsData(
        chartPoints: [
          WalletTrendsPoint(
            date: DateTime(2024, 1, 1),
            balance: 1000000.0,
          ),
        ],
        income: 100000.0,
        expenses: 500000.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletTrendsProvider.overrideWith((_) async => mockData),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WalletTrendsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Net should be negative
      expect(mockData.net, equals(-400000.0)); // 100k - 500k = -400k

      // Should still display (with negative formatting)
      expect(find.text('Net'), findsOneWidget);
    });

    testWidgets('data models have proper equality', (tester) async {
      final point1 = WalletTrendsPoint(
        date: DateTime(2024, 1, 1),
        balance: 1000.0,
      );
      final point2 = WalletTrendsPoint(
        date: DateTime(2024, 1, 1),
        balance: 1000.0,
      );
      final point3 = WalletTrendsPoint(
        date: DateTime(2024, 1, 2),
        balance: 1000.0,
      );

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));

      final data1 = WalletTrendsData(
        chartPoints: [point1],
        income: 100.0,
        expenses: 50.0,
      );
      final data2 = WalletTrendsData(
        chartPoints: [point2],
        income: 100.0,
        expenses: 50.0,
      );
      final data3 = WalletTrendsData(
        chartPoints: [point3],
        income: 100.0,
        expenses: 50.0,
      );

      expect(data1, equals(data2));
      expect(data1, isNot(equals(data3)));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/wallet_trends_card.dart';

void main() {
  group('WalletTrendsCard Golden Tests', () {
    testGoldens('WalletTrendsCard states render correctly', (tester) async {
      final mockData = WalletTrendsData(
        chartPoints: [
          WalletTrendsPoint(date: DateTime(2024, 1, 1), balance: 10000000000.0),
          WalletTrendsPoint(date: DateTime(2024, 1, 2), balance: 12000000000.0),
          WalletTrendsPoint(date: DateTime(2024, 1, 3), balance: 15000000000.0),
        ],
        income: 7000000000.0,
        expenses: 2000000000.0,
      );

      final emptyData = WalletTrendsData(
        chartPoints: [],
        income: 0.0,
        expenses: 0.0,
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'With Data',
          ProviderScope(
            overrides: [
              walletTrendsProvider.overrideWith((_) async => mockData),
            ],
            child: SizedBox(
              height: 400,
              width: 400,
              child: const WalletTrendsCard(),
            ),
          ),
        )
        ..addScenario(
          'Empty State',
          ProviderScope(
            overrides: [
              walletTrendsProvider.overrideWith((_) async => emptyData),
            ],
            child: SizedBox(
              height: 400,
              width: 400,
              child: const WalletTrendsCard(),
            ),
          ),
        )
        ..addScenario(
          'Error State',
          ProviderScope(
            overrides: [
              walletTrendsProvider.overrideWith(
                (_) async => throw Exception('Database error'),
              ),
            ],
            child: SizedBox(
              height: 400,
              width: 400,
              child: const WalletTrendsCard(),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build(), surfaceSize: const Size(800, 1600));
      // Need pumpAndSettle to resolve the FutureProviders
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'wallet_trends_card_states');
    });
  });
}

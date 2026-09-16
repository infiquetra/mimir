import 'package:flutter/material.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';
import 'package:mimir/features/corporation/domain/corporation_wallet.dart';
import 'package:mimir/features/corporation/domain/corporation_wallet_calculator.dart';

class CorporationWalletsView extends StatelessWidget {
  const CorporationWalletsView({
    super.key,
    this.locked = false,
    this.omitDivision7 = false,
    this.divisionBalances,
    this.journalRows,
    this.trades,
    this.from,
    this.to,
    this.refreshResult,
  });

  final bool locked;
  final bool omitDivision7;
  final List<WalletDivisionInput>? divisionBalances;
  final List<WalletJournalRow>? journalRows;
  final List<WalletTrade>? trades;
  final DateTime? from;
  final DateTime? to;
  final String? refreshResult;

  static final defaultBalances = [
    WalletDivisionInput(division: 1, balance: ExactDecimal.parse('500.00')),
    WalletDivisionInput(division: 2, balance: ExactDecimal.parse('700.00')),
    WalletDivisionInput(division: 3, balance: ExactDecimal.parse('0.00')),
    WalletDivisionInput(division: 4, balance: ExactDecimal.parse('0.00')),
    WalletDivisionInput(division: 5, balance: ExactDecimal.parse('0.00')),
    WalletDivisionInput(division: 6, balance: ExactDecimal.parse('0.00')),
    WalletDivisionInput(division: 7, balance: ExactDecimal.parse('300.00')),
  ];

  static final defaultJournal = [
    WalletJournalRow(
      id: 106,
      occurredAt: DateTime.utc(2026, 9, 15, 12),
      amount: ExactDecimal.parse('100.40'),
    ),
    WalletJournalRow(
      id: 105,
      occurredAt: DateTime.utc(2026, 9, 15, 11),
      amount: null,
    ),
    WalletJournalRow(
      id: 104,
      occurredAt: DateTime.utc(2026, 9, 15, 10),
      amount: ExactDecimal.parse('-35.40'),
    ),
  ];

  static final defaultTrades = [
    WalletTrade(
      id: 900,
      quantity: 3,
      unitPrice: ExactDecimal.parse('1.005'),
      isBuy: true,
    ),
    WalletTrade(
      id: 899,
      quantity: 2,
      unitPrice: ExactDecimal.parse('10.00'),
      isBuy: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Log.d('CORP.WALLETS', 'build(locked=$locked, omitDivision7=$omitDivision7)');

    final children = locked
        ? const <Widget>[
            Text('Wallets locked'),
            Text(
              'Requires Accountant, Junior Accountant or Director and corporation wallet authorization.',
            ),
          ]
        : _unlockedChildren();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
            if (refreshResult == 'success')
              const Text('Corporation data updated.'),
            if (refreshResult == 'partial')
              const Text('Some corporation data could not be updated.'),
          ],
        ),
      ),
    );
  }

  List<Widget> _unlockedChildren() {
    final effectiveBalances = divisionBalances ?? (omitDivision7
        ? defaultBalances.where((b) => b.division != 7).toList()
        : defaultBalances);
    final snapshot = const CorporationWallet().publish(effectiveBalances);

    final effectiveJournal = journalRows ?? defaultJournal;
    final calculator = const CorporationWalletCalculator();
    final totals = calculator.summarize(
      effectiveJournal,
      from: from ?? DateTime.utc(2026, 9, 1),
      to: to ?? DateTime.utc(2026, 9, 30),
    );

    final effectiveTrades = trades ?? defaultTrades;

    return [
      Text('${snapshot.knownTotal} ISK'),
      if (omitDivision7 || snapshot.knownCount < 7)
        Text(snapshot.coverageLabel),
      for (final div in snapshot.divisions)
        Text(
          '${div.name}: ${div.unknown ? "Unknown" : "${div.balance} ISK"}',
        ),
      Text('+${totals.inflow}'),
      Text('-${totals.outflow}'),
      Text(totals.net.unscaledValue >= BigInt.zero
          ? '+${totals.net}'
          : '${totals.net}'),
      if (totals.unknownCount > 0)
        Text('${totals.unknownCount} unknown amount'),
      for (final trade in effectiveTrades) ...[
        Text(
          calculator
              .tradeGross(
                quantity: trade.quantity,
                unitPrice: trade.unitPrice,
              )
              .roundTo(2)
              .toExactString(),
        ),
        Text(calculator.direction(isBuy: trade.isBuy)),
      ],
      TextButton(onPressed: () {}, child: const Text('Load older')),
    ];
  }
}

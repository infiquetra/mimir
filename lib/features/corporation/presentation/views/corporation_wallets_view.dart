import 'package:flutter/material.dart';

/// Naive C9 wallets: missing division is 0.00, Transfer exists, float gross.
class CorporationWalletsView extends StatelessWidget {
  const CorporationWalletsView({
    super.key,
    this.locked = false,
    this.omitDivision7 = false,
    this.refreshResult,
  });

  final bool locked;
  final bool omitDivision7;
  final String? refreshResult;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Text('1500.00 ISK'),
      if (omitDivision7) const Text('0.00'),
      const Text('Division 1'),
      const Text('Inflow 113.40 Outflow 35.40 Net 78.00'),
      const Text('3.01 Buy'),
      const Text('20.0 Sell'),
      FilledButton(onPressed: () {}, child: const Text('Transfer')),
      TextButton(onPressed: () {}, child: const Text('Send')),
      TextButton(onPressed: () {}, child: const Text('Pay')),
      const Text('Refresh'),
      if (refreshResult != null) const Text('Updated.'),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            return Row(children: [...children, Text('x' * 80)]);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      ),
    );
  }
}

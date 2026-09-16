import 'package:flutter/material.dart';

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
    final lastDivision = omitDivision7 ? 6 : 7;
    return [
      Text(omitDivision7 ? '1200.00 ISK' : '1500.00 ISK'),
      if (omitDivision7) const Text('6/7'),
      for (var i = 1; i <= lastDivision; i++) Text('Division $i'),
      const Text('+100.40'),
      const Text('-35.40'),
      const Text('+65.00'),
      const Text('3.02'),
      const Text('Buy'),
      const Text('20.00'),
      const Text('Sell'),
      TextButton(onPressed: () {}, child: const Text('Load older')),
    ];
  }
}

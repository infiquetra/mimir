// X8 RED contracts for Intel TheraConnectionsCard migration.
// Compile stubs are the existing card: tests fail until GREEN projects the
// shared feed ViewModel, includes Turnur, and drops Live/remainingHours.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/intel/data/intel_providers.dart';
import 'package:mimir/features/intel/domain/thera_models.dart';
import 'package:mimir/features/intel/presentation/widgets/thera_connections_card.dart';

void main() {
  TheraConnection sample() {
    return TheraConnection(
      id: 'evescout:42',
      whType: 'B274',
      maxShipSize: 'xlarge',
      expiresAt: DateTime.utc(2026, 9, 15, 18),
      remainingHours: 3,
      outSystemId: 31000005,
      outSystemName: 'Thera',
      outSignature: 'HUB-123',
      inSystemId: 9101,
      inSystemClass: 'hs',
      inSystemName: 'Alpha',
      inRegionId: 9201,
      inRegionName: 'Fixture Region',
      inSignature: 'FAR-456',
    );
  }

  testWidgets('title includes Turnur and drops Live/remainingHours', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          theraConnectionsProvider.overrideWith((ref) async => [sample()]),
        ],
        child: const MaterialApp(home: Scaffold(body: TheraConnectionsCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Turnur'), findsOneWidget);
    expect(find.textContaining('Live'), findsNothing);
    expect(find.textContaining('3h'), findsNothing);
    expect(find.textContaining('Item #'), findsNothing);
    expect(find.textContaining('9101'), findsNothing);
  });

  test('card source does not infer remainingHours or Live', () {
    final source = File(
      'lib/features/intel/presentation/widgets/thera_connections_card.dart',
    ).readAsStringSync();
    expect(source.contains('remainingHours'), isFalse);
    expect(source.contains('Live'), isFalse);
    expect(source.contains('eveScoutFeedProvider'), isTrue);
  });
}

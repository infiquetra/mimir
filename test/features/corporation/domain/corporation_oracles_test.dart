// C0 RED oracles for F2–F8 fixture builders (tax, roster, assets, fuel, wallets).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';
import 'package:mimir/features/corporation/domain/corporation_oracles.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  group('F2 profile, join dates, activity', () {
    test('current 10 is 10%, current 0.10 is 0.1%, legacy 0.10 is 10%', () {
      expect(TaxRate.parseCurrentIsk(10)?.toExactString(), '10');
      expect(TaxRate.parseCurrentIsk(5.6)?.toExactString(), '5.6');
      expect(TaxRate.parseCurrentIsk(0.10)?.toExactString(), '0.1');
      expect(TaxRate.parseLegacy(0.10)?.toExactString(), '10');
    });

    test('current 101 and NaN are rejected', () {
      expect(TaxRate.parseCurrentIsk(101), isNull);
      expect(TaxRate.parseCurrentIsk(double.nan), isNull);
    });

    test('roster [1,2] does not invent member 3 from public count', () {
      final roster = F2Fixtures.roster();
      expect(roster['members'], [1, 2]);
      expect(roster['publicCount'], 3);
      expect((roster['members'] as List).length, isNot(roster['publicCount']));
    });

    test('Ada join is September 1 from record 9, not January 1', () {
      final history = (F2Fixtures.roster()['history'] as Map)['1'] as List;
      final join = RosterOracle().currentJoin(history, kHeliosId);
      expect(join, DateTime.utc(2026, 9, 1));
    });

    test('Bea latest Selene record makes Helios join unavailable', () {
      final history = (F2Fixtures.roster()['history'] as Map)['2'] as List;
      expect(RosterOracle().currentJoin(history, kHeliosId), isNull);
    });

    test('tracking 99 does not extend the roster', () {
      final tracking = F2Fixtures.roster()['tracking'] as Map;
      expect(tracking.containsKey('99'), isTrue);
      expect(F2Fixtures.roster()['members'], isNot(contains(99)));
    });

    test('7-day login includes Ada at T0 and excludes at T0+1ms', () {
      final login = DateTime.utc(2026, 9, 8, 12);
      final oracle = RosterOracle();
      expect(oracle.withinSevenDays(login, kCorporationT0), isTrue);
      expect(
        oracle.withinSevenDays(
          login,
          kCorporationT0.add(const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
    });
  });

  group('F3 assets', () {
    test('11 rows, 10 goods, 8 priced, 2 unpriced', () {
      final rows = F3Fixtures.rows();
      expect(rows, hasLength(11));
      final goods = rows.where((row) => !row.administrative).toList();
      expect(goods, hasLength(10));
      final priced = goods.where(
        (row) =>
            F3Fixtures.prices.containsKey(row.typeId) && !row.isBlueprintCopy,
      );
      expect(priced, hasLength(8));
      expect(
        goods.where((row) => row.isBlueprintCopy || row.typeId == 9999),
        hasLength(2),
      );
    });

    test('global priced subtotal is 725.00 with 2 unpriced rows', () {
      final valuation = const AssetValuation();
      final total = valuation.pricedSubtotal(
        F3Fixtures.rows(),
        F3Fixtures.priceMap(),
      );
      expect(total.toExactString(), '725.00');
    });

    test('ammo search is 4 matches valued 35.00 without ancestors', () {
      final hits = const AssetValuation().search(
        F3Fixtures.rows(),
        'Test Ammunition',
        F3Fixtures.names,
      );
      expect(hits.map((row) => row.itemId).toList(), [1110, 1300, 1400, 1401]);
      expect(hits, hasLength(4));
      final value = const AssetValuation().pricedSubtotal(
        hits,
        F3Fixtures.priceMap(),
      );
      expect(value.toExactString(), '35.00');
    });
  });

  group('F4 fuel', () {
    test('expiry 216000s is 60h Low', () {
      final remaining = FuelOracle().reportedRemaining(
        F4Fixtures.expiresAt,
        kCorporationT0,
      );
      expect(remaining.inSeconds, 216000);
      expect(remaining.inHours, 60);
      expect(FuelOracle().severity(remaining), 'Low');
    });

    test('observed blocks are 1440 excluding reserves', () {
      expect(FuelOracle().observedBlocks(F4Fixtures.bay()), 1440);
    });

    test('two 9/h consumers are 18/h, 432/day, 80h, 3.33 days', () {
      final rate = FuelOracle().hourlyRate(onlineConsumers: 2, reduction: 0.25);
      expect(rate, 18);
      expect(rate * 24, 432);
      expect(1440 / rate, 80);
      expect(((1440 / rate) / 24).toStringAsFixed(2), '3.33');
    });

    test('manual 1440@20/h is 480/day, 72h, 3.00 days', () {
      expect(20 * 24, 480);
      expect(1440 / 20, 72);
      expect((72 / 24).toStringAsFixed(2), '3.00');
    });

    test('severity boundaries at 72h and 24h', () {
      final oracle = FuelOracle();
      expect(
        oracle.severity(const Duration(hours: 72, milliseconds: 1)),
        'Normal',
      );
      expect(oracle.severity(const Duration(hours: 72)), 'Low');
      expect(
        oracle.severity(const Duration(hours: 24, milliseconds: 1)),
        'Low',
      );
      expect(oracle.severity(const Duration(hours: 24)), 'Critical');
      expect(oracle.severity(Duration.zero), 'Reported expiry passed');
      expect(
        oracle.severity(const Duration(milliseconds: -1)),
        'Reported expiry passed',
      );
    });

    test('5m skew qualifies and 5m+1ms does not', () {
      final a = kCorporationT0;
      final ok = a.add(const Duration(minutes: 5));
      final late = a.add(const Duration(minutes: 5, milliseconds: 1));
      expect(FuelOracle().compatible(a, ok), isTrue);
      expect(FuelOracle().compatible(a, late), isFalse);
    });
  });

  group('F5 wallets', () {
    test('journal interval excludes ID107 and nets 65.00', () {
      final end = DateTime.utc(2026, 9, 16);
      expect(
        WalletOracle().includeJournal([101, 102, 103, 104, 105, 106, 107], end),
        [101, 102, 103, 104, 105, 106],
      );
      final inflow =
          ExactDecimal.parse('100.10') +
          ExactDecimal.parse('0.10') +
          ExactDecimal.parse('0.20');
      final outflow = ExactDecimal.parse('25.05') + ExactDecimal.parse('10.35');
      expect(inflow.toExactString(), '100.40');
      expect(outflow.toExactString(), '35.40');
      expect((inflow - outflow).toExactString(), '65.00');
    });

    test('cursor pages yield three unique trades', () {
      final pages = (F5Fixtures.wallets()['cursor_pages'] as List)
          .map((page) => List<int>.from(page as List))
          .toList();
      expect(WalletOracle().followCursor(pages).toSet(), {900, 899, 898});
      expect(WalletOracle().followCursor(pages), hasLength(3));
    });
  });

  group('F6 backoff and F8 extremes', () {
    test('429 Retry-After and backoff schedule', () {
      final raw = jsonDecode(corporationFixture('f6_headers.json')) as Map;
      expect(raw['backoffSeconds'], [30, 60, 120, 300, 300]);
      expect((raw['retryAfter'] as Map)['Retry-After'], '120');
    });

    test('F8 matrix and extreme ISK lexeme', () {
      expect(F8Fixtures.widths, [320, 600, 900, 1200]);
      expect(F8Fixtures.longName(), hasLength(80));
      expect(F8Fixtures.extremeIsk, '-1234567890123456.78');
      expect(
        ExactDecimal.parse(F8Fixtures.extremeIsk).toExactString(),
        '-1234567890123456.78',
      );
    });
  });

  group('F7 isolation fixture', () {
    test('temporary corporation 0 is not a departure purge', () {
      final raw = corporationJson('f7_isolation.json');
      expect(raw['temporaryCorporationId'], 0);
      expect(raw['switchTo'], 'Ada');
      expect(raw['delayedPage'], 2);
    });
  });

  group('fuel manifest schema', () {
    test('records SDE 3503375 and group-1415 reduction', () {
      final rules = corporationJson('corporation_fuel_rules.v1.json');
      final ledger = corporationJson('fuel_source_ledger.json');
      expect(rules['sdeBuild'], 3503375);
      expect(ledger['sdeBuild'], 3503375);
      expect((rules['hullEffects'] as List).first['reduction'], 0.25);
      expect((rules['hullEffects'] as List).first['serviceGroup'], 1415);
    });
  });
}

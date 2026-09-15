// W5 RED contracts for BOM prices and cached spare annotations.
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §7.2 / §7.3:
// - D13: adjustedPrice/Dogma fallbacks; exact-24h quotes stay fresh;
//   future-dated quotes are not uncertain; per-unit rounding; "Total cost".
// - D14: any asset at the station is credited; baseline overlap still
//   subtracts; empty cache is a verified shortage.
// - P12: refresh also syncs orders/assets and clears cache on error.
// - P10/P11: other-character hangar stock is credited to encounter P.
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_bom.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_comparison.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_pricing.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_spares.dart';

import '../fixtures/aar_comparison_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 12);

  List<AarPriceEstimate> f2Estimates({
    DateTime? quotedAt,
    bool pasteAdjustedOnly = true,
  }) {
    return [
      AarPriceEstimate.fromQuote(
        AarMarketQuote(
          typeId: kCmpHullH,
          averagePrice: F2Oracle.hullPrice.toDouble(),
          lastUpdated: quotedAt ?? now,
        ),
        now: now,
      ),
      AarPriceEstimate.fromQuote(
        AarMarketQuote(
          typeId: kCmpModuleA,
          averagePrice: F2Oracle.aPrice.toDouble(),
          lastUpdated: quotedAt ?? now,
        ),
        now: now,
      ),
      AarPriceEstimate.fromQuote(
        AarMarketQuote(
          typeId: kCmpModuleC,
          averagePrice: F2Oracle.cPrice.toDouble(),
          lastUpdated: quotedAt ?? now,
        ),
        now: now,
      ),
      AarPriceEstimate.fromQuote(
        AarMarketQuote(
          typeId: kCmpAmmo,
          averagePrice: F2Oracle.ammoPrice.toDouble(),
          lastUpdated: quotedAt ?? now,
        ),
        now: now,
      ),
      AarPriceEstimate.fromQuote(
        AarMarketQuote(
          typeId: kCmpPaste,
          averagePrice: pasteAdjustedOnly ? null : 5,
          adjustedPrice: 5,
          dogmaCost: 1,
          lastUpdated: quotedAt ?? now,
        ),
        now: now,
      ),
    ];
  }

  FitBillOfMaterials changesBom() {
    return const FitBillOfMaterials(
      mode: AarBomMode.changes,
      requirements: [
        FitBomLine(typeId: kCmpModuleC, requiredCount: 1),
        FitBomLine(typeId: kCmpAmmo, requiredCount: 50),
        FitBomLine(typeId: kCmpPaste, requiredCount: 20),
      ],
    );
  }

  FitBillOfMaterials replacementBom() {
    return const FitBillOfMaterials(
      mode: AarBomMode.fullReplacement,
      requirements: [
        FitBomLine(typeId: kCmpHullH, requiredCount: 1),
        FitBomLine(typeId: kCmpModuleA, requiredCount: 2),
        FitBomLine(typeId: kCmpModuleC, requiredCount: 1),
        FitBomLine(typeId: kCmpAmmo, requiredCount: 150),
        FitBomLine(typeId: kCmpPaste, requiredCount: 20),
      ],
    );
  }

  group('W5 D13 F2 price coverage', () {
    test('Changes priced subtotal is 2,000,500 with 2/3 lines', () {
      final priced = const AarBomPricer().price(
        bom: changesBom(),
        estimates: f2Estimates(),
      );
      expect(priced.heading.toLowerCase(), contains('priced subtotal'));
      expect(priced.heading.toLowerCase(), isNot(contains('total cost')));
      expect(priced.amount.asDouble, F2Oracle.changesPricedSubtotal);
      expect(priced.coverage, F2Oracle.changesPricedLines);
      expect(priced.lines.where((line) => line.typeId == kCmpModuleA), isEmpty);
      expect(
        priced.lines.singleWhere((line) => line.typeId == kCmpPaste).label,
        'Price unavailable',
      );
      expect(
        priced.lines
            .singleWhere((line) => line.typeId == kCmpModuleC)
            .estimate!
            .sourceLabel,
        'ESI average price estimate',
      );
    });

    test('Full replacement priced subtotal is 104,001,500 with 4/5 lines', () {
      final priced = const AarBomPricer().price(
        bom: replacementBom(),
        estimates: f2Estimates(),
      );
      expect(priced.amount.asDouble, F2Oracle.replacementPricedSubtotal);
      expect(priced.coverage, F2Oracle.replacementPricedLines);
      expect(
        priced.lines.singleWhere((line) => line.typeId == kCmpPaste).label,
        'Price unavailable',
      );
    });

    test('adjusted-only and Dogma cost are not purchase prices', () {
      final paste = AarPriceEstimate.fromQuote(
        const AarMarketQuote(typeId: kCmpPaste, adjustedPrice: 5, dogmaCost: 1),
        now: now,
      );
      expect(paste.isPriced, isFalse);
      expect(paste.unitPrice, isNull);
      expect(paste.unavailableReason, isNot('missing'));
    });

    test('stored zero average is 0 ISK estimate, not free', () {
      final zero = AarPriceEstimate.fromQuote(
        AarMarketQuote(typeId: kCmpModuleC, averagePrice: 0, lastUpdated: now),
        now: now,
      );
      expect(zero.isPriced, isTrue);
      expect(zero.unitPrice!.asDouble, 0);
      expect(zero.unavailableReason, isNull);
      final priced = const AarBomPricer().price(
        bom: const FitBillOfMaterials(
          requirements: [FitBomLine(typeId: kCmpModuleC, requiredCount: 1)],
        ),
        estimates: [zero],
      );
      expect(priced.lines.single.label, '0 ISK estimate');
      expect(priced.lines.single.label, isNot('free'));
    });

    test('exact 24h quotes are stale; future-dated quotes are uncertain', () {
      final stale = AarPriceEstimate.fromQuote(
        AarMarketQuote(
          typeId: kCmpModuleC,
          averagePrice: F2Oracle.cPrice.toDouble(),
          lastUpdated: now.subtract(const Duration(hours: 24)),
        ),
        now: now,
      );
      final future = AarPriceEstimate.fromQuote(
        AarMarketQuote(
          typeId: kCmpAmmo,
          averagePrice: F2Oracle.ammoPrice.toDouble(),
          lastUpdated: now.add(const Duration(hours: 1)),
        ),
        now: now,
      );
      expect(stale.isStale, isTrue);
      expect(future.uncertain, isTrue);
      expect(future.isStale, isFalse);
    });

    test('IskEstimateAmount multiplies in scale before formatIsk rounding', () {
      final unit = IskEstimateAmount.fromAverage(1.239);
      final extension = unit.times(50);
      expect(extension.asDouble, closeTo(61.95, 1e-9));
      expect(formatIsk(extension.asDouble), '61.95 ISK');
    });
  });

  group('W5 D14 cached asset match', () {
    const station = 60003760;
    const pilot = 42;
    const matcher = AarSpareMatcher();

    AarCachedAsset asset({
      int itemId = 1,
      int characterId = pilot,
      int typeId = kCmpModuleC,
      int locationId = station,
      String flag = 'Hangar',
      int quantity = 1,
      int? containedInId,
      int? parentItemId,
    }) {
      return AarCachedAsset(
        itemId: itemId,
        characterId: characterId,
        typeId: typeId,
        locationId: locationId,
        locationFlag: flag,
        quantity: quantity,
        containedInId: containedInId,
        parentItemId: parentItemId,
      );
    }

    test('eligible loose hangar stock produces F2 Changes shortfalls', () {
      final stock = [
        asset(itemId: 10, typeId: kCmpModuleC, quantity: 1),
        asset(itemId: 11, typeId: kCmpAmmo, quantity: 30),
        asset(itemId: 12, typeId: kCmpPaste, quantity: 5),
      ];
      final c = matcher.match(
        typeId: kCmpModuleC,
        requiredCount: 1,
        encounterCharacterId: pilot,
        selectedLocationId: station,
        assets: stock,
      );
      final ammo = matcher.match(
        typeId: kCmpAmmo,
        requiredCount: 50,
        encounterCharacterId: pilot,
        selectedLocationId: station,
        assets: stock,
      );
      final paste = matcher.match(
        typeId: kCmpPaste,
        requiredCount: 20,
        encounterCharacterId: pilot,
        selectedLocationId: station,
        assets: stock,
      );
      expect(c.eligibleLooseCount, 1);
      expect(c.estimatedShortfall, 0);
      expect(ammo.estimatedShortfall, 20);
      expect(paste.estimatedShortfall, 15);
      expect(c.disclosure, contains('Asset freshness unknown'));
    });

    test('fitted, cargo, drone bay and nested stacks are not loose stock', () {
      final stock = [
        asset(itemId: 1, flag: 'HiSlot0'),
        asset(itemId: 2, flag: 'Cargo'),
        asset(itemId: 3, flag: 'DroneBay'),
        asset(itemId: 4, flag: 'FighterBay'),
        asset(itemId: 5, flag: 'Hangar', parentItemId: 99, containedInId: null),
      ];
      final match = matcher.match(
        typeId: kCmpModuleC,
        requiredCount: 1,
        encounterCharacterId: pilot,
        selectedLocationId: station,
        assets: stock,
      );
      expect(match.eligibleLooseCount, 0);
      expect(match.eligibility, AarAssetEligibility.fittedOrContained);
      expect(match.estimatedShortfall, 1);
    });

    test('Changes-mode baseline overlap leaves A shortfall unknown', () {
      final match = matcher.match(
        typeId: kCmpModuleA,
        requiredCount: 1,
        encounterCharacterId: pilot,
        selectedLocationId: station,
        assets: [asset(itemId: 88, typeId: kCmpModuleA, quantity: 1)],
        baselineTypeIds: {kCmpModuleA},
        changesMode: true,
      );
      expect(match.eligibility, AarAssetEligibility.baselineOverlap);
      expect(match.estimatedShortfall, isNull);
      expect(match.eligibleLooseCount, isNull);
    });

    test(
      'type absent from complete baseline can still credit hangar stock',
      () {
        final match = matcher.match(
          typeId: kCmpModuleC,
          requiredCount: 1,
          encounterCharacterId: pilot,
          selectedLocationId: station,
          assets: [asset(quantity: 1)],
          baselineTypeIds: {kCmpModuleA, kCmpAmmo},
          changesMode: true,
        );
        expect(match.estimatedShortfall, 0);
        expect(match.eligibleLooseCount, 1);
      },
    );

    test('empty cache is availability unknown, not a verified shortage', () {
      final match = matcher.match(
        typeId: kCmpModuleC,
        requiredCount: 1,
        encounterCharacterId: pilot,
        selectedLocationId: station,
        assets: const [],
      );
      expect(match.disclosure, 'Availability unknown');
      expect(match.estimatedShortfall, isNull);
      expect(match.eligibleLooseCount, isNull);
      expect(match.disclosure, isNot('Not found in cached assets'));
    });
  });

  group('W5 P12 price-only refresh', () {
    test('refresh calls price sync only and keeps cache on failure', () async {
      var prices = 0;
      var orders = 0;
      var assets = 0;
      final prior = [
        AarPriceEstimate.fromQuote(
          AarMarketQuote(
            typeId: kCmpModuleC,
            averagePrice: F2Oracle.cPrice.toDouble(),
            lastUpdated: now,
          ),
          now: now,
        ),
      ];
      final controller = AarPriceRefreshController(
        cached: prior,
        syncPrices: () async {
          prices += 1;
          throw StateError('esi down');
        },
        syncOrders: () async {
          orders += 1;
        },
        syncAssets: () async {
          assets += 1;
        },
      );
      await expectLater(controller.refresh(), throwsA(isA<StateError>()));
      expect(prices, 1);
      expect(orders, 0);
      expect(assets, 0);
      expect(controller.cached, hasLength(1));
      expect(controller.cached.single.typeId, kCmpModuleC);
    });
  });

  group('W5 P10/P11 shares', () {
    const station = 60003760;
    const matcher = AarSpareMatcher();

    test('P11 Q hangar stock is not credited to encounter pilot P', () {
      final match = matcher.match(
        typeId: kCmpModuleC,
        requiredCount: 1,
        encounterCharacterId: 42,
        selectedLocationId: station,
        assets: const [
          AarCachedAsset(
            itemId: 7,
            characterId: 99,
            typeId: kCmpModuleC,
            locationId: station,
            locationFlag: 'Hangar',
            quantity: 4,
          ),
        ],
      );
      expect(match.eligibility, AarAssetEligibility.otherCharacter);
      expect(match.eligibleLooseCount, 0);
      expect(match.estimatedShortfall, 1);
    });

    test(
      'P10 price failure leaves BOM and prior estimates inspectable',
      () async {
        final bom = const FitBillOfMaterials(
          requirements: [FitBomLine(typeId: kCmpModuleC, requiredCount: 1)],
        );
        final prior = [
          AarPriceEstimate.fromQuote(
            AarMarketQuote(
              typeId: kCmpModuleC,
              averagePrice: F2Oracle.cPrice.toDouble(),
              lastUpdated: now,
            ),
            now: now,
          ),
        ];
        final controller = AarPriceRefreshController(
          cached: prior,
          syncPrices: () async {
            throw StateError('offline');
          },
        );
        await expectLater(controller.refresh(), throwsA(anything));
        final priced = const AarBomPricer().price(
          bom: bom,
          estimates: controller.cached,
        );
        expect(bom.requirement(kCmpModuleC)?.requiredCount, 1);
        expect(priced.lines, isNotEmpty);
        expect(
          priced.lines.single.estimate?.unitPrice?.asDouble,
          F2Oracle.cPrice,
        );
      },
    );
  });
}

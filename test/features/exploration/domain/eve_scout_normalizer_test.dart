// X3 RED contracts for EveScoutNormalizer (D08–D11, D24).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §3.2 / product F3:
// - D08: missing far signature copied from hub; null orientation treated as true.
// - D09: remaining_hours 999 drives Stable/EOL instead of expiresAt.
// - D10: completed infers Mass Fresh.
// - D11: int/string ids diverge; HTML and conflicts are accepted.
// - D24: OR filters, case-sensitive region, Unknown dropped from All.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/eve_scout_normalizer.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  const normalizer = EveScoutNormalizer();

  FeedNormalizationResult parse(Object raw, {DateTime? now}) {
    return normalizer.normalize(raw, now: now ?? kExplorationT0);
  }

  NormalizedFeedRecord single(Object raw, {DateTime? now}) {
    final result = parse(raw, now: now);
    expect(result.valid, isTrue);
    expect(result.records, hasLength(1));
    return result.records.single;
  }

  group('D08 orientation and signatures', () {
    test('true/false swap types not systems; null orientation is unknown', () {
      final outward = single([F3Fixtures.wireRecord()]);
      expect(outward.connection.providerKey, F3Fixtures.providerKey);
      expect(outward.connection.hub.systemId, kTurnurSystemId);
      expect(outward.connection.far.systemId, kAlphaSystemId);
      expect(outward.connection.departureType(fromHub: true), 'B274');
      expect(outward.connection.departureType(fromHub: false), 'K162');
      expect(outward.connection.departureSignature(fromHub: true), 'HUB-123');
      expect(outward.connection.departureSignature(fromHub: false), 'FAR-456');

      final inward = single([F3Fixtures.wireRecord(exitsOutward: false)]);
      expect(inward.connection.hub.systemId, kTurnurSystemId);
      expect(inward.connection.far.systemId, kAlphaSystemId);
      expect(inward.connection.departureType(fromHub: true), 'K162');
      expect(inward.connection.departureType(fromHub: false), 'B274');
      expect(inward.connection.departureSignature(fromHub: true), 'HUB-123');
      expect(inward.connection.departureSignature(fromHub: false), 'FAR-456');

      final unknown = single([F3Fixtures.wireRecord(exitsOutward: null)]);
      expect(unknown.connection.exitsOutward, isNull);
      expect(unknown.connection.hub.typeCode, isNull);
      expect(unknown.connection.far.typeCode, isNull);
    });

    test('absent far signature is not copied from the hub', () {
      final row = single([F3Fixtures.wireRecord(inSignature: null)]);
      expect(row.connection.far.signature, isNull);
      expect(row.connection.hub.signature, 'HUB-123');
      expect(row.diagnostics, isNotEmpty);
      expect(row.diagnostics.join(' '), contains('Signature not reported'));
    });
  });

  group('D09 time states ignore remaining_hours 999', () {
    test(
      'T0 is Stable 6h; 4h exact Stable; +1ms EOL; expiry is not Collapsed',
      () {
        final atT0 = single([F3Fixtures.wireRecord()]);
        expect(atT0.connection.time, TimeEstimate.stable);
        expect(atT0.remaining, const Duration(hours: 6));
        expect(atT0.connection.remainingHours, isNull);

        final at4h = single([
          F3Fixtures.wireRecord(),
        ], now: F3Fixtures.stableAt4h);
        expect(at4h.connection.time, TimeEstimate.stable);

        final eol = single([
          F3Fixtures.wireRecord(),
        ], now: F3Fixtures.eolAt4hPlus1ms);
        expect(eol.connection.time, TimeEstimate.eol);

        final expired = single([
          F3Fixtures.wireRecord(),
        ], now: F3Fixtures.expiresAt);
        expect(expired.connection.time, TimeEstimate.expired);
        expect(expired.createsEdge, isFalse);
        expect(expired.diagnostics.join(' '), isNot(contains('Collapsed')));
      },
    );
  });

  group('D10 mass stays Unknown', () {
    test('completed/fresh/size variants never infer Fresh mass', () {
      for (final row in [
        F3Fixtures.wireRecord(),
        F3Fixtures.wireRecord(completed: false),
        F3Fixtures.wireRecord(maxShipSize: 'capital'),
        F3Fixtures.wireRecord(maxShipSize: 'small'),
        F3Fixtures.wireRecord(signatureType: 'wormhole'),
      ]) {
        final parsed = single([row]);
        expect(parsed.connection.mass, MassState.unknown, reason: '$row');
      }
      final unknownSize = single([F3Fixtures.wireRecord(maxShipSize: 'titan')]);
      expect(unknownSize.connection.shipSize, ShipSizeCategory.unknown);
    });
  });

  group('D11 keys, enums, and snapshot rejection', () {
    test('integer 42 and string 42 share evescout:42', () {
      expect(
        single([F3Fixtures.wireRecord(id: 42)]).connection.providerKey,
        F3Fixtures.providerKey,
      );
      expect(
        single([F3Fixtures.wireRecord()]).connection.providerKey,
        F3Fixtures.providerKey,
      );
    });

    test('conflicting duplicates and bad core reject the whole snapshot', () {
      final conflict = parse([
        F3Fixtures.wireRecord(id: 42),
        F3Fixtures.wireRecord(id: '42', expiresAt: '2026-09-16T00:00:00Z'),
      ]);
      expect(conflict.valid, isFalse);
      expect(conflict.records, isEmpty);

      final badHub = parse([
        {...F3Fixtures.wireRecord(), 'out_system_id': 1},
      ]);
      expect(badHub.valid, isFalse);

      final html = parse('<html>nope</html>');
      expect(html.valid, isFalse);

      final incomplete = single([F3Fixtures.wireRecord(completed: false)]);
      expect(incomplete.createsEdge, isFalse);

      final nonWormhole = single([
        F3Fixtures.wireRecord(signatureType: 'combat_site'),
      ]);
      expect(nonWormhole.createsEdge, isFalse);
    });
  });

  group('D24 far-side AND filters and All view', () {
    List<NormalizedFeedRecord> catalog() {
      Map<String, dynamic> row({
        required Object id,
        required int hub,
        required String cls,
        required String region,
        required String updated,
        required String farName,
      }) {
        return {
          ...F3Fixtures.wireRecord(id: id),
          'out_system_id': hub,
          'out_system_name': hub == kTheraSystemId ? 'Thera' : 'Turnur',
          'in_system_class': cls,
          'in_region_name': region,
          'in_system_name': farName,
          'updated_at': updated,
        };
      }

      return parse([
        row(
          id: 'hs1',
          hub: kTurnurSystemId,
          cls: 'hs',
          region: 'Fixture Region',
          updated: '2026-09-15T11:00:00Z',
          farName: 'Alpha',
        ),
        row(
          id: 'ls1',
          hub: kTurnurSystemId,
          cls: 'ls',
          region: 'Fixture Region',
          updated: '2026-09-15T11:10:00Z',
          farName: 'Bravo',
        ),
        row(
          id: 'ns1',
          hub: kTheraSystemId,
          cls: 'ns',
          region: 'Other Region',
          updated: '2026-09-15T11:20:00Z',
          farName: 'Charlie',
        ),
        row(
          id: 'po1',
          hub: kTheraSystemId,
          cls: 'c25',
          region: 'Pochven',
          updated: '2026-09-15T11:30:00Z',
          farName: 'Delta',
        ),
        row(
          id: 'js1',
          hub: kTheraSystemId,
          cls: 'c2',
          region: 'J-Space',
          updated: '2026-09-15T11:40:00Z',
          farName: 'Echo',
        ),
        row(
          id: 'un1',
          hub: kTurnurSystemId,
          cls: 'mystery',
          region: 'Fixture Region',
          updated: '2026-09-15T11:50:00Z',
          farName: 'Foxtrot',
        ),
      ]).records;
    }

    test('All includes Unknown; AND hub+category+region; stable sort', () {
      final rows = catalog();
      final all = const PublicConnectionFilter().select(rows);
      expect(all.map((row) => row.connection.providerKey), [
        'evescout:un1',
        'evescout:js1',
        'evescout:po1',
        'evescout:ns1',
        'evescout:ls1',
        'evescout:hs1',
      ]);
      expect(
        all.any((row) => row.farCategory == FarSideCategory.unknown),
        isTrue,
      );

      final anded = const PublicConnectionFilter(
        hubSystemId: kTurnurSystemId,
        regionSubstring: 'fIxTuRe',
      ).select(rows, farCategory: FarSideCategory.highsec);
      expect(anded.map((row) => row.connection.providerKey), ['evescout:hs1']);
    });
  });
}

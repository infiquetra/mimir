import '../../../fixtures/corporation/corporation_fixtures.dart';
import 'fake_corporation_clock.dart';
import 'recording_esi_transport.dart';

/// C0 skeleton harness. Owns clock and recording transport; later units attach
/// real AppDatabase connections and the Corporation host.
class CorporationTestHarness {
  CorporationTestHarness();

  late FakeCorporationClock clock;
  late RecordingEsiTransport transport;

  static final t0 = kCorporationT0;

  Future<void> setUp() async {
    clock = FakeCorporationClock(now: t0);
    transport = RecordingEsiTransport();
  }

  Future<void> tearDown() async {
    transport.assertNoWrites();
  }
}

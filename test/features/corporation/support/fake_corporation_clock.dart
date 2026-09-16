/// Frozen injectable UTC clock. Naive wall-clock is never used by tests.
class FakeCorporationClock {
  FakeCorporationClock({DateTime? now})
    : _now = (now ?? DateTime.utc(2026, 9, 15, 12)).toUtc();

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  void setNow(DateTime value) {
    _now = value.toUtc();
  }
}

import 'dart:math';

/// Result of a capacitor simulation.
class CapSimResult {
  const CapSimResult({
    required this.isStable,
    required this.stablePercent,
    required this.secondsToEmpty,
  });

  /// True when the capacitor settles into a repeating cycle above zero.
  final bool isStable;

  /// Midpoint of the stable cycle's low/high water marks, in percent of
  /// capacity. Zero when unstable.
  final double stablePercent;

  /// Seconds until the capacitor empties when unstable. Zero when stable.
  final double secondsToEmpty;
}

/// A repeating capacitor drain: one module cycle.
class CapDrain {
  const CapDrain({
    required this.durationMs,
    required this.capNeed,
    this.count = 1,
  });

  /// Cycle time in milliseconds.
  final double durationMs;

  /// Capacitor energy consumed per activation, in GJ.
  final double capNeed;

  /// Number of identical modules sharing this cycle.
  final int count;
}

/// Event-driven capacitor simulator, a faithful port of pyfa's
/// `eos/capSim.py` (the de-facto reference implementation) restricted to
/// repeating module drains: no cap injectors, no reloads.
///
/// Recharge between events uses pyfa's closed form
/// `cap = ((1 + (sqrt(cap/C) - 1) * exp(-(dt)/tau))^2) * C` with
/// `tau = rechargeTime / 5`. Identical modules are staggered the way pyfa
/// does (one activation every duration/count); different modules keep their
/// own cadence. Stability is detected when the cap at a whole LCM period is
/// no lower than at the previous one; otherwise the sim ends when cap goes
/// negative.
class CapSimulator {
  CapSimulator({
    required this.capacity,
    required this.rechargeMs,
    required this.drains,
    this.maxSeconds = 3600,
  });

  final double capacity;
  final double rechargeMs;
  final List<CapDrain> drains;
  final double maxSeconds;

  CapSimResult run() {
    if (capacity <= 0 || rechargeMs <= 0) {
      return const CapSimResult(
        isStable: true,
        stablePercent: 0,
        secondsToEmpty: 0,
      );
    }
    final active = drains.where((d) => d.capNeed > 0 && d.durationMs > 0);
    if (active.isEmpty) {
      return const CapSimResult(
        isStable: true,
        stablePercent: 100,
        secondsToEmpty: 0,
      );
    }

    final tau = rechargeMs / 5.0;
    final maxMs = maxSeconds * 1000.0;

    // pyfa staggering: identical modules fire as one module with the
    // duration divided by the count; distinct modules keep their cadence.
    final events = <List<double>>[];
    var period = 1.0;
    for (final drain in active) {
      final duration = drain.count > 1
          ? (drain.durationMs / drain.count).floorToDouble()
          : drain.durationMs;
      events.add([0.0, duration, drain.capNeed]);
      period = _lcm(period, duration);
    }
    events.sort((a, b) => a[0].compareTo(b[0]));

    var cap = capacity;
    var capLowest = capacity;
    var capLowestPre = capacity;
    var capWrap = capacity;
    var tLast = 0.0;
    var tWrap = period;
    var tEnd = 0.0;

    while (events.isNotEmpty) {
      events.sort((a, b) => a[0].compareTo(b[0]));
      final event = events.removeAt(0);
      final tNow = event[0];
      if (tNow >= maxMs) {
        tEnd = maxMs;
        return CapSimResult(
          isStable: true,
          stablePercent: _stablePercent(capLowest, capLowestPre),
          secondsToEmpty: 0,
        );
      }

      if (tNow > tLast) {
        cap = _recharge(cap, tNow - tLast, tau);
      }
      if (tNow != tLast) {
        if (cap < capLowestPre) capLowestPre = cap;
        if (tNow == tWrap) {
          // History repeats: if we have at least as much cap as last
          // period, the setup is stable.
          if (cap >= capWrap) {
            return CapSimResult(
              isStable: true,
              stablePercent: _stablePercent(capLowest, capLowestPre),
              secondsToEmpty: 0,
            );
          }
          capWrap = cap;
          tWrap += period;
        }
      }
      tLast = tNow;

      cap -= event[2];
      if (cap < 0) {
        return CapSimResult(
          isStable: false,
          stablePercent: 0,
          secondsToEmpty: tLast / 1000.0,
        );
      }
      if (cap < capLowest) capLowest = cap;

      event[0] = tNow + event[1];
      events.add(event);
      tEnd = tLast;
    }

    return CapSimResult(
      isStable: true,
      stablePercent: _stablePercent(capLowest, capLowestPre),
      secondsToEmpty: tEnd / 1000.0,
    );
  }

  double _stablePercent(double low, double high) =>
      ((low + high) / (2 * capacity)) * 100;

  double _recharge(double cap, double dtMs, double tau) {
    final ratio = cap / capacity;
    final factor = 1.0 + (sqrt(ratio) - 1.0) * exp(-dtMs / tau);
    return factor * factor * capacity;
  }

  static double _lcm(double a, double b) {
    var x = a.round();
    var y = b.round();
    if (x == 0 || y == 0) return a;
    final product = x * y;
    while (y != 0) {
      final t = y;
      y = x % y;
      x = t;
    }
    return (product / x).toDouble();
  }
}

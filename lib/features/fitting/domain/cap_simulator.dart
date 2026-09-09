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

  /// Full cycle time in milliseconds (activation plus reactivation delay).
  final double durationMs;

  /// Capacitor energy consumed per activation, in GJ.
  final double capNeed;

  /// Number of identical modules sharing this cycle.
  final int count;
}

/// A capacitor booster: held in reserve and fired on demand when the
/// capacitor cannot pay a drain, exactly like pyfa's capSim injectors.
class CapInjector {
  const CapInjector({required this.durationMs, required this.capGain});

  /// Cycle time in milliseconds (activation plus reload).
  final double durationMs;

  /// Capacitor energy restored per activation, in GJ.
  final double capGain;
}

class _CapEvent {
  _CapEvent({
    required this.t,
    required this.duration,
    required this.capNeed,
    required this.isInjector,
  });

  double t;
  final double duration;

  /// Positive for drains, negative for injectors.
  final double capNeed;
  final bool isInjector;
}

/// Event-driven capacitor simulator, a faithful port of pyfa's
/// `eos/capSim.py` restricted to repeating module drains and on-demand cap
/// boosters: no reloads (charge quantities are not part of a fitting, so
/// clips are treated as infinite — a stocked-boosters assumption).
///
/// Recharge between events uses pyfa's closed form
/// `cap = ((1 + (sqrt(cap/C) - 1) * exp(-(dt)/tau))^2) * C` with
/// `tau = rechargeTime / 5`. Identical drains are staggered the way pyfa
/// does (one activation every duration/count); injectors are postponed
/// while their gain would overshoot capacity and fire the moment a drain
/// cannot be paid. Stability is detected when the cap at a whole LCM period
/// (with an identical set of postponed injectors) is no lower than at the
/// previous one; otherwise the sim ends when cap goes negative.
class CapSimulator {
  CapSimulator({
    required this.capacity,
    required this.rechargeMs,
    required this.drains,
    this.injectors = const [],
    this.maxSeconds = 3600,
  });

  final double capacity;
  final double rechargeMs;
  final List<CapDrain> drains;
  final List<CapInjector> injectors;
  final double maxSeconds;

  CapSimResult run() {
    if (capacity <= 0 || rechargeMs <= 0) {
      return const CapSimResult(
        isStable: true,
        stablePercent: 0,
        secondsToEmpty: 0,
      );
    }
    final activeDrains = drains.where((d) => d.capNeed > 0 && d.durationMs > 0);
    final activeInjectors = injectors.where(
      (i) => i.capGain > 0 && i.durationMs > 0,
    );
    if (activeDrains.isEmpty && activeInjectors.isEmpty) {
      return const CapSimResult(
        isStable: true,
        stablePercent: 100,
        secondsToEmpty: 0,
      );
    }

    final tau = rechargeMs / 5.0;
    final maxMs = maxSeconds * 1000.0;

    final queue = <_CapEvent>[];
    var period = 1.0;
    for (final drain in activeDrains) {
      final duration = drain.count > 1
          ? (drain.durationMs / drain.count).floorToDouble()
          : drain.durationMs;
      queue.add(
        _CapEvent(
          t: 0.0,
          duration: duration,
          capNeed: drain.capNeed,
          isInjector: false,
        ),
      );
      period = _lcm(period, duration);
    }
    for (final injector in activeInjectors) {
      queue.add(
        _CapEvent(
          t: 0.0,
          duration: injector.durationMs,
          capNeed: -injector.capGain,
          isInjector: true,
        ),
      );
      period = _lcm(period, injector.durationMs);
    }
    queue.sort((a, b) => a.t.compareTo(b.t));

    var cap = capacity;
    var capLowest = capacity;
    var capLowestPre = capacity;
    var capWrap = capacity;
    var tLast = 0.0;
    var tWrap = period;
    final awaiting = <_CapEvent>[];
    var awaitingWrapSignature = '';

    String awaitingSignature() {
      final gains = awaiting.map((e) => e.capNeed.toStringAsFixed(3)).toList()
        ..sort();
      return gains.join(',');
    }

    void reschedule(_CapEvent event, double tNow) {
      // Infinite clips in this model: no reload time to add.
      event.t = tNow + event.duration;
      queue.add(event);
    }

    // Fire a postponed booster right now, pyfa-style: prefer the smallest
    // gain that covers the shortfall, else the largest gain available.
    void fireBestInjector(double neededInjection, double tNow) {
      final good = awaiting
          .where((i) => -i.capNeed >= neededInjection)
          .toList();
      final best = good.isNotEmpty
          ? good.reduce((a, b) => -a.capNeed <= -b.capNeed ? a : b)
          : awaiting.reduce((a, b) => -a.capNeed >= -b.capNeed ? a : b);
      awaiting.remove(best);
      cap = min(capacity, cap - best.capNeed);
      reschedule(best, tNow);
    }

    while (queue.isNotEmpty) {
      queue.sort((a, b) => a.t.compareTo(b.t));
      final event = queue.removeAt(0);
      final tNow = event.t;
      if (tNow >= maxMs) {
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
          // period, with the same boosters postponed, the setup is stable.
          final signature = awaitingSignature();
          if (cap >= capWrap && signature == awaitingWrapSignature) {
            return CapSimResult(
              isStable: true,
              stablePercent: _stablePercent(capLowest, capLowestPre),
              secondsToEmpty: 0,
            );
          }
          capWrap = cap;
          awaitingWrapSignature = signature;
          tWrap += period;
        }
      }
      tLast = tNow;

      // Injecting would overshoot max cap: postpone the booster.
      if (event.isInjector && cap - event.capNeed > capacity) {
        awaiting.add(event);
        continue;
      }

      // Cannot pay the drain: top up from postponed boosters first.
      if (event.capNeed > cap && cap < capacity) {
        while (awaiting.isNotEmpty && event.capNeed > cap && cap < capacity) {
          final neededInjection = min(event.capNeed - cap, capacity - cap);
          fireBestInjector(neededInjection, tNow);
        }
      }

      cap -= event.capNeed;
      if (cap > capacity) cap = capacity;
      if (cap < capLowest) {
        if (cap < 0.0) {
          return CapSimResult(
            isStable: false,
            stablePercent: 0,
            secondsToEmpty: tLast / 1000.0,
          );
        }
        capLowest = cap;
      }

      // After spending, top up towards full without overshooting.
      while (awaiting.isNotEmpty && cap < capacity) {
        final neededInjection = capacity - cap;
        final good = awaiting
            .where((i) => -i.capNeed <= neededInjection)
            .toList();
        if (good.isEmpty) break;
        final best = good.reduce((a, b) => -a.capNeed >= -b.capNeed ? a : b);
        awaiting.remove(best);
        cap = min(capacity, cap - best.capNeed);
        reschedule(best, tNow);
      }

      reschedule(event, tNow);
    }

    // Only postponed boosters left: nothing else ever fires again.
    return CapSimResult(
      isStable: true,
      stablePercent: _stablePercent(capLowest, capLowestPre),
      secondsToEmpty: 0,
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

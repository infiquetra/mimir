import '../../../core/logging/logger.dart';
import '../../fitting/domain/models.dart';

enum TankLayer { shield, armor, hull, unknown }

enum TankMode { active, buffer, unfitted }

class TankAssessment {
  const TankAssessment({
    required this.layer,
    required this.mode,
    required this.shieldBoostHps,
    required this.armorRepairHps,
    required this.hullRepairHps,
    required this.shieldGainEhp,
    required this.armorGainEhp,
    required this.hullGainEhp,
    required this.reasoning,
  });

  final TankLayer layer;
  final TankMode mode;
  final double shieldBoostHps;
  final double armorRepairHps;
  final double hullRepairHps;
  final double shieldGainEhp;
  final double armorGainEhp;
  final double hullGainEhp;
  final String reasoning;

  String get label {
    final name = layer.name;
    final titled = '${name[0].toUpperCase()}${name.substring(1)}';
    return '$titled (${mode.name})';
  }
}

class TankClassifier {
  static const double minGainEhp = 0.5;

  /// R4.2: active HP/s, then omni-EHP gain vs bare hull, then largest layer.
  static TankAssessment classify({
    required FittingStats fit,
    required FittingStats baseline,
  }) {
    Log.d(
      'AAR',
      'TankClassifier.classify shieldBoost=${fit.defenses.effectiveShieldBoost} '
          'armorRepair=${fit.defenses.effectiveArmorRepair} '
          'hullRepair=${fit.defenses.effectiveHullRepair}',
    );

    final shieldBoostHps = fit.defenses.effectiveShieldBoost;
    final armorRepairHps = fit.defenses.effectiveArmorRepair;
    final hullRepairHps = fit.defenses.effectiveHullRepair;
    final shieldGainEhp = fit.defenses.shieldEhp - baseline.defenses.shieldEhp;
    final armorGainEhp = fit.defenses.armorEhp - baseline.defenses.armorEhp;
    final hullGainEhp = fit.defenses.hullEhp - baseline.defenses.hullEhp;

    late final TankLayer layer;
    late final TankMode mode;

    if (fit.defenses.shieldEhp <= 0 &&
        fit.defenses.armorEhp <= 0 &&
        fit.defenses.hullEhp <= 0) {
      layer = TankLayer.unknown;
      mode = TankMode.unfitted;
    } else {
      final active = <TankLayer, double>{
        TankLayer.shield: shieldBoostHps,
        TankLayer.armor: armorRepairHps,
        TankLayer.hull: hullRepairHps,
      };
      final maxActive = active.values.reduce((a, b) => a > b ? a : b);
      if (maxActive > 0) {
        mode = TankMode.active;
        layer = _pick(
          active,
          maxActive,
          ehpOf: (l) => _ehp(fit, l),
          tieOrder: const [TankLayer.armor, TankLayer.shield, TankLayer.hull],
        );
      } else {
        final gain = <TankLayer, double>{
          TankLayer.shield: shieldGainEhp,
          TankLayer.armor: armorGainEhp,
          TankLayer.hull: hullGainEhp,
        };
        final maxGain = gain.values.reduce((a, b) => a > b ? a : b);
        if (maxGain > minGainEhp) {
          mode = TankMode.buffer;
          layer = _pick(
            gain,
            maxGain,
            ehpOf: (l) => _ehp(fit, l),
            tieOrder: const [TankLayer.shield, TankLayer.armor, TankLayer.hull],
          );
        } else {
          mode = TankMode.unfitted;
          final ehp = <TankLayer, double>{
            TankLayer.shield: fit.defenses.shieldEhp,
            TankLayer.armor: fit.defenses.armorEhp,
            TankLayer.hull: fit.defenses.hullEhp,
          };
          final maxEhp = ehp.values.reduce((a, b) => a > b ? a : b);
          layer = _pick(
            ehp,
            maxEhp,
            ehpOf: (l) => _ehp(fit, l),
            tieOrder: const [TankLayer.shield, TankLayer.armor, TankLayer.hull],
          );
        }
      }
    }

    final assessment = TankAssessment(
      layer: layer,
      mode: mode,
      shieldBoostHps: shieldBoostHps,
      armorRepairHps: armorRepairHps,
      hullRepairHps: hullRepairHps,
      shieldGainEhp: shieldGainEhp,
      armorGainEhp: armorGainEhp,
      hullGainEhp: hullGainEhp,
      reasoning: _reasoning(
        layer: layer,
        mode: mode,
        shieldBoostHps: shieldBoostHps,
        armorRepairHps: armorRepairHps,
        hullRepairHps: hullRepairHps,
        shieldGainEhp: shieldGainEhp,
        armorGainEhp: armorGainEhp,
        hullGainEhp: hullGainEhp,
        fit: fit,
      ),
    );
    Log.d('AAR', 'TankClassifier result ${assessment.label}');
    return assessment;
  }

  static double _ehp(FittingStats stats, TankLayer layer) {
    return switch (layer) {
      TankLayer.shield => stats.defenses.shieldEhp,
      TankLayer.armor => stats.defenses.armorEhp,
      TankLayer.hull => stats.defenses.hullEhp,
      TankLayer.unknown => 0,
    };
  }

  static TankLayer _pick(
    Map<TankLayer, double> scores,
    double target, {
    required double Function(TankLayer) ehpOf,
    required List<TankLayer> tieOrder,
  }) {
    final tied = [
      for (final layer in tieOrder)
        if ((scores[layer] ?? 0) == target) layer,
    ];
    tied.sort((a, b) {
      final ehp = ehpOf(b).compareTo(ehpOf(a));
      if (ehp != 0) return ehp;
      return tieOrder.indexOf(a).compareTo(tieOrder.indexOf(b));
    });
    return tied.first;
  }

  static String _reasoning({
    required TankLayer layer,
    required TankMode mode,
    required double shieldBoostHps,
    required double armorRepairHps,
    required double hullRepairHps,
    required double shieldGainEhp,
    required double armorGainEhp,
    required double hullGainEhp,
    required FittingStats fit,
  }) {
    final title = TankAssessment(
      layer: layer,
      mode: mode,
      shieldBoostHps: shieldBoostHps,
      armorRepairHps: armorRepairHps,
      hullRepairHps: hullRepairHps,
      shieldGainEhp: shieldGainEhp,
      armorGainEhp: armorGainEhp,
      hullGainEhp: hullGainEhp,
      reasoning: '',
    ).label;
    final gains =
        'buffer gains shield ${_fmtGain(shieldGainEhp)} / '
        'armor ${_fmtGain(armorGainEhp)} / hull ${_fmtGain(hullGainEhp)} EHP';
    if (layer == TankLayer.unknown) {
      return '$title: no positive HP on any layer.';
    }
    if (mode == TankMode.active) {
      return '$title: ${_fmtRate(armorRepairHps)} HP/s armor repair vs '
          '${_fmtRate(shieldBoostHps)} shield boost, '
          '${_fmtRate(hullRepairHps)} hull repair; $gains.';
    }
    if (mode == TankMode.buffer) {
      return '$title: no active tank; $gains.';
    }
    final ehp = _ehp(fit, layer);
    return '$title: no active tank and no buffer investment; '
        '${layer.name} omni EHP ${_fmtRate(ehp)} is the largest layer.';
  }

  static String _fmtRate(double value) => value.toStringAsFixed(1);

  static String _fmtGain(double value) {
    final n = value.round();
    final sign = n >= 0 ? '+' : '-';
    return '$sign${_comma(n.abs())}';
  }

  static String _comma(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

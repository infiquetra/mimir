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

  /// U2 stub: Devs implement the R4.2 rule in design §3.2.
  static TankAssessment classify({
    required FittingStats fit,
    required FittingStats baseline,
  }) {
    return const TankAssessment(
      layer: TankLayer.shield,
      mode: TankMode.unfitted,
      shieldBoostHps: 0,
      armorRepairHps: 0,
      hullRepairHps: 0,
      shieldGainEhp: 0,
      armorGainEhp: 0,
      hullGainEhp: 0,
      reasoning: '',
    );
  }
}

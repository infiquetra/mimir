import '../../../core/logging/logger.dart';
import '../../fitting/data/fitting_stats_inputs.dart';
import '../../fitting/domain/dogma_engine.dart';
import '../../fitting/domain/models.dart';
import 'aar_fit_derivation.dart';
import 'combat_evidence_ledger.dart';
import 'tank_classifier.dart';

class CombatFitDeriver {
  const CombatFitDeriver({this.engine});

  final DogmaEngine? engine;

  /// Pure: no I/O. Runs the engine on the evidence fit and on a bare hull.
  Future<AarFitDerivation> derive({
    required FitEvidence evidence,
    required AarFitSubject subject,
    required FittingStatsInputs inputs,
    required AarSkillContext skills,
    DateTime? now,
  }) async {
    final fitting = evidence.fitting;
    Log.d(
      'AAR.DERIVE',
      'derive role=${evidence.role.name} subject=${subject.name} '
          'ship=${fitting.shipName} skills=${skills.basis.name} '
          'modules=${fitting.allModules.length}',
    );

    final dogma = engine ?? DogmaEngine();
    final stats = await dogma.calculateStats(
      fitting,
      inputs.shipType,
      inputs.moduleTypes,
      skills.skills,
      effectModifiers: inputs.effectModifiers,
      skillTypes: inputs.skillTypes,
    );
    final baseline = await dogma.calculateStats(
      Fitting(
        id: '${fitting.id}-baseline',
        name: 'baseline',
        shipTypeId: fitting.shipTypeId,
        shipName: fitting.shipName,
      ),
      inputs.shipType,
      const {},
      skills.skills,
      effectModifiers: inputs.effectModifiers,
      skillTypes: inputs.skillTypes,
    );
    final tank = TankClassifier.classify(fit: stats, baseline: baseline);
    final coverage = AarFitCoverage.of(
      fitting,
      inputs.shipType,
      inputs.unresolved,
    );

    final limitations = <String>[
      skills.label,
      'Module states from evidence are assumed active',
    ];
    if (coverage.hasUnresolved) {
      limitations.add(
        '${coverage.unresolvedTypeIds.length} modules not in the SDE were ignored; EHP and DPS are a floor',
      );
    }
    if (_hasAncillary(fitting, inputs)) {
      limitations.add(
        'Ancillary reload, overheat and clip reloads are not modelled',
      );
    }

    Log.i(
      'AAR.DERIVE',
      'derived ${fitting.shipName} EHP=${stats.defenses.totalEhp.toStringAsFixed(0)} '
          'DPS=${stats.dpsTotal.toStringAsFixed(1)} tank=${tank.label}',
    );

    return AarFitDerivation(
      role: evidence.role,
      subject: subject,
      fitSource: evidence.source,
      shipTypeId: fitting.shipTypeId,
      shipName: fitting.shipName,
      skills: skills,
      stats: stats,
      baseline: baseline,
      tank: tank,
      coverage: coverage,
      derivedAt: now ?? DateTime.now().toUtc(),
      limitations: limitations,
    );
  }

  static bool _hasAncillary(Fitting fitting, FittingStatsInputs inputs) {
    const ancillaryEffects = {5275, 4936};
    for (final module in fitting.allModules) {
      final type = inputs.moduleTypes[module.typeId.toString()];
      if (type == null) continue;
      if (type.effects.any((e) => ancillaryEffects.contains(e.effectId))) {
        return true;
      }
    }
    return false;
  }
}

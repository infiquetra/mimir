import '../../../core/logging/logger.dart';
import '../../fitting/data/fitting_stats_inputs.dart';
import '../../fitting/domain/dogma_engine.dart';
import '../../fitting/domain/models.dart';
import 'aar_fit_calculation.dart';
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

    final computation = await deriveFitting(
      fitting: fitting,
      inputs: inputs,
      skills: skills,
      canonicalizeDeployment: false,
    );
    final limitations = <String>[
      skills.label,
      'Module states from evidence are assumed active',
      ...computation.diagnostics,
    ];
    if (computation.coverage.hasUnresolved) {
      limitations.add(
        '${computation.coverage.unresolvedTypeIds.length} modules not in the SDE were ignored; EHP and DPS are a floor',
      );
    }
    if (_hasAncillary(fitting, inputs)) {
      limitations.add(
        'Ancillary reload, overheat and clip reloads are not modelled',
      );
    }

    Log.i(
      'AAR.DERIVE',
      'derived ${fitting.shipName} EHP=${computation.stats.defenses.totalEhp.toStringAsFixed(0)} '
          'DPS=${computation.stats.dpsTotal.toStringAsFixed(1)} tank=${computation.tank.label}',
    );

    return AarFitDerivation(
      role: evidence.role,
      subject: subject,
      fitSource: evidence.source,
      shipTypeId: fitting.shipTypeId,
      shipName: fitting.shipName,
      skills: skills,
      stats: computation.stats,
      baseline: computation.bareHullStats,
      tank: computation.tank,
      coverage: computation.coverage,
      derivedAt: now ?? DateTime.now().toUtc(),
      limitations: limitations,
    );
  }

  Future<CombatFitComputation> deriveFitting({
    required Fitting fitting,
    required FittingStatsInputs inputs,
    required AarSkillContext skills,
    bool canonicalizeDeployment = true,
  }) async {
    final working = canonicalizeDeployment
        ? _withCanonicalDeployment(fitting)
        : fitting;
    final dogma = engine ?? DogmaEngine();
    final detailed = await dogma.calculateDetailedStats(
      working,
      inputs.shipType,
      inputs.moduleTypes,
      skills.skills,
      effectModifiers: inputs.effectModifiers,
      skillTypes: inputs.skillTypes,
    );
    final bareHull = await dogma.calculateDetailedStats(
      Fitting(
        id: '${working.id}-baseline',
        name: 'baseline',
        shipTypeId: working.shipTypeId,
        shipName: working.shipName,
      ),
      inputs.shipType,
      const {},
      skills.skills,
      effectModifiers: inputs.effectModifiers,
      skillTypes: inputs.skillTypes,
    );
    final tank = TankClassifier.classify(
      fit: detailed.stats,
      baseline: bareHull.stats,
    );
    final coverage = AarFitCoverage.of(
      working,
      inputs.shipType,
      inputs.unresolved,
    );
    final diagnostics = <String>[
      ...detailed.diagnostics,
      ...bareHull.diagnostics,
      if (inputs.unavailableEffectIds.isNotEmpty)
        '${inputs.unavailableEffectIds.length} effects unavailable locally',
    ];
    return CombatFitComputation(
      stats: detailed.stats,
      bareHullStats: bareHull.stats,
      tank: tank,
      coverage: coverage,
      diagnostics: diagnostics,
    );
  }

  static Fitting _withCanonicalDeployment(Fitting fitting) {
    return Fitting(
      id: fitting.id,
      name: fitting.name,
      description: fitting.description,
      shipTypeId: fitting.shipTypeId,
      shipName: fitting.shipName,
      highSlots: List<FittedModule>.from(fitting.highSlots),
      medSlots: List<FittedModule>.from(fitting.medSlots),
      lowSlots: List<FittedModule>.from(fitting.lowSlots),
      rigSlots: List<FittedModule>.from(fitting.rigSlots),
      subsystems: List<FittedModule>.from(fitting.subsystems),
      drones: AarComparisonMetrics.canonicalDrones(fitting.drones),
      fighters: AarComparisonMetrics.canonicalFighters(fitting.fighters),
      cargo: List<CargoItem>.from(fitting.cargo),
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

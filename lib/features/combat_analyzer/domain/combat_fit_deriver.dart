import '../../fitting/data/fitting_stats_inputs.dart';
import '../../fitting/domain/dogma_engine.dart';
import 'aar_fit_derivation.dart';
import 'combat_evidence_ledger.dart';

class CombatFitDeriver {
  const CombatFitDeriver({this.engine});

  final DogmaEngine? engine;

  /// Pure: no I/O. Runs the engine on the evidence fit and on a bare hull.
  ///
  /// U2 stub: Devs implement per design §3.3.
  Future<AarFitDerivation> derive({
    required FitEvidence evidence,
    required AarFitSubject subject,
    required FittingStatsInputs inputs,
    required AarSkillContext skills,
    DateTime? now,
  }) async {
    throw UnimplementedError('U2: CombatFitDeriver.derive');
  }
}

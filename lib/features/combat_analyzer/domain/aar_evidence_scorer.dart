import '../../../core/logging/logger.dart';
import 'aar_evidence_assessment.dart';
import 'aar_fit_derivation.dart';
import 'combat_damage_profile.dart';
import 'combat_enrichment.dart';
import 'combat_evidence_ledger.dart';
import 'parsed_combat_encounter.dart';

class AarEvidenceInputs {
  const AarEvidenceInputs({
    required this.encounter,
    required this.enrichment,
    required this.bundle,
    required this.incoming,
    required this.outgoing,
  });

  final ParsedCombatEncounter encounter;
  final CombatEnrichment? enrichment;
  final AarDerivationBundle bundle;
  final CombatDamageProfile incoming;
  final CombatDamageProfile outgoing;
}

enum _IdentityKind {
  noCharacter,
  notSearched,
  needsReauth,
  ambiguous,
  matchedHigh,
  matchedLow,
  noKillmail,
}

class AarEvidenceScorer {
  const AarEvidenceScorer();

  AarEvidenceAssessment assess(AarEvidenceInputs inputs) {
    Log.d('AAR.EVIDENCE', 'assess(encounter=${inputs.encounter.id}) - START');
    final assessment = combine([
      pilotFit(inputs),
      combatLog(inputs.encounter),
      opponentIdentity(inputs),
      opponentFit(inputs),
      damageProfile(inputs),
    ]);
    Log.i('AAR.EVIDENCE', assessment.logLine);
    return assessment;
  }

  static AarEvidenceAssessment combine(
    List<AarEvidenceDimensionResult> results,
  ) {
    if (results.length != AarEvidenceDimension.values.length) {
      throw ArgumentError.value(
        results.length,
        'results',
        'exactly one result per dimension is required',
      );
    }
    final seen = <AarEvidenceDimension>{};
    final byDimension = <AarEvidenceDimension, AarEvidenceDimensionResult>{};
    for (final result in results) {
      if (!seen.add(result.dimension)) {
        throw ArgumentError.value(
          result.dimension,
          'results',
          'duplicate dimension',
        );
      }
      byDimension[result.dimension] = result;
    }
    if (seen.length != AarEvidenceDimension.values.length) {
      throw ArgumentError('results must cover every dimension');
    }
    final dimensions = [
      for (final dimension in AarEvidenceDimension.values)
        byDimension[dimension]!,
    ];
    var earned = 0.0;
    var available = 0;
    var capped = false;
    for (final row in dimensions) {
      if (row.status == AarEvidenceStatus.unavailable) {
        capped = true;
        continue;
      }
      earned += row.earned;
      available += row.weight;
    }
    final score = available == 0 ? 0 : ((100 * earned) / available).round();
    return AarEvidenceAssessment(
      dimensions: dimensions,
      score: score,
      band: AarEvidenceBand.of(score),
      capped: capped,
      earned: earned,
      available: available,
    );
  }

  static AarEvidenceDimensionResult pilotFit(AarEvidenceInputs inputs) {
    const dimension = AarEvidenceDimension.pilotFit;
    const attachActions = [
      AarEvidenceAction.useCurrentFit,
      AarEvidenceAction.importFit,
    ];
    final evidence = _selfEvidence(inputs);
    if (evidence == null) {
      return const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.missing,
        detail: 'No pilot fit attached for this fight.',
        actions: attachActions,
      );
    }
    final derived = inputs.bundle.self;
    if (derived == null) {
      final failure = _fitFailure(inputs, AarUnknownCategory.pilotFit);
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.missing,
        detail: failure?.detail ?? 'Fit derivation failed.',
        actions: attachActions,
      );
    }
    if (evidence.confidence == EvidenceConfidence.derived ||
        evidence.confidence == EvidenceConfidence.reference ||
        evidence.confidence == EvidenceConfidence.unknown) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.inferred,
        detail: _inferredPilotDetail(evidence),
        actions: attachActions,
      );
    }
    final source = _pilotSourceLabel(evidence, inputs.enrichment);
    if (derived.coverage.hasUnresolved) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.partial,
        detail:
            '$source; ${_unresolvedModules(derived)}; slots ${derived.coverage.describe()}',
      );
    }
    if (derived.skills.basis == AarSkillBasis.allFive) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.partial,
        detail:
            '$source; skills assumed All V (trained skills not loaded for this character); slots ${derived.coverage.describe()}',
      );
    }
    return AarEvidenceDimensionResult(
      dimension: dimension,
      status: AarEvidenceStatus.complete,
      detail: '$source; slots ${derived.coverage.describe()}',
    );
  }

  static AarEvidenceDimensionResult combatLog(ParsedCombatEncounter encounter) {
    final n = encounter.events
        .where(
          (event) => event.kind == CombatEventKind.damage && event.amount > 0,
        )
        .length;
    final incoming = encounter.events.any((event) => event.isIncomingDamage);
    final outgoing = encounter.events.any((event) => event.isOutgoingDamage);
    final dirs = incoming && outgoing
        ? 'both directions'
        : incoming
        ? 'incoming only'
        : outgoing
        ? 'outgoing only'
        : 'no damage events';
    final complete =
        n >= AarEvidenceRules.minDamageEventsForComplete &&
        incoming &&
        outgoing;
    final fewer = n < AarEvidenceRules.minDamageEventsForComplete
        ? ' (fewer than ${AarEvidenceRules.minDamageEventsForComplete})'
        : '';
    return AarEvidenceDimensionResult(
      dimension: AarEvidenceDimension.combatLog,
      status: complete ? AarEvidenceStatus.complete : AarEvidenceStatus.partial,
      detail:
          '$n damage events over ${encounter.durationSeconds}s, $dirs${complete ? '' : fewer}',
    );
  }

  static AarEvidenceDimensionResult opponentIdentity(AarEvidenceInputs inputs) {
    const dimension = AarEvidenceDimension.opponentIdentity;
    final enrichment = inputs.enrichment;
    final kind = _identityKind(inputs);
    final pct = ((enrichment?.matchConfidence ?? 0) * 100).round();
    return switch (kind) {
      _IdentityKind.matchedHigh => AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.complete,
        detail: _matchedIdentityDetail(enrichment, pct, lowConfidence: false),
      ),
      _IdentityKind.matchedLow => AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.partial,
        detail: _matchedIdentityDetail(enrichment, pct, lowConfidence: true),
      ),
      _IdentityKind.ambiguous => AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.partial,
        detail: 'Ambiguous killmail match: ${enrichment?.matchReason ?? ''}',
      ),
      _IdentityKind.needsReauth => const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.missing,
        detail:
            'Killmail scope is missing for this character; reauthorize to search ESI killmails.',
        actions: [AarEvidenceAction.reauthorize],
      ),
      _IdentityKind.notSearched => const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.missing,
        detail: 'Killmail search has not run for this encounter.',
        actions: [AarEvidenceAction.searchKillmails],
      ),
      _IdentityKind.noKillmail => AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.unavailable,
        detail:
            enrichment?.matchReason ?? 'No killmail matched this encounter.',
      ),
      _IdentityKind.noCharacter => const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.unavailable,
        detail:
            'This log is not linked to an authenticated character, so killmails cannot be searched.',
      ),
    };
  }

  static AarEvidenceDimensionResult opponentFit(AarEvidenceInputs inputs) {
    const dimension = AarEvidenceDimension.opponentFit;
    final kind = _identityKind(inputs);
    final enrichment = inputs.enrichment;
    if (kind == _IdentityKind.noKillmail || kind == _IdentityKind.noCharacter) {
      return const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.unavailable,
        detail: 'No opponent identified; there is no fit to derive.',
      );
    }
    if (kind == _IdentityKind.ambiguous) {
      return const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.unavailable,
        detail:
            'Ambiguous killmail match; no single destroyed fit can be attributed.',
      );
    }
    if (kind == _IdentityKind.notSearched) {
      return const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.missing,
        detail:
            'Opponent fit needs a matched killmail; run the killmail search.',
        actions: [AarEvidenceAction.searchKillmails],
      );
    }
    if (kind == _IdentityKind.needsReauth) {
      return const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.missing,
        detail: 'Opponent fit needs a matched killmail; reauthorize to search.',
        actions: [AarEvidenceAction.reauthorize],
      );
    }
    final opponent = inputs.bundle.opponent;
    if (opponent != null && opponent.fitSource == EvidenceSource.killmail) {
      final unresolved = opponent.coverage.hasUnresolved
          ? '; ${_unresolvedModules(opponent)}'
          : '';
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.inferred,
        detail:
            'Killmail #${enrichment?.killmailId} shows destroyed and dropped modules only (${opponent.shipName})$unresolved',
      );
    }
    if (opponent != null && opponent.coverage.hasUnresolved) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.partial,
        detail:
            '${_opponentSourceLabel(opponent, enrichment)}; ${_unresolvedModules(opponent)}',
      );
    }
    if (opponent != null) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.complete,
        detail: _opponentSourceLabel(opponent, enrichment),
      );
    }
    if (_victimIsSelf(inputs)) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.unavailable,
        detail:
            'Own loss killmail #${enrichment?.killmailId}: attacker fittings are not exposed by killmails.',
      );
    }
    if (enrichment?.victimFitEvidence != null) {
      final failure = _fitFailure(inputs, AarUnknownCategory.opponentFit);
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.partial,
        detail: failure?.detail ?? 'Fit derivation failed.',
      );
    }
    return AarEvidenceDimensionResult(
      dimension: dimension,
      status: AarEvidenceStatus.unavailable,
      detail: 'Killmail #${enrichment?.killmailId} carries no destroyed fit.',
    );
  }

  static AarEvidenceDimensionResult damageProfile(AarEvidenceInputs inputs) {
    const dimension = AarEvidenceDimension.damageProfile;
    var profiledSum = 0;
    var totalSum = 0;
    var scored = false;
    void consider(CombatDamageProfile profile, int total) {
      if (total == 0) return;
      scored = true;
      profiledSum += profile.totalProfiledDamage;
      totalSum += total;
    }

    consider(inputs.incoming, inputs.encounter.totalDamageReceived);
    consider(inputs.outgoing, inputs.encounter.totalDamageDealt);
    if (!scored) {
      return const AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.unavailable,
        detail: 'No damage recorded in either direction.',
      );
    }
    final typed = totalSum == 0
        ? 0.0
        : (profiledSum / totalSum).clamp(0.0, 1.0);
    final unknown = <String>{
      ...inputs.incoming.unknownWeapons,
      ...inputs.outgoing.unknownWeapons,
    };
    final resolved = <String>{
      ...inputs.incoming.resolvedWeapons,
      ...inputs.outgoing.resolvedWeapons,
    };
    final names = {...resolved, ...unknown}.toList()..sort();
    final unknownNames = unknown.toList()..sort();
    final m = names.length;
    final u = unknown.length;
    final pct = (typed * 100).round();
    final inferredOnly = [
      ...inputs.incoming.entries,
      ...inputs.outgoing.entries,
    ].any((entry) => entry.confidence == CombatDamageConfidence.modelInferred);
    if (typed == 0) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.unavailable,
        detail:
            'None of the $m weapons in this log resolve to SDE damage attributes (${unknownNames.join(', ')}).',
      );
    }
    if (u == 0 && !inferredOnly) {
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.complete,
        detail:
            'All $m weapons resolved; 100% of damage typed from SDE attributes.',
      );
    }
    if (typed >= AarEvidenceRules.minTypedFractionForPartial) {
      final detail = u == 0
          ? 'All weapons resolved; damage types model-inferred.'
          : '$u of $m weapons unresolved (${unknownNames.join(', ')}); $pct% of damage typed.';
      return AarEvidenceDimensionResult(
        dimension: dimension,
        status: AarEvidenceStatus.partial,
        detail: detail,
      );
    }
    return AarEvidenceDimensionResult(
      dimension: dimension,
      status: AarEvidenceStatus.inferred,
      detail:
          '$u of $m weapons unresolved (${unknownNames.join(', ')}); $pct% of damage typed.',
    );
  }

  static bool _victimIsSelf(AarEvidenceInputs inputs) {
    final victimId = inputs.enrichment?.victimCharacterId;
    return victimId != null && victimId == inputs.encounter.characterId;
  }

  static FitEvidence? _selfEvidence(AarEvidenceInputs inputs) {
    final enrichment = inputs.enrichment;
    if (enrichment == null) return null;
    return enrichment.pilotFitEvidence ??
        (_victimIsSelf(inputs) ? enrichment.victimFitEvidence : null);
  }

  static _IdentityKind _identityKind(AarEvidenceInputs inputs) {
    final enrichment = inputs.enrichment;
    if (enrichment == null && inputs.encounter.characterId == null) {
      return _IdentityKind.noCharacter;
    }
    if (enrichment == null) return _IdentityKind.notSearched;
    return switch (enrichment.status) {
      CombatEnrichmentStatus.needsReauth => _IdentityKind.needsReauth,
      CombatEnrichmentStatus.ambiguous => _IdentityKind.ambiguous,
      CombatEnrichmentStatus.killmailMatched =>
        enrichment.matchConfidence >= AarEvidenceRules.matchConfidenceComplete
            ? _IdentityKind.matchedHigh
            : _IdentityKind.matchedLow,
      CombatEnrichmentStatus.logOnly =>
        enrichment.killmailSearchCompleted
            ? _IdentityKind.noKillmail
            : _IdentityKind.notSearched,
    };
  }

  static AarUnknown? _fitFailure(
    AarEvidenceInputs inputs,
    AarUnknownCategory category,
  ) {
    for (final unknown in inputs.bundle.unknowns) {
      if (unknown.category == category &&
          (unknown.label == 'Ship type not in SDE' ||
              unknown.label == 'Fit derivation failed')) {
        return unknown;
      }
    }
    return null;
  }

  static String _pilotSourceLabel(
    FitEvidence evidence,
    CombatEnrichment? enrichment,
  ) {
    return switch (evidence.source) {
      EvidenceSource.currentShipSnapshot =>
        'Current ship snapshot, confirmed for this fight',
      EvidenceSource.manualFitImport => 'Imported fit, user-confirmed',
      EvidenceSource.killmail =>
        'Own loss killmail #${enrichment?.killmailId}: every fitted module proven',
      _ => evidence.source.name,
    };
  }

  static String _inferredPilotDetail(FitEvidence evidence) {
    if (evidence.source == EvidenceSource.currentShipSnapshot) {
      final time = evidence.evidenceTime == null
          ? ''
          : ' ${formatAarUtcMinute(evidence.evidenceTime!)}';
      return 'Current ship snapshot captured$time, not confirmed for this fight.';
    }
    return '${_pilotSourceLabel(evidence, null)}, unconfirmed.';
  }

  static String _unresolvedModules(AarFitDerivation derivation) {
    final ids = derivation.coverage.unresolvedTypeIds;
    final names = [
      for (var i = 0; i < ids.length; i++)
        i < derivation.coverage.unresolvedNames.length &&
                derivation.coverage.unresolvedNames[i].isNotEmpty
            ? derivation.coverage.unresolvedNames[i]
            : 'Type #${ids[i]}',
    ];
    final noun = ids.length == 1 ? 'module' : 'modules';
    return '${ids.length} $noun not in the SDE (${names.join(', ')})';
  }

  static String _matchedIdentityDetail(
    CombatEnrichment? enrichment,
    int pct, {
    required bool lowConfidence,
  }) {
    final id = enrichment?.killmailId;
    final victim = enrichment?.victimName;
    if (lowConfidence) {
      return 'Killmail #$id matched at low confidence ($pct%): ${enrichment?.matchReason ?? ''}';
    }
    final victimBit = victim == null || victim.isEmpty
        ? ''
        : ', victim $victim';
    return 'Killmail #$id matched ($pct%)$victimBit';
  }

  static String _opponentSourceLabel(
    AarFitDerivation opponent,
    CombatEnrichment? enrichment,
  ) {
    return switch (opponent.fitSource) {
      EvidenceSource.killmail =>
        'Killmail #${enrichment?.killmailId} destroyed fit',
      EvidenceSource.manualFitImport => 'Imported fit, user-confirmed',
      _ => opponent.fitSource.name,
    };
  }
}

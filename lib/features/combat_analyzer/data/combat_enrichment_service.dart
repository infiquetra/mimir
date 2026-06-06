import 'package:dio/dio.dart';

import '../../../core/auth/oauth_service.dart';
import '../../../core/auth/token_manager.dart';
import '../../../core/config/eve_config.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/sde/sde_service.dart';
import '../../fitting/domain/format_parser.dart';
import '../domain/combat_enrichment.dart';
import '../domain/combat_evidence_ledger.dart';
import '../domain/combat_fit_snapshot_mapper.dart';
import '../domain/combat_killmail_fit_mapper.dart';
import '../domain/combat_killmail_matcher.dart';
import '../domain/parsed_combat_encounter.dart';
import 'combat_enrichment_repository.dart';
import 'combat_killmail_discovery_client.dart';

class CombatEnrichmentService {
  CombatEnrichmentService({
    required CombatEnrichmentRepository repository,
    required EsiClient esiClient,
    required CombatKillmailDiscoveryClient discoveryClient,
    required TokenManager tokenManager,
    required OAuthService oauthService,
    required SdeService sdeService,
  }) : _repository = repository,
       _esiClient = esiClient,
       _discoveryClient = discoveryClient,
       _tokenManager = tokenManager,
       _oauthService = oauthService,
       _sdeService = sdeService;

  static const int maxRecentDetails = 80;
  static const int maxZkillPagesPerDirection = 3;

  final CombatEnrichmentRepository _repository;
  final EsiClient _esiClient;
  final CombatKillmailDiscoveryClient _discoveryClient;
  final TokenManager _tokenManager;
  final OAuthService _oauthService;
  final SdeService _sdeService;

  Future<CombatEnrichment> enrichEncounter(
    ParsedCombatEncounter encounter, {
    bool forceRefresh = false,
  }) async {
    Log.d(
      'COMBAT.ENRICH',
      'CombatEnrichmentService.enrichEncounter(${encounter.id}, forceRefresh=$forceRefresh) - START',
    );
    if (!forceRefresh) {
      final cached = await _repository.loadEnrichment(encounter.id);
      if (cached != null) return cached;
    }

    final characterId = encounter.characterId;
    if (characterId == null) {
      return _save(
        CombatEnrichment(
          parsedEncounterId: encounter.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          matchReason:
              'No authenticated character ID was associated with this log listener.',
          limitations: const [
            'Killmail matching requires the combat log listener to match an authenticated character.',
          ],
          evidenceLedger: _baselineLedger(encounter),
        ),
      );
    }

    var missingScope = !await _hasKillmailScope(characterId);
    if (!missingScope) {
      final esiResult = await _tryEsiRecent(encounter, characterId);
      if (esiResult.missingScope) missingScope = true;
      if (esiResult.enrichment != null) return _save(esiResult.enrichment!);
    }

    final zkillEnrichment = await _tryZkillDiscovery(
      encounter,
      characterId,
      missingScope: missingScope,
    );
    if (zkillEnrichment != null) return _save(zkillEnrichment);

    return _save(
      CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: missingScope
            ? CombatEnrichmentStatus.needsReauth
            : CombatEnrichmentStatus.logOnly,
        source: CombatEnrichmentSource.none,
        matchReason: missingScope
            ? 'Killmail scope is missing and no public zKill match was found.'
            : 'No ESI or zKill killmail matched this encounter.',
        limitations: [
          if (missingScope)
            'Reauthorize this character to enable ESI recent killmail discovery.',
          'The AAR is based on combat-log evidence only.',
        ],
        evidenceLedger: _baselineLedger(encounter, missingScope: missingScope),
      ),
    );
  }

  Future<CombatEnrichment> importPilotFit(
    ParsedCombatEncounter encounter,
    String rawFit,
  ) async {
    Log.d('COMBAT.ENRICH', 'importPilotFit(${encounter.id}) - START');
    final parser = FittingFormatParser(_sdeService);
    final fitting = rawFit.trim().contains(':')
        ? await parser.parseDna(rawFit.trim())
        : await parser.parseEft(rawFit);
    if (fitting == null || fitting.shipTypeId <= 0) {
      throw const FormatException(
        'Unable to resolve the pasted fit. Paste an EFT fit with a known ship and modules.',
      );
    }
    final evidence = FitEvidence(
      role: FitEvidenceRole.pilot,
      source: EvidenceSource.manualFitImport,
      confidence: EvidenceConfidence.confirmed,
      fitting: fitting,
      evidenceTime: DateTime.now().toUtc(),
      limitations: const ['User-confirmed manual fit import.'],
    );
    final existing = await _loadOrCreateEnrichment(encounter);
    final updated = _withPilotFitEvidence(
      existing,
      encounter,
      evidence,
      'Pilot fit imported by user.',
    );
    return _save(updated);
  }

  Future<CombatEnrichment> captureCurrentPilotFit(
    ParsedCombatEncounter encounter, {
    bool confirmed = false,
  }) async {
    Log.d(
      'COMBAT.ENRICH',
      'captureCurrentPilotFit(${encounter.id}, confirmed=$confirmed) - START',
    );
    final characterId = encounter.characterId;
    if (characterId == null) {
      throw const FormatException(
        'Current fit snapshot requires an authenticated character match.',
      );
    }

    final ship = await _esiClient.getCharacterShip(characterId);
    if (ship == null) {
      throw const FormatException('ESI did not return a current ship.');
    }
    final assets = await _fetchAllAssets(characterId);
    final fitting = CombatFitSnapshotMapper.mapCurrentShipAssets(
      characterId: characterId,
      ship: ship,
      assets: assets,
    );
    final evidence = FitEvidence(
      role: FitEvidenceRole.pilot,
      source: EvidenceSource.currentShipSnapshot,
      confidence: confirmed
          ? EvidenceConfidence.confirmed
          : EvidenceConfidence.reference,
      fitting: fitting,
      evidenceTime: DateTime.now().toUtc(),
      limitations: [
        if (confirmed)
          'User confirmed this current ship snapshot was the fight fit.'
        else
          'Current ship snapshots are not historical proof until user-confirmed.',
      ],
    );
    final existing = await _loadOrCreateEnrichment(encounter);
    final updated = _withPilotFitEvidence(
      existing,
      encounter,
      evidence,
      confirmed
          ? 'Pilot confirmed current ship snapshot as the fight fit.'
          : 'Current ship snapshot captured as reference evidence.',
    );
    return _save(updated);
  }

  Future<CombatEnrichment?> loadEnrichment(String parsedEncounterId) {
    Log.d(
      'COMBAT.ENRICH',
      'CombatEnrichmentService.loadEnrichment($parsedEncounterId) - START',
    );
    return _repository.loadEnrichment(parsedEncounterId);
  }

  Future<CombatEnrichment> _save(CombatEnrichment enrichment) async {
    await _repository.saveEnrichment(enrichment);
    return enrichment;
  }

  Future<_EsiRecentResult> _tryEsiRecent(
    ParsedCombatEncounter encounter,
    int characterId,
  ) async {
    Log.d('COMBAT.ENRICH', '_tryEsiRecent(${encounter.id}) - START');
    try {
      final refs = await _esiClient.getCharacterRecentKillmailRefs(characterId);
      final details = <EsiKillmailDetail>[];
      for (final ref in refs.take(maxRecentDetails)) {
        final detail = await _safeFetchDetail(ref.killmailId, ref.killmailHash);
        if (detail != null) details.add(detail);
      }
      final match = CombatKillmailMatcher.selectBest(encounter, details);
      return _EsiRecentResult(
        enrichment: await _enrichmentFromMatch(
          encounter: encounter,
          match: match,
          source: CombatEnrichmentSource.esiRecent,
          totalValues: const {},
          extraLimitations: const [],
        ),
      );
    } on DioException catch (e, stack) {
      final error = e.error;
      if (error is EsiException && error.isScopeError) {
        Log.w('COMBAT.ENRICH', 'ESI recent killmail scope missing');
        return const _EsiRecentResult(missingScope: true);
      }
      Log.e('COMBAT.ENRICH', 'ESI recent killmail lookup failed', e, stack);
      return const _EsiRecentResult();
    } on EsiException catch (e, stack) {
      if (e.isScopeError) return const _EsiRecentResult(missingScope: true);
      Log.e('COMBAT.ENRICH', 'ESI recent killmail lookup failed', e, stack);
      return const _EsiRecentResult();
    } catch (e, stack) {
      Log.e('COMBAT.ENRICH', 'ESI recent killmail lookup failed', e, stack);
      return const _EsiRecentResult();
    }
  }

  Future<CombatEnrichment?> _tryZkillDiscovery(
    ParsedCombatEncounter encounter,
    int characterId, {
    required bool missingScope,
  }) async {
    Log.d('COMBAT.ENRICH', '_tryZkillDiscovery(${encounter.id}) - START');
    final details = <EsiKillmailDetail>[];
    final totalValues = <int, double>{};
    final lowerBound = encounter.startTime.toUtc().subtract(
      const Duration(minutes: 2),
    );
    final month = encounter.startTime.toUtc().month;
    final year = encounter.startTime.toUtc().year;

    try {
      for (final direction in const ['kills', 'losses']) {
        var stopDirection = false;
        for (var page = 1; page <= maxZkillPagesPerDirection; page++) {
          final cached = await _repository.loadSearchCache(
            characterId: characterId,
            year: year,
            month: month,
            direction: direction,
            page: page,
          );
          final refs = cached == null
              ? await _fetchAndCacheZkillPage(
                  characterId: characterId,
                  year: year,
                  month: month,
                  direction: direction,
                  page: page,
                )
              : cached.map(CombatZkillKillmailRef.fromJson).toList();

          if (refs.isEmpty) break;
          for (final ref in refs) {
            final detail = await _safeFetchDetail(
              ref.killmailId,
              ref.killmailHash,
            );
            if (detail == null) continue;
            if (detail.killmailTime.toUtc().isBefore(lowerBound)) {
              stopDirection = true;
              break;
            }
            details.add(detail);
            if (ref.totalValue != null) {
              totalValues[ref.killmailId] = ref.totalValue!;
            }
          }
          if (stopDirection) break;
        }
      }
    } catch (e, stack) {
      Log.e('COMBAT.ENRICH', 'zKill discovery failed', e, stack);
      return null;
    }

    final match = CombatKillmailMatcher.selectBest(encounter, details);
    return _enrichmentFromMatch(
      encounter: encounter,
      match: match,
      source: CombatEnrichmentSource.zkillEsi,
      totalValues: totalValues,
      extraLimitations: [
        if (missingScope)
          'Character killmail scope is missing; this match used public zKill discovery instead of authenticated recent ESI refs.',
      ],
    );
  }

  Future<List<CombatZkillKillmailRef>> _fetchAndCacheZkillPage({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
  }) async {
    final refs = await _discoveryClient.fetchCharacterPage(
      characterId: characterId,
      year: year,
      month: month,
      direction: direction,
      page: page,
    );
    await _repository.saveSearchCache(
      characterId: characterId,
      year: year,
      month: month,
      direction: direction,
      page: page,
      response: refs.map((ref) => ref.toJson()).toList(),
    );
    return refs;
  }

  Future<EsiKillmailDetail?> _safeFetchDetail(
    int killmailId,
    String killmailHash,
  ) async {
    try {
      return await _esiClient.getKillmailDetail(
        killmailId: killmailId,
        killmailHash: killmailHash,
      );
    } catch (e, stack) {
      Log.w('COMBAT.ENRICH', 'Failed to fetch killmail $killmailId: $e');
      Log.d('COMBAT.ENRICH', 'Killmail $killmailId stack: $stack');
      return null;
    }
  }

  Future<CombatEnrichment?> _enrichmentFromMatch({
    required ParsedCombatEncounter encounter,
    required CombatKillmailMatchResult match,
    required CombatEnrichmentSource source,
    required Map<int, double> totalValues,
    required List<String> extraLimitations,
  }) async {
    if (match.status == CombatKillmailMatchStatus.noMatch) return null;
    if (match.status == CombatKillmailMatchStatus.ambiguous) {
      return CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: CombatEnrichmentStatus.ambiguous,
        source: source,
        matchConfidence: match.confidence,
        matchReason: match.reason,
        limitations: [
          ...extraLimitations,
          'Multiple killmails fit the encounter window; AI analysis should treat killmail outcome and fits as unproven.',
        ],
        evidenceLedger: _baselineLedger(
          encounter,
          extraUnknowns: const [
            AarUnknown(
              category: AarUnknownCategory.telemetry,
              label: 'Killmail match',
              detail:
                  'Multiple killmails fit the encounter window; outcome and fit evidence are ambiguous.',
            ),
          ],
        ),
      );
    }

    final detail = await _withResolvedNames(match.detail!);
    final destroyedFit = CombatKillmailFitMapper.mapVictimFit(detail);
    final pilotWasVictim = detail.victim.characterId == encounter.characterId;
    final enrichment = CombatEnrichment.fromKillmail(
      parsedEncounterId: encounter.id,
      source: source,
      detail: detail,
      confidence: match.confidence,
      reason: match.reason,
      destroyedFit: destroyedFit,
      totalValue: totalValues[detail.killmailId],
      limitations: [
        ...extraLimitations,
        if (pilotWasVictim)
          'Killmail proves the pilot destroyed fit; opposing full fits remain unknown.'
        else
          'Killmail proves the destroyed opponent fit; the pilot full fit remains unknown.',
      ],
    );
    return enrichment.copyWith(
      evidenceLedger: _mergeLedgers(
        _baselineLedger(encounter),
        enrichment.evidenceLedger,
      ),
    );
  }

  Future<List<AssetItem>> _fetchAllAssets(int characterId) async {
    final assets = <AssetItem>[];
    var page = 1;
    int? totalPages;
    do {
      final response = await _esiClient.getCharacterAssets(
        characterId,
        page: page,
      );
      assets.addAll(response.data);
      totalPages ??= int.tryParse(response.headers['x-pages']?.first ?? '1');
      page++;
    } while (totalPages != null && page <= totalPages);
    return assets;
  }

  Future<CombatEnrichment> _loadOrCreateEnrichment(
    ParsedCombatEncounter encounter,
  ) async {
    final existing = await _repository.loadEnrichment(encounter.id);
    if (existing != null) return existing;
    return CombatEnrichment(
      parsedEncounterId: encounter.id,
      status: CombatEnrichmentStatus.logOnly,
      source: CombatEnrichmentSource.none,
      matchReason: 'No killmail evidence is cached for this AAR.',
      limitations: const ['This report is based on combat-log evidence only.'],
      evidenceLedger: _baselineLedger(encounter),
    );
  }

  CombatEnrichment _withPilotFitEvidence(
    CombatEnrichment existing,
    ParsedCombatEncounter encounter,
    FitEvidence evidence,
    String factValue,
  ) {
    final ledger = _mergeLedgers(
      existing.evidenceLedger.isEmpty
          ? _baselineLedger(encounter)
          : existing.evidenceLedger,
      CombatEvidenceLedger(
        facts: [
          CombatEvidenceFact(
            id: 'ev-pilot-fit-${encounter.id}',
            label: 'Pilot fit',
            value: factValue,
            source: evidence.source,
            confidence: evidence.confidence,
            evidenceTime: evidence.evidenceTime,
            limitations: evidence.limitations,
          ),
        ],
      ),
      removeUnknownCategories: const {AarUnknownCategory.pilotFit},
    );
    return existing.copyWith(
      pilotFitEvidence: evidence,
      evidenceLedger: ledger,
      limitations: [
        ...existing.limitations.where(
          (item) =>
              !item.toLowerCase().contains('pilot full fit remains unknown'),
        ),
        ...evidence.limitations,
      ],
    );
  }

  CombatEvidenceLedger _baselineLedger(
    ParsedCombatEncounter encounter, {
    bool missingScope = false,
    List<AarUnknown> extraUnknowns = const [],
  }) {
    return CombatEvidenceLedger(
      facts: [
        CombatEvidenceFact(
          id: 'ev-log-window-${encounter.id}',
          label: 'Combat log window',
          value:
              '${encounter.startTime.toUtc().toIso8601String()} - ${encounter.endTime.toUtc().toIso8601String()}',
          source: EvidenceSource.combatLog,
          confidence: EvidenceConfidence.proven,
          evidenceTime: encounter.startTime,
        ),
        CombatEvidenceFact(
          id: 'ev-log-damage-${encounter.id}',
          label: 'Damage totals',
          value:
              '${encounter.totalDamageDealt} dealt / ${encounter.totalDamageReceived} taken',
          source: EvidenceSource.combatLog,
          confidence: EvidenceConfidence.proven,
          evidenceTime: encounter.endTime,
        ),
      ],
      unknowns: [
        const AarUnknown(
          category: AarUnknownCategory.pilotFit,
          label: 'Pilot fit',
          detail:
              'The combat log does not contain the pilot ship fitting. Import or confirm a fit to resolve this.',
        ),
        const AarUnknown(
          category: AarUnknownCategory.range,
          label: 'Range and transversal',
          detail:
              'EVE combat logs do not include range, angular velocity, or manual piloting inputs.',
        ),
        const AarUnknown(
          category: AarUnknownCategory.tankLayer,
          label: 'Tank layer timing',
          detail:
              'Combat logs do not show shield, armor, or hull layer depletion.',
        ),
        if (missingScope)
          const AarUnknown(
            category: AarUnknownCategory.telemetry,
            label: 'Private killmail scope',
            detail:
                'The character token is missing killmail scope; public zKill matching may be incomplete.',
          ),
        ...extraUnknowns,
      ],
    );
  }

  CombatEvidenceLedger _mergeLedgers(
    CombatEvidenceLedger first,
    CombatEvidenceLedger second, {
    Set<AarUnknownCategory> removeUnknownCategories = const {},
  }) {
    final factsById = <String, CombatEvidenceFact>{
      for (final fact in first.facts) fact.id: fact,
      for (final fact in second.facts) fact.id: fact,
    };
    final unknowns = [...first.unknowns, ...second.unknowns]
        .where((unknown) => !removeUnknownCategories.contains(unknown.category))
        .toList();
    return CombatEvidenceLedger(
      facts: factsById.values.toList(),
      unknowns: unknowns,
    );
  }

  Future<EsiKillmailDetail> _withResolvedNames(EsiKillmailDetail detail) async {
    Log.d('COMBAT.ENRICH', '_withResolvedNames(${detail.killmailId}) - START');
    final ids = <int>{
      if (detail.victim.characterId != null) detail.victim.characterId!,
      for (final attacker in detail.attackers)
        if (attacker.characterId != null) attacker.characterId!,
    }.toList();
    if (ids.isEmpty) return detail;

    try {
      final names = await _esiClient.resolveNames(ids);
      final namesById = {
        for (final name in names)
          if (name.category == 'character') name.id: name.name,
      };
      return detail.copyWith(
        victim: detail.victim.copyWith(
          characterName: namesById[detail.victim.characterId],
        ),
        attackers: detail.attackers
            .map(
              (attacker) => attacker.copyWith(
                characterName: namesById[attacker.characterId],
              ),
            )
            .toList(),
      );
    } catch (e, stack) {
      Log.e('COMBAT.ENRICH', 'Failed to resolve killmail names', e, stack);
      return detail;
    }
  }

  Future<bool> _hasKillmailScope(int characterId) async {
    Log.d('COMBAT.ENRICH', '_hasKillmailScope($characterId) - START');
    final tokens = await _tokenManager.getTokens(characterId);
    final accessToken = tokens?.accessToken;
    if (accessToken == null || accessToken.trim().isEmpty) return false;
    try {
      final info = _oauthService.parseAccessToken(accessToken);
      final hasScope = info.scopes.contains(EveConfig.killmailReadScope);
      Log.i(
        'COMBAT.ENRICH',
        'Killmail scope for $characterId: ${hasScope ? 'present' : 'missing'}',
      );
      return hasScope;
    } catch (e, stack) {
      Log.e('COMBAT.ENRICH', 'Failed to inspect token scopes', e, stack);
      return false;
    }
  }
}

class _EsiRecentResult {
  const _EsiRecentResult({this.enrichment, this.missingScope = false});

  final CombatEnrichment? enrichment;
  final bool missingScope;
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_providers.dart';
import 'combat_enrichment_repository.dart';
import 'combat_enrichment_service.dart';
import 'combat_killmail_discovery_client.dart';
import 'log_scanner.dart';
import 'parsed_encounter_cache.dart';
import '../domain/combat_enrichment.dart';
import '../domain/parsed_combat_encounter.dart';
import '../domain/combat_log_parser.dart';

enum CombatAarStatus { none, ready, legacy }

final logScannerProvider = FutureProvider<LogScanner>((ref) async {
  Log.d('COMBAT', 'logScannerProvider() - START');
  Log.d('COMBAT', 'logScannerProvider() - SUCCESS');
  return LogScanner();
});

final combatEnrichmentRepositoryProvider = Provider<CombatEnrichmentRepository>(
  (ref) {
    Log.d('COMBAT.ENRICH', 'combatEnrichmentRepositoryProvider() - START');
    return CombatEnrichmentRepository(database: ref.watch(databaseProvider));
  },
);

final combatKillmailDiscoveryClientProvider =
    Provider<CombatKillmailDiscoveryClient>((ref) {
      Log.d('COMBAT.ENRICH', 'combatKillmailDiscoveryClientProvider() - START');
      return CombatKillmailDiscoveryClient();
    });

final combatEnrichmentServiceProvider = Provider<CombatEnrichmentService>((
  ref,
) {
  Log.d('COMBAT.ENRICH', 'combatEnrichmentServiceProvider() - START');
  return CombatEnrichmentService(
    repository: ref.watch(combatEnrichmentRepositoryProvider),
    esiClient: ref.watch(esiClientProvider),
    discoveryClient: ref.watch(combatKillmailDiscoveryClientProvider),
    tokenManager: ref.watch(tokenManagerProvider),
    oauthService: ref.watch(oauthServiceProvider),
    sdeService: ref.watch(sdeServiceProvider),
  );
});

final combatEnrichmentProvider =
    FutureProvider.family<CombatEnrichment?, String>((ref, parsedEncounterId) {
      Log.d(
        'COMBAT.ENRICH',
        'combatEnrichmentProvider($parsedEncounterId) - START',
      );
      return ref
          .watch(combatEnrichmentServiceProvider)
          .loadEnrichment(parsedEncounterId);
    });

final rawEncountersProvider = FutureProvider<List<ParsedCombatEncounter>>((
  ref,
) async {
  Log.d('COMBAT', 'rawEncountersProvider() - START');
  final scanner = await ref.watch(logScannerProvider.future);
  final database = ref.watch(databaseProvider);
  final cache = ParsedEncounterCache(database);
  final files = await scanner.getCombatLogs();
  Log.i('COMBAT', 'Parsing ${files.length} combat log files');

  await cache.pruneToFiles(files);
  final characters = await database.getAllCharacters();
  final characterIdsByName = {
    for (final character in characters)
      character.name.trim().toLowerCase(): character.characterId,
  };

  final allEncounters = <ParsedCombatEncounter>[];
  for (final file in files) {
    final cached = await cache.loadValidForFile(file);
    final encounters = cached ?? await CombatLogParser.parseFile(file);
    if (cached == null) {
      await cache.saveForFile(file, encounters);
    }
    allEncounters.addAll(
      encounters.map((encounter) {
        final characterId =
            characterIdsByName[encounter.characterName.trim().toLowerCase()];
        return characterId == null
            ? encounter
            : encounter.copyWith(characterId: characterId);
      }),
    );
  }

  final sortedEncounters = allEncounters
    ..sort((a, b) => b.startTime.compareTo(a.startTime));
  Log.i('COMBAT', 'Parsed ${sortedEncounters.length} combat encounters');
  return sortedEncounters;
});

final combatAarStatusesProvider = FutureProvider<Map<String, CombatAarStatus>>((
  ref,
) async {
  Log.d('COMBAT.AAR', 'combatAarStatusesProvider() - START');
  final database = ref.watch(databaseProvider);
  final rows = await database.select(database.combatEncounters).get();
  final statuses = <String, CombatAarStatus>{};
  for (final row in rows) {
    final status = _statusForRow(row);
    statuses[row.id] = status;
    final parsedEncounterId = row.parsedEncounterId;
    if (parsedEncounterId != null && parsedEncounterId.trim().isNotEmpty) {
      statuses[parsedEncounterId] = status;
    }
  }
  Log.i('COMBAT.AAR', 'Loaded ${statuses.length} cached AAR markers');
  return statuses;
});

CombatAarStatus _statusForRow(CombatEncounter row) {
  final analysisJson = row.analysisJson;
  if (analysisJson == null || analysisJson.trim().isEmpty) {
    return CombatAarStatus.legacy;
  }
  try {
    final decoded = jsonDecode(analysisJson);
    if (decoded is Map &&
        (decoded['version'] == 2 || decoded['version'] == 3)) {
      return CombatAarStatus.ready;
    }
  } catch (e, stack) {
    Log.w('COMBAT.AAR', 'Failed to inspect AAR version for ${row.id}: $e');
    Log.d('COMBAT.AAR', 'AAR version inspection stack: $stack');
  }
  return CombatAarStatus.legacy;
}

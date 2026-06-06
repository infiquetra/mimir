import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../domain/combat_log_parser.dart';
import '../domain/parsed_combat_encounter.dart';

class ParsedEncounterCache {
  ParsedEncounterCache(this._database);

  final AppDatabase _database;

  Future<List<ParsedCombatEncounter>?> loadValidForFile(File file) async {
    Log.d('COMBAT.CACHE', 'loadValidForFile(path=${file.path}) - START');
    final stat = await file.stat();
    final modified = stat.modified.toUtc();
    final rows =
        await (_database.select(_database.combatParsedEncounters)
              ..where((tbl) => tbl.sourceFilePath.equals(file.path))
              ..where(
                (tbl) =>
                    tbl.parserVersion.equals(CombatLogParser.parserVersion),
              ))
            .get();
    if (rows.isEmpty) return null;

    final validRows = rows.where((row) {
      final modifiedDelta = row.sourceModified
          .toUtc()
          .difference(modified)
          .inMilliseconds
          .abs();
      return row.sourceSize == stat.size &&
          modifiedDelta < Duration.millisecondsPerSecond;
    }).toList();
    if (validRows.length != rows.length) {
      Log.i(
        'COMBAT.CACHE',
        'Cached parsed encounters are stale for ${file.path}',
      );
      return null;
    }

    try {
      final encounters = validRows.map((row) {
        final decoded = jsonDecode(row.parseJson);
        if (decoded is! Map) {
          throw const FormatException(
            'Parsed encounter JSON was not an object',
          );
        }
        return ParsedCombatEncounter.fromJson(
          Map<String, dynamic>.from(decoded),
        ).copyWith(characterId: row.characterId);
      }).toList();
      Log.i(
        'COMBAT.CACHE',
        'Loaded ${encounters.length} cached parsed encounters from ${file.path}',
      );
      return encounters;
    } catch (e, stack) {
      Log.e('COMBAT.CACHE', 'Failed to load parsed encounter cache', e, stack);
      return null;
    }
  }

  Future<void> saveForFile(
    File file,
    List<ParsedCombatEncounter> encounters,
  ) async {
    Log.d(
      'COMBAT.CACHE',
      'saveForFile(path=${file.path}, encounters=${encounters.length}) - START',
    );
    final stat = await file.stat();
    final modified = stat.modified.toUtc();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await (_database.delete(
        _database.combatParsedEncounters,
      )..where((tbl) => tbl.sourceFilePath.equals(file.path))).go();

      if (encounters.isEmpty) return;

      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _database.combatParsedEncounters,
          encounters.map((encounter) {
            final normalized = encounter.copyWith(
              sourceFilePath: file.path,
              sourceModified: modified,
              sourceSize: stat.size,
            );
            return CombatParsedEncountersCompanion.insert(
              id: normalized.id,
              sourceFilePath: file.path,
              sourceModified: modified,
              sourceSize: stat.size,
              parserVersion: CombatLogParser.parserVersion,
              characterName: normalized.characterName,
              characterId: Value(normalized.characterId),
              encounterStart: normalized.startTime,
              encounterEnd: normalized.endTime,
              durationSeconds: normalized.durationSeconds,
              outcome: normalized.outcome.name,
              outcomeConfidence: normalized.outcomeConfidence,
              outcomeEvidence: normalized.outcomeEvidence,
              totalDamageDealt: normalized.totalDamageDealt,
              totalDamageReceived: normalized.totalDamageReceived,
              listSummaryJson: jsonEncode(normalized.toListSummaryJson()),
              parseJson: jsonEncode(normalized.toJson()),
              cachedAt: now,
            );
          }).toList(),
        );
      });
    });
    Log.i(
      'COMBAT.CACHE',
      'Saved ${encounters.length} parsed encounters for ${file.path}',
    );
  }

  Future<void> pruneToFiles(List<File> files) async {
    Log.d('COMBAT.CACHE', 'pruneToFiles(fileCount=${files.length}) - START');
    final validPaths = files.map((file) => file.path).toSet();
    final rows = await _database.select(_database.combatParsedEncounters).get();
    final staleRows = rows
        .where((row) => !validPaths.contains(row.sourceFilePath))
        .toList();
    if (staleRows.isEmpty) return;

    await _database.batch((batch) {
      for (final row in staleRows) {
        batch.deleteWhere(
          _database.combatParsedEncounters,
          (tbl) => tbl.id.equals(row.id),
        );
      }
    });
    Log.i('COMBAT.CACHE', 'Pruned ${staleRows.length} stale parsed encounters');
  }
}

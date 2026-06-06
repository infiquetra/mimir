import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../core/logging/logger.dart';
import 'parsed_combat_encounter.dart';

class CombatLogParser {
  static const int parserVersion = 1;
  static const Duration encounterIdleGap = Duration(seconds: 45);
  static const int maxLlmEvents = 160;

  static final RegExp _htmlRegex = RegExp(r'<[^>]*>');
  static final RegExp _lineRegex = RegExp(
    r'^\[ (\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}) \] (.*?)$',
  );
  static final RegExp _damageRegex = RegExp(
    r'^(\d+) (to|from) (.*?) - (.*?) - (.*)$',
  );
  static final RegExp _missRegex = RegExp(
    r'^(?:Your\s+)?(.+?) misses (.+?)(?: completely)?\.?$',
    caseSensitive: false,
  );
  static final RegExp _listenerRegex = RegExp(r'Listener:\s*(.+)$');
  static const String _combatPrefix = '(combat) ';

  static Future<List<ParsedCombatEncounter>> parseFile(File file) async {
    Log.d('COMBAT.PARSER', 'parseFile(path=${file.path}) - START');
    final stat = await file.stat();
    final lines = await file.readAsLines();
    final encounters = parseLines(
      lines,
      sourceFilePath: file.path,
      sourceModified: stat.modified.toUtc(),
      sourceSize: stat.size,
    );
    Log.i(
      'COMBAT.PARSER',
      'Parsed ${encounters.length} combat encounters from ${file.path}',
    );
    return encounters;
  }

  static Future<bool> fileContainsCombatDamage(File file) async {
    Log.d(
      'COMBAT.PARSER',
      'fileContainsCombatDamage(path=${file.path}) - START',
    );
    try {
      await for (final line
          in file
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (_lineContainsCombatDamage(line)) {
          Log.d(
            'COMBAT.PARSER',
            'fileContainsCombatDamage(path=${file.path}) - TRUE',
          );
          return true;
        }
      }
    } catch (e, stack) {
      Log.e(
        'COMBAT.PARSER',
        'Failed to inspect combat log ${file.path}',
        e,
        stack,
      );
    }
    Log.d(
      'COMBAT.PARSER',
      'fileContainsCombatDamage(path=${file.path}) - FALSE',
    );
    return false;
  }

  static List<ParsedCombatEncounter> parseLines(
    List<String> lines, {
    String sourceFilePath = '',
    DateTime? sourceModified,
    int sourceSize = 0,
  }) {
    Log.d('COMBAT.PARSER', 'parseLines(lineCount=${lines.length}) - START');
    String characterName = 'Unknown';
    final encounters = <ParsedCombatEncounter>[];

    List<CombatEvent> currentEvents = [];
    DateTime? encounterStart;
    DateTime? lastLineTime;
    bool currentEncounterHasDamage = false;

    void flushEncounter() {
      if (currentEvents.isEmpty || !currentEncounterHasDamage) {
        currentEvents = [];
        encounterStart = null;
        currentEncounterHasDamage = false;
        return;
      }

      final startTime = encounterStart ?? currentEvents.first.timestamp;
      final endTime = currentEvents.last.timestamp;
      final aggregates = _buildAggregates(currentEvents);
      final outcome = _deriveOutcome(aggregates);
      final llmPayload = _buildLlmPayload(currentEvents, aggregates);
      final id = _stableEncounterId(
        sourceFilePath: sourceFilePath,
        characterName: characterName,
        startTime: startTime,
        endTime: endTime,
        events: currentEvents,
        aggregates: aggregates,
      );

      encounters.add(
        ParsedCombatEncounter(
          id: id,
          sourceFilePath: sourceFilePath,
          sourceModified: sourceModified,
          sourceSize: sourceSize,
          characterName: characterName,
          startTime: startTime,
          endTime: endTime,
          durationSeconds: endTime.difference(startTime).inSeconds,
          outcome: outcome.outcome,
          outcomeConfidence: outcome.confidence,
          outcomeEvidence: outcome.evidence,
          events: currentEvents,
          aggregates: aggregates,
          llmPayloadString: llmPayload,
        ),
      );

      currentEvents = [];
      encounterStart = null;
      currentEncounterHasDamage = false;
    }

    for (final rawLine in lines) {
      if (rawLine.trim().isEmpty) continue;

      final cleanLine = _stripHtml(rawLine);
      final listenerMatch = _listenerRegex.firstMatch(cleanLine);
      if (listenerMatch != null) {
        characterName = listenerMatch.group(1)!.trim();
        continue;
      }

      final lineMatch = _lineRegex.firstMatch(cleanLine);
      if (lineMatch == null) continue;

      final fullTimeStr = lineMatch.group(1)!;
      var content = lineMatch.group(2)!.trim();
      if (!content.startsWith(_combatPrefix)) continue;
      content = content.substring(_combatPrefix.length).trim();

      final currentTime = _parseEveTimestamp(fullTimeStr);
      if (lastLineTime != null &&
          currentTime.difference(lastLineTime) >= encounterIdleGap) {
        flushEncounter();
      }
      lastLineTime = currentTime;
      encounterStart ??= currentTime;

      final relativeSecond = currentTime.difference(encounterStart!).inSeconds;
      final event = _parseCombatEvent(
        content: content,
        timestamp: currentTime,
        second: relativeSecond,
        index: currentEvents.length,
      );
      if (event == null) continue;

      currentEvents.add(event);
      if (event.kind == CombatEventKind.damage && event.amount > 0) {
        currentEncounterHasDamage = true;
      }
    }

    flushEncounter();

    Log.d(
      'COMBAT.PARSER',
      'parseLines(lineCount=${lines.length}) - ${encounters.length} encounters',
    );
    return encounters;
  }

  static String _stripHtml(String rawLine) =>
      rawLine.replaceAll(_htmlRegex, '');

  static DateTime _parseEveTimestamp(String value) {
    final dateParts = value.split(RegExp(r'[. :]'));
    return DateTime.utc(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(dateParts[3]),
      int.parse(dateParts[4]),
      int.parse(dateParts[5]),
    );
  }

  static CombatEvent? _parseCombatEvent({
    required String content,
    required DateTime timestamp,
    required int second,
    required int index,
  }) {
    final damageMatch = _damageRegex.firstMatch(content);
    if (damageMatch != null) {
      final amount = int.tryParse(damageMatch.group(1)!) ?? 0;
      final direction = damageMatch.group(2)! == 'to'
          ? CombatEventDirection.outgoing
          : CombatEventDirection.incoming;
      return CombatEvent(
        id: 'e${index + 1}',
        timestamp: timestamp,
        second: second,
        direction: direction,
        kind: CombatEventKind.damage,
        amount: amount,
        targetName: damageMatch.group(3)!.trim(),
        weaponName: damageMatch.group(4)!.trim(),
        hitQuality: damageMatch.group(5)!.trim(),
        rawLine: content,
      );
    }

    final missMatch = _missRegex.firstMatch(content);
    if (missMatch != null) {
      return CombatEvent(
        id: 'e${index + 1}',
        timestamp: timestamp,
        second: second,
        direction: CombatEventDirection.outgoing,
        kind: CombatEventKind.miss,
        targetName: missMatch.group(2)!.trim(),
        weaponName: missMatch.group(1)!.trim(),
        hitQuality: 'Misses',
        rawLine: content,
      );
    }

    final kind = _looksLikeEwar(content)
        ? CombatEventKind.ewar
        : CombatEventKind.other;
    return CombatEvent(
      id: 'e${index + 1}',
      timestamp: timestamp,
      second: second,
      direction: CombatEventDirection.neutral,
      kind: kind,
      rawLine: content,
    );
  }

  static bool _looksLikeEwar(String content) {
    final lower = content.toLowerCase();
    return lower.contains('warp scramble') ||
        lower.contains('warp disrupt') ||
        lower.contains('web') ||
        lower.contains('jam') ||
        lower.contains('tracking disrupt') ||
        lower.contains('sensor damp') ||
        lower.contains('target paint') ||
        lower.contains('energy neutral') ||
        lower.contains('nosferatu');
  }

  static CombatAggregates _buildAggregates(List<CombatEvent> events) {
    var totalDealt = 0;
    var totalReceived = 0;
    var runningDealt = 0;
    var runningReceived = 0;
    var missCount = 0;
    var ewarCount = 0;
    var outgoingHitCount = 0;
    var incomingHitCount = 0;
    var peakOutgoingHit = 0;
    var peakIncomingHit = 0;
    final cumulative = <CombatTimelinePoint>[
      const CombatTimelinePoint(second: 0, outgoing: 0, incoming: 0),
    ];
    final byTarget = <String, int>{};
    final byWeapon = <String, int>{};
    final bySource = <String, int>{};
    final hitQuality = <String, int>{};
    final outgoingHitQuality = <String, int>{};
    final incomingHitQuality = <String, int>{};

    for (final event in events) {
      if (event.kind == CombatEventKind.miss) missCount++;
      if (event.kind == CombatEventKind.ewar) ewarCount++;

      final quality = event.hitQuality;
      if (quality != null && quality.isNotEmpty) {
        hitQuality.update(quality, (value) => value + 1, ifAbsent: () => 1);
      }

      if (event.isOutgoingDamage) {
        outgoingHitCount++;
        if (event.amount > peakOutgoingHit) peakOutgoingHit = event.amount;
        if (quality != null && quality.isNotEmpty) {
          outgoingHitQuality.update(
            quality,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        totalDealt += event.amount;
        runningDealt += event.amount;
        final target = event.targetName ?? 'Unknown';
        final weapon = event.weaponName ?? 'Unknown';
        byTarget.update(
          target,
          (value) => value + event.amount,
          ifAbsent: () => event.amount,
        );
        byWeapon.update(
          weapon,
          (value) => value + event.amount,
          ifAbsent: () => event.amount,
        );
        cumulative.add(
          CombatTimelinePoint(
            second: event.second,
            outgoing: runningDealt,
            incoming: runningReceived,
          ),
        );
      } else if (event.isIncomingDamage) {
        incomingHitCount++;
        if (event.amount > peakIncomingHit) peakIncomingHit = event.amount;
        if (quality != null && quality.isNotEmpty) {
          incomingHitQuality.update(
            quality,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        totalReceived += event.amount;
        runningReceived += event.amount;
        final source = event.targetName ?? 'Unknown';
        bySource.update(
          source,
          (value) => value + event.amount,
          ifAbsent: () => event.amount,
        );
        cumulative.add(
          CombatTimelinePoint(
            second: event.second,
            outgoing: runningDealt,
            incoming: runningReceived,
          ),
        );
      }
    }

    return CombatAggregates(
      totalDamageDealt: totalDealt,
      totalDamageReceived: totalReceived,
      cumulativeDamage: cumulative,
      damageByTarget: byTarget,
      damageByWeapon: byWeapon,
      incomingBySource: bySource,
      hitQualityCounts: hitQuality,
      outgoingHitQualityCounts: outgoingHitQuality,
      incomingHitQualityCounts: incomingHitQuality,
      outgoingHitCount: outgoingHitCount,
      incomingHitCount: incomingHitCount,
      peakOutgoingHit: peakOutgoingHit,
      peakIncomingHit: peakIncomingHit,
      averageOutgoingHit: outgoingHitCount == 0
          ? 0
          : totalDealt / outgoingHitCount,
      averageIncomingHit: incomingHitCount == 0
          ? 0
          : totalReceived / incomingHitCount,
      missCount: missCount,
      idleGapCount: 0,
      ewarEventCount: ewarCount,
    );
  }

  static _OutcomeDecision _deriveOutcome(CombatAggregates aggregates) {
    final dealt = aggregates.totalDamageDealt;
    final received = aggregates.totalDamageReceived;
    if (dealt <= 0 && received <= 0) {
      return const _OutcomeDecision(
        CombatOutcome.unknown,
        0,
        'No meaningful damage was recorded.',
      );
    }
    if (received > dealt && received > 0) {
      return const _OutcomeDecision(
        CombatOutcome.likelyDefeat,
        0.62,
        'Outcome inferred from damage balance; no killmail/loss event was available.',
      );
    }
    if (dealt > 0 && dealt >= received) {
      return const _OutcomeDecision(
        CombatOutcome.likelyVictory,
        0.58,
        'Outcome inferred from damage balance; no killmail/loss event was available.',
      );
    }
    return const _OutcomeDecision(
      CombatOutcome.unknown,
      0.35,
      'Outcome could not be inferred from the combat log.',
    );
  }

  static String _buildLlmPayload(
    List<CombatEvent> events,
    CombatAggregates aggregates,
  ) {
    final lines = <String>[
      'Totals: dealt=${aggregates.totalDamageDealt}, received=${aggregates.totalDamageReceived}',
      'Primary target: ${aggregates.primaryTarget}',
      'Primary weapon/drone: ${aggregates.primaryWeapon}',
      'Misses: ${aggregates.missCount}',
      'Combat events:',
    ];
    final cappedEvents = events.take(maxLlmEvents).toList();
    for (final event in cappedEvents) {
      lines.add('${event.id} ${event.compactDescription}');
    }
    final omitted = events.length - cappedEvents.length;
    if (omitted > 0) {
      lines.add(
        'Omitted $omitted additional low-level events for token safety.',
      );
    }
    return lines.join('\n');
  }

  static String _stableEncounterId({
    required String sourceFilePath,
    required String characterName,
    required DateTime startTime,
    required DateTime endTime,
    required List<CombatEvent> events,
    required CombatAggregates aggregates,
  }) {
    final first = events.isEmpty ? '' : events.first.rawLine;
    final last = events.isEmpty ? '' : events.last.rawLine;
    final fingerprint = [
      'combat-parser-v$parserVersion',
      sourceFilePath,
      characterName,
      startTime.toUtc().toIso8601String(),
      endTime.toUtc().toIso8601String(),
      aggregates.totalDamageDealt,
      aggregates.totalDamageReceived,
      events.length,
      first,
      last,
    ].join('|');
    return sha256.convert(utf8.encode(fingerprint)).toString();
  }

  static bool _lineContainsCombatDamage(String rawLine) {
    final cleanLine = _stripHtml(rawLine);
    final match = _lineRegex.firstMatch(cleanLine);
    if (match == null) return false;

    var content = match.group(2)!.trim();
    if (!content.startsWith(_combatPrefix)) return false;
    content = content.substring(_combatPrefix.length).trim();

    final damageMatch = _damageRegex.firstMatch(content);
    if (damageMatch == null) return false;
    return (int.tryParse(damageMatch.group(1)!) ?? 0) > 0;
  }
}

class _OutcomeDecision {
  const _OutcomeDecision(this.outcome, this.confidence, this.evidence);

  final CombatOutcome outcome;
  final double confidence;
  final String evidence;
}

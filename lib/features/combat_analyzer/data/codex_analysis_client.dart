import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../domain/combat_aar_report.dart';
import '../domain/combat_enrichment.dart';
import '../domain/combat_log_parser.dart';
import '../domain/parsed_combat_encounter.dart';
import 'codex_auth_service.dart';
import 'codex_auth_store.dart';

final codexAnalysisClientProvider = Provider<CodexAnalysisClient>((ref) {
  return CodexAnalysisClient(authService: ref.watch(codexAuthServiceProvider));
});

class CodexAnalysisResult {
  const CodexAnalysisResult({required this.report});

  final CombatAarReport report;

  String get summary => report.summary;
  String get mistakes => report.mistakesText;
  String get improvements => report.improvementsText;
  String get fits => report.fitsText;

  factory CodexAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CodexAnalysisResult(report: CombatAarReport.fromJson(json));
  }
}

class CodexAnalysisException implements Exception {
  const CodexAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CodexAnalysisClient {
  CodexAnalysisClient({required CodexAuthService authService, Dio? dio})
    : _authService = authService,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 3),
            ),
          );

  final CodexAuthService _authService;
  final Dio _dio;

  Future<CodexAnalysisResult> analyzeEncounter({
    required ParsedCombatEncounter encounter,
    required String model,
    CombatEnrichment? enrichment,
  }) async {
    Log.d('COMBAT.AI', 'analyzeEncounter(model=$model) - START');
    final prompt = _buildPrompt(encounter, enrichment: enrichment);
    final text = await _requestAnalysisText(model: model, prompt: prompt);
    try {
      return _parseAnalysisText(text);
    } on CodexAnalysisException catch (e) {
      Log.w('COMBAT.AI', 'Structured report parse failed; retrying repair: $e');
      final repairText = await _requestAnalysisText(
        model: model,
        prompt: _buildRepairPrompt(
          originalPrompt: prompt,
          invalidResponse: text,
        ),
      );
      return _parseAnalysisText(repairText);
    }
  }

  Future<String> _requestAnalysisText({
    required String model,
    required String prompt,
  }) async {
    final response = await _postResponsesRequest(
      model: model,
      prompt: prompt,
      forceRefresh: false,
    );
    return _extractOutputText(response);
  }

  CodexAnalysisResult _parseAnalysisText(String text) {
    final json = _parseJsonObject(text);
    final result = CodexAnalysisResult.fromJson(json);
    Log.i('COMBAT.AI', 'AI structured analysis response parsed');
    return result;
  }

  Future<Map<String, dynamic>> _postResponsesRequest({
    required String model,
    required String prompt,
    required bool forceRefresh,
  }) async {
    final credentials = await _authService.resolveRuntimeCredentials(
      forceRefresh: forceRefresh,
    );
    final accountId = chatGptAccountIdFromAccessToken(credentials.accessToken);
    final headers = <String, String>{
      'Authorization': 'Bearer ${credentials.accessToken}',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'User-Agent': 'codex_cli_rs/0.0.0 (Mimir)',
      'originator': 'codex_cli_rs',
    };
    if (accountId != null && accountId.isNotEmpty) {
      headers['ChatGPT-Account-ID'] = accountId;
    }

    try {
      final response = await _dio.post<ResponseBody>(
        '${credentials.baseUrl}/responses',
        options: Options(headers: headers, responseType: ResponseType.stream),
        data: {
          'model': model,
          'instructions': _systemPrompt,
          'input': [
            {
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': prompt},
              ],
            },
          ],
          'store': false,
          'stream': true,
        },
      );
      final body = await _readResponseBody(response.data);
      final outputText = _extractOutputTextFromSse(body);
      if (outputText.trim().isEmpty) {
        throw const CodexAnalysisException('AI returned an empty response.');
      }
      return {'output_text': outputText};
    } on DioException catch (e, stack) {
      final status = e.response?.statusCode;
      Log.e('COMBAT.AI', 'AI Responses request failed', e, stack);
      if (!forceRefresh && (status == 401 || status == 403)) {
        Log.w('COMBAT.AI', 'Retrying AI request after token refresh');
        return _postResponsesRequest(
          model: model,
          prompt: prompt,
          forceRefresh: true,
        );
      }
      throw CodexAnalysisException(await _summarizeDioError(e));
    }
  }

  String _buildPrompt(
    ParsedCombatEncounter encounter, {
    CombatEnrichment? enrichment,
  }) {
    Log.d('COMBAT.AI', '_buildPrompt() - START');
    final events = encounter.events
        .take(CombatLogParser.maxLlmEvents)
        .map(
          (event) => {
            'id': event.id,
            'timestamp': event.timestamp.toUtc().toIso8601String(),
            'second': event.second,
            'kind': event.kind.name,
            'direction': event.direction.name,
            'amount': event.amount,
            if (event.targetName != null) 'targetName': event.targetName,
            if (event.weaponName != null) 'weaponName': event.weaponName,
            if (event.hitQuality != null) 'hitQuality': event.hitQuality,
            'rawLine': event.rawLine,
          },
        )
        .toList();
    final payload = {
      'schema': 'mimir.combat_aar_input.v3',
      'pilot': encounter.characterName,
      'startTime': encounter.startTime.toUtc().toIso8601String(),
      'endTime': encounter.endTime.toUtc().toIso8601String(),
      'durationSeconds': encounter.durationSeconds,
      'outcomeHint': encounter.outcome.name,
      'outcomeEvidence': encounter.outcomeEvidence,
      'aggregates': encounter.aggregates.toJson(),
      'events': events,
      'eventOmittedCount': encounter.events.length - events.length,
      if (enrichment != null) ...{
        'killmailEvidence': enrichment.toPromptJson(),
        if (!enrichment.evidenceLedger.isEmpty)
          'evidenceLedger': enrichment.evidenceLedger.toJson(),
        if (enrichment.pilotFitEvidence != null)
          'pilotFitEvidence': enrichment.pilotFitEvidence!.toPromptJson(),
        if (enrichment.victimFitEvidence != null)
          'victimFitEvidence': enrichment.victimFitEvidence!.toPromptJson(),
      },
      'compactEvidence': encounter.llmPayloadString,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _buildRepairPrompt({
    required String originalPrompt,
    required String invalidResponse,
  }) {
    Log.d('COMBAT.AI', '_buildRepairPrompt() - START');
    return '''
The previous response was not valid structured JSON for the requested combat AAR.
Return only one valid JSON object matching the schema in the system instructions.

Original encounter payload:
$originalPrompt

Invalid response to repair:
$invalidResponse
''';
  }

  String _extractOutputText(Map<String, dynamic> response) {
    Log.d('COMBAT.AI', '_extractOutputText() - START');
    final outputText = response['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final output = response['output'];
    if (output is List) {
      final parts = <String>[];
      for (final item in output) {
        if (item is! Map) continue;
        final content = item['content'];
        if (content is String && content.trim().isNotEmpty) {
          parts.add(content.trim());
          continue;
        }
        if (content is! List) continue;
        for (final part in content) {
          if (part is! Map) continue;
          final type = part['type'];
          final text = part['text'];
          if ((type == 'output_text' || type == 'text') &&
              text is String &&
              text.trim().isNotEmpty) {
            parts.add(text.trim());
          }
        }
      }
      final joined = parts.join('\n').trim();
      if (joined.isNotEmpty) return joined;
    }

    throw const CodexAnalysisException(
      'AI response did not contain output text.',
    );
  }

  Future<String> _readResponseBody(ResponseBody? body) async {
    Log.d('COMBAT.AI', '_readResponseBody() - START');
    if (body == null) return '';
    final buffer = StringBuffer();
    await for (final chunk in body.stream) {
      buffer.write(utf8.decode(chunk));
    }
    return buffer.toString();
  }

  String _extractOutputTextFromSse(String body) {
    Log.d('COMBAT.AI', '_extractOutputTextFromSse() - START');
    final deltaBuffer = StringBuffer();
    String? doneText;
    String? completedText;

    for (final event in body.split(RegExp(r'\r?\n\r?\n'))) {
      final dataLines = event
          .split(RegExp(r'\r?\n'))
          .where((line) => line.startsWith('data:'))
          .map((line) => line.substring(5).trimLeft())
          .where((line) => line.isNotEmpty)
          .toList();
      if (dataLines.isEmpty) continue;

      final data = dataLines.join('\n');
      Map<String, dynamic>? decoded;
      try {
        final json = jsonDecode(data);
        if (json is Map) decoded = Map<String, dynamic>.from(json);
      } catch (_) {
        continue;
      }
      if (decoded == null) continue;

      switch (decoded['type']) {
        case 'response.output_text.delta':
          final delta = decoded['delta'];
          if (delta is String) deltaBuffer.write(delta);
          break;
        case 'response.output_text.done':
          final text = decoded['text'];
          if (text is String && text.trim().isNotEmpty) doneText = text;
          break;
        case 'response.completed':
          final response = decoded['response'];
          if (response is Map) {
            completedText = _extractOutputText(
              Map<String, dynamic>.from(response),
            );
          }
          break;
        case 'response.failed':
          final response = decoded['response'];
          if (response is Map) {
            final error = response['error'];
            if (error is Map) {
              final message = error['message'];
              if (message is String && message.trim().isNotEmpty) {
                throw CodexAnalysisException(message.trim());
              }
            }
          }
          break;
      }
    }

    if (doneText != null) return doneText.trim();
    if (completedText != null) return completedText.trim();
    return deltaBuffer.toString().trim();
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    Log.d('COMBAT.AI', '_parseJsonObject() - START');
    final trimmed = _stripMarkdownFence(text.trim());
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Fall through to balanced object extraction.
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final objectText = trimmed.substring(start, end + 1);
      try {
        final decoded = jsonDecode(objectText);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Throw the canonical error below.
      }
    }

    throw const CodexAnalysisException(
      'AI response was not valid combat-analysis JSON.',
    );
  }

  String _stripMarkdownFence(String text) {
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$');
    final match = fence.firstMatch(text);
    return match?.group(1)?.trim() ?? text;
  }

  Future<String> _summarizeDioError(DioException error) async {
    final status = error.response?.statusCode;
    final body = await _normalizeErrorBody(error.response?.data);
    var message = 'Failed to communicate with AI';
    if (status != null) {
      message = '$message (HTTP $status)';
    }
    if (body is Map) {
      final errorBody = body['error'];
      if (errorBody is Map) {
        final nestedMessage = errorBody['message'];
        if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
          return '$message: ${nestedMessage.trim()}';
        }
      } else if (errorBody is String && errorBody.trim().isNotEmpty) {
        return '$message: ${errorBody.trim()}';
      }
    }
    if (error.message != null && error.message!.trim().isNotEmpty) {
      return '$message: ${error.message}';
    }
    return message;
  }

  Future<Object?> _normalizeErrorBody(Object? body) async {
    if (body is ResponseBody) {
      final text = await _readResponseBody(body);
      try {
        return jsonDecode(text);
      } catch (_) {
        return text;
      }
    }
    if (body is String) {
      try {
        return jsonDecode(body);
      } catch (_) {
        return body;
      }
    }
    return body;
  }
}

const String _systemPrompt = '''
You are an expert EVE Online combat analyst.
Analyze the provided structured combat telemetry and return one JSON object.

Rules:
- Use only supplied evidence.
- Reference timestamps or event ids for tactical claims whenever possible.
- Do not invent ships, fits, modules, killmails, or pilot intent.
- If actual fit or killmail data is missing, say so in unknowns or limitations.
- Treat evidenceLedger facts as the source-of-truth index. Cite evidence ids in evidence fields when a fact is decisive.
- Treat pilotFitEvidence with confidence "confirmed" as user-confirmed fight-fit evidence. Treat confidence "reference" only as current-ship context, not historical proof.
- Treat victimFitEvidence from killmail as proven destroyed-victim fit evidence, but do not infer attacker full fits from it.
- If killmailEvidence.status is killmailMatched, treat the killmail outcome, destroyed victim fit, participants, final blow, and killmail time as supplied evidence.
- If killmailEvidence.status is ambiguous, needsReauth, or logOnly, do not use killmail or fit conclusions as proven facts.
- You may infer tactical meaning from EVE mechanics, but label inferred claims and keep them tied to supplied event evidence.
- Parser-provided counts, totals, hit rates, and event ids are authoritative.
- Damage type or resist conclusions must be confidence-labeled. If the log does not prove a defense layer or exact fit, state that limitation.
- Return JSON only: no markdown, no prose outside the JSON object.

Required schema:
{
  "version": 3,
  "headline": "Short battle-review headline",
  "summary": "Brief commander-style summary",
  "outcomeAssessment": "What the evidence says about the outcome",
  "keyMoments": [
    {
      "timestamp": "HH:mm:ss or ISO timestamp from evidence",
      "relativeSecond": 0,
      "category": "opening|pressure|target_switch|damage_spike|mistake|turning_point|finish|unknown",
      "severity": "critical|high|medium|low",
      "title": "Moment title",
      "details": "Why it mattered",
      "eventIds": ["e1"]
    }
  ],
  "rankedMistakes": [
    {
      "rank": 1,
      "title": "Most important tactical issue",
      "severity": "critical|high|medium|low",
      "evidence": "Timestamp/event evidence",
      "impact": "Battle impact",
      "correction": "Specific correction",
      "eventIds": ["e1"]
    }
  ],
  "recommendations": [
    {
      "title": "Actionable recommendation",
      "details": "What to do differently",
      "linkedMistakeRank": 1
    }
  ],
  "fitAdvice": [
    {
      "title": "Fit/application advice",
      "details": "Practical fitting advice grounded in observed evidence",
      "confidence": "observed|inferred|unknown",
      "observedItems": ["Observed weapon/drone/module names only"],
      "recommendedItems": ["Recommended item or class names"],
      "limitations": "State what is unknown about actual fit"
    }
  ],
  "trainingDrills": [
    {
      "title": "Practice drill",
      "details": "Concrete drill or habit"
    }
  ],
  "damageAnalysis": {
    "summary": "Specific damage and application analysis",
    "evidence": "Event ids or aggregate fields supporting the damage analysis",
    "damageTypes": [
      {
        "type": "EM|Thermal|Kinetic|Explosive|unknown",
        "percent": 0.0,
        "amount": 0,
        "confidence": "observed|sde_exact|model_inferred|unknown",
        "source": "Weapon, drone, ammo, or unknown",
        "evidence": "Why this type assignment is justified"
      }
    ],
    "defenseNotes": [
      {
        "layer": "shield|armor|hull|unknown",
        "note": "Resist or layer observation",
        "confidence": "observed|sde_exact|model_inferred|unknown",
        "evidence": "Evidence or limitation"
      }
    ],
    "confidence": 0.0,
    "unknowns": ["Damage/resist facts that cannot be proven from the supplied log"]
  },
  "resourceTopicIds": [
    "drone_application",
    "range_control",
    "transversal",
    "target_selection",
    "damage_application",
    "fit_tank_vs_application",
    "escape_decision"
  ],
  "confidence": 0.0,
  "unknowns": ["Unknown or unenriched facts"]
}
''';

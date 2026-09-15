import 'exploration_notebook.dart';

class ScanRow {
  const ScanRow({
    required this.sourceRow,
    required this.code,
    this.group = '',
    this.typeLabel = '',
    this.name = '',
    this.type = SignatureType.unknown,
    this.valid = true,
    this.duplicate = false,
  });

  final int sourceRow;
  final String code;
  final String group;
  final String typeLabel;
  final String name;
  final SignatureType type;
  final bool valid;
  final bool duplicate;
}

class RowDiagnostic {
  const RowDiagnostic({required this.sourceRow, required this.message});

  final int sourceRow;
  final String message;
}

class ImportConflict {
  const ImportConflict({
    required this.code,
    required this.existing,
    required this.incoming,
  });

  final String code;
  final String existing;
  final String incoming;
}

class ParsedScan {
  const ParsedScan({
    this.rows = const [],
    this.diagnostics = const [],
    this.wholeInputError,
  });

  final List<ScanRow> rows;
  final List<RowDiagnostic> diagnostics;
  final String? wholeInputError;
}

class MergeCandidate {
  const MergeCandidate({
    required this.code,
    this.preservedNotes,
    this.preservedBookmark,
    this.preservedFirstSeenAt,
    this.preservedName,
    this.conflict = false,
    this.newEpisode = false,
  });

  final String code;
  final String? preservedNotes;
  final String? preservedBookmark;
  final DateTime? preservedFirstSeenAt;
  final String? preservedName;
  final bool conflict;
  final bool newEpisode;
}

class ImportPreview {
  const ImportPreview({
    required this.operationId,
    required this.scope,
    required this.observedAt,
    this.inputDigest = '',
    this.rows = const [],
    this.added = 0,
    this.updated = 0,
    this.seenAgain = 0,
    this.duplicates = 0,
    this.invalid = 0,
    this.conflicts = const [],
    this.candidates = const [],
  });

  final String operationId;
  final NotebookScope scope;
  final DateTime observedAt;
  final String inputDigest;
  final List<ScanRow> rows;
  final int added;
  final int updated;
  final int seenAgain;
  final int duplicates;
  final int invalid;
  final List<ImportConflict> conflicts;
  final List<MergeCandidate> candidates;

  String get successMessage {
    final imported = added + updated + seenAgain;
    return 'Imported $imported signatures: $added added, $updated updated, $seenAgain seen again.';
  }
}

class ResolvedImportPreview {
  const ResolvedImportPreview({
    required this.preview,
    this.committed = false,
    this.databaseMutated = false,
  });

  final ImportPreview preview;
  final bool committed;
  final bool databaseMutated;
}

class ScannerImportParser {
  static final _codePattern = RegExp(r'^[A-Z]{3}-[0-9]{3}$');
  static const _supportedGroups = {'cosmic signature', 'cosmic anomaly'};

  static ParsedScan parse(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final stripped = normalized.startsWith('\uFEFF')
        ? normalized.substring(1)
        : normalized;
    final rows = <ScanRow>[];
    final diagnostics = <RowDiagnostic>[];
    final seen = <String>{};
    var physical = 0;
    var skippedHeader = false;
    for (final rawLine in stripped.split('\n')) {
      if (rawLine.trim().isEmpty) continue;
      physical += 1;
      final cells = rawLine.split('\t');
      if (!skippedHeader && _isHeader(cells)) {
        skippedHeader = true;
        continue;
      }
      if (cells.length < 2 || cells.length > 6) {
        rows.add(
          ScanRow(
            sourceRow: physical,
            code: cells.isEmpty ? '' : cells.first.trim(),
            valid: false,
          ),
        );
        diagnostics.add(
          RowDiagnostic(
            sourceRow: physical,
            message: 'Row must have 2 to 6 tab-separated cells.',
          ),
        );
        continue;
      }
      final code = cells[0].trim().toUpperCase();
      final group = cells.length > 1 ? cells[1].trim() : '';
      final typeLabel = cells.length > 2 ? cells[2].trim() : '';
      final name = cells.length > 3 ? cells[3].trim() : '';
      final groupOk = _supportedGroups.contains(group.toLowerCase());
      final codeOk = _codePattern.hasMatch(code);
      if (!codeOk || !groupOk) {
        rows.add(
          ScanRow(
            sourceRow: physical,
            code: code,
            group: group,
            typeLabel: typeLabel,
            name: name,
            valid: false,
          ),
        );
        diagnostics.add(
          RowDiagnostic(
            sourceRow: physical,
            message: codeOk
                ? 'Unsupported scan group.'
                : 'Signature code is invalid.',
          ),
        );
        continue;
      }
      final duplicate = !seen.add(code);
      rows.add(
        ScanRow(
          sourceRow: physical,
          code: code,
          group: group,
          typeLabel: typeLabel,
          name: name,
          valid: true,
          duplicate: duplicate,
        ),
      );
    }
    return ParsedScan(rows: rows, diagnostics: diagnostics);
  }

  static bool _isHeader(List<String> cells) {
    if (cells.isEmpty) return false;
    return cells.first.trim().toUpperCase() == 'ID';
  }
}

class ScannerMergePlanner {
  static ImportPreview plan({
    required ParsedScan parsed,
    required NotebookScope scope,
    required DateTime observedAt,
    List<TrackedSignature> existing = const [],
    String operationId = 'preview',
  }) {
    final byCode = <String, TrackedSignature>{
      for (final row in existing) row.code.toUpperCase(): row,
    };
    var added = 0;
    var updated = 0;
    var seenAgain = 0;
    var duplicates = 0;
    var invalid = 0;
    for (final row in parsed.rows) {
      if (!row.valid) {
        invalid += 1;
        continue;
      }
      if (row.duplicate) {
        duplicates += 1;
        continue;
      }
      final current = byCode[row.code];
      if (current == null) {
        added += 1;
        continue;
      }
      final incomingType = _mapType(row.typeLabel);
      final typeChanged =
          incomingType != SignatureType.unknown && incomingType != current.type;
      final nameChanged =
          row.name.isNotEmpty && row.name != (current.name ?? '');
      if (typeChanged || nameChanged) {
        updated += 1;
      } else {
        seenAgain += 1;
      }
    }
    return ImportPreview(
      operationId: operationId,
      scope: scope,
      observedAt: observedAt,
      rows: parsed.rows,
      added: added,
      updated: updated,
      seenAgain: seenAgain,
      duplicates: duplicates,
      invalid: invalid,
    );
  }

  static SignatureType _mapType(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return SignatureType.unknown;
    if (normalized.contains('wormhole')) return SignatureType.wormhole;
    if (normalized.contains('data')) return SignatureType.data;
    if (normalized.contains('relic')) return SignatureType.relic;
    if (normalized.contains('gas')) return SignatureType.gas;
    if (normalized.contains('combat')) return SignatureType.combat;
    if (normalized.contains('ore')) return SignatureType.ore;
    return SignatureType.unknown;
  }
}

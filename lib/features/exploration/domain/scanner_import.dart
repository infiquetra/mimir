import 'exploration_notebook.dart';

class ScanRow {
  const ScanRow({
    required this.sourceRow,
    required this.code,
    this.group = '',
    this.typeLabel = '',
    this.name = '',
    this.valid = true,
    this.duplicate = false,
  });

  final int sourceRow;
  final String code;
  final String group;
  final String typeLabel;
  final String name;
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
  const ParsedScan({this.rows = const [], this.diagnostics = const []});

  final List<ScanRow> rows;
  final List<RowDiagnostic> diagnostics;
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

  String get successMessage =>
      'Imported ${rows.length} signatures: $added added, $updated updated, $seenAgain seen again.';
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
  /// Naive: whitespace split, no tab contract, no duplicate coalescing.
  static ParsedScan parse(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty);
    final rows = <ScanRow>[];
    var index = 1;
    for (final line in lines) {
      final cells = line.trim().split(RegExp(r'\s+'));
      rows.add(
        ScanRow(
          sourceRow: index,
          code: cells.first,
          group: cells.length > 1 ? cells[1] : '',
          typeLabel: cells.length > 2 ? cells[2] : '',
          name: cells.length > 3 ? cells[3] : '',
        ),
      );
      index += 1;
    }
    return ParsedScan(rows: rows);
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
    return ImportPreview(
      operationId: operationId,
      scope: scope,
      observedAt: observedAt,
      rows: parsed.rows,
      added: parsed.rows.length,
      updated: 0,
      seenAgain: 0,
      duplicates: 0,
      invalid: 0,
    );
  }
}

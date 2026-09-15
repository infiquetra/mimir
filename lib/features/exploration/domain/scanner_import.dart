import 'exploration_notebook.dart';

export 'scanner_import_parser.dart';
export 'scanner_merge_planner.dart';

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
    this.type = SignatureType.unknown,
    this.existingId,
    this.preservedNotes,
    this.preservedBookmark,
    this.preservedFirstSeenAt,
    this.preservedName,
    this.conflict = false,
    this.newEpisode = false,
  });

  final String code;
  final SignatureType type;
  final String? existingId;
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
    this.wholeInputError,
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
  final String? wholeInputError;

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

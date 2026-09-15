import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'exploration_notebook.dart';
import 'scanner_import.dart';

/// Combines parsed scanner rows with a frozen notebook snapshot.
class ScannerMergePlanner {
  static ImportPreview plan({
    required ParsedScan parsed,
    required NotebookScope scope,
    required DateTime observedAt,
    List<TrackedSignature> existing = const [],
    String operationId = 'preview',
  }) {
    if (parsed.wholeInputError != null) {
      return ImportPreview(
        operationId: operationId,
        scope: scope,
        observedAt: observedAt,
        inputDigest: _digest(parsed, operationId),
        wholeInputError: parsed.wholeInputError,
      );
    }

    final activeByCode = <String, TrackedSignature>{};
    final trashByCode = <String, TrackedSignature>{};
    for (final row in existing) {
      final code = row.code.toUpperCase();
      if (row.state == SignatureState.active) {
        activeByCode.putIfAbsent(code, () => row);
      } else if (row.state == SignatureState.trash) {
        trashByCode.putIfAbsent(code, () => row);
      }
    }

    final grouped = <String, List<ScanRow>>{};
    var invalid = 0;
    for (final row in parsed.rows) {
      if (!row.valid) {
        invalid += 1;
        continue;
      }
      grouped.putIfAbsent(row.code, () => []).add(row);
    }

    var added = 0;
    var updated = 0;
    var seenAgain = 0;
    var duplicates = 0;
    final conflicts = <ImportConflict>[];
    final candidates = <MergeCandidate>[];

    final codes = grouped.keys.toList()..sort();
    for (final code in codes) {
      final group = grouped[code]!;
      duplicates += group.length - 1;

      ScanRow? merged;
      var pasteConflict = false;
      for (final row in group) {
        if (merged == null) {
          merged = row;
          continue;
        }
        if (_conflicts(merged, row)) {
          pasteConflict = true;
          conflicts.add(
            ImportConflict(
              code: code,
              existing: _describe(merged),
              incoming: _describe(row),
            ),
          );
        } else {
          merged = _coalesce(merged, row);
        }
      }
      if (merged == null) continue;
      if (pasteConflict) {
        candidates.add(
          MergeCandidate(
            code: code,
            type: merged.type,
            conflict: true,
            preservedName: merged.name.isEmpty ? null : merged.name,
          ),
        );
        continue;
      }

      final active = activeByCode[code];
      if (active != null) {
        if (_conflictsWithExisting(merged, active)) {
          conflicts.add(
            ImportConflict(
              code: code,
              existing: _describeExisting(active),
              incoming: _describe(merged),
            ),
          );
          candidates.add(
            MergeCandidate(
              code: code,
              type: merged.type,
              existingId: active.id,
              conflict: true,
              preservedName: active.name,
              preservedNotes: active.notes,
              preservedBookmark: active.bookmark,
              preservedFirstSeenAt: active.firstSeenAt,
            ),
          );
          continue;
        }
        final fillsType =
            active.type == SignatureType.unknown &&
            merged.type != SignatureType.unknown;
        final fillsName =
            (active.name == null || active.name!.isEmpty) &&
            merged.name.isNotEmpty;
        if (fillsType || fillsName) {
          updated += 1;
        } else {
          seenAgain += 1;
        }
        candidates.add(
          MergeCandidate(
            code: code,
            type: merged.type == SignatureType.unknown
                ? active.type
                : merged.type,
            existingId: active.id,
            preservedName: merged.name.isEmpty ? active.name : merged.name,
            preservedNotes: active.notes,
            preservedBookmark: active.bookmark,
            preservedFirstSeenAt: active.firstSeenAt,
          ),
        );
        continue;
      }

      final trashed = trashByCode[code];
      added += 1;
      candidates.add(
        MergeCandidate(
          code: code,
          type: merged.type,
          newEpisode: trashed != null,
          preservedName: merged.name.isEmpty ? null : merged.name,
        ),
      );
    }

    return ImportPreview(
      operationId: operationId,
      scope: scope,
      observedAt: observedAt,
      inputDigest: _digest(parsed, operationId),
      rows: parsed.rows,
      added: added,
      updated: updated,
      seenAgain: seenAgain,
      duplicates: duplicates,
      invalid: invalid,
      conflicts: conflicts,
      candidates: candidates,
    );
  }

  static bool _conflicts(ScanRow a, ScanRow b) {
    final typeConflict =
        a.type != SignatureType.unknown &&
        b.type != SignatureType.unknown &&
        a.type != b.type;
    final nameConflict =
        a.name.isNotEmpty && b.name.isNotEmpty && a.name != b.name;
    return typeConflict || nameConflict;
  }

  static bool _conflictsWithExisting(
    ScanRow incoming,
    TrackedSignature existing,
  ) {
    final typeConflict =
        incoming.type != SignatureType.unknown &&
        existing.type != SignatureType.unknown &&
        incoming.type != existing.type;
    final existingName = existing.name ?? '';
    final nameConflict =
        incoming.name.isNotEmpty &&
        existingName.isNotEmpty &&
        incoming.name != existingName;
    return typeConflict || nameConflict;
  }

  static ScanRow _coalesce(ScanRow base, ScanRow incoming) {
    return ScanRow(
      sourceRow: base.sourceRow,
      code: base.code,
      group: base.group,
      typeLabel: incoming.typeLabel.isEmpty
          ? base.typeLabel
          : incoming.typeLabel,
      name: incoming.name.isEmpty ? base.name : incoming.name,
      type: incoming.type == SignatureType.unknown ? base.type : incoming.type,
      valid: true,
    );
  }

  static String _describe(ScanRow row) {
    return '${row.type.name}:${row.name}';
  }

  static String _describeExisting(TrackedSignature row) {
    return '${row.type.name}:${row.name ?? ''}';
  }

  static String _digest(ParsedScan parsed, String operationId) {
    final payload = jsonEncode({
      'operationId': operationId,
      'error': parsed.wholeInputError,
      'rows': [
        for (final row in parsed.rows)
          {
            'row': row.sourceRow,
            'code': row.code,
            'type': row.type.name,
            'name': row.name,
            'valid': row.valid,
          },
      ],
    });
    return sha256.convert(utf8.encode(payload)).toString();
  }
}

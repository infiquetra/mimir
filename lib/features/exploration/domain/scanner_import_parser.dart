import 'dart:convert';

import 'exploration_notebook.dart';
import 'scanner_import.dart';

/// Pure clipboard/scanner parser. Caps are inclusive; excess is a whole-input
/// error with no truncation. Physical row numbers count blank lines.
class ScannerImportParser {
  static final _codePattern = RegExp(r'^[A-Z]{3}-[0-9]{3}$');
  static const _supportedGroups = {'cosmic signature', 'cosmic anomaly'};
  static const maxUtf8Bytes = 512 * 1024;
  static const maxNonblankRows = 5000;
  static const maxNameChars = 256;
  static const maxBookmarkChars = 512;
  static const maxNotesChars = 4096;

  static const _types = <String, SignatureType>{
    'unknown': SignatureType.unknown,
    'wormhole': SignatureType.wormhole,
    'data': SignatureType.data,
    'data site': SignatureType.data,
    'relic': SignatureType.relic,
    'relic site': SignatureType.relic,
    'gas': SignatureType.gas,
    'gas site': SignatureType.gas,
    'combat': SignatureType.combat,
    'combat site': SignatureType.combat,
    'ore': SignatureType.ore,
    'ore site': SignatureType.ore,
  };

  static ParsedScan parse(String text) {
    final byteLength = utf8.encode(text).length;
    if (byteLength > maxUtf8Bytes) {
      return const ParsedScan(
        wholeInputError: 'Input exceeds 512KiB UTF-8 limit.',
      );
    }

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final stripped = normalized.startsWith('\uFEFF')
        ? normalized.substring(1)
        : normalized;
    final lines = stripped.split('\n');
    final nonblank = [
      for (final line in lines)
        if (line.trim().isNotEmpty) line,
    ];
    if (nonblank.length > maxNonblankRows) {
      return const ParsedScan(
        wholeInputError: 'Input exceeds 5000 nonblank rows.',
      );
    }

    final rows = <ScanRow>[];
    final diagnostics = <RowDiagnostic>[];
    final seen = <String>{};
    var skippedHeader = false;

    for (var i = 0; i < lines.length; i++) {
      final physical = i + 1;
      final rawLine = lines[i];
      if (rawLine.trim().isEmpty) continue;
      final cells = rawLine.split('\t');
      if (!skippedHeader && _isHeader(cells)) {
        skippedHeader = true;
        continue;
      }
      if (cells.length < 2 || cells.length > 6) {
        rows.add(
          ScanRow(
            sourceRow: physical,
            code: cells.isEmpty ? '' : cells.first.trim().toUpperCase(),
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
      final bookmark = cells.length > 4 ? cells[4].trim() : '';
      final notes = cells.length > 5 ? cells[5].trim() : '';
      final codeOk = _codePattern.hasMatch(code);
      final groupOk = _supportedGroups.contains(group.toLowerCase());

      if (!codeOk) {
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
            message: 'Signature code is invalid.',
          ),
        );
        continue;
      }

      if (!groupOk) {
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
            message: 'Unsupported scan group.',
          ),
        );
        continue;
      }

      if (_scalarLength(name) > maxNameChars ||
          _scalarLength(bookmark) > maxBookmarkChars ||
          _scalarLength(notes) > maxNotesChars) {
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
            message: 'Field exceeds maximum length.',
          ),
        );
        continue;
      }

      final mapped = _mapType(typeLabel);
      final unfamiliar = typeLabel.isNotEmpty && !_isKnownTypeLabel(typeLabel);
      if (unfamiliar) {
        diagnostics.add(
          RowDiagnostic(
            sourceRow: physical,
            message: 'Unknown signature type; recorded as Unknown.',
          ),
        );
      }

      final duplicate = !seen.add(code);
      rows.add(
        ScanRow(
          sourceRow: physical,
          code: code,
          group: group,
          typeLabel: typeLabel,
          name: name,
          type: mapped,
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

  static SignatureType _mapType(String label) {
    return _types[label.trim().toLowerCase()] ?? SignatureType.unknown;
  }

  static bool _isKnownTypeLabel(String label) {
    return _types.containsKey(label.trim().toLowerCase());
  }

  static int _scalarLength(String value) => value.runes.length;
}

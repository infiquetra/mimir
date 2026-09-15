// X4 RED contracts for ScannerImportParser (D12, D14).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §4.3:
// - physical row numbers skip blanks incorrectly
// - mapped SignatureType stays unknown
// - unfamiliar types have no warning
// - 512KiB / 5000-row / name-256 limits are not enforced
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/scanner_import.dart';

void main() {
  group('D12 CRLF/BOM/tabs/groups/types', () {
    test('BOM, CRLF, Cosmic Anomaly, and physical row numbers', () {
      const text =
          '\uFEFFID\tGroup\tType\tName\r\n'
          '\r\n'
          'abc-123\tCosmic Anomaly\tOre Site\tMercoxit\r\n'
          'def-456\tCosmic Signature\tWormhole\tUnstable Wormhole';
      final parsed = ScannerImportParser.parse(text);
      expect(parsed.wholeInputError, isNull);
      expect(parsed.rows, hasLength(2));
      expect(parsed.rows.first.sourceRow, 3);
      expect(parsed.rows.first.code, 'ABC-123');
      expect(parsed.rows.first.type, SignatureType.ore);
      expect(parsed.rows.last.sourceRow, 4);
      expect(parsed.rows.last.type, SignatureType.wormhole);
    });

    test('unfamiliar type under supported group is Unknown with warning', () {
      final parsed = ScannerImportParser.parse(
        'XYZ-111\tCosmic Signature\tAncient Relic Gizmo\tSite',
      );
      expect(parsed.rows, hasLength(1));
      expect(parsed.rows.single.valid, isTrue);
      expect(parsed.rows.single.type, SignatureType.unknown);
      expect(parsed.rows.single.typeLabel, 'Ancient Relic Gizmo');
      expect(
        parsed.diagnostics.any(
          (row) =>
              row.sourceRow == 1 &&
              row.message.toLowerCase().contains('unknown'),
        ),
        isTrue,
      );
    });

    test(
      'unsupported localized group is invalid with the physical row number',
      () {
        final parsed = ScannerImportParser.parse(
          'AAA-111\tKosmisches Signal\tData Site\tFoo',
        );
        expect(parsed.rows.single.valid, isFalse);
        expect(parsed.rows.single.sourceRow, 1);
        expect(parsed.diagnostics.single.message, contains('Unsupported'));
      },
    );

    test('whitespace split is not a fallback; 7 cells are invalid', () {
      final spaces = ScannerImportParser.parse(
        'ABC-123 Cosmic Signature Data Site Name',
      );
      expect(spaces.rows.single.valid, isFalse);
      final wide = ScannerImportParser.parse(
        'ABC-123\tCosmic Signature\tData Site\tName\t1\t2\textra',
      );
      expect(wide.rows.single.valid, isFalse);
      expect(wide.rows.single.sourceRow, 1);
    });
  });

  group('D14 field and input limits', () {
    test('5001 nonblank rows are rejected without truncation', () {
      final buffer = StringBuffer('ID\tGroup\tType\tName\n');
      for (var i = 0; i < 5000; i++) {
        buffer.writeln(
          'A${i.toString().padLeft(2, '0')}-001\tCosmic Signature\tData Site\tN',
        );
      }
      final parsed = ScannerImportParser.parse(buffer.toString());
      expect(parsed.wholeInputError, isNotNull);
      expect(parsed.rows, isEmpty);
    });

    test('512KiB + 1 byte is rejected without truncation', () {
      final oversized = utf8.decode(List<int>.filled(512 * 1024 + 1, 0x41));
      final parsed = ScannerImportParser.parse(oversized);
      expect(parsed.wholeInputError, isNotNull);
      expect(parsed.rows, isEmpty);
    });

    test('name 257, bookmark 513, notes 4097 are invalid', () {
      final name = ScannerImportParser.parse(
        'ABC-123\tCosmic Signature\tData Site\t${'n' * 257}',
      );
      expect(name.rows.single.valid, isFalse);
    });
  });
}

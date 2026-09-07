import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/window/window_types.dart';

void main() {
  group('icon assets', () {
    test('every WindowType icon path exists on disk', () {
      for (final type in WindowType.values) {
        final path = type.iconAsset;
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'WindowType.$type points at missing asset $path',
        );
      }
    });

    test('every tray menu icon referenced in tray_service exists', () {
      final source = File('lib/core/tray/tray_service.dart').readAsStringSync();
      final pattern = RegExp(r"'(assets/icons/tray/[A-Za-z0-9_@.]+\.png)'");
      final referenced = pattern.allMatches(source).map((m) => m.group(1)!);

      expect(referenced, isNotEmpty);
      for (final path in referenced.toSet()) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'tray_service references missing asset $path',
        );
      }
    });
  });
}

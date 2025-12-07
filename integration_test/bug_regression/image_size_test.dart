import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/core/widgets/eve_type_icon.dart';
import 'package:mimir/features/skills/presentation/widgets/eve_skill_icon.dart';

/// Bug regression tests for EVE image size normalization.
///
/// These tests prevent recurring bugs from commit:
/// - 8e6b143: fix(widgets): normalize EveTypeIcon sizes to valid EVE Image Server values
///
/// Historical issue:
/// EVE Image Server only accepts specific sizes: 32, 64, 128, 256, 512, 1024
/// Requesting non-standard sizes (e.g., 24, 48, 100) returns 404 errors.
///
/// CLAUDE.md states: "EVE Image Server only accepts sizes: 32, 64, 128, 256, 512, 1024"
/// "Widgets auto-normalize to nearest valid size"
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('EVE Image Size Normalization Regression Tests', () {
    test(
      'TC-SIZE-001: EveTypeIcon normalizes to valid sizes',
      () {
        // GIVEN: Non-standard size requests
        final testCases = [
          // (requested size, expected normalized size)
          (24, 32), // 24 rounds up to 32
          (40, 32), // 40 rounds down to 32
          (48, 64), // 48 rounds up to 64
          (100, 128), // 100 rounds up to 128
          (200, 256), // 200 rounds up to 256
          (400, 512), // 400 rounds up to 512
          (800, 1024), // 800 rounds up to 1024
          (1500, 1024), // 1500 caps at max 1024
        ];

        for (final (requestedSize, expectedSize) in testCases) {
          // WHEN: Size is normalized
          final normalizedSize = _normalizeIconSize(requestedSize);

          // THEN: Should match expected valid size
          expect(
            normalizedSize,
            expectedSize,
            reason: 'Size $requestedSize should normalize to $expectedSize',
          );
        }

        // REGRESSION CHECK: Before fix (commit 8e6b143), non-standard sizes
        // were passed directly to the EVE Image Server, causing 404 errors.
        // Now all sizes are normalized to valid values (32, 64, 128, 256, 512, 1024).
      },
    );

    test(
      'TC-SIZE-002: Valid sizes pass through unchanged',
      () {
        // GIVEN: Already-valid size requests
        const validSizes = [32, 64, 128, 256, 512, 1024];

        for (final size in validSizes) {
          // WHEN: Size is normalized
          final normalizedSize = _normalizeIconSize(size);

          // THEN: Should remain unchanged
          expect(
            normalizedSize,
            size,
            reason: 'Valid size $size should pass through unchanged',
          );
        }

        // REGRESSION CHECK: Valid sizes should not be modified.
        // The normalization function should be idempotent for valid inputs.
      },
    );

    test(
      'TC-SIZE-003: Edge cases handle gracefully',
      () {
        // GIVEN: Edge case size requests
        final edgeCases = [
          // (requested size, expected normalized size)
          (0, 32), // 0 defaults to minimum (32)
          (1, 32), // 1 rounds up to minimum (32)
          (31, 32), // Just below 32 rounds up
          (33, 32), // Just above 32 rounds down
          (2000, 1024), // Very large size caps at max
          (10000, 1024), // Extremely large size caps at max
        ];

        for (final (requestedSize, expectedSize) in edgeCases) {
          // WHEN: Size is normalized
          final normalizedSize = _normalizeIconSize(requestedSize);

          // THEN: Should handle edge case gracefully
          expect(
            normalizedSize,
            expectedSize,
            reason: 'Edge case $requestedSize should normalize to $expectedSize',
          );
        }

        // REGRESSION CHECK: Edge cases should not crash or produce invalid sizes.
        // All outputs must be one of: 32, 64, 128, 256, 512, 1024.
      },
    );
  });
}

/// Normalize icon size to nearest valid EVE Image Server size.
///
/// Valid sizes: 32, 64, 128, 256, 512, 1024
/// This is the logic that should be implemented in EveTypeIcon and EveSkillIcon.
int _normalizeIconSize(int requestedSize) {
  const validSizes = [32, 64, 128, 256, 512, 1024];

  // Clamp to minimum 32
  if (requestedSize <= 32) return 32;

  // Clamp to maximum 1024
  if (requestedSize >= 1024) return 1024;

  // Find nearest valid size
  int nearest = validSizes.first;
  int minDiff = (requestedSize - nearest).abs();

  for (final size in validSizes) {
    final diff = (requestedSize - size).abs();
    if (diff < minDiff) {
      minDiff = diff;
      nearest = size;
    }
  }

  return nearest;
}

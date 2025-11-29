import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'sde_database.dart';

/// Result of checking for SDE updates.
sealed class SdeUpdateResult {
  const SdeUpdateResult();
}

/// No update available - current version is latest.
class SdeUpToDate extends SdeUpdateResult {
  const SdeUpToDate({required this.currentVersion});

  final String currentVersion;
}

/// An update is available.
class SdeUpdateAvailable extends SdeUpdateResult {
  const SdeUpdateAvailable({
    required this.currentVersion,
    required this.newVersion,
    required this.skillCount,
  });

  final String? currentVersion;
  final String newVersion;
  final int skillCount;
}

/// Update check failed.
class SdeUpdateCheckFailed extends SdeUpdateResult {
  const SdeUpdateCheckFailed({required this.error});

  final String error;
}

/// Result of applying an SDE update.
sealed class SdeApplyResult {
  const SdeApplyResult();
}

/// Update applied successfully.
class SdeUpdateApplied extends SdeApplyResult {
  const SdeUpdateApplied({
    required this.version,
    required this.skillCount,
  });

  final String version;
  final int skillCount;
}

/// Update application failed.
class SdeUpdateFailed extends SdeApplyResult {
  const SdeUpdateFailed({required this.error});

  final String error;
}

/// Manifest data from GitHub releases.
class SdeManifest {
  const SdeManifest({
    required this.version,
    required this.checksum,
    required this.eveVersion,
    required this.skillCount,
  });

  factory SdeManifest.fromJson(Map<String, dynamic> json) {
    return SdeManifest(
      version: json['version'] as String,
      checksum: json['checksum'] as String,
      eveVersion: json['eveVersion'] as String,
      skillCount: json['skillCount'] as int,
    );
  }

  final String version;
  final String checksum;
  final String eveVersion;
  final int skillCount;
}

/// Service for managing SDE updates from GitHub releases.
///
/// Handles:
/// - Checking for new SDE versions via manifest.json
/// - Downloading and validating skills.json
/// - Atomic import into the database
/// - Version metadata tracking
class SdeUpdateService {
  SdeUpdateService({
    required this.database,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final SdeDatabase database;
  final Dio _dio;

  /// Base URL for GitHub releases.
  static const String _releaseBaseUrl =
      'https://github.com/infiquetra/mimir/releases/download';

  /// Metadata keys stored in the database.
  static const String _keyVersion = 'version';
  static const String _keyEveVersion = 'eve_version';
  static const String _keyLastCheck = 'last_check';
  static const String _keyChecksum = 'checksum';
  static const String _keySkillCount = 'skill_count';

  /// Check for available SDE updates.
  ///
  /// Fetches the latest manifest.json and compares versions.
  /// Returns [SdeUpToDate], [SdeUpdateAvailable], or [SdeUpdateCheckFailed].
  Future<SdeUpdateResult> checkForUpdates() async {
    try {
      // Fetch the latest manifest
      final manifest = await _fetchLatestManifest();
      if (manifest == null) {
        return const SdeUpdateCheckFailed(
          error: 'Could not fetch update manifest',
        );
      }

      // Get current version from database
      final currentVersion = await database.getMetadata(_keyVersion);

      // Record that we checked
      await database.setMetadata(
        _keyLastCheck,
        DateTime.now().toIso8601String(),
      );

      // Compare versions
      if (currentVersion == manifest.version) {
        return SdeUpToDate(currentVersion: currentVersion!);
      }

      return SdeUpdateAvailable(
        currentVersion: currentVersion,
        newVersion: manifest.version,
        skillCount: manifest.skillCount,
      );
    } catch (e) {
      debugPrint('SDE Update: Check failed: $e');
      return SdeUpdateCheckFailed(error: e.toString());
    }
  }

  /// Apply the latest SDE update.
  ///
  /// Downloads skills.json, validates checksum, and imports atomically.
  /// Returns [SdeUpdateApplied] or [SdeUpdateFailed].
  Future<SdeApplyResult> applyUpdate() async {
    try {
      // Fetch manifest to get version and checksum
      final manifest = await _fetchLatestManifest();
      if (manifest == null) {
        return const SdeUpdateFailed(error: 'Could not fetch update manifest');
      }

      // Download skills data
      final skillsData = await _downloadSkillsData(manifest.version);
      if (skillsData == null) {
        return const SdeUpdateFailed(error: 'Could not download skills data');
      }

      // Validate checksum
      final jsonString = json.encode(skillsData);
      final actualChecksum = _calculateChecksum(jsonString);
      if (!_validateChecksum(actualChecksum, manifest.checksum)) {
        return const SdeUpdateFailed(
          error: 'Checksum validation failed - data may be corrupted',
        );
      }

      // Import data atomically
      await _importSkillsData(skillsData);

      // Update metadata
      await _updateMetadata(manifest, actualChecksum);

      debugPrint(
        'SDE Update: Successfully updated to version ${manifest.version}',
      );

      return SdeUpdateApplied(
        version: manifest.version,
        skillCount: manifest.skillCount,
      );
    } catch (e) {
      debugPrint('SDE Update: Apply failed: $e');
      return SdeUpdateFailed(error: e.toString());
    }
  }

  /// Get current SDE status information.
  Future<SdeStatus> getStatus() async {
    final metadata = await database.getAllMetadata();

    return SdeStatus(
      version: metadata[_keyVersion],
      eveVersion: metadata[_keyEveVersion],
      lastCheck: metadata[_keyLastCheck] != null
          ? DateTime.tryParse(metadata[_keyLastCheck]!)
          : null,
      skillCount: metadata[_keySkillCount] != null
          ? int.tryParse(metadata[_keySkillCount]!)
          : null,
    );
  }

  /// Fetch the latest manifest from GitHub releases.
  Future<SdeManifest?> _fetchLatestManifest() async {
    try {
      // Try to fetch latest release manifest
      // The URL points to the "latest" release tag
      const url = '$_releaseBaseUrl/sde-latest/manifest.json';

      // Fetch as plain text and parse manually.
      // GitHub release URLs redirect to a CDN and sometimes Dio doesn't
      // correctly detect the content-type after redirects.
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = json.decode(response.data!) as Map<String, dynamic>;
        return SdeManifest.fromJson(data);
      }
    } catch (e) {
      debugPrint('SDE Update: Failed to fetch manifest: $e');
    }
    return null;
  }

  /// Download skills data for a specific version.
  Future<Map<String, dynamic>?> _downloadSkillsData(String version) async {
    try {
      final url = '$_releaseBaseUrl/sde-v$version/skills.json';

      // Fetch as plain text and parse manually.
      // GitHub release URLs redirect to a CDN and sometimes Dio doesn't
      // correctly detect the content-type after redirects.
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return json.decode(response.data!) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('SDE Update: Failed to download skills: $e');
    }
    return null;
  }

  /// Calculate SHA256 checksum of data.
  String _calculateChecksum(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return 'sha256:${digest.toString()}';
  }

  /// Validate checksum against expected value.
  bool _validateChecksum(String actual, String expected) {
    // Allow exact match or match without prefix
    if (actual == expected) return true;

    // Strip prefix if present for comparison
    final actualHash =
        actual.startsWith('sha256:') ? actual.substring(7) : actual;
    final expectedHash =
        expected.startsWith('sha256:') ? expected.substring(7) : expected;

    return actualHash == expectedHash;
  }

  /// Import skills data into the database atomically.
  Future<void> _importSkillsData(Map<String, dynamic> data) async {
    // Use database transaction for atomic update
    await database.transaction(() async {
      // Clear existing data
      await database.clearAll();

      // Import categories
      if (data.containsKey('categories')) {
        final categories = (data['categories'] as List)
            .map((c) => SdeCategoriesCompanion.insert(
                  categoryId: Value(c['categoryId'] as int),
                  categoryName: c['categoryName'] as String,
                ))
            .toList();
        await database.upsertCategories(categories);
      }

      // Import groups
      if (data.containsKey('groups')) {
        final groups = (data['groups'] as List)
            .map((g) => SdeGroupsCompanion.insert(
                  groupId: Value(g['groupId'] as int),
                  groupName: g['groupName'] as String,
                  categoryId: g['categoryId'] as int,
                ))
            .toList();
        await database.upsertGroups(groups);
      }

      // Import types (skills)
      if (data.containsKey('types')) {
        final types = (data['types'] as List)
            .map((t) => SdeTypesCompanion.insert(
                  typeId: Value(t['typeId'] as int),
                  typeName: t['typeName'] as String,
                  groupId: t['groupId'] as int,
                  description: t['description'] != null
                      ? Value(t['description'] as String)
                      : const Value.absent(),
                ))
            .toList();
        await database.upsertTypes(types);
      }
    });
  }

  /// Update metadata after successful import.
  Future<void> _updateMetadata(SdeManifest manifest, String checksum) async {
    await database.setMetadata(_keyVersion, manifest.version);
    await database.setMetadata(_keyEveVersion, manifest.eveVersion);
    await database.setMetadata(_keyChecksum, checksum);
    await database.setMetadata(_keySkillCount, manifest.skillCount.toString());
    await database.setMetadata(
      _keyLastCheck,
      DateTime.now().toIso8601String(),
    );
  }
}

/// Status information about the installed SDE data.
class SdeStatus {
  const SdeStatus({
    this.version,
    this.eveVersion,
    this.lastCheck,
    this.skillCount,
  });

  /// Installed SDE version (e.g., "20250805").
  final String? version;

  /// EVE SDE release name (e.g., "sde-20250805-TRANQUILITY").
  final String? eveVersion;

  /// When updates were last checked.
  final DateTime? lastCheck;

  /// Number of skills in the database.
  final int? skillCount;

  /// Whether SDE data has been installed.
  bool get hasData => version != null;

  /// Human-readable time since last check.
  String? get lastCheckDisplay {
    if (lastCheck == null) return null;

    final diff = DateTime.now().difference(lastCheck!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }
}

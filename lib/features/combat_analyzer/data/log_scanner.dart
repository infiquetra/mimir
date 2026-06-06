import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/platform/app_paths.dart';
import 'package:path/path.dart' as p;

import '../domain/combat_log_parser.dart';

class LogScanner {
  static const int defaultMaxLogFiles = 100;
  static const String _directoryKey = 'combat_log_directory';
  static const String _combatLogCacheKey = 'combat_log_cache';
  static const String _configFileName = 'combat_analyzer.json';
  static final RegExp _gamelogFilePattern = RegExp(
    r'(^|[/\\])\d{8}_\d{6}(?:_\d+)?\.txt$',
  );

  LogScanner({String? configFilePath, String? defaultLogDirectoryPath})
    : _configFilePath = configFilePath,
      _defaultLogDirectoryPath = defaultLogDirectoryPath;

  final String? _configFilePath;
  final String? _defaultLogDirectoryPath;

  Future<String?> getLogDirectory() async {
    // 1. Try saved directory first
    final savedPath = await _readSavedLogDirectory();
    if (savedPath != null && await _isAccessible(savedPath)) {
      Log.i('COMBAT', 'Using saved log directory: $savedPath');
      return savedPath;
    }

    // 2. Try default macOS Wine path
    final home = Platform.environment['HOME'];
    if (home != null) {
      final defaultPath =
          _defaultLogDirectoryPath ?? '$home/Documents/EVE/logs/Gamelogs/';
      if (await _isAccessible(defaultPath)) {
        Log.i('COMBAT', 'Found default log directory: $defaultPath');
        await _saveLogDirectory(defaultPath);
        return defaultPath;
      }
    }

    // Default not accessible, return null to indicate user prompt needed
    Log.w('COMBAT', 'Default log directory inaccessible or not found.');
    return null;
  }

  Future<String?> promptUserForDirectory() async {
    Log.i('COMBAT', 'Prompting user to select log directory');
    try {
      final String? directoryPath = await getDirectoryPath();
      if (directoryPath != null) {
        Log.i('COMBAT', 'User selected directory: $directoryPath');
        await _saveLogDirectory(directoryPath);
        return directoryPath;
      }
    } catch (e, stack) {
      Log.e('COMBAT', 'Failed to pick directory', e, stack);
    }
    return null;
  }

  Future<List<File>> getCombatLogs({int limit = defaultMaxLogFiles}) async {
    Log.d('COMBAT', 'getCombatLogs(limit=$limit) - START');
    final dirPath = await getLogDirectory();
    if (dirPath == null) return [];

    final dir = Directory(dirPath);
    try {
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => _gamelogFilePattern.hasMatch(f.path))
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));

      final config = await _readConfig();
      final cache = _readCombatLogCache(config);
      var cacheChanged = _pruneCombatLogCache(cache, files);
      var cacheHits = 0;
      var inspected = 0;
      final combatFiles = <File>[];

      for (final file in files) {
        final cached = await _cachedCombatClassification(file, cache);
        final isCombat = cached ?? await _inspectCombatLog(file, cache);
        if (cached != null) {
          cacheHits++;
        } else {
          inspected++;
          cacheChanged = true;
        }

        if (isCombat) {
          combatFiles.add(file);
          if (limit > 0 && combatFiles.length >= limit) {
            break;
          }
        }
      }

      if (cacheChanged) {
        await _saveCombatLogCache(dirPath, cache);
      }

      Log.i(
        'COMBAT',
        'Found ${files.length} EVE gamelog files in $dirPath; '
            'returning ${combatFiles.length} combat logs '
            '(cache hits: $cacheHits, inspected: $inspected)',
      );
      return combatFiles;
    } catch (e, stack) {
      Log.e('COMBAT', 'Failed to list logs in $dirPath', e, stack);
      return [];
    }
  }

  Future<bool> _isAccessible(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        // Try to read it to check permissions
        await dir.list().take(1).toList();
        return true;
      }
    } catch (e) {
      Log.d('COMBAT', 'Directory $path is inaccessible: $e');
    }
    return false;
  }

  Future<String> _configPath() async {
    if (_configFilePath != null) return _configFilePath;
    final supportPath = await getMimirApplicationSupportPath();
    return p.join(supportPath, _configFileName);
  }

  Future<String?> _readSavedLogDirectory() async {
    Log.d('COMBAT', '_readSavedLogDirectory() - START');
    final decoded = await _readConfig();
    final savedPath = decoded[_directoryKey];
    if (savedPath is String && savedPath.trim().isNotEmpty) {
      Log.d('COMBAT', '_readSavedLogDirectory() - found saved directory');
      return savedPath.trim();
    }
    return null;
  }

  Future<Map<String, dynamic>> _readConfig() async {
    Log.d('COMBAT', '_readConfig() - START');
    try {
      final file = File(await _configPath());
      if (!await file.exists()) {
        Log.d('COMBAT', '_readConfig() - no config file');
        return {};
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        Log.w('COMBAT', 'Combat analyzer config is not a JSON object');
        return {};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (e, stack) {
      Log.e('COMBAT', 'Failed to read combat analyzer config', e, stack);
    }
    return {};
  }

  Future<void> _saveLogDirectory(String directoryPath) async {
    Log.d('COMBAT', '_saveLogDirectory() - START');
    final existing = await _readConfig();
    final existingDirectory = existing[_directoryKey];
    final existingCache = existing[_combatLogCacheKey];
    final cache = existingDirectory == directoryPath && existingCache is Map
        ? Map<String, dynamic>.from(existingCache)
        : <String, dynamic>{};
    await _writeConfig({
      'version': 1,
      _directoryKey: directoryPath,
      _combatLogCacheKey: cache,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _saveCombatLogCache(
    String directoryPath,
    Map<String, dynamic> cache,
  ) async {
    Log.d('COMBAT', '_saveCombatLogCache() - START');
    final existing = await _readConfig();
    await _writeConfig({
      ...existing,
      'version': 1,
      _directoryKey: directoryPath,
      _combatLogCacheKey: cache,
      'cache_updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _writeConfig(Map<String, dynamic> config) async {
    Log.d('COMBAT', '_writeConfig() - START');
    try {
      final file = File(await _configPath());
      await file.parent.create(recursive: true);
      final payload = const JsonEncoder.withIndent('  ').convert(config);
      final tmpFile = File(
        '${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}.$pid',
      );
      try {
        await tmpFile.writeAsString('$payload\n');
        if (await file.exists()) {
          await file.delete();
        }
        await tmpFile.rename(file.path);
      } finally {
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      }
      Log.i('COMBAT', 'Saved combat analyzer config');
    } catch (e, stack) {
      Log.e('COMBAT', 'Failed to save combat analyzer config', e, stack);
    }
  }

  Map<String, dynamic> _readCombatLogCache(Map<String, dynamic> config) {
    Log.d('COMBAT', '_readCombatLogCache() - START');
    final cache = config[_combatLogCacheKey];
    if (cache is Map) {
      return Map<String, dynamic>.from(cache);
    }
    return <String, dynamic>{};
  }

  bool _pruneCombatLogCache(Map<String, dynamic> cache, List<File> files) {
    Log.d('COMBAT', '_pruneCombatLogCache() - START');
    final knownPaths = files.map((file) => file.path).toSet();
    final stalePaths = cache.keys
        .where((path) => !knownPaths.contains(path))
        .toList();
    for (final path in stalePaths) {
      cache.remove(path);
    }
    return stalePaths.isNotEmpty;
  }

  Future<bool?> _cachedCombatClassification(
    File file,
    Map<String, dynamic> cache,
  ) async {
    final stat = await file.stat();
    final entry = cache[file.path];
    if (entry is! Map) return null;
    final modified = stat.modified.toUtc().toIso8601String();
    if (entry['modified'] == modified &&
        entry['size'] == stat.size &&
        entry['is_combat'] is bool) {
      return entry['is_combat'] as bool;
    }
    return null;
  }

  Future<bool> _inspectCombatLog(File file, Map<String, dynamic> cache) async {
    Log.d('COMBAT', '_inspectCombatLog(path=${file.path}) - START');
    final stat = await file.stat();
    final isCombat = await CombatLogParser.fileContainsCombatDamage(file);
    cache[file.path] = {
      'modified': stat.modified.toUtc().toIso8601String(),
      'size': stat.size,
      'is_combat': isCombat,
      'checked_at': DateTime.now().toUtc().toIso8601String(),
    };
    return isCombat;
  }
}

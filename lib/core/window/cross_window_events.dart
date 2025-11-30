import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../database/app_database.dart';

/// Event types for cross-window communication.
enum CrossWindowEventType {
  /// Authentication completed for a character.
  authComplete,

  /// A character was deleted.
  characterDeleted,

  /// Character data was refreshed from ESI.
  characterRefreshed,
}

/// An event that can be broadcast across windows via file system.
class CrossWindowEvent {
  final CrossWindowEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CrossWindowEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CrossWindowEvent.fromJson(Map<String, dynamic> json) {
    return CrossWindowEvent(
      type: CrossWindowEventType.values.byName(json['type'] as String),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Service for broadcasting and receiving events across windows.
///
/// Uses file-based signaling with FileSystemEntity.watch() for reliable
/// cross-process communication. This replaces the unreliable IPC mechanism.
class CrossWindowEventService {
  static const _eventsDir = 'events';
  static const _eventFilePrefix = 'event_';

  StreamSubscription<FileSystemEvent>? _watcher;
  final _eventController = StreamController<CrossWindowEvent>.broadcast();
  DateTime? _lastProcessedTimestamp;

  /// Stream of events from other windows.
  Stream<CrossWindowEvent> get events => _eventController.stream;

  /// Gets the events directory path.
  static Future<Directory> _getEventsDir() async {
    final dbPath = await getDatabasePath();
    final dir = Directory(path.join(path.dirname(dbPath), _eventsDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Broadcasts an event to all windows.
  ///
  /// Writes an event file that other windows will detect via file watching.
  static Future<void> broadcast(CrossWindowEvent event) async {
    final dir = await _getEventsDir();
    final fileName =
        '$_eventFilePrefix${event.type.name}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(path.join(dir.path, fileName));

    await file.writeAsString(jsonEncode(event.toJson()));
    debugPrint('[CROSS_WINDOW] Broadcast event: ${event.type.name}');

    // Clean up old event files (keep last 10 seconds worth)
    _cleanupOldEvents(dir);
  }

  /// Starts watching for events from other windows.
  Future<void> startWatching() async {
    final dir = await _getEventsDir();
    _lastProcessedTimestamp = DateTime.now();

    debugPrint('[CROSS_WINDOW] Starting file watcher on: ${dir.path}');

    _watcher = dir.watch(events: FileSystemEvent.create).listen((event) {
      if (event is FileSystemCreateEvent &&
          event.path.contains(_eventFilePrefix) &&
          event.path.endsWith('.json')) {
        _handleEventFile(File(event.path));
      }
    });
  }

  /// Handles a newly created event file.
  Future<void> _handleEventFile(File file) async {
    try {
      // Small delay to ensure file is fully written
      await Future.delayed(const Duration(milliseconds: 50));

      if (!await file.exists()) return;

      final content = await file.readAsString();
      final event = CrossWindowEvent.fromJson(jsonDecode(content));

      // Skip events we've already processed (from before we started watching)
      if (_lastProcessedTimestamp != null &&
          event.timestamp.isBefore(_lastProcessedTimestamp!)) {
        return;
      }

      debugPrint('[CROSS_WINDOW] Received event: ${event.type.name}');
      _eventController.add(event);
    } catch (e) {
      debugPrint('[CROSS_WINDOW] Error processing event file: $e');
    }
  }

  /// Cleans up event files older than 10 seconds.
  static Future<void> _cleanupOldEvents(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 10));
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains(_eventFilePrefix)) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Cleanup failures are non-critical
      debugPrint('[CROSS_WINDOW] Cleanup error: $e');
    }
  }

  /// Stops watching for events.
  void dispose() {
    _watcher?.cancel();
    _watcher = null;
    _eventController.close();
  }
}

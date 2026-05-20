import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mimir/core/logging/logger.dart';
import '../domain/killmail_models.dart';

class ZKillboardClient {
  static const _wsUrl = 'wss://zkillboard.com/websocket/';
  static const _redisQUrl = 'https://redisq.zkillboard.com/listen.php';

  WebSocketChannel? _channel;
  final StreamController<ZKillmail> _killStream =
      StreamController<ZKillmail>.broadcast();
  bool _isPolling = false;
  bool _isIntentionalDisconnect = false;

  Stream<ZKillmail> get kills => _killStream.stream;

  /// Connect to WebSocket feed
  Future<void> connectWebSocket({
    List<int>? systems,
    List<int>? regions,
    List<int>? corporations,
    List<int>? alliances,
    List<int>? characters,
  }) async {
    Log.d('INTEL', 'Connecting to zKillboard WebSocket');
    _isIntentionalDisconnect = false;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      final subs = <Map<String, dynamic>>[];

      if (systems != null) {
        for (final id in systems) {
          subs.add({'action': 'sub', 'channel': 'system:$id'});
        }
      }
      if (regions != null) {
        for (final id in regions) {
          subs.add({'action': 'sub', 'channel': 'region:$id'});
        }
      }
      if (corporations != null) {
        for (final id in corporations) {
          subs.add({'action': 'sub', 'channel': 'corporation:$id'});
        }
      }
      if (alliances != null) {
        for (final id in alliances) {
          subs.add({'action': 'sub', 'channel': 'alliance:$id'});
        }
      }
      if (characters != null) {
        for (final id in characters) {
          subs.add({'action': 'sub', 'channel': 'character:$id'});
        }
      }

      // If no specific subscriptions provided, subscribe to all kills (firehose)
      // Note: zKillboard public feed typically requires some filter to not be overwhelmed,
      // but 'public' channel works for demonstration.
      if (subs.isEmpty) {
        subs.add({'action': 'sub', 'channel': 'public'});
      }

      for (final sub in subs) {
        _channel!.sink.add(jsonEncode(sub));
      }

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String);
            if (json.containsKey('killmail') && json.containsKey('zkb')) {
              final kill = ZKillmail.fromJson(json);
              _killStream.add(kill);
            }
          } catch (e, st) {
            Log.e('INTEL', 'Failed to parse killmail from WebSocket', e, st);
          }
        },
        onError: (e) => _handleError(e),
        onDone: () => _handleDisconnect(),
      );
    } catch (e, st) {
      Log.e('INTEL', 'WebSocket connection failed', e, st);
      // Fallback to RedisQ
      startRedisQPolling();
    }
  }

  void _handleError(dynamic error) {
    if (_isIntentionalDisconnect) return;
    Log.e('INTEL', 'WebSocket error: $error');
    disconnect();
    startRedisQPolling();
  }

  void _handleDisconnect() {
    if (_isIntentionalDisconnect) return;
    Log.w('INTEL', 'WebSocket disconnected unexpectedly');
    _channel = null;
    startRedisQPolling();
  }

  /// Fallback: RedisQ polling for when WebSocket is unavailable or disconnected
  Future<void> startRedisQPolling() async {
    if (_isPolling) return;
    _isPolling = true;
    Log.i('INTEL', 'Started RedisQ polling as fallback');

    while (_isPolling) {
      try {
        final response = await http.get(Uri.parse('$_redisQUrl?ttw=10'));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['package'] != null) {
            final kill = ZKillmail.fromJson(json['package']);
            _killStream.add(kill);
          }
        }
      } catch (e, st) {
        Log.e('INTEL', 'RedisQ polling error', e, st);
        await Future.delayed(const Duration(seconds: 10));
      }
    }
  }

  void disconnect() {
    _isIntentionalDisconnect = true;
    _channel?.sink.close();
    _channel = null;
    _isPolling = false;
    Log.i('INTEL', 'Disconnected from zKillboard feeds');
  }

  void dispose() {
    disconnect();
    _killStream.close();
  }
}

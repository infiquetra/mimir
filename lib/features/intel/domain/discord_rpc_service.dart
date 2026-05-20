import 'package:mimir/core/logging/logger.dart';

class DiscordRpcService {
  bool _isConnected = false;

  Future<void> initialize() async {
    Log.i('DISCORD', 'Initializing Discord RPC Mock');
    _isConnected = true;
  }

  void updatePresence({
    required String details,
    required String state,
    String? largeImageKey,
    String? largeImageText,
    String? smallImageKey,
    String? smallImageText,
  }) {
    if (!_isConnected) {
      Log.w('DISCORD', 'Cannot update presence: Discord RPC not connected');
      return;
    }

    Log.i('DISCORD', 'Updated Presence: $details | $state');
  }

  void clearPresence() {
    if (!_isConnected) return;
    Log.i('DISCORD', 'Cleared Presence');
  }

  void dispose() {
    _isConnected = false;
    Log.i('DISCORD', 'Disposed Discord RPC');
  }
}

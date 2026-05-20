import 'dart:async';
import 'package:mimir/core/logging/logger.dart';

abstract class MapperClient {
  Future<void> connect(String url, String apiKey);
  void disconnect();
  Stream<Map<String, dynamic>> get mapUpdates;
}

class PathfinderClient implements MapperClient {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();
  Timer? _mockTimer;

  @override
  Future<void> connect(String url, String apiKey) async {
    Log.i('MAPPER', 'Connecting to Pathfinder at $url');
    // Mocking an active map feed for MVP
    _mockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _controller.add({
        'activeSystem': 'J210333',
        'chainDepth': 3,
        'connections': 4,
        'hasHostiles': false,
      });
    });

    // Initial mock data
    Future.delayed(const Duration(seconds: 1), () {
      _controller.add({
        'activeSystem': 'J210333',
        'chainDepth': 3,
        'connections': 4,
        'hasHostiles': false,
      });
    });
  }

  @override
  void disconnect() {
    _mockTimer?.cancel();
    Log.i('MAPPER', 'Disconnected from Pathfinder');
  }

  @override
  Stream<Map<String, dynamic>> get mapUpdates => _controller.stream;
}

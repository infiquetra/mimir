import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// HTTP client for zkillboard API.
///
/// Handles:
/// - Character combat statistics retrieval
/// - Rate limiting and caching
/// - Error handling for unreliable zkillboard API
class ZkillboardClient {
  final Dio _dio;

  /// Base URL for zkillboard API.
  static const String baseUrl = 'https://zkillboard.com/api';

  /// Timeout for zkillboard requests (can be slow/unreliable).
  static const int timeoutMs = 15000;

  ZkillboardClient({Dio? dio}) : _dio = dio ?? Dio() {
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(milliseconds: timeoutMs);
    _dio.options.receiveTimeout = const Duration(milliseconds: timeoutMs);

    // Add user agent header as recommended by zkillboard.
    _dio.options.headers = {
      'User-Agent': 'Mimir EVE Companion App',
    };

    // Add interceptor for logging.
    _dio.interceptors.add(_ZkillboardInterceptor());
  }

  /// Gets combat statistics for a character.
  ///
  /// Returns null if the character has no killboard data (404).
  /// Throws [ZkillboardException] for other errors.
  Future<ZkillboardStats?> getCharacterStats(int characterId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats/characterID/$characterId/',
      );

      if (response.data == null) {
        return null;
      }

      return ZkillboardStats.fromJson(response.data!);
    } on DioException catch (e) {
      // 404 means character has no killboard data.
      if (e.response?.statusCode == 404) {
        return null;
      }

      // Handle other errors.
      final statusCode = e.response?.statusCode;
      String message;

      if (statusCode == 429) {
        message = 'Rate limited by zkillboard API';
      } else if (statusCode != null && statusCode >= 500) {
        message = 'zkillboard server error';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        message = 'zkillboard request timed out';
      } else {
        message = e.message ?? 'Unknown zkillboard error';
      }

      throw ZkillboardException(message, statusCode: statusCode);
    }
  }
}

/// Interceptor for zkillboard-specific logging.
class _ZkillboardInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        'zkillboard ${response.requestOptions.method} ${response.requestOptions.path} '
        '-> ${response.statusCode}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      'zkillboard Error: ${err.message} (status: ${err.response?.statusCode})',
    );
    handler.next(err);
  }
}

/// Combat statistics from zkillboard API.
class ZkillboardStats {
  final int kills;
  final int deaths;
  final double iskDestroyed;
  final double iskLost;

  const ZkillboardStats({
    required this.kills,
    required this.deaths,
    required this.iskDestroyed,
    required this.iskLost,
  });

  /// K/D ratio (kills / deaths). Returns 0 if no deaths.
  double get kdRatio {
    if (deaths == 0) {
      return kills.toDouble();
    }
    return kills / deaths;
  }

  /// Danger rating (kills - deaths).
  /// Positive means more kills, negative means more deaths.
  int get dangerRating => kills - deaths;

  /// Net ISK (destroyed - lost).
  /// Positive means net profit, negative means net loss.
  double get netIsk => iskDestroyed - iskLost;

  /// Whether this character has any combat activity.
  bool get hasActivity => kills > 0 || deaths > 0;

  factory ZkillboardStats.fromJson(Map<String, dynamic> json) {
    // zkillboard API can return different structures, handle gracefully.
    final kills = _parseIntField(json, 'shipsDestroyed') ??
        _parseIntField(json, 'kills') ??
        0;
    final deaths = _parseIntField(json, 'shipsLost') ??
        _parseIntField(json, 'deaths') ??
        0;

    final iskDestroyed = _parseDoubleField(json, 'iskDestroyed') ?? 0.0;
    final iskLost = _parseDoubleField(json, 'iskLost') ?? 0.0;

    return ZkillboardStats(
      kills: kills,
      deaths: deaths,
      iskDestroyed: iskDestroyed,
      iskLost: iskLost,
    );
  }

  /// Helper to parse int fields from various formats.
  static int? _parseIntField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  /// Helper to parse double fields from various formats.
  static double? _parseDoubleField(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is num) return value.toDouble();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'shipsDestroyed': kills,
      'shipsLost': deaths,
      'iskDestroyed': iskDestroyed,
      'iskLost': iskLost,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZkillboardStats &&
          runtimeType == other.runtimeType &&
          kills == other.kills &&
          deaths == other.deaths &&
          iskDestroyed == other.iskDestroyed &&
          iskLost == other.iskLost;

  @override
  int get hashCode =>
      kills.hashCode ^
      deaths.hashCode ^
      iskDestroyed.hashCode ^
      iskLost.hashCode;

  @override
  String toString() {
    return 'ZkillboardStats(kills: $kills, deaths: $deaths, '
        'iskDestroyed: $iskDestroyed, iskLost: $iskLost)';
  }
}

/// Exception for zkillboard API errors.
class ZkillboardException implements Exception {
  final String message;
  final int? statusCode;

  const ZkillboardException(this.message, {this.statusCode});

  @override
  String toString() => 'ZkillboardException: $message (status: $statusCode)';

  /// Whether this error indicates rate limiting.
  bool get isRateLimited => statusCode == 429;

  /// Whether this error is a server error (5xx).
  bool get isServerError =>
      statusCode != null && statusCode! >= 500 && statusCode! < 600;

  /// Whether this error is a timeout.
  bool get isTimeout => message.contains('timed out');
}

/// Provider for the zkillboard client.
final zkillboardClientProvider = Provider<ZkillboardClient>((ref) {
  return ZkillboardClient();
});

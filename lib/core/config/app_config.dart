/// Application configuration constants.
abstract class AppConfig {
  /// Application name.
  static const String appName = 'Mimir';

  /// Application version (should match pubspec.yaml).
  static const String version = '0.1.0';

  /// Minimum supported Dart SDK version.
  static const String minDartSdk = '3.5.0';

  /// Whether the app is in debug mode.
  static bool get isDebug {
    var debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }
}

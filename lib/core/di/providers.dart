import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// Provider for the application router.
///
/// This is a singleton that persists for the lifetime of the app.
final routerProvider = Provider<GoRouter>((ref) {
  return createRouter();
});

/// Provider for tracking the current theme mode.
///
/// Defaults to system theme, but can be overridden by user preference.
final themeModeProvider = StateProvider<ThemeModeOption>((ref) {
  return ThemeModeOption.system;
});

/// Theme mode options.
enum ThemeModeOption {
  light,
  dark,
  system,
}

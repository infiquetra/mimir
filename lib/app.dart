import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/deep_link_handler.dart';
import 'core/di/providers.dart';
import 'core/theme/app_theme.dart';

/// The root widget of the Mimir application.
///
/// This widget sets up:
/// - Material app with go_router for navigation
/// - Theme switching (light/dark/system)
/// - Riverpod state management
/// - Deep link handling for OAuth callbacks
class MimirApp extends ConsumerWidget {
  const MimirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Initialize deep link handler for OAuth callbacks.
    // Reading the provider causes it to be created and start listening.
    ref.watch(deepLinkHandlerProvider);

    return MaterialApp.router(
      title: 'Mimir',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _toThemeMode(themeMode),

      // Router configuration
      routerConfig: router,
    );
  }

  ThemeMode _toThemeMode(ThemeModeOption option) {
    switch (option) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }
}

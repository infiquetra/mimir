// X7 RED contracts for WindowType.exploration, coalesced opens, SDE-independent
// mounting, and visibility. Compile stubs load so these fail as assertions.
// Expected RED until GREEN implements design §6:
// - windowId 99 / fromId(14) dashboard / title Explore / 800x600
// - missing exploration icon and tray registration
// - concurrent openWindow creates twice; hide destroys the controller
// - SubWindowApp still waits on sdeInitializerProvider
// - visibility dispose leaves the poll timer; resume is not emitted
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/window/sub_window_app.dart';
import 'package:mimir/core/window/window_service.dart';
import 'package:mimir/core/window/window_types.dart';
import 'package:mimir/core/window/window_visibility_service.dart';
import 'package:mimir/features/exploration/presentation/exploration_screen.dart';

void main() {
  group('U01 WindowType.exploration identity', () {
    test('windowId is 14 and fromId(14) round-trips', () {
      expect(WindowType.exploration.windowId, 14);
      expect(WindowTypeExtension.fromId(14), WindowType.exploration);
      expect(WindowType.combatAnalyzer.windowId, isNot(14));
    });

    test('title is Exploration and default size is 1440x900', () {
      expect(WindowType.exploration.title, 'Exploration');
      expect(WindowType.exploration.defaultSize, (
        width: 1440.0,
        height: 900.0,
      ));
    });

    test('window and tray icons exist and tray registers exploration', () {
      expect(File(WindowType.exploration.iconAsset).existsSync(), isTrue);
      final trayIcon = File('assets/icons/tray/exploration.png');
      expect(trayIcon.existsSync(), isTrue);
      final traySource = File(
        'lib/core/tray/tray_service.dart',
      ).readAsStringSync();
      expect(traySource.contains('WindowType.exploration'), isTrue);
      expect(traySource.contains('assets/icons/tray/exploration.png'), isTrue);
    });
  });

  group('P07/P09 WindowService coalescing and hide', () {
    tearDown(WindowService.instance.debugReset);

    test('concurrent openWindow coalesces to one create', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      WindowService.instance.debugCreateHook = (type) async {
        if (!started.isCompleted) started.complete();
        await release.future;
      };
      final first = WindowService.instance.openWindow(WindowType.exploration);
      final second = WindowService.instance.openWindow(WindowType.exploration);
      await started.future;
      expect(WindowService.instance.debugCreateCalls, 1);
      release.complete();
      await Future.wait([first, second]);
      expect(WindowService.instance.debugCreateCalls, 1);
      expect(
        WindowService.instance.isWindowOpen(WindowType.exploration),
        isTrue,
      );
    });

    test('hide preserves controller; reopen shows without recreate', () async {
      WindowService.instance.debugCreateHook = (_) async {};
      await WindowService.instance.openWindow(WindowType.exploration);
      expect(WindowService.instance.debugCreateCalls, 1);
      await WindowService.instance.hideWindow(WindowType.exploration);
      expect(
        WindowService.instance.isWindowOpen(WindowType.exploration),
        isTrue,
      );
      await WindowService.instance.openWindow(WindowType.exploration);
      expect(WindowService.instance.debugCreateCalls, 1);
      expect(WindowService.instance.debugShowCalls, 1);
    });
  });

  group('SubWindowApp SDE independence', () {
    test('exploration does not wait on the global SDE initializer', () {
      expect(SubWindowApp.waitsForGlobalSde(WindowType.exploration), isFalse);
      expect(SubWindowApp.waitsForGlobalSde(WindowType.skills), isTrue);
    });

    testWidgets('exploration shell mounts while SDE initializer hangs', (
      tester,
    ) async {
      final hang = Completer<void>();
      addTearDown(() {
        if (!hang.isCompleted) hang.complete();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sdeInitializerProvider.overrideWith((ref) => hang.future),
          ],
          child: SubWindowApp(
            windowArgs: jsonEncode({
              'windowType': WindowType.exploration.windowId,
            }),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ExplorationScreen), findsOneWidget);
      expect(find.text('Loading skill data...'), findsNothing);
    });
  });

  group('WindowVisibilityService', () {
    test('emits visible, hidden, closed, and resume', () async {
      final service = WindowVisibilityService();
      final seen = <WindowVisibilityEvent>[];
      final sub = service.events.listen(seen.add);
      service.emitVisible();
      service.emitHidden();
      service.emitClosed();
      service.emitResume();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [
        WindowVisibilityEvent.visible,
        WindowVisibilityEvent.hidden,
        WindowVisibilityEvent.closed,
        WindowVisibilityEvent.resume,
      ]);
      service.dispose();
      await sub.cancel();
    });

    test('stops polling when hidden and detaches on dispose', () {
      final service = WindowVisibilityService();
      service.emitVisible();
      expect(service.isPolling, isTrue);
      service.emitHidden();
      expect(service.isPolling, isFalse);
      service.dispose();
      expect(service.isPolling, isFalse);
    });
  });
}

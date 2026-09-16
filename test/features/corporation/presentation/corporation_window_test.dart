// C7 RED: WindowType.corporation identity, IDs 0–14, coalesce, hide, SDE.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/window/sub_window_app.dart';
import 'package:mimir/core/window/window_types.dart';
import 'package:mimir/features/corporation/presentation/corporation_screen.dart';

void main() {
  group('U01 WindowType.corporation identity', () {
    test('windowId is 15 and fromId(15) round-trips', () {
      expect(WindowType.corporation.windowId, 15);
      expect(WindowTypeExtension.fromId(15), WindowType.corporation);
      expect(WindowType.exploration.windowId, isNot(15));
    });

    test('title is Corporation and default size is 1200x800', () {
      expect(
        WindowType.corporation.title,
        anyOf('Corporation - Mimir', 'Corporation'),
      );
      expect(WindowType.corporation.defaultSize, (
        width: 1200.0,
        height: 800.0,
      ));
    });

    test('prior window IDs 0-14 are unchanged', () {
      expect(WindowType.main.windowId, 0);
      expect(WindowType.dashboard.windowId, 1);
      expect(WindowType.skills.windowId, 2);
      expect(WindowType.wallet.windowId, 3);
      expect(WindowType.characters.windowId, 4);
      expect(WindowType.settings.windowId, 5);
      expect(WindowType.onboarding.windowId, 6);
      expect(WindowType.assets.windowId, 7);
      expect(WindowType.planetary.windowId, 8);
      expect(WindowType.industry.windowId, 9);
      expect(WindowType.market.windowId, 10);
      expect(WindowType.fitting.windowId, 11);
      expect(WindowType.intel.windowId, 12);
      expect(WindowType.combatAnalyzer.windowId, 13);
      expect(WindowType.exploration.windowId, 14);
      expect(WindowTypeExtension.fromId(0), WindowType.main);
      expect(WindowTypeExtension.fromId(14), WindowType.exploration);
    });

    test('window and tray icons exist and tray registers corporation', () {
      expect(File(WindowType.corporation.iconAsset).existsSync(), isTrue);
      expect(
        WindowType.corporation.iconAsset,
        'assets/icons/eve/corporation.png',
      );
      expect(File('assets/icons/tray/corporation.png').existsSync(), isTrue);
      final traySource = File(
        'lib/core/tray/tray_service.dart',
      ).readAsStringSync();
      expect(traySource.contains('WindowType.corporation'), isTrue);
      expect(traySource.contains('assets/icons/tray/corporation.png'), isTrue);
    });
  });

  group('WindowService coalescing and hide', () {
    test('concurrent openWindow coalesces to one create', () async {
      final session = CorporationWindowSession();
      await Future.wait([session.openWindow(), session.openWindow()]);
      expect(session.createCount, 1);
      expect(session.isOpen, isTrue);
    });

    test('hide preserves controller; reopen shows without recreate', () async {
      final session = CorporationWindowSession();
      await session.openWindow();
      expect(session.createCount, 1);
      await session.hideWindow();
      expect(session.isOpen, isTrue);
      await session.openWindow();
      expect(session.createCount, 1);
      expect(session.showCount, 1);
    });
  });

  group('SubWindowApp SDE independence', () {
    test('corporation does not wait on the global SDE initializer', () {
      expect(SubWindowApp.waitsForGlobalSde(WindowType.corporation), isFalse);
      expect(SubWindowApp.waitsForGlobalSde(WindowType.skills), isTrue);
    });

    testWidgets('corporation shell mounts while SDE initializer hangs', (
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
              'windowType': WindowType.corporation.windowId,
            }),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CorporationScreen), findsOneWidget);
      expect(find.text('Loading skill data...'), findsNothing);
    });
  });
}

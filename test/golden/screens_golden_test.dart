import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/window/standalone_characters_screen.dart';
import 'package:mimir/core/window/standalone_dashboard_screen.dart';
import 'package:mimir/features/dashboard/data/combat_providers.dart';
import 'package:mimir/features/dashboard/data/fleet_providers.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/onboarding/presentation/onboarding_screen.dart';
import 'package:mimir/features/pi/presentation/pi_overview_screen.dart';
import 'package:mimir/features/settings/presentation/settings_screen.dart';
import 'package:mimir/features/skills/presentation/skills_screen.dart';
import 'package:mimir/features/wallet/presentation/wallet_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../integration_test/test_utils/fixtures/character_fixtures.dart';
import '../../integration_test/test_utils/fixtures/skill_fixtures.dart';
import '../../integration_test/test_utils/fixtures/wallet_fixtures.dart';
import '../../integration_test/test_utils/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Mark as sub-window to disable CachedNetworkImage disk caching,
  // which prevents path_provider and sqflite errors in tests.
  setDatabasePath('.');

  // Mock path_provider just in case something else calls it
  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return '.';
  });

  group('Screen Visual Validation (Golden Tests)', () {
    final characterId = 12345678;

    // Define custom desktop devices based on window types
    const dashboardDevice = Device(name: 'dashboard', size: Size(1100, 850));
    const skillsDevice = Device(name: 'skills', size: Size(1200, 900));
    const walletDevice = Device(name: 'wallet', size: Size(800, 700));
    const charactersDevice = Device(name: 'characters', size: Size(1200, 800));
    const settingsDevice = Device(name: 'settings', size: Size(500, 450));
    const piDevice = Device(name: 'pi', size: Size(1000, 800));
    const onboardingDevice = Device(name: 'onboarding', size: Size(800, 600));
    const skillsCompactDevice = Device(name: 'skills_compact', size: Size(1000, 800));

    testGoldens('Dashboard renders correctly without overflows', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
              final walletData = WalletFixtures.fullWalletData(characterId: characterId);
              await db.insertWalletJournalEntries((walletData['journal']! as List).cast());
              await db.recordWalletBalance(characterId, 1500000000.0);
            },
            providerOverrides: [
              allCharacterCombatStatsProvider.overrideWith((ref) async => const AggregateCombatStats(
                    totalKills: 100,
                    totalDeaths: 50,
                    totalIskDestroyed: 1000000000.0,
                    totalIskLost: 500000000.0,
                    characterStats: [],
                  )),
              allCharacterFleetStatusProvider.overrideWith((ref) async => const AggregateFleetStatus(
                    totalCharacters: 1,
                    onlineCharacters: 1,
                    offlineCharacters: 0,
                    characterStatuses: [],
                  )),
              walletTrendsProvider.overrideWith((ref) async => WalletTrendsData(
                    chartPoints: [
                      WalletTrendsPoint(date: DateTime(2024, 1, 1), balance: 1000000000.0),
                      WalletTrendsPoint(date: DateTime(2024, 1, 2), balance: 1200000000.0),
                    ],
                    income: 500000000.0,
                    expenses: 200000000.0,
                  )),
            ],
            home: const StandaloneDashboardScreen(),
          ),
          surfaceSize: dashboardDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'dashboard_screen', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });
        
        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testGoldens('Skills Screen renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
          surfaceSize: skillsDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'skills_screen', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });

        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testGoldens('Skills Screen renders correctly (Compact)', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
          surfaceSize: skillsCompactDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'skills_screen_compact', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });

        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testGoldens('Wallet Screen renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              final walletData = WalletFixtures.fullWalletData(characterId: characterId);
              await db.insertWalletJournalEntries((walletData['journal']! as List).cast());
              await db.recordWalletBalance(characterId, 1500000000.0);
            },
            home: const WalletScreen(),
          ),
          surfaceSize: walletDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'wallet_screen', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });

        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testGoldens('Characters Screen renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const StandaloneCharactersScreen(),
          ),
          surfaceSize: charactersDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'characters_screen', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });

        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testGoldens('Settings Screen renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          const TestApp(
            initialCharacter: null,
            home: SettingsScreen(),
          ),
          surfaceSize: settingsDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'settings_screen', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });

        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testGoldens('PI Screen renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const PiOverviewScreen(),
          ),
          surfaceSize: piDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'pi_screen', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });

        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testGoldens('Onboarding Screen renders correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidgetBuilder(
          const TestApp(
            initialCharacter: null,
            home: OnboardingScreen(),
          ),
          surfaceSize: onboardingDevice.size,
        );

        await tester.pump(const Duration(seconds: 2));
        await screenMatchesGolden(tester, 'onboarding_screen', customPump: (tester) async {
          await tester.pump(const Duration(milliseconds: 500));
        });

        // Clean up
        await tester.pumpWidget(Container());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  });
}

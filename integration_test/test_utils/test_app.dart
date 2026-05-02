import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart';

import 'fixtures/character_fixtures.dart';
import 'mocks/mock_esi_client.dart';

/// Test app wrapper for integration tests.
///
/// Provides a consistent test environment with:
/// - In-memory database (isolated per test)
/// - Mock ESI client
/// - Provider overrides
/// - MaterialApp shell
/// - Optional initial character setup
///
/// Example usage:
/// ```dart
/// testWidgets('test name', (tester) async {
///   final app = TestApp(
///     initialCharacter: CharacterFixtures.testCharacter(),
///     child: const MyScreen(),
///   );
///
///   await tester.pumpWidget(app);
///   await tester.pumpAndSettle();
///
///   expect(find.text('Test Capsuleer'), findsOneWidget);
/// });
/// ```
class TestApp extends StatefulWidget {
  const TestApp({
    super.key,
    this.initialCharacter,
    this.setupDatabase,
    this.providerOverrides = const [],
    this.useMockEsi = true,
    this.child,
    this.home,
  }) : assert(
          child != null || home != null,
          'Either child or home must be provided',
        );

  /// Initial character to insert and set as active.
  ///
  /// If null, no character is inserted. Use CharacterFixtures.testCharacter()
  /// for a standard test character.
  final CharactersCompanion? initialCharacter;

  /// Optional callback to set up the database before the app starts.
  ///
  /// Useful for inserting test data beyond the initial character.
  /// Called after initialCharacter is inserted (if provided).
  ///
  /// Example:
  /// ```dart
  /// setupDatabase: (db) async {
  ///   await db.batch((batch) {
  ///     batch.insertAll(
  ///       db.skillQueueEntries,
  ///       SkillFixtures.activeQueue(characterId: 12345678),
  ///     );
  ///   });
  /// },
  /// ```
  final Future<void> Function(AppDatabase db)? setupDatabase;

  /// Additional provider overrides.
  ///
  /// The test database and mock ESI client are already overridden.
  /// Use this for additional providers like themeModeProvider.
  final List<dynamic> providerOverrides;

  /// Whether to use MockEsiClient (default: true).
  ///
  /// Set to false if you want to provide a custom ESI client override.
  final bool useMockEsi;

  /// Child widget to render (wrapped in Scaffold).
  ///
  /// Use this for widget-level tests where you're testing a specific widget.
  final Widget? child;

  /// Home widget to render (not wrapped).
  ///
  /// Use this for screen-level tests where the widget handles its own Scaffold.
  final Widget? home;

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  late final AppDatabase _database;
  late final MockEsiClient _mockEsiClient;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTestEnvironment();
  }

  Future<void> _initializeTestEnvironment() async {
    // Create in-memory database for isolation.
    _database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

    // Create and configure mock ESI client.
    _mockEsiClient = MockEsiClient();

    // Insert initial character if provided.
    if (widget.initialCharacter != null) {
      await _database.upsertCharacter(widget.initialCharacter!);

      // Set as active character.
      final characterId = widget.initialCharacter!.characterId.value;
      await _database.setActiveCharacter(characterId);

      // Set up mock ESI client for this character.
      _mockEsiClient.setupFullCharacterData(characterId);
    }

    // Run custom database setup if provided.
    if (widget.setupDatabase != null) {
      await widget.setupDatabase!(_database);
    }

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Build provider overrides list.
    final overrides = [
      // Always override database with in-memory instance.
      databaseProvider.overrideWithValue(_database),

      // Override ESI client if useMockEsi is true.
      if (widget.useMockEsi)
        esiClientProvider.overrideWithValue(_mockEsiClient),

      // Add any additional overrides.
      ...widget.providerOverrides,
    ];

    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: widget.home ??
            Scaffold(
              body: widget.child!,
            ),
      ),
    );
  }
}

/// Get the test database from a WidgetTester's element tree.
///
/// Useful for verifying database state in tests.
///
/// Example:
/// ```dart
/// final db = getTestDatabase(tester);
/// final characters = await db.getAllCharacters();
/// expect(characters.length, 2);
/// ```
AppDatabase getTestDatabase(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return container.read(databaseProvider);
}

/// Get the mock ESI client from a WidgetTester's element tree.
///
/// Useful for setting up additional mock responses mid-test.
///
/// Example:
/// ```dart
/// final mockEsi = getMockEsiClient(tester);
/// mockEsi.setupActiveSkillQueue(12345678);
/// ```
MockEsiClient getMockEsiClient(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return container.read(esiClientProvider) as MockEsiClient;
}

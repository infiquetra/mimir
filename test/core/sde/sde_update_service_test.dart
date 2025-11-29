import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_update_service.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late SdeDatabase database;
  late MockDio mockDio;
  late SdeUpdateService service;

  setUp(() {
    database = SdeDatabase.forTesting(NativeDatabase.memory());
    mockDio = MockDio();
    service = SdeUpdateService(database: database, dio: mockDio);
  });

  tearDown(() async {
    await database.close();
  });

  group('SdeManifest', () {
    test('should parse from JSON', () {
      final json = {
        'version': '20250805',
        'checksum': 'sha256:abc123',
        'eveVersion': 'sde-20250805-TRANQUILITY',
        'skillCount': 517,
      };

      final manifest = SdeManifest.fromJson(json);

      expect(manifest.version, '20250805');
      expect(manifest.checksum, 'sha256:abc123');
      expect(manifest.eveVersion, 'sde-20250805-TRANQUILITY');
      expect(manifest.skillCount, 517);
    });
  });

  group('SdeStatus', () {
    test('should indicate no data when version is null', () {
      const status = SdeStatus();
      expect(status.hasData, false);
    });

    test('should indicate has data when version is set', () {
      const status = SdeStatus(version: '20250805');
      expect(status.hasData, true);
    });

    test('should display "Just now" for recent check', () {
      final status = SdeStatus(lastCheck: DateTime.now());
      expect(status.lastCheckDisplay, 'Just now');
    });

    test('should display minutes ago', () {
      final status = SdeStatus(
        lastCheck: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      expect(status.lastCheckDisplay, '30 minutes ago');
    });

    test('should display hours ago', () {
      final status = SdeStatus(
        lastCheck: DateTime.now().subtract(const Duration(hours: 5)),
      );
      expect(status.lastCheckDisplay, '5 hours ago');
    });

    test('should display days ago', () {
      final status = SdeStatus(
        lastCheck: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(status.lastCheckDisplay, '3 days ago');
    });

    test('should display weeks ago', () {
      final status = SdeStatus(
        lastCheck: DateTime.now().subtract(const Duration(days: 14)),
      );
      expect(status.lastCheckDisplay, '2 weeks ago');
    });

    test('should return null when lastCheck is null', () {
      const status = SdeStatus();
      expect(status.lastCheckDisplay, null);
    });
  });

  group('SdeDatabase metadata', () {
    test('should store and retrieve metadata', () async {
      await database.setMetadata('version', '20250805');
      final version = await database.getMetadata('version');
      expect(version, '20250805');
    });

    test('should update existing metadata', () async {
      await database.setMetadata('version', '20250801');
      await database.setMetadata('version', '20250805');
      final version = await database.getMetadata('version');
      expect(version, '20250805');
    });

    test('should return null for missing metadata', () async {
      final value = await database.getMetadata('nonexistent');
      expect(value, null);
    });

    test('should get all metadata as map', () async {
      await database.setMetadata('version', '20250805');
      await database.setMetadata('skill_count', '517');

      final metadata = await database.getAllMetadata();

      expect(metadata['version'], '20250805');
      expect(metadata['skill_count'], '517');
    });

    test('should delete metadata', () async {
      await database.setMetadata('version', '20250805');
      await database.deleteMetadata('version');
      final value = await database.getMetadata('version');
      expect(value, null);
    });

    test('should clear all metadata', () async {
      await database.setMetadata('version', '20250805');
      await database.setMetadata('skill_count', '517');
      await database.clearMetadata();
      final metadata = await database.getAllMetadata();
      expect(metadata, isEmpty);
    });
  });

  group('SdeUpdateService.getStatus', () {
    test('should return status with no data initially', () async {
      final status = await service.getStatus();

      expect(status.hasData, false);
      expect(status.version, null);
      expect(status.lastCheck, null);
    });

    test('should return status with stored metadata', () async {
      await database.setMetadata('version', '20250805');
      await database.setMetadata('eve_version', 'sde-20250805-TRANQUILITY');
      await database.setMetadata('skill_count', '517');
      await database.setMetadata(
        'last_check',
        DateTime.now().toIso8601String(),
      );

      final status = await service.getStatus();

      expect(status.hasData, true);
      expect(status.version, '20250805');
      expect(status.eveVersion, 'sde-20250805-TRANQUILITY');
      expect(status.skillCount, 517);
      expect(status.lastCheck, isNotNull);
    });
  });

  group('SdeUpdateService.checkForUpdates', () {
    // JSON string for mock manifest response
    const manifestJson = '{"version":"20250805","checksum":"sha256:abc123",'
        '"eveVersion":"sde-20250805-TRANQUILITY","skillCount":517}';

    test('should return SdeUpdateCheckFailed when manifest fetch fails',
        () async {
      when(
        () => mockDio.get<String>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        error: 'Network error',
      ));

      final result = await service.checkForUpdates();

      expect(result, isA<SdeUpdateCheckFailed>());
    });

    test('should return SdeUpToDate when versions match', () async {
      // Set current version
      await database.setMetadata('version', '20250805');

      // Mock manifest response (now returns String, not Map)
      when(
        () => mockDio.get<String>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: manifestJson,
          ));

      final result = await service.checkForUpdates();

      expect(result, isA<SdeUpToDate>());
      expect((result as SdeUpToDate).currentVersion, '20250805');
    });

    test('should return SdeUpdateAvailable when newer version exists',
        () async {
      // Set current version
      await database.setMetadata('version', '20250801');

      // Mock manifest response with newer version (returns String)
      when(
        () => mockDio.get<String>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: manifestJson,
          ));

      final result = await service.checkForUpdates();

      expect(result, isA<SdeUpdateAvailable>());
      final available = result as SdeUpdateAvailable;
      expect(available.currentVersion, '20250801');
      expect(available.newVersion, '20250805');
      expect(available.skillCount, 517);
    });

    test('should return SdeUpdateAvailable when no current version', () async {
      // No version set

      // Mock manifest response (returns String)
      when(
        () => mockDio.get<String>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: manifestJson,
          ));

      final result = await service.checkForUpdates();

      expect(result, isA<SdeUpdateAvailable>());
      final available = result as SdeUpdateAvailable;
      expect(available.currentVersion, null);
      expect(available.newVersion, '20250805');
    });
  });

  group('Update result types', () {
    test('SdeUpToDate should store currentVersion', () {
      const result = SdeUpToDate(currentVersion: '20250805');
      expect(result.currentVersion, '20250805');
    });

    test('SdeUpdateAvailable should store all fields', () {
      const result = SdeUpdateAvailable(
        currentVersion: '20250801',
        newVersion: '20250805',
        skillCount: 517,
      );
      expect(result.currentVersion, '20250801');
      expect(result.newVersion, '20250805');
      expect(result.skillCount, 517);
    });

    test('SdeUpdateCheckFailed should store error', () {
      const result = SdeUpdateCheckFailed(error: 'Network error');
      expect(result.error, 'Network error');
    });

    test('SdeUpdateApplied should store version and count', () {
      const result = SdeUpdateApplied(version: '20250805', skillCount: 517);
      expect(result.version, '20250805');
      expect(result.skillCount, 517);
    });

    test('SdeUpdateFailed should store error', () {
      const result = SdeUpdateFailed(error: 'Checksum mismatch');
      expect(result.error, 'Checksum mismatch');
    });
  });
}

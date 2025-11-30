import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mimir/features/dashboard/data/zkillboard_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('ZkillboardClient', () {
    late MockDio mockDio;
    late ZkillboardClient client;

    setUp(() {
      mockDio = MockDio();

      // Stub options property to return a BaseOptions instance
      when(() => mockDio.options).thenReturn(BaseOptions());

      // Stub interceptors property to return an empty Interceptors instance
      when(() => mockDio.interceptors).thenReturn(Interceptors());

      client = ZkillboardClient(dio: mockDio);
    });

    group('getCharacterStats', () {
      const characterId = 12345;

      test('should return ZkillboardStats on successful response', () async {
        // Arrange
        final responseData = {
          'shipsDestroyed': 100,
          'shipsLost': 50,
          'iskDestroyed': 10000000000.0,
          'iskLost': 5000000000.0,
        };

        when(() => mockDio.get<Map<String, dynamic>>(
              '/stats/characterID/$characterId/',
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
            data: responseData,
            statusCode: 200,
          ),
        );

        // Act
        final result = await client.getCharacterStats(characterId);

        // Assert
        expect(result, isNotNull);
        expect(result!.kills, 100);
        expect(result.deaths, 50);
        expect(result.iskDestroyed, 10000000000.0);
        expect(result.iskLost, 5000000000.0);
        expect(result.kdRatio, 2.0);
        expect(result.dangerRating, 50);
      });

      test('should return null on 404 response', () async {
        // Arrange
        when(() => mockDio.get<Map<String, dynamic>>(
              '/stats/characterID/$characterId/',
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
            response: Response(
              requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
              statusCode: 404,
            ),
          ),
        );

        // Act
        final result = await client.getCharacterStats(characterId);

        // Assert
        expect(result, isNull);
      });

      test('should throw ZkillboardException on 429 rate limit', () async {
        // Arrange
        when(() => mockDio.get<Map<String, dynamic>>(
              '/stats/characterID/$characterId/',
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
            response: Response(
              requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
              statusCode: 429,
            ),
          ),
        );

        // Act & Assert
        expect(
          () => client.getCharacterStats(characterId),
          throwsA(
            predicate<ZkillboardException>(
              (e) => e.statusCode == 429 && e.isRateLimited,
            ),
          ),
        );
      });

      test('should throw ZkillboardException on 500 server error', () async {
        // Arrange
        when(() => mockDio.get<Map<String, dynamic>>(
              '/stats/characterID/$characterId/',
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
            response: Response(
              requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
              statusCode: 500,
            ),
          ),
        );

        // Act & Assert
        expect(
          () => client.getCharacterStats(characterId),
          throwsA(
            predicate<ZkillboardException>(
              (e) => e.statusCode == 500 && e.isServerError,
            ),
          ),
        );
      });

      test('should throw ZkillboardException on timeout', () async {
        // Arrange
        when(() => mockDio.get<Map<String, dynamic>>(
              '/stats/characterID/$characterId/',
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        // Act & Assert
        expect(
          () => client.getCharacterStats(characterId),
          throwsA(
            predicate<ZkillboardException>(
              (e) => e.isTimeout,
            ),
          ),
        );
      });

      test('should handle alternate JSON format (kills/deaths)', () async {
        // Arrange
        final responseData = {
          'kills': 75,
          'deaths': 25,
          'iskDestroyed': 8000000000.0,
          'iskLost': 2000000000.0,
        };

        when(() => mockDio.get<Map<String, dynamic>>(
              '/stats/characterID/$characterId/',
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
            data: responseData,
            statusCode: 200,
          ),
        );

        // Act
        final result = await client.getCharacterStats(characterId);

        // Assert
        expect(result, isNotNull);
        expect(result!.kills, 75);
        expect(result.deaths, 25);
      });

      test('should return null when response data is null', () async {
        // Arrange
        when(() => mockDio.get<Map<String, dynamic>>(
              '/stats/characterID/$characterId/',
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/stats/characterID/$characterId/'),
            data: null,
            statusCode: 200,
          ),
        );

        // Act
        final result = await client.getCharacterStats(characterId);

        // Assert
        expect(result, isNull);
      });
    });

    group('ZkillboardStats', () {
      test('should calculate K/D ratio correctly', () {
        const stats = ZkillboardStats(
          kills: 100,
          deaths: 50,
          iskDestroyed: 10000000000.0,
          iskLost: 5000000000.0,
        );

        expect(stats.kdRatio, 2.0);
      });

      test('should handle zero deaths for K/D ratio', () {
        const stats = ZkillboardStats(
          kills: 100,
          deaths: 0,
          iskDestroyed: 10000000000.0,
          iskLost: 5000000000.0,
        );

        expect(stats.kdRatio, 100.0);
      });

      test('should calculate danger rating correctly', () {
        const stats = ZkillboardStats(
          kills: 100,
          deaths: 50,
          iskDestroyed: 10000000000.0,
          iskLost: 5000000000.0,
        );

        expect(stats.dangerRating, 50);
      });

      test('should calculate net ISK correctly', () {
        const stats = ZkillboardStats(
          kills: 100,
          deaths: 50,
          iskDestroyed: 10000000000.0,
          iskLost: 5000000000.0,
        );

        expect(stats.netIsk, 5000000000.0);
      });

      test('should detect activity correctly', () {
        const statsWithActivity = ZkillboardStats(
          kills: 100,
          deaths: 50,
          iskDestroyed: 10000000000.0,
          iskLost: 5000000000.0,
        );

        const statsNoActivity = ZkillboardStats(
          kills: 0,
          deaths: 0,
          iskDestroyed: 0.0,
          iskLost: 0.0,
        );

        expect(statsWithActivity.hasActivity, isTrue);
        expect(statsNoActivity.hasActivity, isFalse);
      });

      test('should serialize to JSON correctly', () {
        const stats = ZkillboardStats(
          kills: 100,
          deaths: 50,
          iskDestroyed: 10000000000.0,
          iskLost: 5000000000.0,
        );

        final json = stats.toJson();

        expect(json['shipsDestroyed'], 100);
        expect(json['shipsLost'], 50);
        expect(json['iskDestroyed'], 10000000000.0);
        expect(json['iskLost'], 5000000000.0);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'shipsDestroyed': 100,
          'shipsLost': 50,
          'iskDestroyed': 10000000000.0,
          'iskLost': 5000000000.0,
        };

        final stats = ZkillboardStats.fromJson(json);

        expect(stats.kills, 100);
        expect(stats.deaths, 50);
        expect(stats.iskDestroyed, 10000000000.0);
        expect(stats.iskLost, 5000000000.0);
      });
    });
  });
}

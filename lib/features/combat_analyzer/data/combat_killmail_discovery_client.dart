import 'package:dio/dio.dart';

import '../../../core/logging/logger.dart';

class CombatKillmailDiscoveryClient {
  CombatKillmailDiscoveryClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://zkillboard.com',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {
                'Accept': 'application/json',
                'Accept-Encoding': 'gzip',
                'User-Agent': 'Mimir Combat Analyzer (contact: local-user)',
              },
            ),
          );

  final Dio _dio;

  Future<List<CombatZkillKillmailRef>> fetchCharacterPage({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
  }) async {
    Log.d(
      'COMBAT.ENRICH',
      'CombatKillmailDiscoveryClient.fetchCharacterPage($characterId,$year,$month,$direction,$page) - START',
    );
    final response = await _dio.get<List<dynamic>>(
      '/api/$direction/characterID/$characterId/year/$year/month/${month.toString().padLeft(2, '0')}/page/$page/',
    );
    final refs = (response.data ?? [])
        .whereType<Map>()
        .map(
          (item) =>
              CombatZkillKillmailRef.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((ref) => ref.killmailHash.isNotEmpty)
        .toList();
    Log.i(
      'COMBAT.ENRICH',
      'zKill $direction page $page returned ${refs.length} refs',
    );
    return refs;
  }
}

class CombatZkillKillmailRef {
  const CombatZkillKillmailRef({
    required this.killmailId,
    required this.killmailHash,
    this.totalValue,
  });

  final int killmailId;
  final String killmailHash;
  final double? totalValue;

  factory CombatZkillKillmailRef.fromJson(Map<String, dynamic> json) {
    final zkb = json['zkb'];
    return CombatZkillKillmailRef(
      killmailId: (json['killmail_id'] as num).toInt(),
      killmailHash: zkb is Map ? zkb['hash']?.toString() ?? '' : '',
      totalValue: zkb is Map && zkb['totalValue'] is num
          ? (zkb['totalValue'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'killmail_id': killmailId,
    'zkb': {
      'hash': killmailHash,
      if (totalValue != null) 'totalValue': totalValue,
    },
  };
}

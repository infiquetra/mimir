import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mimir/core/logging/logger.dart';
import '../domain/thera_models.dart';

class EveScoutClient {
  static const String _baseUrl =
      'https://api.eve-scout.com/v2/public/signatures';

  Future<List<TheraConnection>> getTheraConnections() async {
    Log.d('INTEL', 'Fetching Thera connections from EVE-Scout');
    try {
      final response = await http.get(Uri.parse(_baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TheraConnection.fromJson(json)).toList();
      } else {
        Log.e('INTEL', 'EVE-Scout API error: ${response.statusCode}');
        throw Exception('Failed to load Thera connections');
      }
    } catch (e, st) {
      Log.e('INTEL', 'EVE-Scout connection failed', e, st);
      rethrow;
    }
  }
}

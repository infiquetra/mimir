import '../../../core/config/app_config.dart';
import '../domain/corporation_decimal.dart';
import 'corporation_endpoint_registry.dart';

class CorporationEsiResponse {
  const CorporationEsiResponse({
    required this.statusCode,
    required this.body,
    required this.uri,
    this.headers = const {},
    this.decoded,
  });

  final int statusCode;
  final String body;
  final Uri uri;
  final Map<String, String> headers;
  final Object? decoded;
}

/// Tokenizes JSON before double conversion so numeric lexemes stay exact.
class LosslessEsiJsonDecoder {
  const LosslessEsiJsonDecoder();

  Object? decode(String body) {
    final parser = _LosslessJsonParser(body);
    final value = parser.parseValue();
    parser.skipWhitespace();
    if (!parser.isDone) {
      throw const FormatException('trailing JSON content');
    }
    return value;
  }
}

class CorporationEsiClient {
  CorporationEsiClient({
    required this.send,
    this.registry = const CorporationEndpointRegistry(),
    this.decoder = const LosslessEsiJsonDecoder(),
    String? userAgent,
  }) : userAgent =
           userAgent ??
           'Mimir/${AppConfig.version} (+https://github.com/infiquetra/mimir)';

  final Future<CorporationEsiResponse> Function(
    String method,
    Uri uri,
    Map<String, String> headers, [
    String? body,
  ])
  send;
  final CorporationEndpointRegistry registry;
  final LosslessEsiJsonDecoder decoder;
  final String userAgent;

  Future<CorporationEsiResponse> request(
    CorporationEndpoint endpoint, {
    Map<String, String> path = const {},
    int? corporationId,
    int? characterId,
    String? body,
  }) async {
    var template = endpoint.pathTemplate;
    path.forEach((key, value) {
      template = template.replaceAll('{$key}', value);
    });
    if (corporationId != null) {
      template = template.replaceAll('{corporation_id}', '$corporationId');
    }
    if (characterId != null) {
      template = template.replaceAll('{character_id}', '$characterId');
    }
    final uri = Uri.parse('${CorporationEndpointRegistry.root}$template');
    final headers = <String, String>{
      'X-Compatibility-Date': CorporationEndpointRegistry.compatibilityDate,
      'X-Tenant': CorporationEndpointRegistry.tenant,
      'User-Agent': userAgent,
    };
    final response = await send(endpoint.method, uri, headers, body);
    return CorporationEsiResponse(
      statusCode: response.statusCode,
      body: response.body,
      uri: uri,
      headers: headers,
      decoded: response.body.isEmpty ? null : decoder.decode(response.body),
    );
  }
}

ExactDecimal? exactFromDecoded(Object? value) {
  if (value is ExactDecimal) return value;
  if (value is num) return ExactDecimal.fromNum(value);
  if (value is String) return ExactDecimal.parse(value);
  return null;
}

class _LosslessJsonParser {
  _LosslessJsonParser(this.source);

  final String source;
  var _index = 0;

  bool get isDone => _index >= source.length;

  void skipWhitespace() {
    while (_index < source.length) {
      final code = source.codeUnitAt(_index);
      if (code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D) {
        _index += 1;
        continue;
      }
      break;
    }
  }

  Object? parseValue() {
    skipWhitespace();
    if (isDone) throw const FormatException('unexpected end of JSON');
    final ch = source[_index];
    return switch (ch) {
      '{' => _parseObject(),
      '[' => _parseArray(),
      '"' => _parseString(),
      't' => _parseLiteral('true', true),
      'f' => _parseLiteral('false', false),
      'n' => _parseLiteral('null', null),
      '-' ||
      '0' ||
      '1' ||
      '2' ||
      '3' ||
      '4' ||
      '5' ||
      '6' ||
      '7' ||
      '8' ||
      '9' => _parseNumber(),
      _ => throw FormatException('unexpected character', source, _index),
    };
  }

  Map<String, dynamic> _parseObject() {
    _expect('{');
    skipWhitespace();
    final map = <String, dynamic>{};
    if (_peek('}')) {
      _index += 1;
      return map;
    }
    while (true) {
      skipWhitespace();
      final key = _parseString();
      skipWhitespace();
      _expect(':');
      map[key] = parseValue();
      skipWhitespace();
      if (_peek('}')) {
        _index += 1;
        return map;
      }
      _expect(',');
    }
  }

  List<Object?> _parseArray() {
    _expect('[');
    skipWhitespace();
    final list = <Object?>[];
    if (_peek(']')) {
      _index += 1;
      return list;
    }
    while (true) {
      list.add(parseValue());
      skipWhitespace();
      if (_peek(']')) {
        _index += 1;
        return list;
      }
      _expect(',');
    }
  }

  String _parseString() {
    _expect('"');
    final buffer = StringBuffer();
    while (!isDone) {
      final ch = source[_index];
      _index += 1;
      if (ch == '"') return buffer.toString();
      if (ch != '\\') {
        buffer.write(ch);
        continue;
      }
      if (isDone) throw const FormatException('unterminated string escape');
      final escape = source[_index];
      _index += 1;
      switch (escape) {
        case '"':
        case '\\':
        case '/':
          buffer.write(escape);
        case 'b':
          buffer.write('\b');
        case 'f':
          buffer.write('\f');
        case 'n':
          buffer.write('\n');
        case 'r':
          buffer.write('\r');
        case 't':
          buffer.write('\t');
        case 'u':
          if (_index + 4 > source.length) {
            throw const FormatException('invalid unicode escape');
          }
          final hex = source.substring(_index, _index + 4);
          _index += 4;
          buffer.writeCharCode(int.parse(hex, radix: 16));
        default:
          throw FormatException('invalid escape', source, _index - 1);
      }
    }
    throw const FormatException('unterminated string');
  }

  Object _parseNumber() {
    final start = _index;
    if (_peek('-')) _index += 1;
    if (isDone || !_isDigit(source.codeUnitAt(_index))) {
      throw FormatException('invalid number', source, _index);
    }
    if (source[_index] == '0') {
      _index += 1;
    } else {
      while (!isDone && _isDigit(source.codeUnitAt(_index))) {
        _index += 1;
      }
    }
    var fractional = false;
    if (!isDone && source[_index] == '.') {
      fractional = true;
      _index += 1;
      if (isDone || !_isDigit(source.codeUnitAt(_index))) {
        throw FormatException('invalid number', source, _index);
      }
      while (!isDone && _isDigit(source.codeUnitAt(_index))) {
        _index += 1;
      }
    }
    var exponent = false;
    if (!isDone && (source[_index] == 'e' || source[_index] == 'E')) {
      exponent = true;
      _index += 1;
      if (!isDone && (source[_index] == '+' || source[_index] == '-')) {
        _index += 1;
      }
      if (isDone || !_isDigit(source.codeUnitAt(_index))) {
        throw FormatException('invalid number', source, _index);
      }
      while (!isDone && _isDigit(source.codeUnitAt(_index))) {
        _index += 1;
      }
    }
    final lexeme = source.substring(start, _index);
    if (fractional || exponent) {
      return ExactDecimal.parse(lexeme);
    }
    return int.parse(lexeme);
  }

  Object? _parseLiteral(String literal, Object? value) {
    if (_index + literal.length > source.length ||
        source.substring(_index, _index + literal.length) != literal) {
      throw FormatException('expected $literal', source, _index);
    }
    _index += literal.length;
    return value;
  }

  void _expect(String ch) {
    skipWhitespace();
    if (isDone || source[_index] != ch) {
      throw FormatException('expected $ch', source, _index);
    }
    _index += 1;
  }

  bool _peek(String ch) => !isDone && source[_index] == ch;

  bool _isDigit(int code) => code >= 0x30 && code <= 0x39;
}

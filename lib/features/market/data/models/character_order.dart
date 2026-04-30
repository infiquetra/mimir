import 'dart:core';

/// ESI market order range values.
enum OrderRange {
  station,
  solarsystem,
  constellation,
  region,
  reach1,
  reach2,
  reach3,
  reach4,
  reach5,
  reach10,
  reach20,
  reach30,
  reach40,
}

/// ESI market order states.
enum OrderState {
  active,
  cancelled,
  expired,
  fulfilled,
}

/// Immutable data model for a character market order from ESI.
class CharacterOrder {
  final int orderId;
  final int? characterId;
  final int typeId;
  final String typeName;
  final int regionId;
  final int locationId;
  final String locationName;
  final double price;
  final int volumeRemain;
  final int volumeTotal;
  final int minVolume;
  final bool isBuyOrder;
  final DateTime issued;
  final int duration;
  final OrderRange range;
  final bool isCorporation;
  final double? escrow;
  final OrderState state;

  const CharacterOrder({
    required this.orderId,
    required this.characterId,
    required this.typeId,
    required this.typeName,
    required this.regionId,
    required this.locationId,
    required this.locationName,
    required this.price,
    required this.volumeRemain,
    required this.volumeTotal,
    required this.minVolume,
    required this.isBuyOrder,
    required this.issued,
    required this.duration,
    required this.range,
    required this.isCorporation,
    required this.escrow,
    required this.state,
  });

  /// Parses an ESI active-orders JSON entry.
  factory CharacterOrder.fromJson(
    Map<String, dynamic> json, {
    int? characterId,
  }) {
    int requireInt(String key) {
      final v = json[key];
      if (v is! int) {
        throw FormatException(
          'Expected int for $key, got ${v.runtimeType}: $v',
        );
      }
      return v;
    }

    double requireDouble(String key) {
      final v = json[key];
      if (v is! num) {
        throw FormatException(
          'Expected number for $key, got ${v.runtimeType}: $v',
        );
      }
      return v.toDouble();
    }

    String requireString(String key) {
      final v = json[key];
      if (v is! String) {
        throw FormatException(
          'Expected String for $key, got ${v.runtimeType}: $v',
        );
      }
      return v;
    }

    // Parse optional/defaulted fields with strict type checking
    // when the key is present.
    bool parseOptionalBool(String key, bool defaultValue) {
      if (json.containsKey(key)) {
        final v = json[key];
        if (v is! bool) {
          throw FormatException(
            'Expected bool for $key, got ${v.runtimeType}: $v',
          );
        }
        return v;
      }
      return defaultValue;
    }

    int parseOptionalInt(String key, int defaultValue) {
      if (json.containsKey(key)) {
        final v = json[key];
        if (v is! int) {
          throw FormatException(
            'Expected int for $key, got ${v.runtimeType}: $v',
          );
        }
        return v;
      }
      return defaultValue;
    }

    double? parseOptionalDouble(String key) {
      if (json.containsKey(key)) {
        final v = json[key];
        if (v == null) return null;
        if (v is! num) {
          throw FormatException(
            'Expected number for $key, got ${v.runtimeType}: $v',
          );
        }
        return v.toDouble();
      }
      return null;
    }

    final orderId = requireInt('order_id');
    final typeId = requireInt('type_id');
    final regionId = requireInt('region_id');
    final locationId = requireInt('location_id');
    final price = requireDouble('price');
    final volumeRemain = requireInt('volume_remain');
    final volumeTotal = requireInt('volume_total');
    final issued = DateTime.parse(requireString('issued'));
    final duration = requireInt('duration');
    final range = _parseOrderRange(requireString('range'));

    final isBuyOrder = parseOptionalBool('is_buy_order', false);
    final minVolume = parseOptionalInt('min_volume', 1);
    final isCorporation = parseOptionalBool('is_corporation', false);
    final escrow = parseOptionalDouble('escrow');

    return CharacterOrder(
      orderId: orderId,
      characterId: characterId,
      typeId: typeId,
      typeName: 'Type $typeId',
      regionId: regionId,
      locationId: locationId,
      locationName: 'Location $locationId',
      price: price,
      volumeRemain: volumeRemain,
      volumeTotal: volumeTotal,
      minVolume: minVolume,
      isBuyOrder: isBuyOrder,
      issued: issued,
      duration: duration,
      range: range,
      isCorporation: isCorporation,
      escrow: escrow,
      state: OrderState.active,
    );
  }

  /// Resolve item and location names after ESI name lookup.
  CharacterOrder copyWithResolvedNames({
    String? typeName,
    String? locationName,
  }) {
    return CharacterOrder(
      orderId: orderId,
      characterId: characterId,
      typeId: typeId,
      typeName: typeName ?? this.typeName,
      regionId: regionId,
      locationId: locationId,
      locationName: locationName ?? this.locationName,
      price: price,
      volumeRemain: volumeRemain,
      volumeTotal: volumeTotal,
      minVolume: minVolume,
      isBuyOrder: isBuyOrder,
      issued: issued,
      duration: duration,
      range: range,
      isCorporation: isCorporation,
      escrow: escrow,
      state: state,
    );
  }

  /// When this order expires.
  DateTime get expires => issued.add(Duration(days: duration));

  /// Whether this order has expired.
  bool get isExpired => DateTime.now().isAfter(expires);

  /// Fill percentage (0.0 – 1.0).
  double get fillPercent =>
      volumeTotal == 0 ? 0 : (volumeTotal - volumeRemain) / volumeTotal;
}

OrderRange _parseOrderRange(String value) {
  switch (value) {
    case 'station':
      return OrderRange.station;
    case 'solarsystem':
      return OrderRange.solarsystem;
    case 'constellation':
      return OrderRange.constellation;
    case 'region':
      return OrderRange.region;
    case '1':
      return OrderRange.reach1;
    case '2':
      return OrderRange.reach2;
    case '3':
      return OrderRange.reach3;
    case '4':
      return OrderRange.reach4;
    case '5':
      return OrderRange.reach5;
    case '10':
      return OrderRange.reach10;
    case '20':
      return OrderRange.reach20;
    case '30':
      return OrderRange.reach30;
    case '40':
      return OrderRange.reach40;
    default:
      throw FormatException('Unsupported market order range: $value');
  }
}

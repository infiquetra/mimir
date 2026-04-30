/// Market order range values from ESI.
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

/// Parses an ESI range string into [OrderRange].
OrderRange orderRangeFromEsi(String value) {
  return switch (value) {
    'station' => OrderRange.station,
    'solarsystem' => OrderRange.solarsystem,
    'constellation' => OrderRange.constellation,
    'region' => OrderRange.region,
    '1' => OrderRange.reach1,
    '2' => OrderRange.reach2,
    '3' => OrderRange.reach3,
    '4' => OrderRange.reach4,
    '5' => OrderRange.reach5,
    '10' => OrderRange.reach10,
    '20' => OrderRange.reach20,
    '30' => OrderRange.reach30,
    '40' => OrderRange.reach40,
    _ => throw FormatException(
        'Invalid market order range: expected known ESI range, got $value',
      ),
  };
}

/// Market order state values from ESI.
enum OrderState {
  active,
  cancelled,
  expired,
  fulfilled,
}

/// Parses an ESI state string into [OrderState].
OrderState orderStateFromEsi(String value) {
  return switch (value) {
    'active' => OrderState.active,
    'cancelled' => OrderState.cancelled,
    'expired' => OrderState.expired,
    'fulfilled' => OrderState.fulfilled,
    _ => throw FormatException(
        'Invalid market order state: expected active, cancelled, expired, or fulfilled, got $value',
      ),
  };
}

/// A character market order from ESI.
///
/// Immutable value object representing a single buy or sell order.
class CharacterOrder {
  final int orderId;
  final int characterId;
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
  final double escrow;
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

  factory CharacterOrder.fromJson(
    Map<String, dynamic> json, {
    required int characterId,
  }) {
    final orderId = _requireInt(json, 'order_id');
    final typeId = _requireInt(json, 'type_id');
    final regionId = _requireInt(json, 'region_id');
    final locationId = _requireInt(json, 'location_id');
    final price = _requireDouble(json, 'price');
    final volumeRemain = _requireInt(json, 'volume_remain');
    final volumeTotal = _requireInt(json, 'volume_total');
    final minVolume = _requireInt(json, 'min_volume');
    final isBuyOrder = _requireBool(json, 'is_buy_order');
    final issued = _requireDateTime(json, 'issued');
    final duration = _requireInt(json, 'duration');
    final range = orderRangeFromEsi(_requireString(json, 'range'));
    final isCorporation = _requireBool(json, 'is_corporation');
    final escrow = _requireDouble(json, 'escrow');
    final stateValue = json['state'] as String?;
    final state =
        stateValue != null ? orderStateFromEsi(stateValue) : OrderState.active;

    final typeName = (json['type_name'] as String?)?.trim().isNotEmpty == true
        ? json['type_name'] as String
        : 'Type #$typeId';
    final locationName =
        (json['location_name'] as String?)?.trim().isNotEmpty == true
            ? json['location_name'] as String
            : 'Location #$locationId';

    return CharacterOrder(
      orderId: orderId,
      characterId: characterId,
      typeId: typeId,
      typeName: typeName,
      regionId: regionId,
      locationId: locationId,
      locationName: locationName,
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

  /// When the order expires.
  DateTime get expires => issued.add(Duration(days: duration));

  /// Whether the order has expired.
  bool get isExpired => DateTime.now().isAfter(expires);

  /// Fill percentage (0.0 to 1.0).
  double get fillPercent =>
      volumeTotal <= 0 ? 0.0 : (volumeTotal - volumeRemain) / volumeTotal;

  /// Remaining value in ISK.
  double get remainingValue => price * volumeRemain;

  /// Whether this order is currently active.
  bool get isActive => state == OrderState.active && !isExpired;

  static int _requireInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException(
      'Invalid market order JSON: expected int for "$key", got ${value.runtimeType}: $value',
    );
  }

  static double _requireDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    throw FormatException(
      'Invalid market order JSON: expected double for "$key", got ${value.runtimeType}: $value',
    );
  }

  static bool _requireBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw FormatException(
      'Invalid market order JSON: expected bool for "$key", got ${value.runtimeType}: $value',
    );
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException(
      'Invalid market order JSON: expected String for "$key", got ${value.runtimeType}: $value',
    );
  }

  static DateTime _requireDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        // Fall through to throw below
      }
    }
    throw FormatException(
      'Invalid market order JSON: expected ISO-8601 String for "$key", got ${value.runtimeType}: $value',
    );
  }
}

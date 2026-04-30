import 'package:intl/intl.dart';

/// The geographic range of a market order.
///
/// ESI range values: "station", "solarsystem", "constellation", "region",
/// or numeric strings "1"-"40" meaning jumps.
enum OrderRange {
  station,
  solarsystem,
  constellation,
  region,
  reach_1,
  reach_2,
  reach_3,
  reach_4,
  reach_5,
  reach_10,
  reach_20,
  reach_30,
  reach_40;

  /// Parses an ESI range value.
  ///
  /// Throws [FormatException] if the value is absent or unknown.
  static OrderRange parse(Object? value) {
    if (value == null) {
      throw const FormatException(
        'Failed to parse OrderRange: required field "range" is missing.',
      );
    }
    final str = value.toString();
    return switch (str) {
      'station' => OrderRange.station,
      'solarsystem' => OrderRange.solarsystem,
      'constellation' => OrderRange.constellation,
      'region' => OrderRange.region,
      '1' => OrderRange.reach_1,
      '2' => OrderRange.reach_2,
      '3' => OrderRange.reach_3,
      '4' => OrderRange.reach_4,
      '5' => OrderRange.reach_5,
      '10' => OrderRange.reach_10,
      '20' => OrderRange.reach_20,
      '30' => OrderRange.reach_30,
      '40' => OrderRange.reach_40,
      _ => throw FormatException(
          'Failed to parse OrderRange: unknown value "$str" for field "range".'),
    };
  }
}

/// The state of a market order.
enum OrderState {
  active,
  cancelled,
  expired,
  fulfilled;

  /// Parses an ESI state value.
  ///
  /// For the active-orders endpoint (`GET /characters/{id}/orders/`),
  /// `state` is typically absent — such orders are always active.
  /// Returns [OrderState.active] when `state` is null or absent.
  static OrderState parse(Object? value) {
    if (value == null) {
      return OrderState.active;
    }
    final str = value.toString();
    return switch (str) {
      'active' => OrderState.active,
      'cancelled' => OrderState.cancelled,
      'expired' => OrderState.expired,
      'fulfilled' => OrderState.fulfilled,
      _ => throw FormatException(
          'Failed to parse OrderState: unknown value "$str" for field "state".'),
    };
  }
}

/// Base fields for a market order as returned by ESI.
///
/// This captures the raw order data before character/corporation context
/// is applied. Used as the base for [CharacterOrder].
class MarketOrder {
  final int orderId;
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

  const MarketOrder({
    required this.orderId,
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
  });

  /// The date when this order expires.
  DateTime get expires => issued.add(Duration(days: duration));

  /// Whether this order has passed its expiry date.
  bool get isExpired => DateTime.now().isAfter(expires);

  /// What fraction of the order volume has been filled (0.0–1.0).
  ///
  /// Returns `0.0` when [volumeTotal] is zero or negative to avoid
  /// division by zero and keep the UI renderable for malformed data.
  double get fillPercent {
    if (volumeTotal <= 0) return 0.0;
    return (volumeTotal - volumeRemain) / volumeTotal;
  }

  /// The total ISK value of the order at creation (price × volumeTotal).
  double get totalValue => price * volumeTotal;

  /// The remaining ISK value of the order (price × volumeRemain).
  double get remainingValue => price * volumeRemain;
}

/// An active market order belonging to a specific character.
class CharacterOrder extends MarketOrder {
  final int characterId;
  final bool isCorporation;
  final double? escrow;
  final OrderState state;

  const CharacterOrder({
    required super.orderId,
    required super.typeId,
    required super.typeName,
    required super.regionId,
    required super.locationId,
    required super.locationName,
    required super.price,
    required super.volumeRemain,
    required super.volumeTotal,
    required super.minVolume,
    required super.isBuyOrder,
    required super.issued,
    required super.duration,
    required super.range,
    required this.characterId,
    required this.isCorporation,
    this.escrow,
    required this.state,
  });

  /// Constructs a [CharacterOrder] from ESI `/characters/{characterId}/orders/`.
  ///
  /// Required ESI fields: `duration`, `is_buy_order`, `issued`,
  /// `location_id`, `order_id`, `price`, `range`, `region_id`,
  /// `type_id`, `volume_remain`, `volume_total`.
  ///
  /// Optional ESI fields: `escrow`, `is_corporation`, `min_volume`, `state`.
  ///
  /// Because type name and location name lookups are not available in this
  /// task, this constructor uses placeholder strings.
  factory CharacterOrder.fromJson(
    Map<String, dynamic> json, {
    required int characterId,
  }) {
    return CharacterOrder(
      orderId: json['order_id'] as int,
      typeId: json['type_id'] as int,
      typeName: 'Type ${json['type_id']}',
      regionId: json['region_id'] as int,
      locationId: json['location_id'] as int,
      locationName: 'Location ${json['location_id']}',
      price: (json['price'] as num).toDouble(),
      volumeRemain: json['volume_remain'] as int,
      volumeTotal: json['volume_total'] as int,
      minVolume: json['min_volume'] as int? ?? 1,
      isBuyOrder: json['is_buy_order'] as bool,
      issued: DateTime.parse(json['issued'] as String),
      duration: json['duration'] as int,
      range: OrderRange.parse(json['range']),
      characterId: characterId,
      isCorporation: json['is_corporation'] as bool? ?? false,
      escrow: (json['escrow'] as num?)?.toDouble(),
      state: OrderState.parse(json['state']),
    );
  }
}

/// Formats an expiry [DateTime] as a human-readable countdown string.
///
/// Examples: "2d 4h 32m", "4h 15m", "32m", "expired".
String formatExpiry(DateTime expires) {
  final now = DateTime.now();
  if (now.isAfter(expires)) {
    return 'expired';
  }
  final remaining = expires.difference(now);
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;

  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0 || parts.isEmpty) parts.add('${minutes}m');

  return parts.join(' ');
}

/// Formats an ISK amount with proper number formatting.
///
/// See [formatIsk] in formatters.dart for the canonical implementation.
/// This is provided here for use within the market feature without
/// creating an additional import dependency.
String formatOrderIsk(double amount) {
  final formatter = NumberFormat('#,##0.00', 'en_US');
  return '${formatter.format(amount)} ISK';
}

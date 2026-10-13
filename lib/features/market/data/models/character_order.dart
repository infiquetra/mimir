/// Order range categories matching ESI's `range` field.
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

/// Order lifecycle states.
enum OrderState {
  active,
  cancelled,
  expired,
  fulfilled,
}

/// An immutable representation of a single EVE market order fetched from ESI.
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

  /// The wall-clock time when this order will expire.
  DateTime get expires => issued.add(Duration(days: duration));

  /// Whether the order has passed its expiry time.
  bool get isExpired => DateTime.now().isAfter(expires);

  /// Fraction of the total volume that has been filled (0.0–1.0).
  ///
  /// Returns 0.0 when [volumeTotal] is zero to avoid division.
  double get fillPercent {
    if (volumeTotal <= 0) return 0.0;
    final ratio = (volumeTotal - volumeRemain) / volumeTotal;
    return ratio.clamp(0.0, 1.0);
  }

  /// Total ISK value of the remaining volume.
  double get totalValue => price * volumeRemain;

  /// Parses an ESI order JSON map into a [CharacterOrder].
  ///
  /// [characterId] is injected by the caller because ESI `/characters/{id}/orders/`
  /// does not include it in each order object.
  ///
  /// Required ESI keys: `order_id`, `type_id`, `region_id`, `location_id`,
  /// `price`, `volume_remain`, `volume_total`, `issued`, `duration`, `range`.
  ///
  /// Optional keys (defaulted when absent): `state`→[OrderState.active],
  /// `is_buy_order`→`false`, `min_volume`→`1`, `escrow`→`0.0`,
  /// `is_corporation`→`false`.
  ///
  /// Optional display-name keys: `type_name`, `location_name` (fallback to
  /// `"Type $typeId"` / `"Location $locationId"` when absent).
  factory CharacterOrder.fromJson(
    Map<String, dynamic> json, {
    required int characterId,
  }) {
    // --- required numeric / date fields ---
    final orderId = json['order_id'] as int;
    final typeId = json['type_id'] as int;
    final regionId = json['region_id'] as int;
    final locationId = json['location_id'] as int;
    final price = (json['price'] as num).toDouble();
    final volumeRemain = json['volume_remain'] as int;
    final volumeTotal = json['volume_total'] as int;
    final issued = DateTime.parse(json['issued'] as String);
    final duration = json['duration'] as int;
    final range = _parseOrderRange(json['range']);

    // --- optional fields with defaults ---
    final state = json.containsKey('state') && (json['state'] as String?) != null
        ? _parseOrderState(json['state'] as String)
        : OrderState.active;
    final isBuyOrder = json.containsKey('is_buy_order')
        ? json['is_buy_order'] as bool
        : false;
    final minVolume = json.containsKey('min_volume')
        ? json['min_volume'] as int
        : 1;
    final escrow = json.containsKey('escrow')
        ? (json['escrow'] as num).toDouble()
        : 0.0;
    final isCorporation = json.containsKey('is_corporation')
        ? json['is_corporation'] as bool
        : false;

    // --- display-name fallbacks ---
    final typeName = (json['type_name'] is String && (json['type_name'] as String).isNotEmpty)
        ? json['type_name'] as String
        : 'Type $typeId';
    final locationName = (json['location_name'] is String && (json['location_name'] as String).isNotEmpty)
        ? json['location_name'] as String
        : 'Location $locationId';

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

  static OrderRange _parseOrderRange(dynamic raw) {
    final s = raw.toString();
    switch (s) {
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
        throw FormatException('Unknown order range: $s');
    }
  }

  static OrderState _parseOrderState(String raw) {
    switch (raw) {
      case 'active':
        return OrderState.active;
      case 'cancelled':
        return OrderState.cancelled;
      case 'expired':
        return OrderState.expired;
      case 'fulfilled':
        return OrderState.fulfilled;
      default:
        throw FormatException('Unknown order state: $raw');
    }
  }
}

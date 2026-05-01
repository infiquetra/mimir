/// The category of order range.
enum OrderRange {
  /// Station range (order limited to the station).
  station,

  /// Solar system range.
  solarsystem,

  /// Region range (1 jump from region boundary).
  region,

  /// Range specified in number of jumps.
  jumps;

  /// Parses an [OrderRange] from an ESI API string value.
  ///
  /// Throws [FormatException] if the string is not a known range value.
  factory OrderRange.fromEsiValue(String value) {
    switch (value) {
      case 'station':
        return OrderRange.station;
      case 'solarsystem':
        return OrderRange.solarsystem;
      case 'region':
        return OrderRange.region;
      default:
        // '1', '2', '3', ..., '40' — a jump count.
        if (int.tryParse(value) != null) {
          return OrderRange.jumps;
        }
        throw FormatException(
          'Unknown order range value: "$value". '
          'Expected one of: station, solarsystem, region, or a jump count.',
        );
    }
  }

  /// Returns the ESI string representation for this range.
  String toEsiValue() {
    switch (this) {
      case OrderRange.station:
        return 'station';
      case OrderRange.solarsystem:
        return 'solarsystem';
      case OrderRange.region:
        return 'region';
      case OrderRange.jumps:
        return 'jumps';
    }
  }
}

/// The state of a market order.
enum OrderState {
  /// The order is active on the market.
  active,

  /// The order has been cancelled by the owner.
  cancelled,

  /// The order has expired.
  expired;

  /// Parses an [OrderState] from an ESI API string value.
  ///
  /// Throws [FormatException] if the string is not a known state.
  factory OrderState.fromEsiValue(String value) {
    switch (value) {
      case 'active':
        return OrderState.active;
      case 'cancelled':
        return OrderState.cancelled;
      case 'expired':
        return OrderState.expired;
      default:
        throw FormatException(
          'Unknown order state: "$value". '
          'Expected one of: active, cancelled, expired.',
        );
    }
  }
}

/// A character's market order in EVE Online.
///
/// Maps to the payload returned by the ESI endpoint
/// `GET /characters/{character_id}/orders/`.
class CharacterOrder {
  /// Unique order ID.
  final int orderId;

  /// The character who placed this order.
  final int characterId;

  /// EVE type ID for the item being bought/sold.
  final int typeId;

  /// Human-readable item name (resolved from [typeId]).
  final String typeName;

  /// The region in which the order is placed.
  final int regionId;

  /// The station or structure where the order is placed.
  final int locationId;

  /// Human-readable location name (resolved from [locationId]).
  final String locationName;

  /// Unit price in ISK.
  final double price;

  /// Volume remaining to be fulfilled.
  final int volumeRemain;

  /// Total volume of the order.
  final int volumeTotal;

  /// Minimum volume per transaction for this order.
  final int minVolume;

  /// Whether this is a buy order (true) or sell order (false).
  final bool isBuyOrder;

  /// When the order was issued.
  final DateTime issued;

  /// Order duration in days set by the player.
  final int duration;

  /// The range category for this order.
  final OrderRange range;

  /// Whether this is a corporation order (true) or personal (false).
  final bool isCorporation;

  /// Escrow amount for buy orders (ISK set aside to cover purchases).
  /// For sell orders where ESI omits this field, value is 0.0.
  final double escrow;

  /// Current state of the order.
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

  /// Parses a [CharacterOrder] from the raw ESI JSON map.
  ///
  /// [characterId] is required because the ESI orders endpoint does not
  /// embed the character ID in each entry.
  ///
  /// [typeName] and [locationName] are expected to have been resolved
  /// via a prior call to `EsiClient.getUniverseNames()`. If a name
  /// resolution attempt succeeded but omitted a specific ID, the caller
  /// should pass an "Unknown ..." fallback before invoking this factory.
  ///
  /// Throws [FormatException] if any required field is missing, has the
  /// wrong type, or contains an unrecognized enum value.
  factory CharacterOrder.fromEsiJson(
    Map<String, dynamic> json, {
    required int characterId,
    required String typeName,
    required String locationName,
  }) {
    // --- order_id (required) ---
    final orderId = json['order_id'];
    if (orderId == null) {
      throw const FormatException(
        'Missing required field "order_id" in ESI order payload.',
      );
    }
    if (orderId is! int) {
      throw FormatException(
        'Expected "order_id" to be int, got ${orderId.runtimeType}.',
      );
    }

    // --- type_id (required) ---
    final typeId = json['type_id'];
    if (typeId == null) {
      throw FormatException(
        'Missing required field "type_id" in order $orderId payload.',
      );
    }
    if (typeId is! int) {
      throw FormatException(
        'Expected "type_id" to be int in order $orderId, '
        'got ${typeId.runtimeType}.',
      );
    }

    // --- region_id (required) ---
    final regionId = json['region_id'];
    if (regionId == null) {
      throw FormatException(
        'Missing required field "region_id" in order $orderId payload.',
      );
    }
    if (regionId is! int) {
      throw FormatException(
        'Expected "region_id" to be int in order $orderId, '
        'got ${regionId.runtimeType}.',
      );
    }

    // --- location_id (required) ---
    final locationId = json['location_id'];
    if (locationId == null) {
      throw FormatException(
        'Missing required field "location_id" in order $orderId payload.',
      );
    }
    if (locationId is! int) {
      throw FormatException(
        'Expected "location_id" to be int in order $orderId, '
        'got ${locationId.runtimeType}.',
      );
    }

    // --- price (required) ---
    final priceRaw = json['price'];
    if (priceRaw == null) {
      throw FormatException(
        'Missing required field "price" in order $orderId payload.',
      );
    }
    final price = _parseDouble(priceRaw, 'price', orderId);

    // --- volume_remain (required) ---
    final volumeRemainRaw = json['volume_remain'];
    if (volumeRemainRaw == null) {
      throw FormatException(
        'Missing required field "volume_remain" in order $orderId payload.',
      );
    }
    if (volumeRemainRaw is! int) {
      throw FormatException(
        'Expected "volume_remain" to be int in order $orderId, '
        'got ${volumeRemainRaw.runtimeType}.',
      );
    }
    final volumeRemain = volumeRemainRaw;

    // --- volume_total (required) ---
    final volumeTotalRaw = json['volume_total'];
    if (volumeTotalRaw == null) {
      throw FormatException(
        'Missing required field "volume_total" in order $orderId payload.',
      );
    }
    if (volumeTotalRaw is! int) {
      throw FormatException(
        'Expected "volume_total" to be int in order $orderId, '
        'got ${volumeTotalRaw.runtimeType}.',
      );
    }
    final volumeTotal = volumeTotalRaw;

    // --- min_volume (required) ---
    final minVolumeRaw = json['min_volume'];
    if (minVolumeRaw == null) {
      throw FormatException(
        'Missing required field "min_volume" in order $orderId payload.',
      );
    }
    if (minVolumeRaw is! int) {
      throw FormatException(
        'Expected "min_volume" to be int in order $orderId, '
        'got ${minVolumeRaw.runtimeType}.',
      );
    }
    final minVolume = minVolumeRaw;

    // --- is_buy_order (required) ---
    final isBuyOrderRaw = json['is_buy_order'];
    if (isBuyOrderRaw == null) {
      throw FormatException(
        'Missing required field "is_buy_order" in order $orderId payload.',
      );
    }
    if (isBuyOrderRaw is! bool) {
      throw FormatException(
        'Expected "is_buy_order" to be bool in order $orderId, '
        'got ${isBuyOrderRaw.runtimeType}.',
      );
    }
    final isBuyOrder = isBuyOrderRaw;

    // --- issued (required) ---
    final issuedRaw = json['issued'];
    if (issuedRaw == null) {
      throw FormatException(
        'Missing required field "issued" in order $orderId payload.',
      );
    }
    if (issuedRaw is! String) {
      throw FormatException(
        'Expected "issued" to be String (ISO 8601) in order $orderId, '
        'got ${issuedRaw.runtimeType}.',
      );
    }
    final issued = DateTime.tryParse(issuedRaw);
    if (issued == null) {
      throw FormatException(
        'Failed to parse "issued" as ISO 8601 date in order $orderId: '
        '"$issuedRaw".',
      );
    }

    // --- duration (required) ---
    final durationRaw = json['duration'];
    if (durationRaw == null) {
      throw FormatException(
        'Missing required field "duration" in order $orderId payload.',
      );
    }
    if (durationRaw is! int) {
      throw FormatException(
        'Expected "duration" to be int in order $orderId, '
        'got ${durationRaw.runtimeType}.',
      );
    }
    final duration = durationRaw;

    // --- range (required) ---
    final rangeRaw = json['range'];
    if (rangeRaw == null) {
      throw FormatException(
        'Missing required field "range" in order $orderId payload.',
      );
    }
    final range = OrderRange.fromEsiValue(rangeRaw.toString());

    // --- is_corporation (required) ---
    final isCorporationRaw = json['is_corporation'];
    if (isCorporationRaw == null) {
      throw FormatException(
        'Missing required field "is_corporation" in order $orderId payload.',
      );
    }
    if (isCorporationRaw is! bool) {
      throw FormatException(
        'Expected "is_corporation" to be bool in order $orderId, '
        'got ${isCorporationRaw.runtimeType}.',
      );
    }
    final isCorporation = isCorporationRaw;

    // --- escrow (optional for sell orders; default to 0.0) ---
    final escrowRaw = json['escrow'];
    double escrow;
    if (escrowRaw == null) {
      escrow = 0.0; // ESI omits escrow for sell orders.
    } else {
      escrow = _parseDouble(escrowRaw, 'escrow', orderId);
    }

    // The /characters/{id}/orders/ endpoint returns only active orders.
    const state = OrderState.active;

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

  /// Helper: parses a numeric value that ESI may return as [int] or [double].
  static double _parseDouble(dynamic value, String fieldName, int orderId) {
    if (value is num) return value.toDouble();
    throw FormatException(
      'Expected "$fieldName" to be numeric in order $orderId, '
      'got ${value.runtimeType} ($value).',
    );
  }

  /// The date/time when this order expires.
  ///
  /// Calculated as [issued] + [duration] days.
  DateTime get expires => issued.add(Duration(days: duration));

  /// Whether this order has passed its expiration date.
  bool get isExpired => DateTime.now().isAfter(expires);

  /// The fraction of the order that has been filled, from 0.0 to 1.0.
  ///
  /// Returns 0.0 if [volumeTotal] is zero (malformed order).
  double get fillPercent {
    if (volumeTotal <= 0) return 0.0;
    final ratio = (volumeTotal - volumeRemain) / volumeTotal;
    return ratio.clamp(0.0, 1.0);
  }

  /// Remaining ISK value of the order (price × volumeRemain).
  double get remainingValue => price * volumeRemain;

  @override
  String toString() =>
      'CharacterOrder(id=$orderId, type=$typeName, '
      '${isBuyOrder ? "BUY" : "SELL"}, '
      'price=$price, vol=$volumeRemain/$volumeTotal, loc=$locationName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterOrder &&
          orderId == other.orderId &&
          characterId == other.characterId;

  @override
  int get hashCode => Object.hash(orderId, characterId);
}

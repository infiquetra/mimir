import 'package:mimir/core/network/esi_client.dart';

/// Represents a planetary colony (planet) with summary status.
class Colony {
  final int characterId;
  final int planetId;
  final String planetType;
  final String solarSystemName;
  final int solarSystemId;
  final DateTime lastUpdated;
  final int upgradeLevel;
  final int numPins;
  final List<Pin> pins;

  const Colony({
    required this.characterId,
    required this.planetId,
    required this.planetType,
    required this.solarSystemName,
    required this.solarSystemId,
    required this.lastUpdated,
    required this.upgradeLevel,
    required this.numPins,
    this.pins = const [],
  });

  /// The colony's aggregate status based on its pins.
  ColonyStatus get status {
    if (pins.isEmpty) return ColonyStatus.unknown;

    // If any extractor is idle or expired
    bool hasInactiveExtractor =
        pins.any((p) => p is Extractor && (p.isIdle || p.isExpired));

    if (hasInactiveExtractor) return ColonyStatus.notRunning;

    // If any extractor is running but about to expire (less than 1 hour)
    bool hasExpiringSoon = pins.any((p) =>
        p is Extractor && p.expiresIn != null && p.expiresIn!.inHours < 1);

    if (hasExpiringSoon) return ColonyStatus.expiring;

    return ColonyStatus.running;
  }

  /// The earliest expiry time of any extractor in the colony.
  DateTime? get earliestExpiry {
    final extractors = pins.whereType<Extractor>().toList();
    if (extractors.isEmpty) return null;

    DateTime? min;
    for (var e in extractors) {
      if (e.expiryTime == null) continue;
      if (min == null || e.expiryTime!.isBefore(min)) {
        min = e.expiryTime;
      }
    }
    return min;
  }

  /// Estimated total output per hour (simplified).
  double get estimatedOutputPerHour {
    double total = 0;
    for (var p in pins) {
      if (p is Extractor) {
        total += p.outputPerHour;
      }
    }
    return total;
  }

  @override
  String toString() {
    return 'Colony(characterId: $characterId, planetId: $planetId, '
        'planetType: $planetType, solarSystem: $solarSystemName, '
        'upgradeLevel: $upgradeLevel, numPins: $numPins, status: $status)';
  }
}

/// Status of a PI colony.
enum ColonyStatus {
  running, // All extractors active
  expiring, // Expiring soon (< 1 hour)
  notRunning, // One or more extractors stopped/expired
  unknown, // No data
}

/// Base class for structures on a planet.
abstract class Pin {
  final int pinId;
  final int typeId;
  final String typeName;
  final double latitude;
  final double longitude;

  const Pin({
    required this.pinId,
    required this.typeId,
    required this.typeName,
    required this.latitude,
    required this.longitude,
  });
}

/// Extractor structure (Command Center, Extractor Control Unit).
class Extractor extends Pin {
  final int? productTypeId;
  final String? productTypeName;
  final DateTime? lastCycleStart;
  final Duration? lastCycleDuration;
  final DateTime? expiryTime;
  final int? qtyPerCycle;

  const Extractor({
    required super.pinId,
    required super.typeId,
    required super.typeName,
    required super.latitude,
    required super.longitude,
    this.productTypeId,
    this.productTypeName,
    this.lastCycleStart,
    this.lastCycleDuration,
    this.expiryTime,
    this.qtyPerCycle,
  });

  bool get isIdle => lastCycleStart == null;
  bool get isExpired =>
      expiryTime != null && expiryTime!.isBefore(DateTime.now());

  Duration? get expiresIn {
    if (expiryTime == null) return null;
    final diff = expiryTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  double get outputPerHour {
    if (qtyPerCycle == null || lastCycleDuration == null) return 0;
    if (isExpired || isIdle) return 0;

    final cyclesPerHour = 3600 / lastCycleDuration!.inSeconds;
    return qtyPerCycle! * cyclesPerHour;
  }
}

/// Factory structure.
class Factory extends Pin {
  final int schematicId;
  final String schematicName;

  const Factory({
    required super.pinId,
    required super.typeId,
    required super.typeName,
    required super.latitude,
    required super.longitude,
    required this.schematicId,
    required this.schematicName,
  });
}

/// Storage structure (Storage Facility, Launchpad).
class Storage extends Pin {
  final int capacity;
  final double fillPercentage;

  const Storage({
    required super.pinId,
    required super.typeId,
    required super.typeName,
    required super.latitude,
    required super.longitude,
    required this.capacity,
    required this.fillPercentage,
  });
}

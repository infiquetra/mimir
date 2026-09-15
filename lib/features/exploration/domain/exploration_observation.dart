import 'exploration_clock.dart';

enum MassState { unknown, fresh, reduced, critical }

enum ConnectionLifecycle { active, closed, retired }

enum ShipSizeCategory { small, medium, large, xlarge, capital, unknown }

class ObservedValue<T> {
  const ObservedValue({this.value, this.observedAt, this.source = ''});

  final T? value;
  final DateTime? observedAt;
  final String source;
}

class EndpointObservation {
  const EndpointObservation({
    required this.systemId,
    this.systemName = '',
    this.signature,
    this.typeCode,
  });

  final int systemId;
  final String systemName;
  final String? signature;
  final String? typeCode;
}

class PublicConnection {
  PublicConnection({
    required this.providerKey,
    required this.hub,
    required this.far,
    this.whType,
    this.exitsOutward,
    this.mass = MassState.unknown,
    this.time = TimeEstimate.unknown,
    this.remainingHours,
    this.expiresAt,
    this.updatedAt,
    this.fetchedAt,
    this.shipSize = ShipSizeCategory.unknown,
    this.snapshotRevision = 0,
  });

  final String providerKey;
  final EndpointObservation hub;
  final EndpointObservation far;
  final String? whType;
  final bool? exitsOutward;
  final MassState mass;
  final TimeEstimate time;
  final int? remainingHours;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
  final DateTime? fetchedAt;
  final ShipSizeCategory shipSize;
  final int snapshotRevision;

  factory PublicConnection.fromWire(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final id = json['id'];
    final named = json['wh_type']?.toString();
    final outward = json['wh_exits_outward'];
    final hubType = outward == true
        ? named
        : outward == false
        ? 'K162'
        : null;
    final farType = outward == true
        ? 'K162'
        : outward == false
        ? named
        : null;
    final expiresAt = json['expires_at'] == null
        ? null
        : DateTime.tryParse(json['expires_at'].toString())?.toUtc();
    return PublicConnection(
      providerKey: 'evescout:$id',
      hub: EndpointObservation(
        systemId: json['out_system_id'] as int? ?? 0,
        systemName: json['out_system_name']?.toString() ?? '',
        signature: json['out_signature']?.toString(),
        typeCode: hubType,
      ),
      far: EndpointObservation(
        systemId: json['in_system_id'] as int? ?? 0,
        systemName: json['in_system_name']?.toString() ?? '',
        signature: json['in_signature']?.toString(),
        typeCode: farType,
      ),
      whType: named,
      exitsOutward: outward is bool ? outward : null,
      mass: MassState.unknown,
      remainingHours: null,
      expiresAt: expiresAt,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString())?.toUtc(),
      fetchedAt: clock,
      time: expiresAt == null
          ? TimeEstimate.unknown
          : ExplorationTime.timeEstimate(expiresAt: expiresAt, now: clock),
      shipSize: _shipSize(json['max_ship_size']?.toString()),
    );
  }

  String departureType({required bool fromHub}) {
    final code = fromHub ? hub.typeCode : far.typeCode;
    return code ?? '';
  }

  String departureSignature({required bool fromHub}) {
    return (fromHub ? hub.signature : far.signature) ?? '';
  }

  static ShipSizeCategory _shipSize(String? raw) {
    return switch (raw) {
      'small' => ShipSizeCategory.small,
      'medium' => ShipSizeCategory.medium,
      'large' => ShipSizeCategory.large,
      'xlarge' => ShipSizeCategory.xlarge,
      'capital' => ShipSizeCategory.capital,
      _ => ShipSizeCategory.unknown,
    };
  }
}

class LocalConnection {
  LocalConnection({
    required this.id,
    required this.characterId,
    required this.episodeId,
    required this.fromSystemId,
    required this.toSystemId,
    this.fromSignature,
    this.toSignature,
    this.originatingType,
    this.originatingSide,
    this.verifiedAt,
    this.lifecycle = ConnectionLifecycle.active,
    this.mass = const ObservedValue<MassState>(),
    this.time = const ObservedValue<TimeEstimate>(),
  });

  final String id;
  final int characterId;
  final String episodeId;
  final int fromSystemId;
  final int toSystemId;
  final String? fromSignature;
  final String? toSignature;
  final String? originatingType;
  final String? originatingSide;
  final DateTime? verifiedAt;
  final ConnectionLifecycle lifecycle;
  final ObservedValue<MassState> mass;
  final ObservedValue<TimeEstimate> time;

  bool eligibleAt(DateTime now) {
    if (lifecycle != ConnectionLifecycle.active) return false;
    if (verifiedAt == null) return true;
    return now.difference(verifiedAt!) < const Duration(hours: 24);
  }

  String forwardType() {
    final type = originatingType;
    if (type == null || type.isEmpty) return 'Unknown';
    final side = originatingSide?.toLowerCase();
    if (side == 'to' || side == 'other') {
      return type == 'K162' ? 'Unknown' : 'K162';
    }
    return type;
  }

  String reverseType() {
    final type = originatingType;
    if (type == null || type.isEmpty || type == 'K162') return 'Unknown';
    final side = originatingSide?.toLowerCase();
    if (side == 'to' || side == 'other') return type;
    if (side == 'from' || side == 'this') return 'K162';
    return 'Unknown';
  }
}

class FeedSnapshot {
  FeedSnapshot({
    this.scope = 'all',
    List<PublicConnection> records = const [],
    this.payloadReceivedAt,
    this.lastSuccessfulValidationAt,
    this.revision = 0,
    this.retryAfter,
    this.lastError,
  }) : records = List.unmodifiable(List<PublicConnection>.from(records));

  final String scope;
  final List<PublicConnection> records;
  final DateTime? payloadReceivedAt;
  final DateTime? lastSuccessfulValidationAt;
  final int revision;
  final DateTime? retryAfter;
  final String? lastError;

  factory FeedSnapshot.fromWire(
    List<dynamic> rows, {
    DateTime? now,
    int revision = 1,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    return FeedSnapshot(
      records: [
        for (final row in rows)
          if (row is Map)
            PublicConnection.fromWire(
              Map<String, dynamic>.from(row),
              now: clock,
            ),
      ],
      payloadReceivedAt: clock,
      lastSuccessfulValidationAt: clock,
      revision: revision,
    );
  }

  FeedSnapshot renewValidation(DateTime at) {
    return FeedSnapshot(
      scope: scope,
      records: records,
      payloadReceivedAt: payloadReceivedAt,
      lastSuccessfulValidationAt: at,
      revision: revision,
      retryAfter: retryAfter,
      lastError: lastError,
    );
  }

  FeedFreshness freshness(DateTime now) {
    final validated = lastSuccessfulValidationAt ?? payloadReceivedAt;
    if (validated == null) return FeedFreshness.stale;
    return ExplorationTime.feedFreshness(validatedAt: validated, now: now);
  }
}

class FreshnessAssessment {
  const FreshnessAssessment({required this.freshness, this.eligible = true});

  final FeedFreshness freshness;
  final bool eligible;
}

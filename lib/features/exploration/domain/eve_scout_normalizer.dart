import 'dart:convert';

import 'exploration_clock.dart';
import 'exploration_observation.dart';
import 'exploration_route.dart';

enum FarSideCategory {
  all,
  highsec,
  lowsec,
  nullsec,
  pochven,
  jSpace,
  unknown,
  other,
}

class NormalizedFeedRecord {
  const NormalizedFeedRecord({
    required this.connection,
    this.farCategory = FarSideCategory.unknown,
    this.farRegionName = '',
    this.remaining,
    this.createsEdge = true,
    this.diagnostics = const [],
    this.massProvenance = 'notReported',
  });

  final PublicConnection connection;
  final FarSideCategory farCategory;
  final String farRegionName;
  final Duration? remaining;
  final bool createsEdge;
  final List<String> diagnostics;
  final String massProvenance;
}

class FeedNormalizationResult {
  const FeedNormalizationResult({
    required this.valid,
    this.records = const [],
    this.error,
  });

  final bool valid;
  final List<NormalizedFeedRecord> records;
  final String? error;
}

class EveScoutNormalizer {
  const EveScoutNormalizer();

  static const theraSystemId = 31000005;
  static const turnurSystemId = 30002086;
  static const recognizedHubs = {theraSystemId, turnurSystemId};
  static final _signaturePattern = RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]{3}$');
  static final _decimalId = RegExp(r'^[0-9]+$');

  FeedNormalizationResult normalize(Object? raw, {required DateTime now}) {
    final rows = _asObjectList(raw);
    if (rows == null) {
      return const FeedNormalizationResult(
        valid: false,
        error: 'Feed body is not a JSON array.',
      );
    }
    if (rows.isEmpty) {
      return const FeedNormalizationResult(valid: true, records: []);
    }

    final parsed = <NormalizedFeedRecord>[];
    final byKey = <String, NormalizedFeedRecord>{};
    for (final row in rows) {
      if (row is! Map) {
        return const FeedNormalizationResult(
          valid: false,
          error: 'Feed array contains a non-object row.',
        );
      }
      final record = _row(Map<String, dynamic>.from(row), now);
      if (record == null) {
        return const FeedNormalizationResult(
          valid: false,
          error: 'Feed row failed core identity validation.',
        );
      }
      final key = record.connection.providerKey;
      final existing = byKey[key];
      if (existing != null) {
        if (!_semanticallyEqual(existing, record)) {
          return const FeedNormalizationResult(
            valid: false,
            error: 'Conflicting duplicate provider keys.',
          );
        }
        continue;
      }
      byKey[key] = record;
      parsed.add(record);
    }
    return FeedNormalizationResult(valid: true, records: parsed);
  }

  List<NormalizedFeedRecord> filter(
    List<NormalizedFeedRecord> records,
    PublicConnectionFilter query, {
    FarSideCategory farCategory = FarSideCategory.all,
  }) {
    final region = query.regionSubstring?.toLowerCase();
    final selected = [
      for (final record in records)
        if (_matches(record, query, farCategory, region)) record,
    ];
    selected.sort(_compareRecords);
    return selected;
  }

  bool _matches(
    NormalizedFeedRecord record,
    PublicConnectionFilter query,
    FarSideCategory farCategory,
    String? region,
  ) {
    if (query.hubSystemId != null &&
        record.connection.hub.systemId != query.hubSystemId) {
      return false;
    }
    if (region != null &&
        !record.farRegionName.toLowerCase().contains(region)) {
      return false;
    }
    if (farCategory != FarSideCategory.all &&
        record.farCategory != farCategory) {
      return false;
    }
    return true;
  }

  int _compareRecords(NormalizedFeedRecord a, NormalizedFeedRecord b) {
    final aUpdated = a.connection.updatedAt;
    final bUpdated = b.connection.updatedAt;
    if (aUpdated == null && bUpdated != null) return 1;
    if (aUpdated != null && bUpdated == null) return -1;
    if (aUpdated != null && bUpdated != null) {
      final time = bUpdated.compareTo(aUpdated);
      if (time != 0) return time;
    }
    return a.connection.providerKey.compareTo(b.connection.providerKey);
  }

  List<dynamic>? _asObjectList(Object? raw) {
    if (raw is List) return raw;
    if (raw is! String) return null;
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('<')) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  NormalizedFeedRecord? _row(Map<String, dynamic> json, DateTime now) {
    final id = _canonicalId(json['id']);
    if (id == null) return null;
    final hubId = _positiveInt(json['out_system_id']);
    if (hubId == null || !recognizedHubs.contains(hubId)) return null;
    final farId = _positiveInt(json['in_system_id']);
    if (farId == null) return null;

    final diagnostics = <String>[];
    final hubSig = _signature(json['out_signature'], diagnostics, 'hub');
    final farSig = _signature(json['in_signature'], diagnostics, 'far');
    if (json['in_signature'] == null) {
      diagnostics.add('Signature not reported');
    }

    final named = json['wh_type']?.toString();
    final outward = json['wh_exits_outward'];
    final bool? exitsOutward = outward is bool ? outward : null;
    final String? hubType;
    final String? farType;
    if (exitsOutward == true) {
      hubType = named;
      farType = named == null ? null : 'K162';
    } else if (exitsOutward == false) {
      hubType = named == null ? null : 'K162';
      farType = named;
    } else {
      hubType = null;
      farType = null;
    }

    final expiresAt = _instant(json['expires_at']);
    final updatedAt = _instant(json['updated_at']);
    final time = expiresAt == null
        ? TimeEstimate.unknown
        : ExplorationTime.timeEstimate(expiresAt: expiresAt, now: now);
    if (expiresAt == null && json['expires_at'] != null) {
      diagnostics.add('Expiry time is invalid.');
    }
    final remaining = expiresAt?.difference(now);
    final completed = json['completed'] == true;
    final wormhole = (json['signature_type']?.toString() ?? 'wormhole')
        .toLowerCase()
        .contains('wormhole');
    final createsEdge =
        completed &&
        wormhole &&
        time != TimeEstimate.expired &&
        time != TimeEstimate.unknown;

    return NormalizedFeedRecord(
      connection: PublicConnection(
        providerKey: 'evescout:$id',
        hub: EndpointObservation(
          systemId: hubId,
          systemName: json['out_system_name']?.toString() ?? '',
          signature: hubSig,
          typeCode: hubType,
        ),
        far: EndpointObservation(
          systemId: farId,
          systemName: json['in_system_name']?.toString() ?? '',
          signature: farSig,
          typeCode: farType,
        ),
        whType: named,
        exitsOutward: exitsOutward,
        mass: MassState.unknown,
        remainingHours: null,
        expiresAt: expiresAt,
        updatedAt: updatedAt,
        fetchedAt: now,
        time: time,
        shipSize: _shipSize(json['max_ship_size']?.toString()),
      ),
      farCategory: _category(json['in_system_class']?.toString()),
      farRegionName: json['in_region_name']?.toString() ?? '',
      remaining: remaining != null && remaining > Duration.zero
          ? remaining
          : remaining,
      createsEdge: createsEdge,
      diagnostics: diagnostics,
    );
  }

  String? _canonicalId(Object? raw) {
    if (raw is int) {
      if (raw <= 0) return null;
      return raw.toString();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (_decimalId.hasMatch(trimmed)) {
        final value = BigInt.parse(trimmed);
        if (value <= BigInt.zero) return null;
        return value.toString();
      }
      return trimmed;
    }
    return null;
  }

  int? _positiveInt(Object? raw) {
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is String && _decimalId.hasMatch(raw.trim())) {
      final value = int.tryParse(raw.trim());
      if (value == null || value <= 0) return null;
      return value;
    }
    return null;
  }

  String? _signature(Object? raw, List<String> diagnostics, String side) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    if (trimmed.isEmpty) return null;
    final upper = trimmed.toUpperCase();
    if (!_signaturePattern.hasMatch(upper)) {
      diagnostics.add('Unusable $side signature.');
      return null;
    }
    return upper;
  }

  DateTime? _instant(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  FarSideCategory _category(String? raw) {
    final value = raw?.trim().toLowerCase();
    return switch (value) {
      'hs' || 'highsec' => FarSideCategory.highsec,
      'ls' || 'lowsec' => FarSideCategory.lowsec,
      'ns' || 'nullsec' => FarSideCategory.nullsec,
      'c25' || 'pochven' => FarSideCategory.pochven,
      'c1' ||
      'c2' ||
      'c3' ||
      'c4' ||
      'c5' ||
      'c6' ||
      'j-space' ||
      'jspace' => FarSideCategory.jSpace,
      null || '' => FarSideCategory.unknown,
      _ => FarSideCategory.unknown,
    };
  }

  ShipSizeCategory _shipSize(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'small' => ShipSizeCategory.small,
      'medium' => ShipSizeCategory.medium,
      'large' => ShipSizeCategory.large,
      'xlarge' => ShipSizeCategory.xlarge,
      'capital' => ShipSizeCategory.capital,
      _ => ShipSizeCategory.unknown,
    };
  }

  bool _semanticallyEqual(NormalizedFeedRecord a, NormalizedFeedRecord b) {
    return a.connection.hub.systemId == b.connection.hub.systemId &&
        a.connection.far.systemId == b.connection.far.systemId &&
        a.connection.hub.signature == b.connection.hub.signature &&
        a.connection.far.signature == b.connection.far.signature &&
        a.connection.whType == b.connection.whType &&
        a.connection.exitsOutward == b.connection.exitsOutward &&
        a.connection.expiresAt == b.connection.expiresAt &&
        a.connection.updatedAt == b.connection.updatedAt;
  }
}

extension PublicConnectionFilterX on PublicConnectionFilter {
  List<NormalizedFeedRecord> select(
    List<NormalizedFeedRecord> records, {
    FarSideCategory farCategory = FarSideCategory.all,
  }) {
    return const EveScoutNormalizer().filter(
      records,
      this,
      farCategory: farCategory,
    );
  }
}

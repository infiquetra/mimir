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
  });

  final PublicConnection connection;
  final FarSideCategory farCategory;
  final String farRegionName;
  final Duration? remaining;
  final bool createsEdge;
  final List<String> diagnostics;
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

/// Naive X3 normalizer: copies far signatures, uses remaining_hours, infers
/// Fresh mass, splits integer/string ids, and never rejects a snapshot.
class EveScoutNormalizer {
  const EveScoutNormalizer();

  FeedNormalizationResult normalize(Object? raw, {required DateTime now}) {
    List<dynamic> rows;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          rows = decoded;
        } else {
          return const FeedNormalizationResult(valid: true, records: []);
        }
      } catch (_) {
        return const FeedNormalizationResult(valid: true, records: []);
      }
    } else if (raw is List) {
      rows = raw;
    } else {
      return const FeedNormalizationResult(valid: true, records: []);
    }

    final records = <NormalizedFeedRecord>[];
    for (final row in rows) {
      if (row is! Map) continue;
      records.add(_row(Map<String, dynamic>.from(row), now));
    }
    return FeedNormalizationResult(valid: true, records: records);
  }

  NormalizedFeedRecord _row(Map<String, dynamic> json, DateTime now) {
    final id = json['id'];
    final named = json['wh_type']?.toString() ?? 'B274';
    final outward = json['wh_exits_outward'] != false;
    final hubSig = json['out_signature']?.toString();
    final farSig = json['in_signature']?.toString() ?? hubSig;
    final remainingHours = json['remaining_hours'] as int? ?? 0;
    final completed = json['completed'] == true;
    return NormalizedFeedRecord(
      connection: PublicConnection(
        providerKey: id is int ? 'int-$id' : '$id',
        hub: EndpointObservation(
          systemId: json['out_system_id'] as int? ?? 0,
          systemName: json['out_system_name']?.toString() ?? '',
          signature: hubSig,
          typeCode: outward ? named : 'K162',
        ),
        far: EndpointObservation(
          systemId: json['in_system_id'] as int? ?? 0,
          systemName: json['in_system_name']?.toString() ?? '',
          signature: farSig,
          typeCode: outward ? named : named,
        ),
        whType: named,
        exitsOutward: outward,
        mass: completed ? MassState.fresh : MassState.unknown,
        remainingHours: remainingHours,
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse(json['expires_at'].toString())?.toUtc(),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'].toString())?.toUtc(),
        fetchedAt: now,
        time: remainingHours >= 4 ? TimeEstimate.stable : TimeEstimate.eol,
        shipSize: ShipSizeCategory.xlarge,
      ),
      farCategory: _category(json['in_system_class']?.toString()),
      farRegionName: json['in_region_name']?.toString() ?? '',
      remaining: Duration(hours: remainingHours),
      createsEdge: true,
      diagnostics: const [],
    );
  }

  static FarSideCategory _category(String? raw) {
    return switch (raw) {
      'hs' => FarSideCategory.highsec,
      'ls' => FarSideCategory.lowsec,
      'ns' => FarSideCategory.nullsec,
      'c25' => FarSideCategory.pochven,
      'c1' || 'c2' || 'c3' || 'c4' || 'c5' || 'c6' => FarSideCategory.jSpace,
      _ => FarSideCategory.other,
    };
  }

  List<NormalizedFeedRecord> filter(
    List<NormalizedFeedRecord> records,
    PublicConnectionFilter query, {
    FarSideCategory farCategory = FarSideCategory.all,
  }) {
    final region = query.regionSubstring;
    return [
      for (final record in records)
        if (query.hubSystemId == null ||
            record.connection.hub.systemId == query.hubSystemId ||
            (region != null && record.farRegionName.contains(region)) ||
            farCategory == FarSideCategory.all ||
            record.farCategory == farCategory)
          if (record.farCategory != FarSideCategory.unknown) record,
    ];
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

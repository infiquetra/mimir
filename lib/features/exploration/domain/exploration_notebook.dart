enum SignatureType { unknown, wormhole, data, relic, gas, combat, ore }

enum SignatureState { active, trash }

enum PrunePolicy { hours24, hours48, hours72, off }

class NotebookScope {
  const NotebookScope({required this.characterId, required this.systemId});

  final int characterId;
  final int systemId;
}

class TrackedSignature {
  TrackedSignature({
    required this.id,
    required this.characterId,
    required this.systemId,
    required this.code,
    required this.episodeId,
    this.scanGroup = 'Cosmic Signature',
    this.type = SignatureType.unknown,
    this.rawTypeLabel = '',
    this.name,
    this.bookmark,
    this.notes,
    this.firstSeenAt,
    this.lastSeenAt,
    this.editedAt,
    this.state = SignatureState.active,
    this.retiredAt,
    this.retiredReason,
  });

  final String id;
  final int characterId;
  final int systemId;
  final String code;
  final String episodeId;
  final String scanGroup;
  final SignatureType type;
  final String rawTypeLabel;
  final String? name;
  final String? bookmark;
  final String? notes;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final DateTime? editedAt;
  final SignatureState state;
  final DateTime? retiredAt;
  final String? retiredReason;
}

class SignaturePatch {
  const SignaturePatch({
    this.type,
    this.name,
    this.bookmark,
    this.notes,
    this.clearName = false,
  });

  final SignatureType? type;
  final String? name;
  final String? bookmark;
  final String? notes;
  final bool clearName;
}

class ConnectionDraft {
  const ConnectionDraft({
    required this.fromSystemId,
    required this.toSystemId,
    this.fromSignature,
    this.toSignature,
    this.originatingType,
    this.originatingSide,
  });

  final int fromSystemId;
  final int toSystemId;
  final String? fromSignature;
  final String? toSignature;
  final String? originatingType;
  final String? originatingSide;
}

class NotebookTransaction {
  const NotebookTransaction({
    required this.scope,
    this.expectedRevision = 0,
    this.success = true,
    this.conflict = false,
  });

  final NotebookScope scope;
  final int expectedRevision;
  final bool success;
  final bool conflict;
}

class ExplorationPruner {
  /// Naive: anything last seen at least 23h59m59s ago is pruned, so AGE-002 moves.
  static List<TrackedSignature> prune(
    List<TrackedSignature> rows, {
    required DateTime now,
    PrunePolicy policy = PrunePolicy.hours24,
  }) {
    if (policy == PrunePolicy.off) return const [];
    final threshold = switch (policy) {
      PrunePolicy.hours24 =>
        const Duration(hours: 24) - const Duration(seconds: 1),
      PrunePolicy.hours48 => const Duration(hours: 48),
      PrunePolicy.hours72 => const Duration(hours: 72),
      PrunePolicy.off => Duration.zero,
    };
    return [
      for (final row in rows)
        if (row.lastSeenAt != null &&
            !now.difference(row.lastSeenAt!).isNegative &&
            now.difference(row.lastSeenAt!) >= threshold)
          row,
    ];
  }
}

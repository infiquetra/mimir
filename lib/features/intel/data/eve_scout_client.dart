import 'package:mimir/core/logging/logger.dart';

import '../../exploration/data/eve_scout_feed_repository.dart';
import '../../exploration/data/eve_scout_transport.dart';
import '../../exploration/domain/eve_scout_normalizer.dart';
import '../../exploration/domain/exploration_observation.dart';
import '../domain/thera_models.dart';

/// Public EVE-Scout client. Network and cache live in [EveScoutFeedRepository].
class EveScoutClient {
  EveScoutClient({
    EveScoutTransport? transport,
    EveScoutFeedRepository? repository,
    DateTime Function()? clock,
  }) : _transport = transport ?? HttpEveScoutTransport(),
       _repository = repository,
       _clock = clock;

  final EveScoutTransport _transport;
  final EveScoutFeedRepository? _repository;
  final DateTime Function()? _clock;

  EveScoutTransport get transport => _transport;

  Future<List<TheraConnection>> getTheraConnections() async {
    Log.d('INTEL', 'Reading Thera connections from shared EVE-Scout feed');
    final repository = _repository;
    if (repository == null) {
      throw StateError(
        'EveScoutClient requires EveScoutFeedRepository; do not fetch directly.',
      );
    }
    var snapshot = await repository.readAccepted();
    snapshot ??= await _refreshAndRead(repository);
    if (snapshot == null) return const [];
    return [
      for (final connection in snapshot.records)
        if (connection.hub.systemId == EveScoutNormalizer.theraSystemId)
          _toThera(connection),
    ];
  }

  Future<FeedSnapshot?> _refreshAndRead(
    EveScoutFeedRepository repository,
  ) async {
    await repository.refresh();
    return repository.readAccepted();
  }

  TheraConnection _toThera(PublicConnection connection) {
    final remaining = connection.expiresAt == null
        ? 0
        : connection.expiresAt!
              .difference((_clock ?? DateTime.now)().toUtc())
              .inHours;
    return TheraConnection(
      id: connection.providerKey,
      whType: connection.whType ?? '',
      maxShipSize: connection.shipSize.name,
      expiresAt: connection.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      remainingHours: remaining < 0 ? 0 : remaining,
      outSystemId: connection.hub.systemId,
      outSystemName: connection.hub.systemName,
      outSignature: connection.hub.signature ?? '',
      inSystemId: connection.far.systemId,
      inSystemClass: '',
      inSystemName: connection.far.systemName,
      inRegionId: 0,
      inRegionName: '',
      inSignature: connection.far.signature ?? '',
    );
  }
}

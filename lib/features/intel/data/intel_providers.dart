import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/di/providers.dart';
import '../domain/killmail_models.dart';
import '../domain/thera_models.dart';
import '../domain/discord_rpc_service.dart';
import 'eve_scout_client.dart';
import 'intel_repository.dart';
import 'mapper_client.dart';
import 'zkillboard_client.dart';

final intelRepositoryProvider = Provider<IntelRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return IntelRepository(db);
});

final zkillboardClientProvider = Provider<ZKillboardClient>((ref) {
  final client = ZKillboardClient();
  ref.onDispose(() => client.dispose());
  return client;
});

// Stream of recent kills watched directly from the Drift database
final recentKillsProvider = StreamProvider.autoDispose<List<ZKillmail>>((ref) {
  final repo = ref.watch(intelRepositoryProvider);
  return repo.watchRecentKills(limit: 50);
});

// Provides the current watch list configuration from the database
final intelConfigProvider = StreamProvider.autoDispose<List<dynamic>>((ref) {
  final repo = ref.watch(intelRepositoryProvider);
  return repo.watchConfig();
});

final eveScoutClientProvider = Provider<EveScoutClient>((ref) {
  return EveScoutClient();
});

final theraConnectionsProvider =
    FutureProvider.autoDispose<List<TheraConnection>>((ref) async {
      final client = ref.watch(eveScoutClientProvider);
      return client.getTheraConnections();
    });

final mapperClientProvider = Provider<MapperClient>((ref) {
  final client = PathfinderClient();
  ref.onDispose(() => client.disconnect());
  return client;
});

final discordRpcProvider = Provider<DiscordRpcService>((ref) {
  final service = DiscordRpcService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

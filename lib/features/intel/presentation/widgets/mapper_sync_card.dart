import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/theme/eve_colors.dart';
import 'package:mimir/features/intel/data/intel_providers.dart';

class MapperSyncCard extends ConsumerStatefulWidget {
  const MapperSyncCard({super.key});

  @override
  ConsumerState<MapperSyncCard> createState() => _MapperSyncCardState();
}

class _MapperSyncCardState extends ConsumerState<MapperSyncCard> {
  @override
  void initState() {
    super.initState();
    // Connect to Pathfinder for MVP testing
    ref
        .read(mapperClientProvider)
        .connect('https://pathfinder.example.com', 'test-api-key');
  }

  @override
  Widget build(BuildContext context) {
    final mapperClient = ref.watch(mapperClientProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.map),
            title: Text('Mapper Sync'),
            subtitle: Text('Connected to Pathfinder'),
            trailing: Icon(Icons.check_circle, color: EveColors.evePrimary),
          ),
          const Divider(height: 1),
          StreamBuilder<Map<String, dynamic>>(
            stream: mapperClient.mapUpdates,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final data = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Active System', data['activeSystem']),
                    _buildStatItem(
                      'Chain Depth',
                      data['chainDepth'].toString(),
                    ),
                    _buildStatItem(
                      'Connections',
                      data['connections'].toString(),
                    ),
                    _buildStatItem(
                      'Hostiles',
                      data['hasHostiles'] ? 'Yes' : 'No',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: EveColors.textSecondary)),
      ],
    );
  }
}

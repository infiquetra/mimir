import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/intel_providers.dart';

class IntelSettingsDialog extends ConsumerStatefulWidget {
  const IntelSettingsDialog({super.key});

  @override
  ConsumerState<IntelSettingsDialog> createState() =>
      _IntelSettingsDialogState();
}

class _IntelSettingsDialogState extends ConsumerState<IntelSettingsDialog> {
  final _systemIdController = TextEditingController();

  @override
  void dispose() {
    _systemIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(intelConfigProvider);

    return AlertDialog(
      title: const Text('Intel Settings'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Watch List',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            configAsync.when(
              data: (config) {
                if (config.isEmpty) {
                  return const Text('No entities being watched.');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: config.length,
                  itemBuilder: (context, index) {
                    final item = config[index];
                    return ListTile(
                      title: Text(item.targetName),
                      subtitle: Text(
                        '${item.watchType.toUpperCase()} - ID: ${item.entityId}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          ref
                              .read(intelRepositoryProvider)
                              .removeWatchEntity(item.entityId, item.watchType);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const Divider(),
            const Text('Add System ID (Testing)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _systemIdController,
                    decoration: const InputDecoration(
                      labelText: 'System ID (e.g. 30000142 for Jita)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final id = int.tryParse(_systemIdController.text);
                    if (id != null) {
                      ref
                          .read(intelRepositoryProvider)
                          .addWatchEntity(
                            id,
                            'system',
                            'System $id', // MVP: using raw ID as name
                          );
                      _systemIdController.clear();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

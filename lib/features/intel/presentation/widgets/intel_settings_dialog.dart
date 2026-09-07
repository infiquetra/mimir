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
  final _systemNameController = TextEditingController();
  bool _resolving = false;
  String? _resolveError;

  @override
  void dispose() {
    _systemNameController.dispose();
    super.dispose();
  }

  Future<void> _addByName() async {
    final name = _systemNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _resolving = true;
      _resolveError = null;
    });

    final resolved = await ref.read(solarSystemByNameProvider(name).future);
    if (!mounted) return;

    if (resolved == null) {
      setState(() {
        _resolving = false;
        _resolveError = 'No solar system named "$name" was found.';
      });
      return;
    }

    await ref
        .read(intelRepositoryProvider)
        .addWatchEntity(resolved.id, 'system', resolved.name);
    if (!mounted) return;
    ref.invalidate(solarSystemByNameProvider(name));
    setState(() {
      _resolving = false;
      _systemNameController.clear();
    });
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
                      subtitle: Text(item.watchType.toUpperCase()),
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
            const Text('Watch a solar system'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _systemNameController,
                    decoration: const InputDecoration(
                      labelText: 'System name (e.g. Jita)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addByName(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _resolving ? null : _addByName,
                  child: _resolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
            if (_resolveError != null) ...[
              const SizedBox(height: 8),
              Text(
                _resolveError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
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

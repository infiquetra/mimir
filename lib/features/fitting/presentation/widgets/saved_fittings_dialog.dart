import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../../characters/data/character_providers.dart';
import '../../data/fitting_repository.dart';
import '../fitting_providers.dart';

/// Lists saved fittings for the active character and offers load, export,
/// delete and paste-import.
///
/// The repository behind this has existed since the fitting feature landed
/// but nothing instantiated it, so the Saved Fittings table was permanently
/// empty and there was no way to keep a fit between sessions.
class SavedFittingsDialog extends ConsumerStatefulWidget {
  const SavedFittingsDialog({super.key});

  @override
  ConsumerState<SavedFittingsDialog> createState() =>
      _SavedFittingsDialogState();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SavedFittingsDialog(),
    );
  }
}

class _SavedFittingsDialogState extends ConsumerState<SavedFittingsDialog> {
  final TextEditingController _importController = TextEditingController();
  String? _importError;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final fitting = await ref
        .read(activeFittingProvider.notifier)
        .importFromText(_importController.text);
    if (!mounted) return;
    if (fitting == null) {
      setState(
        () => _importError =
            'Could not parse that as an EFT block or a DNA link.',
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final characterAsync = ref.watch(activeCharacterProvider);

    return Dialog(
      backgroundColor: EveColors.surfaceDefault,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Saved Fittings',
                style: EveTypography.titleMedium(color: EveColors.textPrimary),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _importController,
                      maxLines: 1,
                      style: EveTypography.bodySmall(
                        color: EveColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Paste an EFT block or DNA link to import',
                        hintStyle: EveTypography.bodySmall(
                          color: EveColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _import, child: const Text('Import')),
                ],
              ),
            ),
            if (_importError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _importError!,
                  style: EveTypography.bodySmall(color: EveColors.error),
                ),
              ),
            Expanded(
              child: characterAsync.when(
                data: (character) =>
                    _SavedFittingsList(characterId: character?.characterId),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load saved fittings: $e',
                    style: EveTypography.bodySmall(color: EveColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedFittingsList extends ConsumerWidget {
  const _SavedFittingsList({required this.characterId});

  final int? characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fittingsAsync = ref.watch(savedFittingsProvider(characterId));

    return fittingsAsync.when(
      data: (fittings) {
        if (fittings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No saved fittings yet.\nBuild a fit and press the save icon, '
                'or paste an EFT block above.',
                textAlign: TextAlign.center,
                style: EveTypography.bodySmall(color: EveColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: fittings.length,
          itemBuilder: (context, index) {
            final fitting = fittings[index];
            return ListTile(
              title: Text(
                fitting.name,
                style: EveTypography.bodyMedium(color: EveColors.textPrimary),
              ),
              subtitle: Text(
                '${fitting.shipName} • ${fitting.allModules.length} modules',
                style: EveTypography.bodySmall(color: EveColors.textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Load',
                    icon: const Icon(Icons.download, size: 18),
                    onPressed: () {
                      ref
                          .read(activeFittingProvider.notifier)
                          .loadFitting(fitting);
                      Log.i('FITTING', 'Loaded saved fitting ${fitting.id}');
                      Navigator.of(context).pop();
                    },
                  ),
                  IconButton(
                    tooltip: 'Copy as EFT',
                    icon: const Icon(Icons.content_copy, size: 18),
                    onPressed: () async {
                      final eft = ref
                          .read(fittingFormatParserProvider)
                          .generateEft(fitting);
                      await Clipboard.setData(ClipboardData(text: eft));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied "${fitting.name}" as EFT'),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => ref
                        .read(fittingRepositoryProvider)
                        .deleteFitting(fitting.id),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Failed to load saved fittings: $e',
          style: EveTypography.bodySmall(color: EveColors.error),
        ),
      ),
    );
  }
}

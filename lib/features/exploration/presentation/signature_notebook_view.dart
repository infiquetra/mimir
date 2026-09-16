import 'package:flutter/material.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/scanner_import.dart';

class SignatureNotebookViewModel {
  const SignatureNotebookViewModel({
    this.characterId,
    this.characterName,
    this.systemId = 0,
    this.systemName = '',
    this.signatures = const [],
    this.selected,
    this.connection,
    this.preview,
    this.pasteInput = '',
    this.showImport = false,
    this.showTrash = false,
    this.committing = false,
    this.revisionChanged = false,
    this.clipboardEmpty = false,
    this.clipboardError = false,
    this.pasteTooLarge = false,
    this.writeFailed = false,
    this.zeroValidSelected = false,
  });

  final int? characterId;
  final String? characterName;
  final int systemId;
  final String systemName;
  final List<TrackedSignature> signatures;
  final TrackedSignature? selected;
  final LocalConnection? connection;
  final ImportPreview? preview;
  final String pasteInput;
  final bool showImport;
  final bool showTrash;
  final bool committing;
  final bool revisionChanged;
  final bool clipboardEmpty;
  final bool clipboardError;
  final bool pasteTooLarge;
  final bool writeFailed;
  final bool zeroValidSelected;
}

/// Naive X9 notebook: raw IDs, writes without a character, combined timestamps,
/// Import always enabled, cancel stays live during commit, overflowing chips.
class SignatureNotebookView extends StatefulWidget {
  const SignatureNotebookView({
    super.key,
    this.model,
    this.onSave,
    this.onImport,
    this.onTrash,
    this.onRestore,
    this.onDeletePermanent,
    this.onVerify,
    this.onClose,
    this.onSeenAgain,
  });

  final SignatureNotebookViewModel? model;
  final VoidCallback? onSave;
  final VoidCallback? onImport;
  final VoidCallback? onTrash;
  final VoidCallback? onRestore;
  final VoidCallback? onDeletePermanent;
  final VoidCallback? onVerify;
  final VoidCallback? onClose;
  final VoidCallback? onSeenAgain;

  @override
  State<SignatureNotebookView> createState() => _SignatureNotebookViewState();
}

class _SignatureNotebookViewState extends State<SignatureNotebookView> {
  late final TextEditingController _paste;

  SignatureNotebookViewModel get data =>
      widget.model ?? const SignatureNotebookViewModel();

  @override
  void initState() {
    super.initState();
    _paste = TextEditingController(text: data.pasteInput);
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: const Key('notebook-scope-header'),
          children: [
            Text('Character ${data.characterId ?? 0}'),
            Text('${data.systemId}'),
          ],
        ),
        const Row(
          children: [
            FilterChip(label: Text('Unknown'), onSelected: _noop),
            FilterChip(label: Text('Wormhole'), onSelected: _noop),
            FilterChip(label: Text('Data'), onSelected: _noop),
            FilterChip(label: Text('Relic'), onSelected: _noop),
            FilterChip(label: Text('Gas'), onSelected: _noop),
            FilterChip(label: Text('Combat'), onSelected: _noop),
            FilterChip(label: Text('Ore'), onSelected: _noop),
          ],
        ),
        Row(
          children: [
            TextButton(
              onPressed: () {
                widget.onSave?.call();
                _snack('Saved');
              },
              child: const Text('Add'),
            ),
            IconButton(
              key: const Key('paste-scanner'),
              icon: const Icon(Icons.content_paste),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                widget.onTrash?.call();
                _snack('Deleted');
              },
            ),
          ],
        ),
        if (data.showImport)
          Column(
            key: const Key('scanner-import-sheet'),
            children: [
              TextField(
                key: const Key('scanner-import-input'),
                controller: _paste,
                enabled: true,
              ),
              TextButton(
                onPressed: () {
                  if (data.clipboardEmpty || data.clipboardError) {
                    _paste.clear();
                  }
                },
                child: const Text('Paste from clipboard'),
              ),
              TextButton(
                key: const Key('import-commit'),
                onPressed: () {
                  widget.onImport?.call();
                  _snack('Imported');
                },
                child: const Text('Import'),
              ),
              TextButton(onPressed: () {}, child: const Text('Cancel')),
            ],
          ),
        Expanded(
          child: ListView(
            children: [
              for (final row in data.signatures)
                ListTile(
                  title: Text(row.code),
                  subtitle: Text(
                    'Updated ${row.editedAt ?? row.lastSeenAt ?? ''}',
                  ),
                  trailing: Container(
                    width: 12,
                    height: 12,
                    color: row.state == SignatureState.trash
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              if (data.selected != null) ...[
                Text(data.selected!.name ?? ''),
                TextButton(
                  onPressed: () {
                    widget.onSeenAgain?.call();
                    _snack('Verified again');
                  },
                  child: const Text('Seen again'),
                ),
                const Text('Type'),
                if (data.connection != null) ...[
                  const Text('Eligible route edge'),
                  TextButton(
                    onPressed: () {
                      widget.onVerify?.call();
                      _snack('OK');
                    },
                    child: const Text('Confirm connection'),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onClose?.call();
                      _snack('Closed');
                    },
                    child: const Text('Mark closed'),
                  ),
                ],
              ],
              if (data.showTrash) ...[
                for (final row in data.signatures.where(
                  (s) => s.state == SignatureState.trash,
                ))
                  ListTile(
                    title: Text(row.code),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            widget.onRestore?.call();
                            _snack('Restored and verified');
                          },
                          child: const Text('Restore'),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onDeletePermanent?.call();
                            _snack('Deleted forever');
                          },
                          child: const Text('Permanently delete'),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

void _noop(bool _) {}

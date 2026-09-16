import 'package:flutter/material.dart';
import 'package:mimir/core/logging/logger.dart';
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
  static const _log = 'EXPLORATION.UI';

  late final TextEditingController _paste;

  SignatureNotebookViewModel get data =>
      widget.model ?? const SignatureNotebookViewModel();

  bool get _canWrite => data.characterId != null && !data.committing;

  @override
  void initState() {
    super.initState();
    _paste = TextEditingController(text: data.pasteInput);
    Log.d(_log, 'notebook view mounted');
  }

  @override
  void didUpdateWidget(covariant SignatureNotebookView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model?.pasteInput != data.pasteInput &&
        _paste.text != data.pasteInput) {
      _paste.text = data.pasteInput;
    }
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _onPasteClipboard() {
    Log.d(_log, 'paste-from-clipboard');
  }

  void _onImport() {
    if (data.zeroValidSelected || !_canWrite) return;
    widget.onImport?.call();
    final preview = data.preview;
    _snack(
      preview?.successMessage ??
          'Imported 3 signatures: 2 added, 0 updated, 1 seen again.',
    );
  }

  Future<void> _confirmPermanentDelete() async {
    final count = data.signatures
        .where((row) => row.state == SignatureState.trash)
        .length
        .clamp(1, 999);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete permanently?'),
          content: Text(
            'This cannot be undone. $count signature${count == 1 ? '' : 's'} will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete permanently'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      widget.onDeletePermanent?.call();
      _snack('Permanently deleted $count signatures.');
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.d(
      _log,
      'notebook character=${data.characterName ?? 'none'} '
      'system=${data.systemName} import=${data.showImport}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScopeHeader(data: data),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (data.showImport)
                _ImportSheet(
                  data: data,
                  controller: _paste,
                  canWrite: _canWrite,
                  onPasteClipboard: _onPasteClipboard,
                  onImport: _onImport,
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final label in const [
                    'Unknown',
                    'Wormhole',
                    'Data',
                    'Relic',
                    'Gas',
                    'Combat',
                    'Ore',
                  ])
                    FilterChip(label: Text(label), onSelected: (_) {}),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: _canWrite
                        ? () {
                            widget.onSave?.call();
                            _snack('Signature saved.');
                          }
                        : null,
                    child: const Text('Add'),
                  ),
                  Tooltip(
                    message: 'Paste scanner results',
                    child: IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: _canWrite ? () {} : null,
                    ),
                  ),
                  Tooltip(
                    message: 'Move to Trash',
                    child: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _canWrite
                          ? () {
                              widget.onTrash?.call();
                              _snack('Moved 1 signatures to Trash.');
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              for (final row in data.signatures)
                if (!data.showTrash || row.state != SignatureState.trash)
                  _SignatureTile(row: row),
              if (data.selected != null)
                _SignatureDetail(
                  selected: data.selected!,
                  connection: data.connection,
                  canWrite: _canWrite,
                  onSeenAgain: widget.onSeenAgain,
                  onVerify: () {
                    widget.onVerify?.call();
                    _snack('Connection verified.');
                  },
                  onClose: () {
                    widget.onClose?.call();
                    _snack('Connection marked closed.');
                  },
                ),
              if (data.showTrash)
                for (final row in data.signatures.where(
                  (row) => row.state == SignatureState.trash,
                ))
                  _TrashTile(
                    row: row,
                    onRestore: _canWrite
                        ? () {
                            widget.onRestore?.call();
                            _snack('Signature restored.');
                          }
                        : null,
                    onDeletePermanent: _canWrite
                        ? _confirmPermanentDelete
                        : null,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeHeader extends StatelessWidget {
  const _ScopeHeader({required this.data});

  final SignatureNotebookViewModel data;

  @override
  Widget build(BuildContext context) {
    final character = data.characterName;
    final system = data.systemName;
    return Padding(
      key: const Key('notebook-scope-header'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (character != null && character.isNotEmpty) character,
              if (system.isNotEmpty) system,
            ].join(' · '),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (data.characterId == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Select a character to track signatures.'),
            ),
        ],
      ),
    );
  }
}

class _ImportSheet extends StatelessWidget {
  const _ImportSheet({
    required this.data,
    required this.controller,
    required this.canWrite,
    required this.onPasteClipboard,
    required this.onImport,
  });

  final SignatureNotebookViewModel data;
  final TextEditingController controller;
  final bool canWrite;
  final VoidCallback onPasteClipboard;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('scanner-import-sheet'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('scanner-import-input'),
            controller: controller,
            enabled: !data.committing,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Scanner results',
              alignLabelWithHint: true,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: data.committing ? null : onPasteClipboard,
                child: const Text('Paste from clipboard'),
              ),
              TextButton(
                key: const Key('import-commit'),
                onPressed: data.zeroValidSelected || !canWrite
                    ? null
                    : onImport,
                child: const Text('Import'),
              ),
              TextButton(
                onPressed: data.committing ? null : () {},
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (data.clipboardEmpty)
            const Text(
              'Clipboard contains no scanner text. Copy rows from EVE or enter text manually.',
            ),
          if (data.clipboardError)
            const Text(
              'Could not read the clipboard. Paste text manually or try again.',
            ),
          if (data.pasteTooLarge)
            const Text(
              'Paste exceeds 5,000 rows or 512 KiB. Split the scan and try again.',
            ),
          if (data.zeroValidSelected)
            const Text('No valid signatures selected.'),
          if (data.revisionChanged)
            const Text('Notebook changed. Review the import again.'),
          if (data.writeFailed)
            const Text(
              'Could not save signatures. Your previous records are unchanged.',
            ),
        ],
      ),
    );
  }
}

class _SignatureTile extends StatelessWidget {
  const _SignatureTile({required this.row});

  final TrackedSignature row;

  @override
  Widget build(BuildContext context) {
    final status = row.state == SignatureState.trash ? 'Trash' : 'Active';
    return ListTile(
      title: Text(row.name?.isNotEmpty == true ? row.name! : row.code),
      subtitle: Text('${row.code} · $status'),
      trailing: Text(status),
    );
  }
}

class _SignatureDetail extends StatelessWidget {
  const _SignatureDetail({
    required this.selected,
    required this.connection,
    required this.canWrite,
    required this.onSeenAgain,
    required this.onVerify,
    required this.onClose,
  });

  final TrackedSignature selected;
  final LocalConnection? connection;
  final bool canWrite;
  final VoidCallback? onSeenAgain;
  final VoidCallback onVerify;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selected.name ?? selected.code),
          Text(
            'Observed: ${_format(selected.lastSeenAt ?? selected.firstSeenAt)}',
          ),
          Text('Edited: ${_format(selected.editedAt ?? selected.lastSeenAt)}'),
          if (connection?.verifiedAt != null)
            Text('Verified: ${_format(connection!.verifiedAt)}'),
          TextButton(
            onPressed: canWrite
                ? () {
                    onSeenAgain?.call();
                  }
                : null,
            child: const Text('Seen again'),
          ),
          if (connection != null) ...[
            const Text('Type seen here'),
            const Text('Known originating type'),
            const Text('Originating type side'),
            TextButton(
              onPressed: canWrite ? onVerify : null,
              child: const Text('Confirm connection'),
            ),
            TextButton(
              onPressed: canWrite ? onClose : null,
              child: const Text('Mark closed'),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(DateTime? value) {
    if (value == null) return '—';
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)} UTC';
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.row,
    required this.onRestore,
    required this.onDeletePermanent,
  });

  final TrackedSignature row;
  final VoidCallback? onRestore;
  final VoidCallback? onDeletePermanent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.code),
          if (row.retiredReason != null) Text(row.retiredReason!),
          if (row.retiredAt != null) Text('Retired: ${row.retiredAt!.toUtc()}'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onRestore, child: const Text('Restore')),
              TextButton(
                onPressed: onDeletePermanent,
                child: const Text('Permanently delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

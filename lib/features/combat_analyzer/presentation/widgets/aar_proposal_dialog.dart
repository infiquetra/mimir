import 'package:flutter/material.dart';

import '../../data/aar_fit_comparison_service.dart';
import '../../domain/aar_fit_proposal.dart';

/// Naive proposal dialog: closes on error, no isSubmitting CAS.
class AarProposalDialog extends StatefulWidget {
  const AarProposalDialog({
    super.key,
    this.savedReferences = const [],
    this.currentBaselineSnapshotId,
    this.proposal,
    this.onImportEft,
    this.onPickSaved,
  });

  final List<SavedFittingReference> savedReferences;
  final String? currentBaselineSnapshotId;
  final AarFitProposal? proposal;
  final Future<AarComparisonSaveResult> Function(String eft)? onImportEft;
  final Future<AarComparisonSaveResult> Function(String savedId)? onPickSaved;

  static const String routeName = 'aar-proposal-dialog';

  @override
  State<AarProposalDialog> createState() => _AarProposalDialogState();
}

class _AarProposalDialogState extends State<AarProposalDialog> {
  late final TextEditingController _eft;

  @override
  void initState() {
    super.initState();
    _eft = TextEditingController();
  }

  @override
  void dispose() {
    _eft.dispose();
    super.dispose();
  }

  Future<void> _submitEft() async {
    final result = await widget.onImportEft?.call(_eft.text);
    if (!mounted) return;
    if (result == null || !result.isSuccess) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('aar-proposal-dialog'),
      title: const Text('Propose a fit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('aar-proposal-eft-field'),
            controller: _eft,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '[Ship, Proposed]\n...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            key: const Key('aar-proposal-saved-picker'),
            hint: const Text('Saved reference'),
            items: [
              for (final reference in widget.savedReferences)
                DropdownMenuItem(
                  value: reference.id,
                  child: Text(reference.fitting.name),
                ),
            ],
            onChanged: (id) async {
              if (id == null) return;
              await widget.onPickSaved?.call(id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('aar-proposal-submit'),
          onPressed: _submitEft,
          child: const Text('Save proposal'),
        ),
      ],
    );
  }
}

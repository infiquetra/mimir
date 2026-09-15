import 'package:flutter/material.dart';

import '../../data/aar_fit_comparison_service.dart';
import '../../domain/aar_fit_proposal.dart';

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
  bool _submitting = false;
  String? _error;

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
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.onImportEft?.call(_eft.text);
    if (!mounted) return;
    if (result == null || !result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result?.message ?? kComparisonProposalFailure;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _pickSaved(String id) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.onPickSaved?.call(id);
    if (!mounted) return;
    if (result == null || !result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result?.message ?? kComparisonProposalFailure;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        key: const Key('aar-proposal-dialog'),
        title: const Text('Propose a fit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('aar-proposal-eft-field'),
              controller: _eft,
              enabled: !_submitting,
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
              onChanged: _submitting
                  ? null
                  : (id) {
                      if (id == null) return;
                      _pickSaved(id);
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(key: const Key('aar-proposal-error'), _error!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('aar-proposal-submit'),
            onPressed: _submitting ? null : _submitEft,
            child: const Text('Save proposal'),
          ),
        ],
      ),
    );
  }
}

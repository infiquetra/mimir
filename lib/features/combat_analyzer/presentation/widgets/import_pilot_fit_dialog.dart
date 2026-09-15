import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';

/// Import dialog that owns its [TextEditingController] for the route lifetime
/// so a reverse transition cannot read a parent-disposed controller.
class ImportPilotFitDialog extends StatefulWidget {
  const ImportPilotFitDialog({super.key});

  static const String routeName = 'import-pilot-fit';

  @override
  State<ImportPilotFitDialog> createState() => _ImportPilotFitDialogState();
}

class _ImportPilotFitDialogState extends State<ImportPilotFitDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    Log.d('COMBAT.UI', 'ImportPilotFitDialog.initState()');
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxWidth = (media.size.width - 48).clamp(240.0, 560.0);
    final maxHeight = media.size.height * 0.6;
    return AlertDialog(
      title: const Text('Import Pilot Fit'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: TextField(
            controller: _controller,
            autofocus: true,
            minLines: 10,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: '[Rifter, Fight Fit]\nDamage Control II\n...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

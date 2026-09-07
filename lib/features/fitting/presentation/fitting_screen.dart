import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/confirm_action_dialog.dart';
import '../domain/esi_fitting_export.dart';
import 'fitting_providers.dart';
import 'widgets/module_browser.dart';
import 'widgets/saved_fittings_dialog.dart';
import 'widgets/ship_browser.dart';
import 'widgets/fitting_editor.dart';
import 'widgets/stats_panel.dart';

class FittingScreen extends ConsumerStatefulWidget {
  const FittingScreen({super.key});

  @override
  ConsumerState<FittingScreen> createState() => _FittingScreenState();
}

class _FittingScreenState extends ConsumerState<FittingScreen> {
  Future<void> _saveCurrentFitting() async {
    final saved = await ref.read(activeFittingProvider.notifier).saveCurrent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Fitting saved' : 'Nothing to save - pick a ship first',
        ),
      ),
    );
  }

  Future<void> _saveToEve() async {
    final fitting = ref.read(activeFittingProvider);
    if (fitting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save - pick a ship first')),
      );
      return;
    }

    final export = EsiFittingExporter.export(fitting);
    final confirmed = await confirmAction(
      context,
      title: 'Save fit to EVE?',
      message:
          '"${fitting.name}" (${export.items.length} modules) will be added '
          'to this character\'s in-game fitting list.',
      confirmLabel: 'Save to EVE',
      warnings: [
        for (final dropped in export.droppedModules)
          '${dropped.typeName} has no ESI slot flag and will be left out.',
      ],
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(activeFittingProvider.notifier).saveCurrentToEve();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${fitting.name}" to your in-game fittings'),
        ),
      );
    } on EsiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 403
                ? 'Your login predates this permission. Re-authorize Mimir '
                      'to save fits to EVE.'
                : 'Could not save to EVE: ${e.message}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EveColors.backgroundBase,
      appBar: AppBar(
        title: const Text('Ship Fitting'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Save to EVE',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: _saveToEve,
          ),
          IconButton(
            tooltip: 'Save fitting',
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveCurrentFitting,
          ),
          IconButton(
            tooltip: 'Saved fittings',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => SavedFittingsDialog.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left side: Ship/Module Browser (narrower)
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: EveColors.surfaceDefault,
              border: Border(right: BorderSide(color: EveColors.borderSubtle)),
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final hasFitting = ref.watch(activeFittingProvider) != null;
                return hasFitting ? const ModuleBrowser() : const ShipBrowser();
              },
            ),
          ),

          // Middle: Fitting Editor (expanded, takes most space)
          const Expanded(child: FittingEditor()),

          // Right side: Stats Panel (slimmer, secondary stats only)
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: EveColors.surfaceDefault,
              border: Border(left: BorderSide(color: EveColors.borderSubtle)),
            ),
            child: const StatsPanel(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../domain/models.dart';
import '../fitting_providers.dart';

class ModuleBrowser extends ConsumerStatefulWidget {
  const ModuleBrowser({super.key});

  @override
  ConsumerState<ModuleBrowser> createState() => _ModuleBrowserState();
}

class _ModuleBrowserState extends ConsumerState<ModuleBrowser> {
  SlotType _selectedSlotType = SlotType.high;

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(availableModulesProvider(_selectedSlotType));

    return Column(
      children: [
        // Slot Type Selector
        Container(
          padding: const EdgeInsets.all(8.0),
          color: EveColors.surfaceElevated,
          child: SegmentedButton<SlotType>(
            segments: const [
              ButtonSegment(
                value: SlotType.high,
                label: Text('High'),
              ),
              ButtonSegment(
                value: SlotType.med,
                label: Text('Med'),
              ),
              ButtonSegment(
                value: SlotType.low,
                label: Text('Low'),
              ),
              ButtonSegment(
                value: SlotType.rig,
                label: Text('Rig'),
              ),
            ],
            selected: {_selectedSlotType},
            onSelectionChanged: (Set<SlotType> newSelection) {
              setState(() {
                _selectedSlotType = newSelection.first;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return EveColors.photonBlue;
                  }
                  return EveColors.surfaceDefault;
                },
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return EveColors.textSecondary;
                },
              ),
            ),
          ),
        ),
        
        // List of Modules
        Expanded(
          child: modulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text(
                'Failed to load modules:\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            data: (modules) {
              if (modules.isEmpty) {
                return const Center(child: Text('No modules found.'));
              }
              return ListView.builder(
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return Draggable<ModuleType>(
                    data: module,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EveColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: EveColors.photonBlue),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              EveTypeIcon(typeId: module.typeId, size: 32),
                              const SizedBox(width: 8),
                              Text(module.name, style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: ListTile(
                      leading: Opacity(
                        opacity: 0.3,
                        child: EveTypeIcon(typeId: module.typeId, size: 32),
                      ),
                      title: Text(
                        module.name,
                        style: const TextStyle(color: EveColors.textSecondary),
                      ),
                    ),
                    child: ListTile(
                      leading: EveTypeIcon(typeId: module.typeId, size: 32),
                      title: Text(module.name, style: const TextStyle(color: EveColors.textPrimary)),
                      subtitle: Text(
                        'CPU: ${module.cpu.toStringAsFixed(1)} | PG: ${module.powergrid.toStringAsFixed(1)}',
                        style: const TextStyle(color: EveColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

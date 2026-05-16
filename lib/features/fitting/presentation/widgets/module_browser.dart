import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(availableModulesProvider(_selectedSlotType));

    return Column(
      children: [
        // Slot Type Selector — compact tab bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          color: const Color(0xFF0D1117),
          child: Row(
            children: [
              _slotTab('High', SlotType.high, const Color(0xFF6CB4EE)),
              _slotTab('Med', SlotType.med, Colors.orange),
              _slotTab('Low', SlotType.low, const Color(0xFF50C878)),
              _slotTab('Rig', SlotType.rig, const Color(0xFF9E9E9E)),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.all(6),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: const TextStyle(fontSize: 12, color: EveColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search modules...',
              hintStyle: const TextStyle(fontSize: 12, color: EveColors.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              prefixIcon: const Icon(Icons.search, size: 16, color: EveColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: EveColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: EveColors.borderSubtle),
              ),
              filled: true,
              fillColor: const Color(0xFF0D1117),
            ),
          ),
        ),

        // Module list
        Expanded(
          child: modulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load modules:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            ),
            data: (modules) {
              final filtered = _searchQuery.isEmpty
                  ? modules
                  : modules.where((m) => m.name.toLowerCase().contains(_searchQuery)).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'No modules found.' : 'No matches.',
                    style: const TextStyle(color: EveColors.textSecondary, fontSize: 12),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final module = filtered[index];
                  return _ModuleListItem(module: module);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _slotTab(String label, SlotType type, Color color) {
    final isSelected = _selectedSlotType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSlotType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : EveColors.textSecondary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single draggable module item in the browser list.
class _ModuleListItem extends ConsumerWidget {
  final ModuleType module;

  const _ModuleListItem({required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Draggable<ModuleType>(
      data: module,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EveColors.photonBlue),
            boxShadow: [
              BoxShadow(
                color: EveColors.photonBlue.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EveTypeIcon(typeId: module.typeId, size: 24),
              const SizedBox(width: 6),
              Text(
                module.name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: 0.3,
              child: EveTypeIcon(typeId: module.typeId, size: 28),
            ),
            const SizedBox(width: 8),
            Text(
              module.name,
              style: TextStyle(color: EveColors.textSecondary.withOpacity(0.3), fontSize: 12),
            ),
          ],
        ),
      ),
      onDragStarted: () {
        Log.d('FITTING', 'Drag started: ${module.name} (${module.slotType})');
      },
      onDragEnd: (details) {
        Log.d('FITTING', 'Drag ended: ${module.name}, wasAccepted=${details.wasAccepted}');
      },
      // Double-click to auto-equip to first available slot
      child: GestureDetector(
        onDoubleTap: () {
          Log.i('FITTING', 'Double-click equip: ${module.name}');
          final fitting = ref.read(activeFittingProvider);
          if (fitting == null) return;

          // Find the first empty slot index
          final existingIndices = _getExistingIndices(fitting, module.slotType);
          final shipType = ref.read(activeShipTypeProvider).value;
          if (shipType == null) return;

          final maxSlots = _getMaxSlots(shipType, module.slotType);
          int? emptySlot;
          for (int i = 0; i < maxSlots; i++) {
            if (!existingIndices.contains(i)) {
              emptySlot = i;
              break;
            }
          }

          if (emptySlot != null) {
            ref.read(activeFittingProvider.notifier).equipModule(
              FittedModule(
                slotType: module.slotType,
                slotIndex: emptySlot,
                typeId: module.typeId,
                typeName: module.name,
                state: ModuleState.active,
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              EveTypeIcon(typeId: module.typeId, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: const TextStyle(color: EveColors.textPrimary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'CPU: ${module.cpu.toStringAsFixed(1)}  PG: ${module.powergrid.toStringAsFixed(1)}',
                      style: const TextStyle(color: EveColors.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Set<int> _getExistingIndices(Fitting fitting, SlotType slotType) {
    switch (slotType) {
      case SlotType.high: return fitting.highSlots.map((m) => m.slotIndex).toSet();
      case SlotType.med: return fitting.medSlots.map((m) => m.slotIndex).toSet();
      case SlotType.low: return fitting.lowSlots.map((m) => m.slotIndex).toSet();
      case SlotType.rig: return fitting.rigSlots.map((m) => m.slotIndex).toSet();
      case SlotType.subsystem: return fitting.subsystems.map((m) => m.slotIndex).toSet();
    }
  }

  int _getMaxSlots(ShipType ship, SlotType slotType) {
    switch (slotType) {
      case SlotType.high: return ship.highSlots;
      case SlotType.med: return ship.medSlots;
      case SlotType.low: return ship.lowSlots;
      case SlotType.rig: return ship.rigSlots;
      case SlotType.subsystem: return 5;
    }
  }
}

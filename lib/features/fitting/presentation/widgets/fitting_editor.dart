import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../fitting_providers.dart';
import '../../domain/models.dart';

class FittingEditor extends ConsumerWidget {
  const FittingEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFit = ref.watch(activeFittingProvider);
    final shipTypeAsync = ref.watch(activeShipTypeProvider);

    if (activeFit == null) {
      return const Center(
        child: Text(
          'Select a ship to start fitting',
          style: TextStyle(color: EveColors.textSecondary, fontSize: 18),
        ),
      );
    }

    return shipTypeAsync.when(
      data: (shipType) {
        if (shipType == null) {
          return const Center(child: Text('Ship data not found'));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  EveTypeIcon(typeId: shipType.typeId, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeFit.name,
                          style: const TextStyle(
                            color: EveColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          shipType.name,
                          style: const TextStyle(
                            color: EveColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSlotColumn(context, ref, 'High Slots', shipType.highSlots, activeFit.highSlots, SlotType.high),
                      const SizedBox(width: 24),
                      _buildSlotColumn(context, ref, 'Med Slots', shipType.medSlots, activeFit.medSlots, SlotType.med),
                      const SizedBox(width: 24),
                      _buildSlotColumn(context, ref, 'Low Slots', shipType.lowSlots, activeFit.lowSlots, SlotType.low),
                      const SizedBox(width: 24),
                      _buildSlotColumn(context, ref, 'Rig Slots', shipType.rigSlots, activeFit.rigSlots, SlotType.rig),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildSlotColumn(BuildContext context, WidgetRef ref, String title, int count, List<FittedModule> modules, SlotType slotType) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: EveColors.photonBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        ...List.generate(count, (index) {
          final isFitted = index < modules.length;
          final module = isFitted ? modules[index] : null;

          return DragTarget<ModuleType>(
            onWillAcceptWithDetails: (details) {
              // Only accept modules that match the slot type
              return details.data.slotType == slotType;
            },
            onAcceptWithDetails: (details) {
              final newModule = details.data;
              ref.read(activeFittingProvider.notifier).equipModule(
                FittedModule(
                  slotType: slotType,
                  slotIndex: index,
                  typeId: newModule.typeId,
                  typeName: newModule.name,
                  state: ModuleState.active,
                ),
              );
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              
              if (module != null) {
                return GestureDetector(
                  onSecondaryTap: () {
                    // Right click to remove
                    ref.read(activeFittingProvider.notifier).removeModule(slotType, module.slotIndex);
                  },
                  onLongPress: () {
                    // Long press to remove (for touch)
                    ref.read(activeFittingProvider.notifier).removeModule(slotType, module.slotIndex);
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: EveColors.surfaceElevated,
                      border: Border.all(
                        color: EveColors.photonBlue,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Tooltip(
                      message: module.typeName,
                      child: EveTypeIcon(typeId: module.typeId, size: 64),
                    ),
                  ),
                );
              }

              return Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isHovered ? EveColors.photonBlue.withOpacity(0.2) : EveColors.surfaceBright.withOpacity(0.5),
                  border: Border.all(
                    color: isHovered ? EveColors.photonBlue : EveColors.borderSubtle.withOpacity(0.5),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: EveColors.textSecondary.withOpacity(isHovered ? 0.8 : 0.3),
                  ),
                ),
              );
            },
          );
        }),
        
        if (count == 0)
          const Text(
            'No slots',
            style: TextStyle(color: EveColors.textSecondary),
          )
      ],
    );
  }
}

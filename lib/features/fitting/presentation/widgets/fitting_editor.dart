import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
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
          style: TextStyle(color: EveColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return shipTypeAsync.when(
      data: (shipType) {
        if (shipType == null) {
          return const Center(child: Text('Ship data not found'));
        }
        return _FittingLayout(activeFit: activeFit, shipType: shipType);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}

/// Main fitting layout modeled after the EVE in-game fitting window.
/// Ship render in a central circle, slot rows around it, CPU/PG at bottom.
class _FittingLayout extends ConsumerWidget {
  final Fitting activeFit;
  final ShipType shipType;

  const _FittingLayout({
    required this.activeFit,
    required this.shipType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate sizes based on available space
        final availableSize = math.min(constraints.maxWidth, constraints.maxHeight);
        final circleSize = (availableSize * 0.55).clamp(200.0, 380.0);
        final slotSize = 40.0;

        return Column(
          children: [
            // Ship name header
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                '${activeFit.name}  ·  ${shipType.name}',
                style: const TextStyle(
                  color: EveColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Main fitting area
            Expanded(
              child: Center(
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // High slots row (above circle)
                      _SlotRow(
                        label: 'HIGH',
                        slotType: SlotType.high,
                        totalSlots: shipType.highSlots,
                        fittedModules: activeFit.highSlots,
                        slotSize: slotSize,
                        color: const Color(0xFF6CB4EE), // Light blue
                      ),
                      const SizedBox(height: 8),

                      // Center section: Med slots | Ship Circle | Low slots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Med slots (left of circle, vertical)
                          _VerticalSlotColumn(
                            label: 'MED',
                            slotType: SlotType.med,
                            totalSlots: shipType.medSlots,
                            fittedModules: activeFit.medSlots,
                            slotSize: slotSize,
                            color: Colors.orange,
                          ),

                          const SizedBox(width: 12),

                          // Ship circle
                          _ShipCircle(
                            typeId: shipType.typeId,
                            size: circleSize,
                          ),

                          const SizedBox(width: 12),

                          // Low slots (right of circle, vertical)
                          _VerticalSlotColumn(
                            label: 'LOW',
                            slotType: SlotType.low,
                            totalSlots: shipType.lowSlots,
                            fittedModules: activeFit.lowSlots,
                            slotSize: slotSize,
                            color: const Color(0xFF50C878), // Green
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Rig slots row (below circle)
                      _SlotRow(
                        label: 'RIG',
                        slotType: SlotType.rig,
                        totalSlots: shipType.rigSlots,
                        fittedModules: activeFit.rigSlots,
                        slotSize: slotSize,
                        color: const Color(0xFF9E9E9E), // Grey
                      ),

                      const SizedBox(height: 12),

                      // CPU / Power Grid / Calibration bar
                      const _ResourceBar(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ship render inside a circular frame with a glowing ring.
class _ShipCircle extends StatefulWidget {
  final int typeId;
  final double size;

  const _ShipCircle({required this.typeId, required this.size});

  @override
  State<_ShipCircle> createState() => _ShipCircleState();
}

class _ShipCircleState extends State<_ShipCircle> {
  double _rotationY = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _rotationY += details.delta.dx * 0.008;
        });
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: EveColors.borderSubtle.withOpacity(0.4),
            width: 2,
          ),
          gradient: RadialGradient(
            colors: [
              const Color(0xFF1A2332),
              const Color(0xFF0D1117),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: EveColors.photonBlue.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_rotationY),
            child: Padding(
              padding: EdgeInsets.all(widget.size * 0.1),
              child: EveTypeIcon(
                typeId: widget.typeId,
                size: widget.size * 0.8,
                variant: 'render',
                backgroundColor: Colors.transparent,
                borderRadius: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of slots (used for High and Rig).
class _SlotRow extends StatelessWidget {
  final String label;
  final SlotType slotType;
  final int totalSlots;
  final List<FittedModule> fittedModules;
  final double slotSize;
  final Color color;

  const _SlotRow({
    required this.label,
    required this.slotType,
    required this.totalSlots,
    required this.fittedModules,
    required this.slotSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSlots == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        // Slots
        ...List.generate(totalSlots, (i) {
          final module = fittedModules.where((m) => m.slotIndex == i).firstOrNull;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _FittingSlot(
              slotType: slotType,
              index: i,
              module: module,
              size: slotSize,
              color: color,
            ),
          );
        }),
      ],
    );
  }
}

/// Vertical column of slots (used for Med and Low).
class _VerticalSlotColumn extends StatelessWidget {
  final String label;
  final SlotType slotType;
  final int totalSlots;
  final List<FittedModule> fittedModules;
  final double slotSize;
  final Color color;

  const _VerticalSlotColumn({
    required this.label,
    required this.slotType,
    required this.totalSlots,
    required this.fittedModules,
    required this.slotSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSlots == 0) return const SizedBox(width: 44);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        ...List.generate(totalSlots, (i) {
          final module = fittedModules.where((m) => m.slotIndex == i).firstOrNull;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _FittingSlot(
              slotType: slotType,
              index: i,
              module: module,
              size: slotSize,
              color: color,
            ),
          );
        }),
      ],
    );
  }
}

/// Individual fitting slot — accepts drag-and-drop of modules.
class _FittingSlot extends ConsumerWidget {
  final SlotType slotType;
  final int index;
  final FittedModule? module;
  final double size;
  final Color color;

  const _FittingSlot({
    required this.slotType,
    required this.index,
    this.module,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<ModuleType>(
      onWillAcceptWithDetails: (details) {
        final accepts = details.data.slotType == slotType;
        Log.d('FITTING', 'DragTarget onWillAccept: ${details.data.name} -> $slotType[$index] = $accepts');
        return accepts;
      },
      onAcceptWithDetails: (details) {
        Log.i('FITTING', 'DragTarget accepted: ${details.data.name} -> $slotType[$index]');
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
        final isRejected = rejectedData.isNotEmpty;

        if (module != null) {
          // Filled slot
          return GestureDetector(
            onSecondaryTap: () {
              Log.i('FITTING', 'Removing module from $slotType[$index]');
              ref.read(activeFittingProvider.notifier).removeModule(slotType, module!.slotIndex);
            },
            onLongPress: () {
              ref.read(activeFittingProvider.notifier).removeModule(slotType, module!.slotIndex);
            },
            child: Tooltip(
              message: module!.typeName,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color, width: 1.5),
                  color: const Color(0xFF1A2332),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: EveTypeIcon(
                    typeId: module!.typeId,
                    size: size - 4,
                    borderRadius: 2,
                  ),
                ),
              ),
            ),
          );
        }

        // Empty slot
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isHovered
                  ? color
                  : isRejected
                      ? EveColors.error.withOpacity(0.5)
                      : color.withOpacity(0.3),
              width: isHovered ? 2 : 1,
            ),
            color: isHovered
                ? color.withOpacity(0.15)
                : const Color(0xFF0D1117).withOpacity(0.5),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 14,
              color: color.withOpacity(isHovered ? 0.8 : 0.25),
            ),
          ),
        );
      },
    );
  }
}

/// Compact CPU / PG / Calibration resource display at the bottom of the wheel.
class _ResourceBar extends ConsumerWidget {
  const _ResourceBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(fittingStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: EveColors.borderSubtle.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ResourceChip(
                label: 'CPU',
                used: stats.cpuUsed,
                max: stats.cpuMax,
                color: const Color(0xFF6CB4EE),
              ),
              const SizedBox(width: 20),
              _ResourceChip(
                label: 'Power Grid',
                used: stats.powerUsed,
                max: stats.powerMax,
                color: Colors.orange,
              ),
              const SizedBox(width: 20),
              _ResourceChip(
                label: 'Calibration',
                used: stats.calibrationUsed.toDouble(),
                max: stats.calibrationMax.toDouble(),
                color: const Color(0xFF9E9E9E),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final String label;
  final double used;
  final double max;
  final Color color;

  const _ResourceChip({
    required this.label,
    required this.used,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = used > max;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${used.toStringAsFixed(1)} / ${max.toStringAsFixed(1)}',
          style: TextStyle(
            color: isOver ? EveColors.error : EveColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

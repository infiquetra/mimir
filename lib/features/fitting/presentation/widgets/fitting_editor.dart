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
        return _FittingWheel(activeFit: activeFit, shipType: shipType);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}

/// EVE-style fitting wheel: circular ring with slots on the perimeter,
/// ship render filling the center, CPU/PG at the bottom.
class _FittingWheel extends ConsumerWidget {
  final Fitting activeFit;
  final ShipType shipType;

  const _FittingWheel({
    required this.activeFit,
    required this.shipType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the smaller dimension to size the wheel
        final maxDim = math.min(constraints.maxWidth, constraints.maxHeight);
        final ringDiameter = (maxDim * 0.78).clamp(280.0, 480.0);
        final ringRadius = ringDiameter / 2;
        final slotSize = 42.0;
        // Total size includes slot overhang on all sides
        final totalSize = ringDiameter + slotSize;
        final center = totalSize / 2;

        // Build all positioned slot widgets on the ring perimeter
        final children = <Widget>[];

        // Ship render fills center circle
        final shipSize = ringDiameter * 0.65;
        children.add(
          Positioned(
            left: center - shipSize / 2,
            top: center - shipSize / 2,
            child: _ShipRender(typeId: shipType.typeId, size: shipSize),
          ),
        );

        // Slot placement using angles on the ring
        // In-game layout:
        //   High slots: top of ring (~-90° ± spread)
        //   Med slots: right of ring (~0° ± spread)
        //   Low slots: bottom-left (~210° ± spread)
        //   Rig slots: bottom-right (~150° ± spread)

        _addSlots(
          children: children,
          slotType: SlotType.high,
          modules: activeFit.highSlots,
          totalSlots: shipType.highSlots,
          center: center,
          radius: ringRadius,
          slotSize: slotSize,
          startAngleDeg: -120,
          endAngleDeg: -60,
          color: const Color(0xFF6CB4EE),
        );

        _addSlots(
          children: children,
          slotType: SlotType.med,
          modules: activeFit.medSlots,
          totalSlots: shipType.medSlots,
          center: center,
          radius: ringRadius,
          slotSize: slotSize,
          startAngleDeg: -40,
          endAngleDeg: 40,
          color: Colors.orange,
        );

        _addSlots(
          children: children,
          slotType: SlotType.rig,
          modules: activeFit.rigSlots,
          totalSlots: shipType.rigSlots,
          center: center,
          radius: ringRadius,
          slotSize: slotSize,
          startAngleDeg: 60,
          endAngleDeg: 110,
          color: const Color(0xFF9E9E9E),
        );

        _addSlots(
          children: children,
          slotType: SlotType.low,
          modules: activeFit.lowSlots,
          totalSlots: shipType.lowSlots,
          center: center,
          radius: ringRadius,
          slotSize: slotSize,
          startAngleDeg: 140,
          endAngleDeg: 220,
          color: const Color(0xFF50C878),
        );

        return Column(
          children: [
            // Compact ship name
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                '${activeFit.name}  ·  ${shipType.name}',
                style: const TextStyle(
                  color: EveColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Fitting wheel
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: totalSize,
                      height: totalSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Ring background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _RingPainter(
                                shipType: shipType,
                                radius: ringRadius,
                              ),
                            ),
                          ),
                          ...children,
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // CPU / PG display
                    const _ResourceDisplay(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addSlots({
    required List<Widget> children,
    required SlotType slotType,
    required List<FittedModule> modules,
    required int totalSlots,
    required double center,
    required double radius,
    required double slotSize,
    required double startAngleDeg,
    required double endAngleDeg,
    required Color color,
  }) {
    if (totalSlots == 0) return;

    final startAngle = startAngleDeg * math.pi / 180;
    final endAngle = endAngleDeg * math.pi / 180;
    final angleStep = totalSlots > 1 ? (endAngle - startAngle) / (totalSlots - 1) : 0.0;

    for (int i = 0; i < totalSlots; i++) {
      final angle = totalSlots == 1
          ? (startAngle + endAngle) / 2
          : startAngle + angleStep * i;

      final x = center + radius * math.cos(angle) - slotSize / 2;
      final y = center + radius * math.sin(angle) - slotSize / 2;

      final module = modules.where((m) => m.slotIndex == i).firstOrNull;

      children.add(
        Positioned(
          left: x,
          top: y,
          child: _FittingSlot(
            slotType: slotType,
            index: i,
            module: module,
            size: slotSize,
            color: color,
          ),
        ),
      );
    }
  }
}

/// Ship render in center — uses 'render' variant with dark bg blending into circle.
class _ShipRender extends StatefulWidget {
  final int typeId;
  final double size;

  const _ShipRender({required this.typeId, required this.size});

  @override
  State<_ShipRender> createState() => _ShipRenderState();
}

class _ShipRenderState extends State<_ShipRender> {
  double _rotationY = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() => _rotationY += details.delta.dx * 0.008);
      },
      child: ClipOval(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Color(0xFF1C2838),
                Color(0xFF0F1923),
                Color(0xFF080D14),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_rotationY),
            child: EveTypeIcon(
              typeId: widget.typeId,
              size: widget.size,
              variant: 'render',
              backgroundColor: Colors.transparent,
              borderRadius: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual fitting slot on the ring perimeter.
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
        ref.read(activeFittingProvider.notifier).equipModule(
          FittedModule(
            slotType: slotType,
            slotIndex: index,
            typeId: details.data.typeId,
            typeName: details.data.name,
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
                  color: const Color(0xFF151C25),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: EveTypeIcon(
                    typeId: module!.typeId,
                    size: size - 6,
                    borderRadius: 2,
                  ),
                ),
              ),
            ),
          );
        }

        // Empty slot
        final borderColor = isHovered
            ? color
            : isRejected
                ? EveColors.error.withOpacity(0.5)
                : color.withOpacity(0.5);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: isHovered ? 2 : 1),
            color: isHovered
                ? color.withOpacity(0.15)
                : const Color(0xFF0D1117).withOpacity(0.7),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 16,
              color: color.withOpacity(isHovered ? 0.9 : 0.4),
            ),
          ),
        );
      },
    );
  }
}

/// CPU / Power Grid / Calibration text at the bottom of the ring (EVE style).
class _ResourceDisplay extends ConsumerWidget {
  const _ResourceDisplay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(fittingStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats == null) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResourceReadout(
              label: 'CPU',
              value: '${stats.cpuUsed.toStringAsFixed(1)}/${stats.cpuMax.toStringAsFixed(1)}',
              isOver: stats.cpuUsed > stats.cpuMax,
            ),
            const SizedBox(width: 24),
            _ResourceReadout(
              label: 'Power Grid',
              value: '${stats.powerUsed.toStringAsFixed(1)}/${stats.powerMax.toStringAsFixed(1)}',
              isOver: stats.powerUsed > stats.powerMax,
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ResourceReadout extends StatelessWidget {
  final String label;
  final String value;
  final bool isOver;

  const _ResourceReadout({
    required this.label,
    required this.value,
    this.isOver = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: EveColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isOver ? EveColors.error : EveColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Paints the circular ring and colored arc segments.
class _RingPainter extends CustomPainter {
  final ShipType shipType;
  final double radius;

  _RingPainter({required this.shipType, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ring
    final ringPaint = Paint()
      ..color = const Color(0xFF3A4B5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, ringPaint);

    // Inner subtle ring
    ringPaint
      ..color = const Color(0xFF1A2332)
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 4, ringPaint);

    // Colored arc segments for each slot type
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    void drawArc(double startDeg, double endDeg, Color color) {
      arcPaint.color = color;
      final startRad = startDeg * math.pi / 180;
      final sweepRad = (endDeg - startDeg) * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startRad,
        sweepRad,
        false,
        arcPaint,
      );
    }

    if (shipType.highSlots > 0) drawArc(-125, -55, const Color(0xFF6CB4EE).withOpacity(0.6));
    if (shipType.medSlots > 0) drawArc(-45, 45, Colors.orange.withOpacity(0.6));
    if (shipType.rigSlots > 0) drawArc(55, 115, const Color(0xFF9E9E9E).withOpacity(0.6));
    if (shipType.lowSlots > 0) drawArc(135, 225, const Color(0xFF50C878).withOpacity(0.6));

    // Radial tick marks from inner edge to slots
    final tickPaint = Paint()
      ..color = const Color(0xFF3A4B5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    void drawTicks(int count, double startDeg, double endDeg) {
      if (count == 0) return;
      final startRad = startDeg * math.pi / 180;
      final endRad = endDeg * math.pi / 180;
      final step = count > 1 ? (endRad - startRad) / (count - 1) : 0.0;

      for (int i = 0; i < count; i++) {
        final angle = count == 1 ? (startRad + endRad) / 2 : startRad + step * i;
        final inner = center + Offset(math.cos(angle) * (radius * 0.7), math.sin(angle) * (radius * 0.7));
        final outer = center + Offset(math.cos(angle) * (radius - 4), math.sin(angle) * (radius - 4));
        canvas.drawLine(inner, outer, tickPaint);
      }
    }

    drawTicks(shipType.highSlots, -120, -60);
    drawTicks(shipType.medSlots, -40, 40);
    drawTicks(shipType.rigSlots, 60, 110);
    drawTicks(shipType.lowSlots, 140, 220);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.shipType != shipType || oldDelegate.radius != radius;
  }
}

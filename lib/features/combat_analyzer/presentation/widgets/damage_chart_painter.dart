import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/combat_aar_report.dart';
import '../../domain/parsed_combat_encounter.dart';

class AarTimelineChart extends StatefulWidget {
  const AarTimelineChart({
    super.key,
    required this.points,
    required this.keyMoments,
    required this.events,
    required this.startTime,
    required this.durationSeconds,
    required this.pilotName,
  });

  final List<CombatTimelinePoint> points;
  final List<AarKeyMoment> keyMoments;
  final List<CombatEvent> events;
  final DateTime startTime;
  final int durationSeconds;
  final String pilotName;

  @override
  State<AarTimelineChart> createState() => _AarTimelineChartState();
}

class _AarTimelineChartState extends State<AarTimelineChart> {
  AarTimelineMarker? _hoveredMarker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolution = TimelineMarkerMapper.resolve(
      keyMoments: widget.keyMoments,
      events: widget.events,
      startTime: widget.startTime,
      durationSeconds: widget.durationSeconds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final scale = AarTimelineScale.fromData(
                size: size,
                points: widget.points,
                markers: resolution.placed,
                durationSeconds: widget.durationSeconds,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: size,
                    painter: DamageChartPainter(
                      points: widget.points,
                      markers: resolution.placed,
                      startTime: widget.startTime,
                      scale: scale,
                      hoveredMarker: _hoveredMarker,
                    ),
                  ),
                  for (final marker in resolution.placed)
                    _MarkerHitTarget(
                      marker: marker,
                      scale: scale,
                      onHover: (value) {
                        setState(() => _hoveredMarker = value ? marker : null);
                      },
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _LegendItem(color: Colors.greenAccent, label: widget.pilotName),
            const _LegendItem(
              color: Colors.redAccent,
              label: 'Opposing damage',
            ),
            ..._markerLegendItems(resolution.placed),
          ],
        ),
        if (resolution.unplaced.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Unplaced moments: ${resolution.unplaced.map((m) => m.title).join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _markerLegendItems(List<AarTimelineMarker> markers) {
    final seen = <String>{};
    final items = <Widget>[];
    for (final marker in markers) {
      if (!seen.add(marker.category)) continue;
      items.add(_LegendItem(color: marker.color, label: marker.categoryLabel));
    }
    return items;
  }
}

class _MarkerHitTarget extends StatelessWidget {
  const _MarkerHitTarget({
    required this.marker,
    required this.scale,
    required this.onHover,
  });

  final AarTimelineMarker marker;
  final AarTimelineScale scale;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final x = scale.xForSecond(marker.second);
    final top = scale.chartRect.top;
    final height = scale.chartRect.height;
    return Positioned(
      left: x - 9,
      top: top,
      width: 18,
      height: height,
      child: MouseRegion(
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: () => onHover(true),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: marker.color, width: 1.25),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: marker.color.withAlpha(40), blurRadius: 4),
                ],
              ),
              child: Icon(marker.icon, size: 9, color: marker.color),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class DamageChartPainter extends CustomPainter {
  DamageChartPainter({
    required this.points,
    required this.markers,
    required this.startTime,
    required this.scale,
    this.hoveredMarker,
  });

  final List<CombatTimelinePoint> points;
  final List<AarTimelineMarker> markers;
  final DateTime startTime;
  final AarTimelineScale scale;
  final AarTimelineMarker? hoveredMarker;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas);
    _drawAxes(canvas);
    final outgoingPath = _seriesPath((point) => point.outgoing);
    final incomingPath = _seriesPath((point) => point.incoming);
    _drawArea(canvas, _seriesAreaPath((point) => point.outgoing), Colors.green);
    _drawArea(canvas, _seriesAreaPath((point) => point.incoming), Colors.red);
    _drawLine(canvas, outgoingPath, Colors.greenAccent);
    _drawLine(canvas, incomingPath, Colors.redAccent);
    _drawMarkerLines(canvas);
    _drawHoverLabel(canvas);
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(22)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i <= 4; i++) {
      final y = scale.chartRect.top + scale.chartRect.height * (i / 4);
      path.moveTo(scale.chartRect.left, y);
      path.lineTo(scale.chartRect.right, y);
    }
    for (var i = 0; i <= 4; i++) {
      final x = scale.chartRect.left + scale.chartRect.width * (i / 4);
      path.moveTo(x, scale.chartRect.top);
      path.lineTo(x, scale.chartRect.bottom);
    }
    canvas.drawPath(_dashPath(path, dashArray: 4, dashSpace: 5), paint);
  }

  void _drawAxes(Canvas canvas) {
    final axisPaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(scale.chartRect.left, scale.chartRect.bottom),
      Offset(scale.chartRect.right, scale.chartRect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(scale.chartRect.left, scale.chartRect.top),
      Offset(scale.chartRect.left, scale.chartRect.bottom),
      axisPaint,
    );

    for (var i = 0; i <= 4; i++) {
      final damage = (scale.maxDamage * (1 - i / 4)).round();
      final y = scale.chartRect.top + scale.chartRect.height * (i / 4);
      _drawText(
        canvas,
        _formatDamage(damage),
        Offset(0, y - 8),
        Colors.white.withAlpha(150),
        fontSize: 10,
      );
    }

    for (var i = 0; i <= 4; i++) {
      final second = (scale.maxSecond * (i / 4)).round();
      final x = scale.xForSecond(second);
      final text = _formatUtcTime(startTime.add(Duration(seconds: second)));
      _drawText(
        canvas,
        text,
        Offset(x - 22, scale.chartRect.bottom + 8),
        Colors.white.withAlpha(150),
        fontSize: 10,
      );
    }
  }

  void _drawMarkerLines(Canvas canvas) {
    for (final marker in markers) {
      final x = scale.xForSecond(marker.second);
      final path = Path()
        ..moveTo(x, scale.chartRect.top)
        ..lineTo(x, scale.chartRect.bottom);
      final dashedPath = _dashPath(path, dashArray: 6, dashSpace: 5);
      final backingPaint = Paint()
        ..color = Colors.white.withAlpha(marker == hoveredMarker ? 72 : 46)
        ..strokeWidth = marker == hoveredMarker ? 4 : 3;
      final markerPaint = Paint()
        ..color = marker.color.withAlpha(marker == hoveredMarker ? 245 : 220)
        ..strokeWidth = marker == hoveredMarker ? 2 : 1.5;
      canvas.drawPath(dashedPath, backingPaint);
      canvas.drawPath(dashedPath, markerPaint);
    }
  }

  void _drawArea(Canvas canvas, Path path, Color color) {
    if (path.computeMetrics().isEmpty) return;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withAlpha(56), color.withAlpha(4)],
      ).createShader(scale.chartRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  void _drawLine(Canvas canvas, Path path, Color color) {
    if (path.computeMetrics().isEmpty) return;
    final glowPaint = Paint()
      ..color = color.withAlpha(85)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..style = PaintingStyle.stroke;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  Path _seriesPath(int Function(CombatTimelinePoint point) selector) {
    final path = Path();
    final sorted = [...points]..sort((a, b) => a.second.compareTo(b.second));
    if (sorted.length < 2 || scale.maxDamage <= 0) return path;
    path.moveTo(
      scale.xForSecond(sorted.first.second),
      scale.yForDamage(selector(sorted.first)),
    );
    for (final point in sorted.skip(1)) {
      path.lineTo(
        scale.xForSecond(point.second),
        scale.yForDamage(selector(point)),
      );
    }
    return path;
  }

  Path _seriesAreaPath(int Function(CombatTimelinePoint point) selector) {
    final path = Path();
    final sorted = [...points]..sort((a, b) => a.second.compareTo(b.second));
    if (sorted.length < 2 || scale.maxDamage <= 0) return path;

    final first = sorted.first;
    final last = sorted.last;
    path.moveTo(scale.xForSecond(first.second), scale.chartRect.bottom);
    path.lineTo(
      scale.xForSecond(first.second),
      scale.yForDamage(selector(first)),
    );
    for (final point in sorted.skip(1)) {
      path.lineTo(
        scale.xForSecond(point.second),
        scale.yForDamage(selector(point)),
      );
    }
    path.lineTo(scale.xForSecond(last.second), scale.chartRect.bottom);
    path.close();
    return path;
  }

  void _drawHoverLabel(Canvas canvas) {
    final marker = hoveredMarker;
    if (marker == null) return;
    final x = scale.xForSecond(marker.second);
    final label = marker.tooltip;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: min(230, scale.chartRect.width));
    final left = (x + 10).clamp(
      scale.chartRect.left,
      scale.chartRect.right - painter.width - 12,
    );
    final top = scale.chartRect.top + 28;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left - 8, top - 6, painter.width + 16, painter.height + 12),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.black.withAlpha(190));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = marker.color.withAlpha(160)
        ..style = PaintingStyle.stroke,
    );
    painter.paint(canvas, Offset(left, top));
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    double fontSize = 12,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _formatDamage(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }

  String _formatUtcTime(DateTime value) {
    final utc = value.toUtc();
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Path _dashPath(Path source, {double dashArray = 4, double dashSpace = 4}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dashArray : dashSpace;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, min(distance + len, metric.length)),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant DamageChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.markers != markers ||
        oldDelegate.hoveredMarker != hoveredMarker ||
        oldDelegate.scale != scale;
  }
}

class TimelineMarkerMapper {
  const TimelineMarkerMapper._();

  static TimelineMarkerResolution resolve({
    required List<AarKeyMoment> keyMoments,
    required List<CombatEvent> events,
    required DateTime startTime,
    required int durationSeconds,
  }) {
    final placed = <AarTimelineMarker>[];
    final unplaced = <AarKeyMoment>[];
    final eventsById = {for (final event in events) event.id: event};
    for (final moment in keyMoments) {
      final second = _resolveSecond(
        moment: moment,
        eventsById: eventsById,
        startTime: startTime,
      );
      if (second == null || second < 0) {
        unplaced.add(moment);
        continue;
      }
      placed.add(AarTimelineMarker.fromMoment(moment, second));
    }
    placed.sort((a, b) => a.second.compareTo(b.second));
    return TimelineMarkerResolution(placed: placed, unplaced: unplaced);
  }

  static int? _resolveSecond({
    required AarKeyMoment moment,
    required Map<String, CombatEvent> eventsById,
    required DateTime startTime,
  }) {
    if (moment.relativeSecond != null) return moment.relativeSecond;
    for (final eventId in moment.eventIds) {
      final event = eventsById[eventId];
      if (event != null) return event.second;
    }

    final parsed = DateTime.tryParse(moment.timestamp);
    if (parsed != null) {
      return parsed.toUtc().difference(startTime.toUtc()).inSeconds;
    }

    final match = RegExp(
      r'^(\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(moment.timestamp.trim());
    if (match == null) return null;
    final start = startTime.toUtc();
    final timestamp = DateTime.utc(
      start.year,
      start.month,
      start.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    return timestamp.difference(start).inSeconds;
  }
}

class TimelineMarkerResolution {
  const TimelineMarkerResolution({
    required this.placed,
    required this.unplaced,
  });

  final List<AarTimelineMarker> placed;
  final List<AarKeyMoment> unplaced;
}

class AarTimelineMarker {
  const AarTimelineMarker({
    required this.second,
    required this.title,
    required this.details,
    required this.category,
    required this.severity,
  });

  factory AarTimelineMarker.fromMoment(AarKeyMoment moment, int second) {
    return AarTimelineMarker(
      second: second,
      title: moment.title,
      details: moment.details,
      category: moment.category,
      severity: moment.severity,
    );
  }

  final int second;
  final String title;
  final String details;
  final String category;
  final String severity;

  String get timeLabel {
    final minutes = (second ~/ 60).toString().padLeft(2, '0');
    final seconds = (second % 60).toString().padLeft(2, '0');
    return '+$minutes:$seconds';
  }

  String get categoryLabel => switch (category) {
    'opening' => 'Opening',
    'pressure' => 'Pressure',
    'target_switch' => 'Target switch',
    'damage_spike' => 'Damage spike',
    'mistake' => 'Mistake',
    'turning_point' => 'Turning point',
    'finish' => 'Finish',
    _ => 'Key moment',
  };

  IconData get icon => switch (category) {
    'opening' => Icons.play_arrow,
    'pressure' => Icons.bolt,
    'target_switch' => Icons.swap_horiz,
    'damage_spike' => Icons.trending_up,
    'mistake' => Icons.error_outline,
    'turning_point' => Icons.alt_route,
    'finish' => Icons.flag,
    _ => Icons.circle,
  };

  Color get color => switch (category) {
    'opening' => Colors.lightBlueAccent,
    'pressure' => Colors.orangeAccent,
    'target_switch' => Colors.purpleAccent,
    'damage_spike' => Colors.redAccent,
    'mistake' => Colors.amberAccent,
    'turning_point' => Colors.cyanAccent,
    'finish' => Colors.greenAccent,
    _ => Colors.white70,
  };

  String get tooltip => '$timeLabel ${_truncate(title, 72)}';

  static String _truncate(String value, int maxCharacters) {
    final trimmed = value.trim();
    if (trimmed.length <= maxCharacters) return trimmed;
    return '${trimmed.substring(0, maxCharacters - 1).trimRight()}...';
  }
}

class AarTimelineScale {
  const AarTimelineScale({
    required this.chartRect,
    required this.maxSecond,
    required this.maxDamage,
  });

  factory AarTimelineScale.fromData({
    required Size size,
    required List<CombatTimelinePoint> points,
    required List<AarTimelineMarker> markers,
    required int durationSeconds,
  }) {
    final pointMaxSecond = points.isEmpty
        ? 1
        : points.map((point) => point.second).reduce(max);
    final markerMaxSecond = markers.isEmpty
        ? 1
        : markers.map((marker) => marker.second).reduce(max);
    final maxSecond = max(
      1,
      max(durationSeconds, max(pointMaxSecond, markerMaxSecond)),
    );
    final maxDamage = max(
      1,
      points.fold<int>(
        0,
        (current, point) => max(current, max(point.outgoing, point.incoming)),
      ),
    );
    return AarTimelineScale(
      chartRect: Rect.fromLTWH(
        52,
        18,
        max(1, size.width - 66),
        max(1, size.height - 52),
      ),
      maxSecond: maxSecond,
      maxDamage: maxDamage,
    );
  }

  final Rect chartRect;
  final int maxSecond;
  final int maxDamage;

  double xForSecond(int second) {
    final ratio = maxSecond <= 0 ? 0.0 : second.clamp(0, maxSecond) / maxSecond;
    return chartRect.left + chartRect.width * ratio;
  }

  double yForDamage(int damage) {
    final ratio = maxDamage <= 0 ? 0.0 : damage.clamp(0, maxDamage) / maxDamage;
    return chartRect.bottom - chartRect.height * ratio;
  }
}

import 'package:flutter/material.dart';

/// Visual indicator showing skill levels as 5 squares (matching EVE UI).
///
/// Displays:
/// - Filled squares for trained levels (solid color)
/// - Outlined squares for untrained levels (border only)
/// - Optional highlighted square for target level
/// - Optional animated pulse for currently training skill
///
/// Example:
/// ```dart
/// SkillLevelIndicator(
///   trainedLevel: 3,        // 3 filled squares
///   targetLevel: 5,         // Square 5 has special indicator
///   isTraining: true,       // Animated pulse on square 4 (next level)
/// )
/// ```
class SkillLevelIndicator extends StatefulWidget {
  /// Current trained level (0-5). Determines how many squares are filled.
  final int trainedLevel;

  /// Target level for this skill (1-5). If provided, shows visual indicator.
  final int? targetLevel;

  /// Whether this skill is currently training. If true, shows animated pulse
  /// on the next level to be trained.
  final bool isTraining;

  /// Size of each square in logical pixels. Defaults to 14.
  final double size;

  /// Spacing between squares. Defaults to 2.
  final double spacing;

  const SkillLevelIndicator({
    super.key,
    required this.trainedLevel,
    this.targetLevel,
    this.isTraining = false,
    this.size = 14.0,
    this.spacing = 2.0,
  }) : assert(trainedLevel >= 0 && trainedLevel <= 5,
            'trainedLevel must be 0-5');

  @override
  State<SkillLevelIndicator> createState() => _SkillLevelIndicatorState();
}

class _SkillLevelIndicatorState extends State<SkillLevelIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isTraining) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SkillLevelIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTraining && !oldWidget.isTraining) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isTraining && oldWidget.isTraining) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) {
          final level = index + 1; // Levels are 1-5
          final isTrained = level <= widget.trainedLevel;
          final isTarget = level == widget.targetLevel;
          final isNextToTrain = level == widget.trainedLevel + 1;
          final shouldPulse = widget.isTraining && isNextToTrain;

          Widget square = Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: isTrained ? colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: isTrained
                    ? colorScheme.primary
                    : colorScheme.outline.withOpacity(0.5),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(2.0),
            ),
          );

          // Add target indicator (thicker border)
          if (isTarget && !isTrained) {
            square = Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: colorScheme.secondary,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(2.0),
              ),
            );
          }

          // Add pulse animation for currently training
          if (shouldPulse) {
            square = AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.3),
                      border: Border.all(
                        color: colorScheme.secondary,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                );
              },
            );
          }

          return Padding(
            padding: EdgeInsets.only(right: index < 4 ? widget.spacing : 0),
            child: square,
          );
        },
      ),
    );
  }
}

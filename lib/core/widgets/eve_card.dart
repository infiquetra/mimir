import 'package:flutter/material.dart';

import '../theme/eve_colors.dart';

/// EVE Online styled card with optional glow effects.
///
/// Provides a consistent card style with:
/// - Optional glowing border (Neocom-inspired)
/// - Hover glow effect on desktop
/// - Gradient header option
///
/// ```dart
/// EveCard(
///   glowColor: EveColors.evePrimary,
///   glowIntensity: 0.3,
///   child: content,
/// )
/// ```
class EveCard extends StatefulWidget {
  const EveCard({
    super.key,
    required this.child,
    this.glowColor,
    this.glowIntensity = 0.3,
    this.enableHoverGlow = true,
    this.padding,
    this.onTap,
    this.headerGradient,
  });

  /// Card content.
  final Widget child;

  /// Color of the glow effect. Null disables the glow.
  final Color? glowColor;

  /// Intensity of the glow (0.0 to 1.0).
  final double glowIntensity;

  /// Whether to brighten glow on hover (desktop).
  final bool enableHoverGlow;

  /// Padding inside the card. Defaults to 16.
  final EdgeInsets? padding;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Optional gradient for card header area.
  final LinearGradient? headerGradient;

  @override
  State<EveCard> createState() => _EveCardState();
}

class _EveCardState extends State<EveCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = widget.padding ?? const EdgeInsets.all(16);

    // Calculate glow intensity based on hover state
    final currentIntensity = _isHovered && widget.enableHoverGlow
        ? (widget.glowIntensity * 1.5).clamp(0.0, 1.0)
        : widget.glowIntensity;

    // Build box shadows for glow effect
    List<BoxShadow> shadows = [];
    if (widget.glowColor != null) {
      shadows = [
        BoxShadow(
          color: widget.glowColor!.withAlpha((currentIntensity * 102).round()),
          blurRadius: 12,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: widget.glowColor!.withAlpha((currentIntensity * 51).round()),
          blurRadius: 24,
          spreadRadius: 2,
        ),
      ];
    }

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: EveColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: shadows,
        border: widget.glowColor != null
            ? Border.all(
                color:
                    widget.glowColor!.withAlpha((currentIntensity * 128).round()),
                width: 1,
              )
            : Border.all(
                color: Colors.white.withAlpha(13), // 5% white border
                width: 1,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.headerGradient != null)
              Container(
                height: 4,
                decoration: BoxDecoration(gradient: widget.headerGradient),
              ),
            Padding(
              padding: effectivePadding,
              child: widget.child,
            ),
          ],
        ),
      ),
    );

    // Wrap with hover detection for desktop
    if (widget.enableHoverGlow && widget.glowColor != null) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: card,
      );
    }

    // Wrap with InkWell if tap callback provided
    if (widget.onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Predefined card styles for common use cases.
abstract class EveCardStyles {
  /// Primary highlighted card (wallet balance, important info).
  static const Color primary = EveColors.evePrimary;

  /// Secondary accent card.
  static const Color secondary = EveColors.eveSecondary;

  /// Success state card (completed skills, positive balance).
  static const Color success = EveColors.success;

  /// Warning state card (expiring soon, low balance).
  static const Color warning = EveColors.warning;

  /// Error state card (failed, negative).
  static const Color error = EveColors.error;

  /// Faction-specific gradients for headers.
  static LinearGradient caldariGradient = LinearGradient(
    colors: [
      EveColors.caldari,
      EveColors.caldari.withAlpha(102),
    ],
  );

  static LinearGradient gallenteGradient = LinearGradient(
    colors: [
      EveColors.gallente,
      EveColors.gallente.withAlpha(102),
    ],
  );

  static LinearGradient amarrGradient = LinearGradient(
    colors: [
      EveColors.amarr,
      EveColors.amarr.withAlpha(102),
    ],
  );

  static LinearGradient minmatarGradient = LinearGradient(
    colors: [
      EveColors.minmatar,
      EveColors.minmatar.withAlpha(102),
    ],
  );
}

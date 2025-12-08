import 'package:flutter/material.dart';

import '../theme/eve_colors.dart';
import '../theme/eve_spacing.dart';

/// EVE Online Photon UI styled card with pronounced glow effects.
///
/// Provides a consistent card style with:
/// - Optional dual-blur glowing border (Photon-inspired)
/// - Hover glow enhancement on desktop
/// - Tighter padding and sharper corners
/// - Optional gradient header accent
///
/// ```dart
/// EveCard(
///   glowColor: EveColors.photonBlue,
///   glowIntensity: EveSpacing.glowIntensity,
///   child: content,
/// )
/// ```
class EveCard extends StatefulWidget {
  const EveCard({
    super.key,
    required this.child,
    this.glowColor,
    this.glowIntensity = EveSpacing.glowIntensity,
    this.enableHoverGlow = true,
    this.padding,
    this.onTap,
    this.headerGradient,
  });

  /// Card content.
  final Widget child;

  /// Color of the glow effect. Null disables the glow.
  final Color? glowColor;

  /// Intensity of the glow (0.0 to 1.0). Defaults to 0.4.
  final double glowIntensity;

  /// Whether to brighten glow on hover (desktop).
  final bool enableHoverGlow;

  /// Padding inside the card. Defaults to 12px (EveSpacing.cardPadding).
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
    // Use tighter default padding (12px instead of 16px)
    final effectivePadding =
        widget.padding ?? const EdgeInsets.all(EveSpacing.cardPadding);

    // Calculate glow intensity based on hover state
    // Hover multiplies by 1.5 (40% → 60%)
    final currentIntensity = _isHovered && widget.enableHoverGlow
        ? (widget.glowIntensity * EveSpacing.glowHoverMultiplier).clamp(0.0, 1.0)
        : widget.glowIntensity;

    // Build box shadows for pronounced dual-blur glow effect
    // Primary: 16px blur, Secondary: 32px blur
    List<BoxShadow> shadows = [];
    if (widget.glowColor != null) {
      shadows = [
        // Primary glow (16px blur)
        BoxShadow(
          color: widget.glowColor!.withAlpha((currentIntensity * 255).round()),
          blurRadius: EveSpacing.glowBlurPrimary,
          spreadRadius: EveSpacing.glowSpread,
        ),
        // Outer glow (32px blur, half intensity)
        BoxShadow(
          color:
              widget.glowColor!.withAlpha((currentIntensity * 128).round()),
          blurRadius: EveSpacing.glowBlurOuter,
          spreadRadius: EveSpacing.glowSpread,
        ),
      ];
    }

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        borderRadius: BorderRadius.circular(EveSpacing.cardRadius),
        boxShadow: shadows,
        border: widget.glowColor != null
            ? Border.all(
                color: widget.glowColor!
                    .withAlpha((currentIntensity * 128).round()),
                width: 1,
              )
            : Border.all(
                color: EveColors.borderSubtle,
                width: 1,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EveSpacing.cardRadius - 1),
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
  /// Primary highlighted card (wallet balance, important info) - Photon Blue.
  static const Color primary = EveColors.photonBlue;

  /// Secondary accent card - Photon Cyan.
  static const Color secondary = EveColors.photonCyan;

  /// Highlight/selection card - Photon Highlight.
  static const Color highlight = EveColors.photonHighlight;

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

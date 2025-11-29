import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eve_colors.dart';

/// EVE Online inspired space background with stars and nebula effects.
///
/// Renders a subtle starfield pattern with optional nebula gradient overlay.
/// Designed to be lightweight and non-distracting while adding depth.
///
/// ```dart
/// SpaceBackground(
///   starDensity: 0.5,
///   nebulaOpacity: 0.1,
///   child: content,
/// )
/// ```
class SpaceBackground extends StatelessWidget {
  const SpaceBackground({
    super.key,
    required this.child,
    this.starDensity = 0.4,
    this.nebulaOpacity = 0.08,
    this.showNebula = true,
  });

  /// Content to display over the background.
  final Widget child;

  /// Density of stars (0.0 to 1.0). Higher = more stars.
  final double starDensity;

  /// Opacity of the nebula overlay (0.0 to 1.0).
  final double nebulaOpacity;

  /// Whether to show the nebula gradient.
  final bool showNebula;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark background
        Container(color: EveColors.darkBackground),

        // Nebula gradient overlay
        if (showNebula)
          Positioned.fill(
            child: Opacity(
              opacity: nebulaOpacity,
              child: const _NebulaGradient(),
            ),
          ),

        // Starfield
        Positioned.fill(
          child: CustomPaint(
            painter: _StarfieldPainter(density: starDensity),
          ),
        ),

        // Content
        child,
      ],
    );
  }
}

/// Nebula gradient effect using EVE colors.
class _NebulaGradient extends StatelessWidget {
  const _NebulaGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.5, -0.3),
          radius: 1.5,
          colors: [
            EveColors.evePrimary.withAlpha(77), // 30%
            EveColors.eveSecondary.withAlpha(38), // 15%
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }
}

/// Custom painter for rendering starfield pattern.
class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.density});

  final double density;

  // Use a fixed seed for consistent star positions
  static const int _seed = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(_seed);

    // Calculate number of stars based on density and canvas size
    final area = size.width * size.height;
    final baseStars = (area / 5000).floor(); // ~1 star per 5000 px²
    final starCount = (baseStars * density).clamp(20, 500).toInt();

    // Different star types with varying sizes and brightness
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < starCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;

      // Random star properties
      final brightness = 0.2 + random.nextDouble() * 0.6; // 20-80% brightness
      final starSize = 0.5 + random.nextDouble() * 1.5; // 0.5-2px radius

      // Some stars are slightly tinted blue/white
      final isBlueTinted = random.nextDouble() > 0.7;
      final baseColor =
          isBlueTinted ? EveColors.evePrimary : Colors.white;

      starPaint.color = baseColor.withAlpha((brightness * 255).round());

      // Draw star
      canvas.drawCircle(Offset(x, y), starSize, starPaint);

      // Add glow to brighter stars
      if (brightness > 0.6 && starSize > 1.0) {
        starPaint.color = baseColor.withAlpha((brightness * 51).round());
        canvas.drawCircle(Offset(x, y), starSize * 2, starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) {
    return oldDelegate.density != density;
  }
}

/// A pre-configured space background suitable for scaffold use.
class EveScaffoldBackground extends StatelessWidget {
  const EveScaffoldBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      starDensity: 0.3,
      nebulaOpacity: 0.06,
      child: child,
    );
  }
}

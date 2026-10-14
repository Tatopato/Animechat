import 'dart:math';
import 'package:flutter/material.dart';

/// Shared cosmic/galaxy background used across Login, Home, Search,
/// and Profile screens so the whole app feels consistent.
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: Stack(
///     children: [
///       const Positioned.fill(child: CosmicBackground()),
///       SafeArea(child: yourContent),
///     ],
///   ),
/// )
/// ```
class CosmicBackground extends StatefulWidget {
  const CosmicBackground({
    super.key,
    this.nebulaColors,
    this.starCount = 70,
  });

  /// Colors used for the glowing nebula blobs. Defaults to a
  /// blue -> pink -> orange trio matching AppColors.
  final List<Color>? nebulaColors;
  final int starCount;

  @override
  State<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends State<CosmicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    // Generate star positions once and reuse every frame instead of
    // rebuilding the list (and a fresh Random per star) on every repaint —
    // that was the main cause of jank on screens using this background.
    _stars = List.generate(widget.starCount, (index) {
      final rnd = Random(index);
      return _Star(
        dx: rnd.nextDouble(),
        dy: rnd.nextDouble(),
        radius: rnd.nextDouble() * 1.4 + 0.4,
        phase: rnd.nextDouble(),
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.nebulaColors ??
        const [
          Color(0xFFFF1E9C), // secondary-ish pink
          Color(0xFF1565C0), // primary blue
          Color(0xFFFA7F61), // accent coral
        ];

    return IgnorePointer(
      child: Stack(
        children: [
          // Deep space gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E2050),
                    Color(0xFF2A2266),
                    Color(0xFF362575),
                    Color(0xFF14132E),
                  ],
                  stops: [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),
          // Nebula glow blobs
          Positioned(top: -80, left: -60, child: _nebulaBlob(colors[0], 220)),
          Positioned(top: 120, right: -80, child: _nebulaBlob(colors[1], 260)),
          Positioned(bottom: 60, left: -60, child: _nebulaBlob(colors[2], 200)),
          // Twinkling stars
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _StarfieldPainter(_controller.value, _stars),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nebulaBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter(this.progress, this.stars);

  final double progress;
  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final star in stars) {
      final twinkle = (sin((progress + star.phase) * 2 * pi) + 1) / 2;
      paint.color = Colors.white.withValues(alpha: 0.25 + twinkle * 0.65);
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Star {
  _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.phase,
  });

  final double dx;
  final double dy;
  final double radius;
  final double phase;
}

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_motion.dart';

/// Shared "anime" look for the Login and Register screens:
/// poster slideshow background, falling sakura petals, floating poster fan,
/// frosted glass card, neon fields and gradient buttons.

class AnimePalette {
  AnimePalette._();

  static const Color night = Color(0xFF0A0617);
  static const Color sakura = Color(0xFFFF7EB6);
  static const Color sakuraDeep = Color(0xFFFF4D94);
  static const Color violet = Color(0xFF8E5BFF);
  static const Color cyan = Color(0xFF5CE1FF);
  static const Color danger = Color(0xFFFF6B81);
}

class AnimeFonts {
  AnimeFonts._();

  /// Bold manga-title look with a hard pink drop shadow.
  static TextStyle display({double size = 30, Color color = Colors.white}) {
    return GoogleFonts.delaGothicOne(
      fontSize: size,
      color: color,
      height: 1.2,
      letterSpacing: 1,
      shadows: [
        const Shadow(color: AnimePalette.sakuraDeep, offset: Offset(3, 3)),
        Shadow(
          color: AnimePalette.violet.withValues(alpha: 0.6),
          blurRadius: 18,
        ),
      ],
    );
  }

  static TextStyle body({
    double size = 14,
    Color color = Colors.white70,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.zenMaruGothic(
      fontSize: size,
      color: color,
      fontWeight: weight,
    );
  }
}

// ---------------------------------------------------------------------------
// Background: cross-fading poster slideshow + sakura petals + sparkles
// ---------------------------------------------------------------------------

class AnimeAuthBackground extends StatefulWidget {
  const AnimeAuthBackground({
    super.key,
    required this.images,
    this.petals = true,
  });

  final List<String> images;

  /// Falling sakura petals on top of the slideshow.
  final bool petals;

  @override
  State<AnimeAuthBackground> createState() => _AnimeAuthBackgroundState();
}

class _AnimeAuthBackgroundState extends State<AnimeAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _petalController;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _petalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 7), (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % widget.images.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _petalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AnimePalette.night),
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1400),
            child: _SlowZoomImage(
              key: ValueKey(_index),
              asset: widget.images[_index],
            ),
          ),
        ),
        // Dark tint so the form stays readable.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x990A0617),
                Color(0xD90E0826),
                Color(0xF2080414),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Soft pink glow at the bottom.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomCenter,
              radius: 1.1,
              colors: [
                AnimePalette.sakuraDeep.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
        if (widget.petals)
          RepaintBoundary(
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _petalController,
                builder: (context, _) => CustomPaint(
                  painter: _SakuraPainter(_petalController.value),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SlowZoomImage extends StatelessWidget {
  const _SlowZoomImage({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.08, end: 1.22),
      duration: const Duration(seconds: 10),
      curve: Curves.linear,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

class _Petal {
  const _Petal({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.sway,
    required this.swayFreq,
    required this.spin,
    required this.alpha,
    required this.white,
  });

  final double x;
  final double phase;
  final int speed; // whole loops per cycle => seamless wrap-around
  final double size;
  final double sway;
  final int swayFreq;
  final int spin;
  final double alpha;
  final bool white;
}

class _Sparkle {
  const _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });

  final double x;
  final double y;
  final double size;
  final double phase;
}

class _SakuraPainter extends CustomPainter {
  _SakuraPainter(this.t);

  final double t;

  static final List<_Petal> _petals = List.generate(26, (i) {
    final r = Random(i * 7 + 3);
    return _Petal(
      x: r.nextDouble(),
      phase: r.nextDouble(),
      speed: 2 + r.nextInt(3),
      size: 4 + r.nextDouble() * 6,
      sway: 12 + r.nextDouble() * 26,
      swayFreq: 1 + r.nextInt(3),
      spin: 1 + r.nextInt(3),
      alpha: 0.5 + r.nextDouble() * 0.35,
      white: r.nextDouble() < 0.25,
    );
  });

  static final List<_Sparkle> _sparkles = List.generate(14, (i) {
    final r = Random(i * 13 + 5);
    return _Sparkle(
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: 3 + r.nextDouble() * 5,
      phase: r.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Sparkles
    for (final s in _sparkles) {
      final twinkle = (sin(2 * pi * (t * 3 + s.phase)) + 1) / 2;
      if (twinkle < 0.05) continue;
      paint.color = Colors.white.withValues(alpha: 0.2 + twinkle * 0.7);
      _drawSparkle(
        canvas,
        Offset(s.x * size.width, s.y * size.height),
        s.size * (0.4 + twinkle * 0.6),
        paint,
      );
    }

    // Petals
    for (final p in _petals) {
      final progress = (t * p.speed + p.phase) % 1.0;
      final y = progress * (size.height + 60) - 30;
      final x = p.x * size.width +
          sin(2 * pi * (t * p.swayFreq) + p.phase * 2 * pi) * p.sway;
      final angle = p.phase * 2 * pi + t * 2 * pi * p.spin;

      paint.color = (p.white ? Colors.white : AnimePalette.sakura)
          .withValues(alpha: p.alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final r = p.size;
      final path = Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(r * 0.95, -r * 0.3, 0, r)
        ..quadraticBezierTo(-r * 0.95, -r * 0.3, 0, -r)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  void _drawSparkle(Canvas c, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SakuraPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ---------------------------------------------------------------------------
// Entry animation
// ---------------------------------------------------------------------------

class AnimeReveal extends StatelessWidget {
  const AnimeReveal({
    super.key,
    required this.parent,
    required this.index,
    required this.child,
  });

  final Animation<double> parent;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.12).clamp(0.0, 0.6);
    final end = (start + 0.5).clamp(0.0, 1.0);
    final animation = CurveTween(
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ).animate(parent);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating poster fan (key-visual style)
// ---------------------------------------------------------------------------

class AnimePosterFan extends StatelessWidget {
  const AnimePosterFan({super.key, required this.images, required this.float})
      : assert(images.length == 3);

  /// [left, center, right]
  final List<String> images;
  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: AnimatedBuilder(
        animation: float,
        builder: (context, _) {
          final dy = sin(float.value * 2 * pi) * 6;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _poster(images[0], -0.2, Offset(-92, 14 - dy * 0.6), 0.78),
              _poster(images[2], 0.2, Offset(92, 14 + dy * 0.6), 0.78),
              _poster(images[1], 0, Offset(0, dy), 1.0),
            ],
          );
        },
      ),
    );
  }

  Widget _poster(String path, double angle, Offset offset, double scale) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 110 * scale,
          height: 165 * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AnimePalette.sakura.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11.5),
            child: Image.asset(path, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Heading
// ---------------------------------------------------------------------------

class AnimeHeading extends StatelessWidget {
  const AnimeHeading({
    super.key,
    this.jp,
    required this.title,
    required this.subtitle,
  });

  /// Optional Japanese tag shown above the title.
  final String? jp;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (jp != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AnimePalette.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AnimePalette.cyan.withValues(alpha: 0.55),
              ),
            ),
            child: Text(
              jp!,
              style: AnimeFonts.body(
                size: 13,
                color: AnimePalette.cyan,
                weight: FontWeight.w700,
              ).copyWith(letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: AnimeFonts.display(size: 30),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AnimeFonts.body(size: 14),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Glass card
// ---------------------------------------------------------------------------

class AnimeGlassCard extends StatelessWidget {
  const AnimeGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: AnimePalette.sakura.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text field
// ---------------------------------------------------------------------------

class AnimeTextField extends StatefulWidget {
  const AnimeTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<AnimeTextField> createState() => _AnimeTextFieldState();
}

class _AnimeTextFieldState extends State<AnimeTextField> {
  bool _obscure = true;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      cursorColor: AnimePalette.sakura,
      style: AnimeFonts.body(size: 15, color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: AnimeFonts.body(size: 14, color: Colors.white60),
        floatingLabelStyle: AnimeFonts.body(
          size: 14,
          color: AnimePalette.sakura,
          weight: FontWeight.w700,
        ),
        prefixIcon: Icon(widget.icon, color: AnimePalette.sakura, size: 22),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white54,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        errorStyle: AnimeFonts.body(size: 12, color: AnimePalette.danger),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.14), 1),
        focusedBorder: _border(AnimePalette.sakura, 1.8),
        errorBorder: _border(AnimePalette.danger, 1),
        focusedErrorBorder: _border(AnimePalette.danger, 1.8),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primary button
// ---------------------------------------------------------------------------

class AnimeButton extends StatelessWidget {
  const AnimeButton({
    super.key,
    required this.label,
    this.jpLabel,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final String? jpLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null && !loading ? 0.6 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [AnimePalette.sakuraDeep, AnimePalette.violet],
          ),
          boxShadow: [
            BoxShadow(
              color: AnimePalette.sakuraDeep.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.delaGothicOne(
                            fontSize: 15,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        if (jpLabel != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            jpLabel!,
                            style: AnimeFonts.body(
                              size: 12,
                              color: Colors.white70,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Social buttons + divider
// ---------------------------------------------------------------------------

class AnimeSocialButton extends StatelessWidget {
  const AnimeSocialButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Widget icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AnimePalette.sakura.withValues(alpha: 0.25),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.4,
            ),
          ),
          child: icon,
        ),
      ),
    );
  }
}

class AnimeDividerLabel extends StatelessWidget {
  const AnimeDividerLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(text, style: AnimeFonts.body(size: 12, color: Colors.white54)),
        ),
        line,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Misc helpers
// ---------------------------------------------------------------------------

void showAnimeSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF241A3F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AnimePalette.sakura.withValues(alpha: 0.5)),
      ),
      content: Text(
        message,
        style: AnimeFonts.body(size: 14, color: Colors.white),
      ),
    ),
  );
}

Route<T> animeFadeRoute<T>(Widget page) => AppMotion.page<T>(page);

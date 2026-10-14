import 'package:flutter/material.dart';
import 'package:app_name_v2/constants/app_colors.dart';
import 'package:app_name_v2/constants/app_text_styles.dart';
import 'package:app_name_v2/constants/cosmic_background.dart';
import 'package:app_name_v2/screens/login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageValue = 0;

  // ---- Onboarding content ----
  // Point `imagePath` at any asset under assets/images/ (declared in
  // pubspec.yaml). Slides render Image.asset directly now; if a file is
  // missing you'll see a soft placeholder icon instead of a crash.
  static const List<_IntroSlide> _slides = [
    _IntroSlide(
      imagePath: 'assets/images/rezero.jpg',
      title: 'Endless Anime Library',
      description: 'Explore thousands of titles across every genre, updated daily.',
      accentColorKey: _ColorKey.primary,
      badgeIcon: Icons.auto_stories_rounded,
    ),
    _IntroSlide(
      imagePath: 'assets/images/jjk.jpg',
      title: 'Personalized For You',
      description: 'Get recommendations tailored to what you love watching.',
      accentColorKey: _ColorKey.secondary,
      badgeIcon: Icons.auto_awesome_rounded,
    ),
    _IntroSlide(
      imagePath: 'assets/images/sao.jpg',
      title: 'Watch Anywhere',
      description: 'Stream seamlessly across your phone, tablet, and desktop.',
      accentColorKey: _ColorKey.accent,
      badgeIcon: Icons.devices_rounded,
    ),
    _IntroSlide(
      imagePath: 'assets/images/onepiece.jpg',
      title: 'Join the Community',
      description: 'Rate, review, and discuss your favorite series with fans worldwide.',
      accentColorKey: _ColorKey.success,
      badgeIcon: Icons.groups_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() => _pageValue = _pageController.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _resolve(_ColorKey key) {
    switch (key) {
      case _ColorKey.primary:
        return AppColors.primary;
      case _ColorKey.secondary:
        return AppColors.secondary;
      case _ColorKey.accent:
        return AppColors.accent;
      case _ColorKey.success:
        return AppColors.success;
    }
  }

  bool get _isFirstPage => _currentPage == 0;
  bool get _isLastPage => _currentPage == _slides.length - 1;

  void _onNext() {
    if (_isLastPage) {
      _goToApp();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onBack() {
    if (!_isFirstPage) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: const LoginScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _resolve(_slides[_currentPage].accentColorKey);

    return Scaffold(
      backgroundColor: const Color(0xFF171A3D),
      body: Stack(
        children: [
          const Positioned.fill(child: CosmicBackground()),
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 20, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _isLastPage ? 0 : 1,
                      child: TextButton(
                        onPressed: _isLastPage ? null : _goToApp,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      // Parallax: pages further from the current one shrink
                      // and fade slightly, so swiping feels more dynamic.
                      final distance = (index - _pageValue).abs().clamp(0.0, 1.0);
                      final scale = 1 - (distance * 0.12);
                      final opacity = 1 - (distance * 0.5);
                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: _IntroSlideView(
                            slide: slide,
                            accentColor: _resolve(slide.accentColorKey),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildDotsIndicator(accent),
                const SizedBox(height: 28),
                _buildBottomControls(accent),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotsIndicator(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        final active = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? accent : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: active ? 0.6 : 0.0),
                blurRadius: active ? 10 : 0,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBottomControls(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Back button — fades/scales in once we're past the first slide.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _isFirstPage
                ? const SizedBox(width: 0, height: 56, key: ValueKey('no-back'))
                : Padding(
                    key: const ValueKey('back'),
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _onBack,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: SizedBox(
              height: 56,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: ElevatedButton(
                  key: ValueKey(_isLastPage),
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ).copyWith(
                    shadowColor: WidgetStateProperty.all(accent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLastPage ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isLastPage ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ColorKey { primary, secondary, accent, success }

class _IntroSlide {
  const _IntroSlide({
    required this.imagePath,
    required this.title,
    required this.description,
    required this.accentColorKey,
    required this.badgeIcon,
  });

  final String imagePath;
  final String title;
  final String description;
  final _ColorKey accentColorKey;
  final IconData badgeIcon;
}

class _IntroSlideView extends StatelessWidget {
  const _IntroSlideView({required this.slide, required this.accentColor});

  final _IntroSlide slide;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing image frame with a small floating icon badge that
          // hints at what this slide is about at a glance.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Image.asset(
                        slide.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 56,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -14,
                right: -14,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    border: Border.all(color: const Color(0xFF171A3D), width: 3),
                    boxShadow: [
                      BoxShadow(color: accentColor.withValues(alpha: 0.6), blurRadius: 14),
                    ],
                  ),
                  child: Icon(slide.badgeIcon, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

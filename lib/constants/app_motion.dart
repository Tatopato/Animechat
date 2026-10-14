import 'package:flutter/material.dart';

/// Short, consistent transitions for opening a new screen.
class AppMotion {
  AppMotion._();

  static Route<T> route<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 190),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(eased),
              child: child,
            ),
          );
        },
      );

  static Route<T> page<T>(Widget page) => route<T>(builder: (_) => page);

  static Route<T> popPage<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 210),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          final eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(eased),
              child: child,
            ),
          );
        },
      );
}

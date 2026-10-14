import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/main_screen.dart';
import 'constants/minimal_ui.dart';
import 'services/theme_controller.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Wait for Firebase to restore the saved session so we know which account
  // (if any) is signed in before choosing the first screen.
  await FirebaseAuth.instance.authStateChanges().first;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.isDarkMode,
      builder: (context, dark, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Anime App',
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: dark ? Mi.violet : Mi.accent,
            brightness: dark ? Brightness.dark : Brightness.light,
          ).copyWith(
            surface: Mi.surface,
            onSurface: Mi.text,
            onSurfaceVariant: Mi.sub,
          ),
          textTheme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ).textTheme.apply(bodyColor: Mi.text, displayColor: Mi.text),
          primaryTextTheme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ).primaryTextTheme.apply(bodyColor: Mi.text, displayColor: Mi.text),
          iconTheme: IconThemeData(color: Mi.text),
          listTileTheme: const ListTileThemeData(
            mouseCursor: WidgetStateMouseCursor.clickable,
          ),
          textButtonTheme: const TextButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          outlinedButtonTheme: const OutlinedButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          filledButtonTheme: const FilledButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          iconButtonTheme: const IconButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          inputDecorationTheme: InputDecorationTheme(
            hintStyle: Mi.body(color: Mi.sub),
            labelStyle: Mi.body(color: Mi.sub),
          ),
          scaffoldBackgroundColor: Mi.bg,
          useMaterial3: true,
        ),
        // Already signed in -> straight to the app with this account's data.
        initialRoute:
            FirebaseAuth.instance.currentUser == null ? '/login' : '/main',
        routes: {
          '/': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/main': (context) => const MainScreen(),
        },
      ),
    );
  }
}

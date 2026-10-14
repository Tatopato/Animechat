import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/account_menu.dart';
import '../constants/minimal_ui.dart';
import '../services/user_data_service.dart';
import '../services/theme_controller.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Shared with the avatar menu so it can jump to the Profile tab.
  int get _currentIndex => mainTabIndex.value;

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onTabChanged);
    ThemeController.isDarkMode.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    mainTabIndex.addListener(_onTabChanged);
    ThemeController.isDarkMode.addListener(_onTabChanged);
    // Create this account's profile document the first time it signs in.
    UserDataService.instance.ensureProfile().catchError((Object _) {});
    ThemeController.loadForSignedInUser();
  }

  @override
  Widget build(BuildContext context) {
    // Safety net: without a signed-in account there is no data to show.
    if (FirebaseAuth.instance.currentUser == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: Mi.bg,
      // IndexedStack keeps each tab alive (scroll position, open streams).
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          ChatScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Mi.surface,
          border: Border(top: BorderSide(color: Mi.line)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return Mi.body(
                size: 12,
                color: selected ? Mi.accent : Mi.sub,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
              );
            }),
          ),
          child: NavigationBar(
            height: 64,
            elevation: 0,
            backgroundColor: Mi.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: Mi.accent.withValues(alpha: 0.14),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => mainTabIndex.value = index,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Mi.sub),
                selectedIcon: Icon(Icons.home_rounded, color: Mi.accent),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded, color: Mi.sub),
                selectedIcon: Icon(Icons.chat_rounded, color: Mi.accent),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded, color: Mi.sub),
                selectedIcon: Icon(Icons.person_rounded, color: Mi.accent),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

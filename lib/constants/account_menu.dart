import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../services/user_data_service.dart';
import 'minimal_ui.dart';

/// Which tab of the main screen is showing (0 Home, 1 Search, 2 Profile).
/// Shared so the avatar menu can jump to the Profile tab from any page.
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);

/// Signs out of Firebase (and the social providers, so the next login can
/// pick a different account) and returns to the login screen.
Future<void> signOutAndGoToLogin(BuildContext context) async {
  final navigator = Navigator.of(context);
  await FirebaseAuth.instance.signOut();
  mainTabIndex.value = 0;
  if (navigator.mounted) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
  // Provider cleanup must not delay showing the login screen.
  try {
    unawaited(GoogleSignIn.instance.signOut().catchError((Object _) {}));
  } catch (_) {}
  try {
    unawaited(FacebookAuth.instance.logOut().catchError((Object _) {}));
  } catch (_) {}
}

/// Asks first, then signs out. Used by the Log out buttons.
Future<void> confirmLogOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Mi.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Log out?', style: Mi.title(size: 18)),
      content: Text(
        'You can sign back in anytime.',
        style: Mi.body(color: Mi.sub),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancel', style: Mi.body(color: Mi.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            'Log out',
            style: Mi.body(color: Mi.danger, weight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) await signOutAndGoToLogin(context);
}

enum _AccountAction { profile, settings, logout }

/// The user's photo with a drop-down menu: Profile, Settings, Log out.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key, required this.profile, this.size = 44});

  final UserProfile profile;
  final double size;

  PopupMenuItem<_AccountAction> _item(
    IconData icon,
    String label,
    _AccountAction action, {
    bool danger = false,
  }) {
    final color = danger ? Mi.danger : Mi.text;
    return PopupMenuItem<_AccountAction>(
      value: action,
      height: 46,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: Mi.body(color: color, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _onSelected(BuildContext context, _AccountAction action) {
    switch (action) {
      case _AccountAction.profile:
        mainTabIndex.value = 2;
      case _AccountAction.settings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case _AccountAction.logout:
        // Signs out right away, no confirmation.
        signOutAndGoToLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      padding: EdgeInsets.zero,
      color: Mi.surface,
      elevation: 10,
      shadowColor: Colors.black38,
      constraints: const BoxConstraints(minWidth: 210),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Mi.line),
      ),
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (_) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          height: 62,
          child: Row(
            children: [
              UserAvatar(profile: profile, size: 36),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Mi.body(weight: FontWeight.w800, color: Mi.text),
                    ),
                    if (profile.email.isNotEmpty)
                      Text(
                        profile.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Mi.caption(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        _item(Icons.person_outline_rounded, 'Profile', _AccountAction.profile),
        _item(Icons.settings_outlined, 'Settings', _AccountAction.settings),
        const PopupMenuDivider(height: 1),
        _item(
          Icons.logout_rounded,
          'Log out',
          _AccountAction.logout,
          danger: true,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: Mi.brand,
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Mi.surface,
            shape: BoxShape.circle,
          ),
          child: UserAvatar(profile: profile, size: size),
        ),
      ),
    );
  }
}

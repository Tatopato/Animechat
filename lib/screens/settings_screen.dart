import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/account_menu.dart';
import '../constants/minimal_ui.dart';
import '../services/theme_controller.dart';
import '../services/user_data_service.dart';

/// Settings: account details, password reset, about and log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    ThemeController.isDarkMode.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _setDarkMode(bool value) async {
    final previous = ThemeController.isDarkMode.value;
    try {
      await ThemeController.saveForSignedInUser(value);
    } catch (_) {
      ThemeController.isDarkMode.value = previous;
      if (mounted) miSnack(context, 'Could not save the theme setting.');
    }
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      miSnack(context, 'This account has no email address.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) miSnack(context, 'Reset link sent to $email');
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        miSnack(context, e.message ?? "Couldn't send the reset email.");
      }
    } catch (_) {
      if (context.mounted) miSnack(context, "Couldn't send the reset email.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Mi.bg,
      appBar: AppBar(
        backgroundColor: Mi.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Mi.text,
        centerTitle: false,
        title: Text('Settings', style: Mi.title(size: 20)),
      ),
      body: MiBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const MiSectionHeader(title: 'Account'),
            const SizedBox(height: 12),
            Container(
              decoration: Mi.card(),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: Mi.tint, borderRadius: BorderRadius.circular(12)),
                      child: Icon(ThemeController.isDarkMode.value ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: Mi.violet, size: 20),
                    ),
                    title: Text('Dark mode', style: Mi.body(weight: FontWeight.w700)),
                    subtitle: Text('Use a darker color theme', style: Mi.caption()),
                    value: ThemeController.isDarkMode.value,
                    onChanged: _setDarkMode,
                  ),
                  Divider(height: 1, indent: 62, color: Mi.line),
                  SettingsTile(
                    icon: Icons.alternate_email_rounded,
                    title: 'Email',
                    subtitle: email.isEmpty ? 'No email on this account' : email,
                    onTap: null,
                  ),
                  Divider(height: 1, indent: 62, color: Mi.line),
                  SettingsTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change password',
                    subtitle: 'Send a reset link to your email',
                    onTap: () => _sendPasswordReset(context),
                  ),
                  Divider(height: 1, indent: 62, color: Mi.line),
                  StreamBuilder<bool>(stream: UserDataService.instance.friendRequestsEnabledStream(), builder: (context, snapshot) => SwitchListTile.adaptive(
                    secondary: const Icon(Icons.person_add_alt_1_rounded, color: Mi.violet),
                    title: Text('Allow friend requests', style: Mi.body(weight: FontWeight.w700)),
                    subtitle: Text('Let other anime fans add you', style: Mi.caption()),
                    value: snapshot.data ?? true,
                    onChanged: (value) => UserDataService.instance.setFriendRequestsEnabled(value),
                  )),
                  Divider(height: 1, indent: 62, color: Mi.line),
                  StreamBuilder<bool>(stream: UserDataService.instance.tasteSharingEnabledStream(), builder: (context, snapshot) => SwitchListTile.adaptive(
                    secondary: const Icon(Icons.favorite_outline_rounded, color: Mi.violet),
                    title: Text('Use favorites for recommendations', style: Mi.body(weight: FontWeight.w700)),
                    subtitle: Text('Share favorite anime IDs to find fans with similar taste', style: Mi.caption()),
                    value: snapshot.data ?? false,
                    onChanged: (value) => UserDataService.instance.setTasteSharingEnabled(value),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: UserDataService.instance.blockedUsersStream(),
              builder: (context, snapshot) {
                final blocked = snapshot.data ?? const <Map<String, dynamic>>[];
                if (blocked.isEmpty) return const SizedBox.shrink();
                return Container(decoration: Mi.card(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text('Blocked users')),
                  for (final user in blocked) ListTile(
                    title: Text(user['uid'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.body()),
                    trailing: TextButton(onPressed: () async { await UserDataService.instance.unblockUser(user['uid'] as String); }, child: const Text('Unblock')),
                  ),
                ]));
              },
            ),
            const SizedBox(height: 28),
            const MiSectionHeader(title: 'App'),
            const SizedBox(height: 12),
            Container(
              decoration: Mi.card(),
              child: SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'Anime App 1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Anime App',
                  applicationVersion: '1.0.0',
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => confirmLogOut(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Mi.danger,
                  side: BorderSide(color: Mi.line),
                  backgroundColor: Mi.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  'Log out',
                  style: Mi.body(color: Mi.danger, weight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row in a settings card: tinted icon, title, subtitle and a chevron
/// (the chevron is hidden for read-only rows).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Mi.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Mi.violet, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Mi.body(weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Mi.caption(),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: Mi.sub),
          ],
        ),
      ),
    );
  }
}

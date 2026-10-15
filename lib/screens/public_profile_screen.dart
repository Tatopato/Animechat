import 'dart:convert';
import 'package:flutter/material.dart';

import '../constants/minimal_ui.dart';
import '../services/user_data_service.dart';

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Mi.bg,
        appBar: AppBar(
          title: const Text('Profile'), backgroundColor: Mi.bg,
          actions: [PopupMenuButton<String>(onSelected: (action) async {
            if (action == 'block') {
              final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Block this user?'), content: const Text('They will be removed from friends and cannot send a friend request.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Block'))]));
              if (ok == true) { try { await UserDataService.instance.blockUser(uid); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked.'))); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not block this user.'))); } }
            } else if (action == 'report') {
              final reason = await showDialog<String>(context: context, builder: (dialogContext) { final controller = TextEditingController(); return AlertDialog(title: const Text('Report user'), content: TextField(controller: controller, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'Tell us what happened')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Submit'))]); });
              if (reason != null && reason.trim().isNotEmpty) { try { await UserDataService.instance.reportUser(uid, reason); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent.'))); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit report.'))); } }
            }
          }, itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: ListTile(dense: true, leading: Icon(Icons.flag_outlined), title: Text('Report'))), PopupMenuItem(value: 'block', child: ListTile(dense: true, leading: Icon(Icons.block_rounded), title: Text('Block')))])],
        ),
        body: MiBackdrop(
          child: SafeArea(
            child: StreamBuilder<UserProfile?>(
              stream: UserDataService.instance.publicProfileStream(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const MiDataError();
                if (!snapshot.hasData) return const MiLoading();
                final profile = snapshot.data;
                if (profile == null) {
                  return const MiEmpty(icon: Icons.person_off_outlined, text: 'Profile not found.');
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    _ProfileBanner(base64: profile.bannerBase64),
                    Transform.translate(
                      offset: const Offset(0, -42),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Mi.brand),
                          child: Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Mi.surface, shape: BoxShape.circle), child: UserAvatar(profile: profile, size: 88)),
                        ),
                        const SizedBox(height: 10),
                        Text(profile.displayName, textAlign: TextAlign.center, style: Mi.title(size: 22)),
                        const SizedBox(height: 12),
                        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: Mi.card(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('About', style: Mi.body(weight: FontWeight.w700)), const SizedBox(height: 8), Text(profile.bio.isEmpty ? 'No bio yet.' : profile.bio, style: Mi.body(color: Mi.text.withValues(alpha: .78)))])),
                        const SizedBox(height: 12),
                        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: Mi.card(), child: Row(children: [const Icon(Icons.badge_outlined, color: Mi.accent), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('UID', style: Mi.caption()), SelectableText(uid, style: Mi.body(size: 13, weight: FontWeight.w700))]))])),
                      ]),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.base64});
  final String? base64;

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [Mi.violet, Mi.accent, Color(0xFFFF91B9)]),
          image: base64 == null ? null : DecorationImage(image: MemoryImage(base64Decode(base64!)), fit: BoxFit.cover),
        ),
        child: base64 == null ? const Center(child: Icon(Icons.auto_awesome, size: 34, color: Colors.white70)) : null,
      );
}

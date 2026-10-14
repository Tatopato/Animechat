import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/account_menu.dart';
import '../constants/app_motion.dart';
import '../constants/minimal_ui.dart';
import '../data/anime_catalog.dart';
import '../services/user_data_service.dart';
import '../services/anime_catalog_service.dart';
import '../services/theme_controller.dart';
import 'settings_screen.dart';
import 'public_profile_screen.dart';
import 'home_screen.dart' show PostDetailScreen, showEditPostSheet, confirmDeletePost;

/// Profile: name, photo, bio, stats and favorites of the signed-in account.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.focusSettings = false});
  final bool focusSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = UserDataService.instance;
  final _settingsKey = GlobalKey();

  late final Stream<UserProfile> _profile = _service.profileStream();
  late Stream<Set<String>> _favorites = _service.favoriteIdsStream();
  late Stream<List<UserPost>> _posts = _service.myPostsStream();
  late Stream<List<UserPost>> _savedPosts = _service.savedPostsStream();
  late final Stream<List<Map<String, dynamic>>> _friends = _service.friendsStream();
  late final Stream<List<FriendRequest>> _requests = _service.friendRequestsStream();
  bool _showAllPosts = false;

  @override
  void initState() {
    super.initState();
    ThemeController.isDarkMode.addListener(_onThemeChanged);
    if (widget.focusSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _settingsKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut, alignment: 0.08);
        }
      });
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Mi.bg,
      body: MiBackdrop(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              StreamBuilder<UserProfile>(
                stream: _profile,
                initialData:
                    user == null ? null : UserProfile.fromData(null, user),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  if (profile == null) return const MiLoading();
                  return _buildHeader(profile);
                },
              ),
              const SizedBox(height: 18),
              _uidCard(user?.uid ?? ''),
              const SizedBox(height: 18),
              _FriendTools(service: _service, requests: _requests),
              const SizedBox(height: 18),
              _buildFriends(),
              const SizedBox(height: 18),
              _buildStats(),
              const SizedBox(height: 28),
              _profileEntryCard(
                icon: Icons.article_outlined,
                title: 'My posts',
                subtitle: 'View, edit or delete your posts',
                onTap: () {
                  _posts = _service.myPostsStream();
                  _openProfileCollection('My posts', _buildMyPosts());
                },
              ),
              _profileEntryCard(
                icon: Icons.bookmark_outline_rounded,
                title: 'Saved posts',
                subtitle: 'Posts saved from the community',
                onTap: () {
                  _savedPosts = _service.savedPostsStream();
                  _openProfileCollection('Saved posts', _buildSavedPosts());
                },
              ),
              _profileEntryCard(
                icon: Icons.favorite_border_rounded,
                title: 'Favorites',
                subtitle: 'Anime you have liked',
                onTap: () {
                  _favorites = _service.favoriteIdsStream();
                  _openProfileCollection('Favorites', _buildFavorites());
                },
              ),
              const SizedBox(height: 28),
              Container(
                key: _settingsKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _settingsSectionLabel('Settings'),
                    const SizedBox(height: 14),
                    _buildSettingsContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _uidCard(String uid) => Container(
    decoration: Mi.card(), padding: const EdgeInsets.all(14),
    child: Row(children: [const Icon(Icons.badge_outlined, color: Mi.accent), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your UID', style: Mi.caption()), SelectableText(uid, style: Mi.body(size: 13, weight: FontWeight.w700))])), IconButton(tooltip: 'Copy UID', icon: Icon(Icons.copy_rounded, color: Mi.sub, size: 19), onPressed: () { Clipboard.setData(ClipboardData(text: uid)); miSnack(context, 'UID copied.'); })]),
  );

  void _openProfileCollection(String title, Widget content) {
    Navigator.of(context).push(
      AppMotion.route(
        builder: (_) => _ProfileCollectionScreen(title: title, content: content),
      ),
    );
  }

  Widget _profileEntryCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData icon = Icons.auto_awesome_rounded,
    Widget? leading,
    Widget? trailing,
    Widget? footer,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: Mi.card(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          leading ?? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Mi.tint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: Mi.violet, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.body(weight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.caption()),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          trailing ?? Icon(Icons.chevron_right_rounded, color: Mi.sub),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ?footer,
            ],
          ),
        ),
      );

  Widget _buildMyPosts() => StreamBuilder<List<UserPost>>(
        stream: _posts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MiDataError(
              onRetry: () => setState(() => _posts = _service.myPostsStream()),
            );
          }
          if (!snapshot.hasData) return _profileEntriesSkeleton();
          final posts = snapshot.data!;
          if (posts.isEmpty) return const MiEmpty(icon: Icons.edit_note_rounded, text: 'Your posts will appear here.');
          final shownPosts = _showAllPosts || posts.length <= 3 ? posts : posts.take(3).toList();
          return Column(children: [
            for (final post in shownPosts)
              _profileEntryCard(
                icon: post.imageBase64 == null ? Icons.article_outlined : Icons.image_outlined,
                title: post.caption.isEmpty
                    ? 'Shared ${post.animeTitle ?? animeById(post.animeId ?? '')?.title ?? 'a post'}'
                    : post.caption,
                subtitle: timeAgo(post.createdAt),
                onTap: () => Navigator.of(context).push(
                  AppMotion.route(builder: (_) => PostDetailScreen(post: post)),
                ),
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => showEditPostSheet(context, post),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: () => confirmDeletePost(context, post),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ),
            if (posts.length > 3)
              TextButton.icon(
                onPressed: () => setState(() => _showAllPosts = !_showAllPosts),
                icon: Icon(_showAllPosts ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                label: Text(_showAllPosts ? 'Show fewer posts' : 'View more (${posts.length - 3})'),
              ),
          ]);
        },
      );

  Widget _buildSavedPosts() => StreamBuilder<List<UserPost>>(
        stream: _savedPosts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MiDataError(
              onRetry: () => setState(
                () => _savedPosts = _service.savedPostsStream(),
              ),
            );
          }
          if (!snapshot.hasData) return _profileEntriesSkeleton();
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return const MiEmpty(
              icon: Icons.bookmark_border_rounded,
              text: 'Posts you save from the community will appear here.',
            );
          }
          return Column(
            children: [
              for (final post in posts)
                _profileEntryCard(
                  icon: Icons.bookmark_rounded,
                  title: post.caption.isEmpty
                      ? 'Shared ${post.animeTitle ?? animeById(post.animeId ?? '')?.title ?? 'a post'}'
                      : post.caption,
                  subtitle: '${post.authorName} · ${timeAgo(post.createdAt)}',
                  onTap: () => Navigator.of(context).push(
                    AppMotion.route(builder: (_) => PostDetailScreen(post: post)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove saved post',
                        icon: Icon(Icons.bookmark_remove_outlined, color: Mi.sub),
                        onPressed: () async {
                          try {
                            await _service.setPostSaved(post.id, false);
                          } catch (_) {
                            if (context.mounted) {
                              miSnack(context, 'Could not remove saved post.');
                            }
                          }
                        },
                      ),
                      Icon(Icons.chevron_right_rounded, color: Mi.sub),
                    ],
                  ),
                ),
            ],
          );
        },
      );

  Widget _buildFriends() => StreamBuilder<List<Map<String, dynamic>>>(
        stream: _friends,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const MiDataError();
          final count = snapshot.data?.length;
          return _profileEntryCard(
            icon: Icons.people_alt_outlined,
            title: 'Friends',
            subtitle: count == null ? 'View and search your friends' : '$count friends · View and search',
            onTap: () => _openProfileCollection(
              'Friends',
              _FriendsCollectionContent(service: _service),
            ),
          );
        },
      );

  // ---------------------------------------------------------------- header

  Widget _buildHeader(UserProfile profile) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text('Profile', style: Mi.title())),
            AccountMenuButton(profile: profile, size: 36),
          ],
        ),
        const SizedBox(height: 16),
        Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
          Container(
            height: 142,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [Mi.violet, Mi.accent, Color(0xFFFF91B9)]),
              image: profile.bannerBase64 == null ? null : DecorationImage(image: MemoryImage(_decodeImage(profile.bannerBase64!)), fit: BoxFit.cover),
            ),
            child: profile.bannerBase64 == null ? const Center(child: Icon(Icons.auto_awesome, size: 32, color: Colors.white70)) : null,
          ),
          Positioned(bottom: -42, child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: Mi.brand,
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Mi.surface,
              shape: BoxShape.circle,
            ),
            child: UserAvatar(profile: profile, size: 84),
          ),
        )),
        ]),
        const SizedBox(height: 52),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          style: Mi.title(size: 22),
        ),
        if (profile.email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(profile.email, style: Mi.caption()),
        ],
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            profile.bio,
            textAlign: TextAlign.center,
            style: Mi.body(color: Mi.text.withValues(alpha: 0.75)),
          ),
        ],
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: Mi.brand,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x447C5CFF),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _openEditProfile(profile),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_outlined,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Edit profile',
                      style: Mi.body(
                        size: 13,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- stats

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: Mi.card(),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<List<UserPost>>(
              stream: _posts,
              builder: (context, snapshot) => _Stat(
                value: snapshot.data?.length,
                label: 'Posts',
              ),
            ),
          ),
          Container(width: 1, height: 32, color: Mi.line),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: _favorites,
              builder: (context, snapshot) => _Stat(
                value: snapshot.data?.length,
                label: 'Favorites',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- favorites

  Widget _buildFavorites() {
    return StreamBuilder<Set<String>>(
      stream: _favorites,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MiDataError(
            onRetry: () => setState(() {
              _favorites = _service.favoriteIdsStream();
            }),
          );
        }
        if (!snapshot.hasData) return _favoritesSkeleton();
        final ids = snapshot.data!;
        if (ids.isEmpty) {
          return const MiEmpty(
            icon: Icons.favorite_border_rounded,
            text: 'No favorites yet.\nTap the heart on any anime.',
          );
        }
        return FutureBuilder<List<Anime>>(
          future: AnimeCatalogService.instance.animeByIds(ids),
          builder: (context, animeSnapshot) {
            if (animeSnapshot.hasError) {
              return MiDataError(
                text: 'โหลดรายการโปรดไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
                onRetry: () => setState(() {}),
              );
            }
            if (!animeSnapshot.hasData) return _favoritesSkeleton();
            final items = animeSnapshot.data!;
            if (items.isEmpty) {
              return const MiEmpty(
                icon: Icons.cloud_off_rounded,
                text: 'ไม่พบข้อมูลอนิเมะที่บันทึกไว้ ลองโหลดใหม่อีกครั้ง',
              );
            }
            return Column(
              children: [
                for (final anime in items)
                  _profileEntryCard(
                    title: anime.title,
                    subtitle: '${anime.score == null ? 'No rating' : '★ ${anime.score!.toStringAsFixed(1)}'} · ${anime.episodes == null ? 'Episodes TBA' : '${anime.episodes} eps'} · ${anime.seasonLabel}',
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        anime.imageUrl,
                        width: 44,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 44,
                          height: 48,
                          color: Mi.tint,
                          alignment: Alignment.center,
                          child: Icon(Icons.movie_outlined, color: Mi.violet, size: 21),
                        ),
                      ),
                    ),
                    onTap: () => showAnimeSheet(context, anime),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Remove favorite',
                          onPressed: () => toggleFavorite(context, anime, true),
                          icon: const Icon(Icons.favorite_rounded, color: Mi.accent, size: 19),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Mi.sub),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _favoritesSkeleton() => _profileEntriesSkeleton(showImage: true);

  Widget _profileEntriesSkeleton({bool showImage = false}) => Column(
        children: List.generate(
          1,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: Mi.card(),
            child: Row(
              children: [
                MiSkeletonBlock(
                  width: showImage ? 44 : 40,
                  height: showImage ? 48 : 40,
                  radius: showImage ? 12 : 14,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MiSkeletonBlock(width: 150, height: 12),
                      SizedBox(height: 7),
                      MiSkeletonBlock(width: 115, height: 10),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Mi.sub),
              ],
            ),
          ),
        ),
      );

  // -------------------------------------------------------------- settings

  Widget _buildSettingsContent() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSectionLabel('Account'),
        const SizedBox(height: 12),
        Container(
          decoration: Mi.card(),
          child: Column(children: [
            SwitchListTile.adaptive(
              secondary: Container(width: 36, height: 36, decoration: BoxDecoration(color: Mi.tint, borderRadius: BorderRadius.circular(12)), child: Icon(ThemeController.isDarkMode.value ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: Mi.violet, size: 20)),
              title: Text('Dark mode', style: Mi.body(weight: FontWeight.w700)),
              subtitle: Text('Use a darker color theme', style: Mi.caption()),
              value: ThemeController.isDarkMode.value,
              onChanged: (value) async {
                final previous = ThemeController.isDarkMode.value;
                try {
                  await ThemeController.saveForSignedInUser(value);
                } catch (_) {
                  ThemeController.isDarkMode.value = previous;
                  if (mounted) miSnack(context, 'Could not save the theme setting.');
                }
              },
            ),
            Divider(height: 1, indent: 62, color: Mi.line),
            SettingsTile(icon: Icons.alternate_email_rounded, title: 'Email', subtitle: email.isEmpty ? 'No email on this account' : email, onTap: null),
            Divider(height: 1, indent: 62, color: Mi.line),
            SettingsTile(
              icon: Icons.lock_reset_rounded,
              title: 'Change password',
              subtitle: 'Send a reset link to your email',
              onTap: () async {
                if (email.isEmpty) {
                  miSnack(context, 'This account has no email address.');
                  return;
                }
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (mounted) miSnack(context, 'Reset link sent to $email');
                } on FirebaseAuthException catch (error) {
                  if (mounted) miSnack(context, error.message ?? "Couldn't send the reset email.");
                } catch (_) {
                  if (mounted) miSnack(context, "Couldn't send the reset email.");
                }
              },
            ),
          ]),
        ),
        const SizedBox(height: 28),
        _settingsSectionLabel('App'),
        const SizedBox(height: 12),
        Container(
          decoration: Mi.card(),
          child: SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Anime App 1.0.0',
            onTap: () => showAboutDialog(context: context, applicationName: 'Anime App', applicationVersion: '1.0.0'),
          ),
        ),
        const SizedBox(height: 20),
        _buildLogout(),
      ],
    );
  }

  Widget _settingsSectionLabel(String title) => Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: Mi.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Mi.body(
              size: 17,
              color: Mi.isDark ? Colors.white : const Color(0xFF21152B),
              weight: FontWeight.w800,
            ),
          ),
        ],
      );

  Widget _buildLogout() {
    return SizedBox(
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
    );
  }

  // --------------------------------------------------------------- actions

  void _openEditProfile(UserProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Mi.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
  }
}

Uint8List _decodeImage(String value) => base64Decode(value);

class _FriendTools extends StatefulWidget {
  const _FriendTools({required this.service, required this.requests});
  final UserDataService service;
  final Stream<List<FriendRequest>> requests;

  @override
  State<_FriendTools> createState() => _FriendToolsState();
}

class _FriendToolsState extends State<_FriendTools> {
  final _uid = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _uid.dispose(); super.dispose(); }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      final result = await widget.service.addFriendByUid(_uid.text);
      if (!mounted) return;
      miSnack(context, result == null ? 'UID not found.' : result == 'already' ? 'Already friends.' : 'Friend request sent.');
      if (result != null && result != 'already') _uid.clear();
    } catch (_) {
      if (mounted) miSnack(context, 'Could not send request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const MiSectionHeader(title: 'Add friends'),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(12), decoration: Mi.card(), child: Row(children: [Expanded(child: TextField(controller: _uid, decoration: const InputDecoration(hintText: 'Enter a friend UID', isDense: true, border: OutlineInputBorder()))), const SizedBox(width: 8), FilledButton(onPressed: _busy ? null : _add, child: const Text('Add'))])),
    const SizedBox(height: 18),
    const MiSectionHeader(title: 'Friend requests'),
    const SizedBox(height: 8),
    StreamBuilder<List<FriendRequest>>(stream: widget.requests, builder: (context, snap) {
      if (snap.hasError) return const MiDataError();
      if (!snap.hasData) return const MiLoading();
      final requests = snap.data!;
      if (requests.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('No incoming requests.', style: Mi.caption()));
      return Column(children: [for (final request in requests) Container(margin: const EdgeInsets.only(bottom: 8), decoration: Mi.card(), child: ListTile(
        title: Text(request.name, style: Mi.body()), subtitle: Text(request.uid, style: Mi.caption()),
        trailing: Wrap(spacing: 2, children: [IconButton(tooltip: 'Accept', icon: const Icon(Icons.check_circle, color: Mi.accent), onPressed: () async { try { await widget.service.acceptFriend(request); } catch (_) { if (context.mounted) miSnack(context, 'Could not accept request.'); } }), IconButton(tooltip: 'Decline', icon: Icon(Icons.cancel_outlined, color: Mi.sub), onPressed: () async { try { await widget.service.rejectFriend(request); } catch (_) { if (context.mounted) miSnack(context, 'Could not decline request.'); } })]),
        onTap: () => Navigator.of(context).push(AppMotion.route(builder: (_) => PublicProfileScreen(uid: request.uid))),
      ))]);
    }),
  ]);
}

class _FriendsCollectionContent extends StatefulWidget {
  const _FriendsCollectionContent({required this.service});

  final UserDataService service;

  @override
  State<_FriendsCollectionContent> createState() => _FriendsCollectionContentState();
}

class _FriendsCollectionContentState extends State<_FriendsCollectionContent> {
  final _search = TextEditingController();
  String _query = '';
  late Stream<List<Map<String, dynamic>>> _friends;
  Timer? _loadTimer;
  bool _waitingForFriends = true;
  bool _loadTimedOut = false;

  @override
  void initState() {
    super.initState();
    _friends = widget.service.friendsStream();
    _startLoadTimer();
  }

  void _startLoadTimer() {
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _waitingForFriends) setState(() => _loadTimedOut = true);
    });
  }

  void _retryLoadingFriends() {
    setState(() {
      _friends = widget.service.friendsStream();
      _waitingForFriends = true;
      _loadTimedOut = false;
    });
    _startLoadTimer();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search friends by name or UID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Mi.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Mi.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Mi.line)),
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _friends,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _waitingForFriends = false;
                _loadTimer?.cancel();
                return MiDataError(onRetry: _retryLoadingFriends);
              }
              if (!snapshot.hasData) {
                return _loadTimedOut
                    ? MiDataError(
                        text: 'โหลดรายชื่อเพื่อนไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองอีกครั้ง',
                        onRetry: _retryLoadingFriends,
                      )
                    : const MiLoading();
              }
              _waitingForFriends = false;
              _loadTimer?.cancel();
              final friends = snapshot.data!;
              final filtered = friends.where((friend) {
                final name = (friend['name'] as String? ?? 'Friend').toLowerCase();
                final uid = (friend['uid'] as String? ?? '').toLowerCase();
                return name.contains(_query) || uid.contains(_query);
              }).toList();
              if (friends.isEmpty) {
                return const MiEmpty(icon: Icons.people_outline_rounded, text: 'Your accepted friends will appear here.');
              }
              if (filtered.isEmpty) {
                return const MiEmpty(icon: Icons.search_off_rounded, text: 'No friends match this search.');
              }
              return Column(
                children: [
                  for (final friend in filtered)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: Mi.card(),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        leading: FriendAvatar(uid: friend['uid'] as String, name: friend['name'] as String? ?? 'Friend', size: 44),
                        title: Text(friend['name'] as String? ?? 'Friend', maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.body(weight: FontWeight.w700)),
                        subtitle: Text(friend['uid'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.caption()),
                        trailing: IconButton(
                          tooltip: 'Remove friend',
                          icon: const Icon(Icons.person_remove_outlined, color: Mi.danger),
                          onPressed: () => _removeFriend(friend),
                        ),
                        onTap: () => Navigator.of(context).push(AppMotion.route(builder: (_) => PublicProfileScreen(uid: friend['uid'] as String))),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );

  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    final uid = friend['uid'] as String?;
    if (uid == null) return;
    final name = friend['name'] as String? ?? 'this friend';
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Mi.surface,
        title: const Text('Remove friend?'),
        content: Text('Remove $name from your friends list?', style: Mi.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Remove', style: Mi.body(color: Mi.danger))),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    try {
      await widget.service.removeFriend(uid);
      if (mounted) miSnack(context, 'Friend removed.');
    } catch (_) {
      if (mounted) miSnack(context, 'Could not remove friend.');
    }
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value?.toString() ?? '–',
          style: Mi.title(size: 22).copyWith(color: Mi.accent),
        ),
        const SizedBox(height: 2),
        Text(label, style: Mi.caption()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile sheet
// ---------------------------------------------------------------------------

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.displayName);
  late final TextEditingController _bio =
      TextEditingController(text: widget.profile.bio);
  late String? _avatar = widget.profile.avatar;

  /// Photo uploaded from the device; wins over the built-in avatars.
  late String? _photoBase64 = widget.profile.photoBase64;
  late String? _bannerBase64 = widget.profile.bannerBase64;
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (picked == null) return;
      final encoded = await UserDataService.instance.encodeAvatar(picked);
      if (mounted) {
        setState(() {
          _photoBase64 = encoded;
          _avatar = null;
        });
      }
    } on FormatException {
      if (mounted) miSnack(context, 'That photo is too large. Try another.');
    } catch (_) {
      if (mounted) miSnack(context, "Couldn't open the photo picker.");
    }
  }

  Future<void> _pickBanner() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 500, imageQuality: 55);
      if (picked == null) return;
      final encoded = await UserDataService.instance.encodeBanner(picked);
      if (mounted) setState(() => _bannerBase64 = encoded);
    } on FormatException {
      if (mounted) miSnack(context, 'Banner is too large. Choose another image.');
    } catch (_) {
      if (mounted) miSnack(context, "Couldn't open the image picker.");
    }
  }

  void _choosePhotoSource() {
    if (kIsWeb) {
      _pickPhoto(ImageSource.gallery);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Mi.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Choose from gallery', style: Mi.body()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('Take a photo', style: Mi.body()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      miSnack(context, 'Please enter a name.');
      return;
    }
    setState(() => _saving = true);
    try {
      await UserDataService.instance.updateProfile(
        displayName: _name.text,
        bio: _bio.text,
        avatar: _avatar,
        photoBase64: _photoBase64,
        bannerBase64: _bannerBase64,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        miSnack(context, "Couldn't save your profile. Please try again.");
      }
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: Mi.body(color: Mi.sub),
        floatingLabelStyle:
            Mi.body(color: Mi.accent, weight: FontWeight.w700),
        filled: true,
        fillColor: Mi.bg,
        counterStyle: Mi.caption(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Mi.accent, width: 1.4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final initialOnly = UserProfile(
      displayName: _name.text.isEmpty ? widget.profile.displayName : _name.text,
      email: widget.profile.email,
      bio: '',
      avatar: null,
      photoUrl: null,
      recentSearches: const [],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit profile', style: Mi.title(size: 20)),
            const SizedBox(height: 18),
            Text('Profile banner', style: Mi.caption()),
            const SizedBox(height: 8),
            MouseRegion(cursor: SystemMouseCursors.click, child: InkWell(
              onTap: _saving ? null : _pickBanner,
              borderRadius: BorderRadius.circular(16),
              child: Container(height: 96, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Mi.violet, Mi.accent, Color(0xFFFF91B9)]), image: _bannerBase64 == null ? null : DecorationImage(image: MemoryImage(_decodeImage(_bannerBase64!)), fit: BoxFit.cover)), child: const Center(child: Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 28))),
            )),
            if (_bannerBase64 != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => _bannerBase64 = null), icon: const Icon(Icons.delete_outline), label: const Text('Remove banner'))),
            const SizedBox(height: 14),
            Text('Photo', style: Mi.caption()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Upload from the device (shows the chosen photo once set)
                _AvatarOption(
                  selected: _photoBase64 != null,
                  onTap: _saving ? () {} : _choosePhotoSource,
                  child: _photoBase64 != null
                      ? UserAvatar(
                          profile: UserProfile(
                            displayName: initialOnly.displayName,
                            email: '',
                            bio: '',
                            avatar: null,
                            photoUrl: null,
                            photoBase64: _photoBase64,
                            recentSearches: const [],
                          ),
                          size: 52,
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Mi.line,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 22,
                            color: Mi.sub,
                          ),
                        ),
                ),
                _AvatarOption(
                  selected: _avatar == null && _photoBase64 == null,
                  onTap: () => setState(() {
                    _avatar = null;
                    _photoBase64 = null;
                  }),
                  child: UserAvatar(profile: initialOnly, size: 52),
                ),
                for (final path in avatarChoices)
                  _AvatarOption(
                    selected: _avatar == path && _photoBase64 == null,
                    onTap: () => setState(() {
                      _avatar = path;
                      _photoBase64 = null;
                    }),
                    child: ClipOval(
                      child: Image.asset(
                        path,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(width: 52, height: 52, color: Mi.line),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              maxLength: 30,
              style: Mi.body(size: 15),
              cursorColor: Mi.accent,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bio,
              maxLength: 80,
              maxLines: 2,
              style: Mi.body(size: 15),
              cursorColor: Mi.accent,
              decoration: _decoration('Bio'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Mi.accent,
                disabledBackgroundColor: Mi.line,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: Mi.body(
                        size: 15,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Mi.accent : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: child,
      ),
      ),
    );
  }
}

class _ProfileCollectionScreen extends StatelessWidget {
  const _ProfileCollectionScreen({required this.title, required this.content});

  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Mi.bg,
        appBar: AppBar(
          title: Text(title, style: Mi.title(size: 20)),
          backgroundColor: Mi.bg,
          surfaceTintColor: Colors.transparent,
        ),
        body: MiBackdrop(
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [content],
            ),
          ),
        ),
      );
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/account_menu.dart';
import '../constants/app_motion.dart';
import '../constants/minimal_ui.dart';
import '../data/anime_catalog.dart';
import '../services/user_data_service.dart';
import 'chat_screen.dart';
import 'public_profile_screen.dart';
import '../services/anime_catalog_service.dart';
import '../services/theme_controller.dart';

/// Home: greeting, trending anime (favorite with the heart) and the public
/// community feed. Posts from every account appear here in real time;
/// favorites stay private under the account's uid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = UserDataService.instance;
  final _trendingController = ScrollController();
  final _genreController = ScrollController();
  final _communityKey = GlobalKey();
  final Map<String, GlobalKey> _postKeys = {};

  late final Stream<UserProfile> _profile = _service.profileStream();
  late final Stream<UserProfile> _composerProfile = _service.profileStream();
  late final Stream<Set<String>> _favorites = _service.favoriteIdsStream();
  late Stream<List<UserPost>> _posts = _service.feedStream();
  late Future<List<Anime>> _trending = AnimeCatalogService.instance.topAnime();
  String? _selectedTrendingGenre;

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ThemeController.isDarkMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.isDarkMode.removeListener(_onThemeChanged);
    _trendingController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Mi.bg,
      body: MiBackdrop(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              Row(children: [
                const Expanded(child: MiSectionHeader(title: 'Trending on AniList')),
                IconButton(tooltip: 'Scroll left', onPressed: () => _scrollTrending(-220), icon: Icon(Icons.chevron_left_rounded, color: Mi.sub)),
                IconButton(tooltip: 'Scroll right', onPressed: () => _scrollTrending(220), icon: Icon(Icons.chevron_right_rounded, color: Mi.sub)),
                IconButton(tooltip: 'Refresh anime', onPressed: () => setState(() => _trending = AnimeCatalogService.instance.topAnime(refresh: true)), icon: Icon(Icons.refresh_rounded, color: Mi.sub)),
              ]),
              const SizedBox(height: 14),
              _buildTrending(),
              const SizedBox(height: 28),
              KeyedSubtree(
                key: _communityKey,
                child: const MiSectionHeader(title: 'Community'),
              ),
              const SizedBox(height: 14),
              _buildComposer(),
              const SizedBox(height: 14),
              _buildPosts(),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollTrending(double offset) {
    if (!_trendingController.hasClients) return;
    final position = _trendingController.position;
    final target = (position.pixels + offset)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _trendingController.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  // ---------------------------------------------------------------- header

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<UserProfile>(
      stream: _profile,
      initialData: user == null ? null : UserProfile.fromData(null, user),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return Row(
          children: [
            Expanded(
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: Mi.brand,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(color: Color(0x337B61D1), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.forum_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 11),
                Flexible(
                  child: ShaderMask(
                    shaderCallback: (bounds) => Mi.brand.createShader(bounds),
                    child: Text(
                      'Anime Chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Mi.title(size: 24).copyWith(color: Colors.white, letterSpacing: -.4),
                    ),
                  ),
                ),
              ]),
            ),
            IconButton(
              tooltip: 'Search anime',
              onPressed: _openAnimeSearch,
              icon: Icon(Icons.search_rounded, color: Mi.sub),
            ),
            if (profile != null) AccountMenuButton(profile: profile, size: 46),
            const SizedBox(width: 4),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.notificationsStream(),
              builder: (context, snapshot) {
                final unread = (snapshot.data ?? const []).where((n) => n['read'] != true).length;
                return Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: IconButton(icon: Icon(Icons.notifications_none_rounded, color: Mi.sub), onPressed: () => _showNotifications(snapshot.data ?? const [])));
              },
            ),
          ],
        );
      },
    );
  }

  void _showNotifications(List<Map<String, dynamic>> notifications) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Mi.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            Text('Notifications', style: Mi.title(size: 20)),
            const SizedBox(height: 8),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No notifications yet.', style: Mi.caption()),
                ),
              ),
            for (final item in notifications)
              ListTile(
                leading: Icon(_notificationIcon(item['type'] as String?), color: Mi.accent),
                title: Text(
                  _notificationTitle(item),
                  style: Mi.body(
                    weight: item['read'] == true
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _notificationSubtitle(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Mi.caption(),
                ),
                trailing: item['read'] == true
                    ? null
                    : const Icon(Icons.circle, size: 9, color: Mi.accent),
                onTap: () => _openNotification(sheetContext, item),
              ),
          ],
        ),
      ),
    );
  }

  IconData _notificationIcon(String? type) => switch (type) {
        'like' => Icons.favorite_rounded,
        'friend_request' || 'friend_accepted' => Icons.person_add_alt_1_rounded,
        'message' => Icons.chat_bubble_rounded,
        _ => Icons.mode_comment_outlined,
      };

  String _notificationTitle(Map<String, dynamic> item) {
    final name = item['fromName'] as String? ?? 'Someone';
    return switch (item['type']) {
      'like' => '$name liked your post',
      'friend_request' => '$name sent you a friend request',
      'friend_accepted' => '$name accepted your friend request',
      'message' => '$name sent you a message',
      _ => '$name commented on your post',
    };
  }

  String _notificationSubtitle(Map<String, dynamic> item) {
    final text = item['text'] as String?;
    if (text?.isNotEmpty == true) return text!;
    return switch (item['type']) {
      'friend_request' => 'Tap to review the request in your profile.',
      'friend_accepted' => 'You are now friends. Tap to open your profile.',
      'message' => 'Tap to open your chats.',
      _ => 'Tap to view the post.',
    };
  }

  Future<void> _openNotification(
    BuildContext sheetContext,
    Map<String, dynamic> item,
  ) async {
    try {
      await _service.markNotificationRead(item['id'] as String);
    } catch (_) {
      // Keep navigation available even if marking as read fails temporarily.
    }
    if (!mounted || !sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    switch (item['type']) {
      case 'friend_request':
      case 'friend_accepted':
        mainTabIndex.value = 2;
        return;
      case 'message':
        ChatScreen.pendingConversation.value = {
          'chatId': item['chatId'],
          'chatName': item['chatName'] ?? item['fromName'] ?? 'Chat',
          'isGroup': item['isGroup'] == true,
          'members': item['members'] ?? const <String>[],
        };
        mainTabIndex.value = 1;
        return;
      default:
        final postId = item['postId'] as String?;
        final target = postId == null ? null : _postKeys[postId]?.currentContext;
        final targetContext = target ?? _communityKey.currentContext;
        if (targetContext != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Scrollable.ensureVisible(
              targetContext,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            );
          });
        }
    }
  }

  void _openAnimeSearch() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AnimeQuickSearchDialog(
        onSelected: (anime) {
          Navigator.of(dialogContext).pop();
          showAnimeSheet(context, anime);
        },
      ),
    );
  }

  // -------------------------------------------------------------- composer

  Widget _buildComposer() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<UserProfile>(
      stream: _composerProfile,
      initialData: user == null ? null : UserProfile.fromData(null, user),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _openNewPost,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              decoration: Mi.card(radius: 20),
              child: Row(
                children: [
                  if (profile != null) UserAvatar(profile: profile, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Mi.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'What are you watching?',
                        style: Mi.body(color: Mi.sub),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Mi.brand,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------- trending

  Widget _buildTrending() {
    return StreamBuilder<Set<String>>(
      stream: _favorites,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const MiDataError();
        final favorites = snapshot.data ?? const <String>{};
        return FutureBuilder<List<Anime>>(
          future: _trending,
          builder: (context, animeSnapshot) {
            if (animeSnapshot.hasError) return MiEmpty(icon: Icons.cloud_off_rounded, text: 'โหลดอนิเมะไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่', actionLabel: 'ลองอีกครั้ง', onAction: () => setState(() => _trending = AnimeCatalogService.instance.topAnime(refresh: true)));
            if (!animeSnapshot.hasData) return _trendingSkeleton();
            final animeList = animeSnapshot.data!;
            if (animeList.isEmpty) return const MiEmpty(icon: Icons.movie_outlined, text: 'No anime found.');
            final genres = animeList.expand((anime) => anime.genres).toSet().toList()..sort();
            final visibleAnime = _selectedTrendingGenre == null
                ? animeList
                : animeList.where((anime) => anime.genres.contains(_selectedTrendingGenre)).toList();
            return SizedBox(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (genres.isNotEmpty) ...[
                  SizedBox(
                    height: 46,
                    child: Scrollbar(
                      controller: _genreController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      thickness: 3,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: const {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView(
                          controller: _genreController,
                          padding: const EdgeInsets.only(right: 16, bottom: 7),
                          scrollDirection: Axis.horizontal,
                          children: [
                            _trendingGenreChip('All', null),
                            for (final genre in genres)
                              _trendingGenreChip(genre, genre),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (visibleAnime.isEmpty)
                  const SizedBox(height: 120, child: Center(child: Text('No anime in this genre yet.')))
                else
                  SizedBox(
                    height: 310,
                    child: ListView.separated(
                      controller: _trendingController,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: visibleAnime.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final anime = visibleAnime[index];
                        return SizedBox(
                          width: 128,
                          child: AnimeTile(anime: anime, isFavorite: favorites.contains(anime.id)),
                        );
                      },
                    ),
                  ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _trendingGenreChip(String label, String? genre) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _selectedTrendingGenre == genre,
          onSelected: (_) => setState(() => _selectedTrendingGenre = genre),
          labelStyle: Mi.body(
            size: 12,
            color: _selectedTrendingGenre == genre ? Colors.white : Mi.text,
            weight: FontWeight.w600,
          ),
          selectedColor: Mi.violet,
          backgroundColor: Mi.surface,
          side: BorderSide(color: _selectedTrendingGenre == genre ? Mi.violet : Mi.line),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  Widget _trendingSkeleton() => SizedBox(
        height: 310,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, _) => SizedBox(
            width: 128,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MiSkeletonBlock(width: 128, height: 190, radius: 14),
              const SizedBox(height: 10),
              const MiSkeletonBlock(width: 108, height: 12),
              const SizedBox(height: 7),
              const MiSkeletonBlock(width: 78, height: 10),
            ]),
          ),
        ),
      );

  // ----------------------------------------------------------------- posts

  Widget _buildPosts() {
    return StreamBuilder<List<UserPost>>(
      stream: _posts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MiDataError(
            onRetry: () => setState(() => _posts = _service.feedStream()),
          );
        }
        if (!snapshot.hasData) return const MiFeedSkeleton();

        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return MiEmpty(
            icon: Icons.edit_note_rounded,
            text: "No posts yet.\nBe the first to share something.",
            actionLabel: 'Write a post',
            onAction: _openNewPost,
          );
        }
        return Column(
          children: [
            for (final post in posts) ...[
              KeyedSubtree(
                key: _postKeys.putIfAbsent(post.id, () => GlobalKey()),
                child: _PostCard(
                  post: post,
                  onDelete: () => _deletePost(post),
                  onEdit: () => showEditPostSheet(context, post),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Future<void> _deletePost(UserPost post) async {
    try {
      await _service.deletePost(post);
    } catch (_) {
      if (mounted) miSnack(context, "Couldn't delete the post.");
    }
  }

  void _openNewPost() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Mi.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _NewPostSheet(),
    );
  }
}

class _AnimeQuickSearchDialog extends StatefulWidget {
  const _AnimeQuickSearchDialog({required this.onSelected});
  final ValueChanged<Anime> onSelected;
  @override
  State<_AnimeQuickSearchDialog> createState() => _AnimeQuickSearchDialogState();
}

class _AnimeQuickSearchDialogState extends State<_AnimeQuickSearchDialog> {
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  Future<List<Anime>>? _results = AnimeCatalogService.instance.topAnime();

  void _search(String term) {
    _debounce?.cancel();
    if (term.trim().isEmpty) {
      setState(() => _results = AnimeCatalogService.instance.topAnime());
      return;
    }
    setState(() => _results = null);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _results = AnimeCatalogService.instance.searchAnime(term));
    });
  }

  @override
  void dispose() { _debounce?.cancel(); _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Mi.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              TextField(
                autofocus: true,
                controller: _searchController,
                onChanged: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search anime title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Expanded(child: _results == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<Anime>>(
                    future: _results,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return MiEmpty(
                          icon: Icons.cloud_off_rounded,
                          text: 'ค้นหาอนิเมะไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
                          actionLabel: 'ลองอีกครั้ง',
                          onAction: () => setState(() => _results = _searchController.text.trim().isEmpty
                              ? AnimeCatalogService.instance.topAnime(refresh: true)
                              : AnimeCatalogService.instance.searchAnime(_searchController.text, refresh: true)),
                        );
                      }
                      if (!snapshot.hasData) return const MiLoading();
                      if (snapshot.data!.isEmpty) return Center(child: Text('No anime found.', style: Mi.caption()));
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final anime = snapshot.data![index];
                          return ListTile(
                            leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(anime.imageUrl, width: 40, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 40, height: 56))),
                            title: Text(anime.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Mi.body(weight: FontWeight.w700)),
                            subtitle: Text('★ ${anime.score?.toStringAsFixed(1) ?? '—'} · ${anime.episodes ?? 'TBA'} episodes', style: Mi.caption()),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => widget.onSelected(anime),
                          );
                        },
                      );
                    },
                  )),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Post card
// ---------------------------------------------------------------------------

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onDelete, required this.onEdit});

  final UserPost post;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final anime = animeById(post.animeId) ?? (post.animeId != null && post.animeImageUrl != null
        ? Anime(
            id: post.animeId!,
            title: post.animeTitle ?? 'Anime',
            genres: const [],
            imageUrl: post.animeImageUrl!,
          )
        : null);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: Mi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(AppMotion.route(builder: (_) => PublicProfileScreen(uid: post.uid))),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Mi.brand),
                    child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Mi.surface, shape: BoxShape.circle), child: UserAvatar(profile: post.author, size: 40)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: () => Navigator.of(context).push(AppMotion.route(builder: (_) => PublicProfileScreen(uid: post.uid))), child: Text(post.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.body(weight: FontWeight.w700)))),
                Row(children: [Text(timeAgo(post.createdAt), style: Mi.caption()), const SizedBox(width: 4), Icon(Icons.public_rounded, size: 12, color: Mi.sub)]),
              ])),
              if (post.isMine)
                PopupMenuButton<String>(
                  tooltip: 'Post options',
                  icon: Icon(Icons.more_horiz_rounded, size: 20, color: Mi.sub),
                  padding: EdgeInsets.zero,
                  color: Mi.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (value) { if (value == 'delete') onDelete(); if (value == 'edit') onEdit(); },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit post', style: Mi.body())),
                    PopupMenuItem(value: 'delete', child: Text('Delete post', style: Mi.body(color: Mi.danger))),
                  ],
                ),
            ]),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (post.caption.isNotEmpty) Text(post.caption, style: Mi.body(size: 14)),
              ]),
            ),
          if (post.imageBase64 != null)
            _PostImage(base64: post.imageBase64!)
          else if (anime != null)
            _TaggedAnimeMedia(anime: anime)
          else if (post.animeId != null)
            _LegacyTaggedAnimeMedia(animeId: post.animeId!)
          else if (post.caption.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Post content unavailable',
                style: Mi.body(color: Mi.sub),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: _PostEngagementSummary(post: post),
          ),
          Divider(height: 1, indent: 14, endIndent: 14, color: Mi.line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: _PostActions(post: post, onComment: () => _openComments(context)),
          ),
        ],
      ),
    );
  }

  void _openComments(BuildContext context) {
    final controller = TextEditingController();
    final service = UserDataService.instance;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Mi.surface,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .65,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: Text('Comments', style: Mi.title(size: 20))),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: service.commentsStream(post.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const MiDataError();
                  if (!snapshot.hasData) return const MiLoading();
                  final comments = snapshot.data!;
                  if (comments.isEmpty) return Center(child: Text('Be the first to comment.', style: Mi.caption()));
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final profile = UserProfile(
                        displayName: (comment['name'] as String?) ?? 'Anime Fan',
                        email: '',
                        bio: '',
                        avatar: comment['avatar'] as String?,
                        photoUrl: comment['photoUrl'] as String?,
                        photoBase64: comment['photoBase64'] as String?,
                        recentSearches: const [],
                      );
                      final createdAt = comment['createdAt'];
                      final postedTime = createdAt is DateTime ? timeAgo(createdAt) : 'Just now';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: Mi.card(radius: 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: () { final uid = comment['uid'] as String?; if (uid != null && uid.isNotEmpty) Navigator.of(context).push(AppMotion.route(builder: (_) => PublicProfileScreen(uid: uid))); }, child: UserAvatar(profile: profile, size: 38))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () {
                                        final uid = comment['uid'] as String?;
                                        if (uid != null && uid.isNotEmpty) {
                                          Navigator.of(context).push(
                                            AppMotion.route(
                                              builder: (_) => PublicProfileScreen(uid: uid),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        profile.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Mi.body(weight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(postedTime, style: Mi.caption()),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text((comment['text'] as String?) ?? '', style: Mi.body()),
                          ])),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: TextField(controller: controller, maxLength: 280, decoration: const InputDecoration(hintText: 'Write a comment', counterText: '', border: OutlineInputBorder()))),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Mi.accent),
                  onPressed: () async {
                    final text = controller.text;
                    try {
                      await service.addComment(post, text);
                      controller.clear();
                    } catch (_) {
                      if (sheetContext.mounted) miSnack(sheetContext, 'Could not post comment.');
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}

class _PostEngagementSummary extends StatelessWidget {
  const _PostEngagementSummary({required this.post});
  final UserPost post;

  @override
  Widget build(BuildContext context) {
    final service = UserDataService.instance;
    return Row(children: [
      StreamBuilder<int>(
        stream: service.postLikeCountStream(post.id),
        builder: (context, snapshot) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Mi.brand), child: const Icon(Icons.favorite_rounded, size: 12, color: Colors.white)),
          const SizedBox(width: 6),
          Text('${snapshot.data ?? 0}', style: Mi.caption()),
        ]),
      ),
      const Spacer(),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.commentsStream(post.id),
        builder: (context, snapshot) => Text('${snapshot.data?.length ?? 0} comments', style: Mi.caption()),
      ),
    ]);
  }
}

class _PostActions extends StatelessWidget {
  const _PostActions({required this.post, required this.onComment});
  final UserPost post;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final service = UserDataService.instance;
    return Row(children: [
      Expanded(
        child: StreamBuilder<bool>(
          stream: service.postLikedStream(post.id),
          builder: (context, likedSnapshot) {
            final liked = likedSnapshot.data ?? false;
            return MouseRegion(
              cursor: likedSnapshot.hasData
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: TextButton.icon(
                onPressed: likedSnapshot.hasData ? () async {
                  try {
                    await service.setPostLiked(post.id, !liked);
                  } catch (_) {
                    if (context.mounted) miSnack(context, 'Could not update like.');
                  }
                } : null,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(liked),
                    color: liked ? Mi.accent : Mi.sub,
                    size: 18,
                  ),
                ),
                label: const Text('Like'),
              ),
            );
          },
        ),
      ),
      Expanded(
        child: TextButton.icon(
          onPressed: onComment,
          icon: const Icon(Icons.mode_comment_outlined, size: 17),
          label: const Text('Comment'),
        ),
      ),
      Expanded(
        child: StreamBuilder<bool>(
          stream: service.postSavedStream(post.id),
          builder: (context, savedSnapshot) {
            final saved = savedSnapshot.data ?? false;
            final canSave = !post.isMine && savedSnapshot.hasData;
            return MouseRegion(
              cursor: canSave ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: TextButton.icon(
              onPressed: !canSave
                  ? null
                  : () async {
                      try {
                        await service.setPostSaved(post.id, !saved);
                      } catch (_) {
                        if (context.mounted) {
                          miSnack(context, 'Could not update saved posts.');
                        }
                      }
                    },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  key: ValueKey(saved),
                  size: 18,
                  color: saved ? Mi.accent : Mi.sub,
                ),
              ),
              label: Text(saved ? 'Saved' : 'Save'),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});
  final UserPost post;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Mi.bg,
        appBar: AppBar(title: const Text('Community post'), backgroundColor: Mi.bg),
        body: MiBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _PostCard(
                post: post,
                onEdit: () => showEditPostSheet(context, post),
                onDelete: () async {
                  final deleted = await confirmDeletePost(context, post);
                  if (deleted && context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
}

Future<void> showEditPostSheet(BuildContext context, UserPost post) {
  if (!post.isMine) {
    miSnack(context, 'Only the post owner can edit this post.');
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Mi.surface,
    showDragHandle: true,
    builder: (_) => _EditPostSheet(post: post),
  );
}

Future<bool> confirmDeletePost(BuildContext context, UserPost post) async {
  if (!post.isMine) {
    miSnack(context, 'Only the post owner can delete this post.');
    return false;
  }
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete post?'),
      content: const Text('This post will be removed from the community.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirm != true) return false;
  try {
    await UserDataService.instance.deletePost(post);
    if (context.mounted) miSnack(context, 'Post deleted.');
    return true;
  } catch (_) {
    if (context.mounted) miSnack(context, 'Could not delete post.');
    return false;
  }
}

class _EditPostSheet extends StatefulWidget {
  const _EditPostSheet({required this.post});
  final UserPost post;
  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final _caption = TextEditingController(text: widget.post.caption);
  late String? _animeId = widget.post.animeId;
  bool _saving = false;

  @override
  void dispose() { _caption.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserDataService.instance.updatePost(widget.post, caption: _caption.text, animeId: _animeId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) { setState(() => _saving = false); miSnack(context, 'Could not edit post.'); }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Edit post', style: Mi.title(size: 20)),
          const SizedBox(height: 14),
          TextField(controller: _caption, maxLength: 280, maxLines: 5, minLines: 3, decoration: const InputDecoration(labelText: 'Caption', border: OutlineInputBorder())),
          Row(children: [
            Expanded(child: Text(_animeId == null ? 'No anime tagged' : 'Tagged: ${animeById(_animeId)?.title ?? _animeId}', style: Mi.caption())),
            TextButton.icon(onPressed: () => showDialog<void>(context: context, builder: (dialogContext) => _AnimeQuickSearchDialog(onSelected: (anime) { setState(() => _animeId = anime.id); Navigator.of(dialogContext).pop(); })), icon: const Icon(Icons.search_rounded, size: 16), label: const Text('Change tag')),
            if (_animeId != null) IconButton(tooltip: 'Remove anime tag', onPressed: () => setState(() => _animeId = null), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save changes')),
        ]),
      );
}

/// Decodes the base64 photo once (not on every rebuild of the feed).
class _TaggedAnimeMedia extends StatelessWidget {
  const _TaggedAnimeMedia({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Mi.tint, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome_rounded, size: 14, color: Mi.violet),
                const SizedBox(width: 5),
                Flexible(child: Text(anime.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.body(size: 12, color: Mi.violet, weight: FontWeight.w700))),
              ]),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 300,
            child: Image.network(
              anime.imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => const _MissingPostMedia(),
            ),
          ),
        ],
      );
}

class _LegacyTaggedAnimeMedia extends StatelessWidget {
  const _LegacyTaggedAnimeMedia({required this.animeId});
  final String animeId;

  @override
  Widget build(BuildContext context) => FutureBuilder<Anime?>(
        future: AnimeCatalogService.instance.animeById(animeId),
        builder: (context, snapshot) {
          if (snapshot.hasError || (snapshot.hasData && snapshot.data == null)) {
            return const _MissingPostMedia();
          }
          if (!snapshot.hasData) {
            return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          return _TaggedAnimeMedia(anime: snapshot.data!);
        },
      );
}

class _MissingPostMedia extends StatelessWidget {
  const _MissingPostMedia();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 180,
        child: ColoredBox(
          color: Mi.line,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 34,
              color: Mi.sub,
            ),
          ),
        ),
      );
}

class _PostImage extends StatefulWidget {
  const _PostImage({required this.base64});

  final String base64;

  @override
  State<_PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<_PostImage> {
  late Uint8List? _bytes = _decode(widget.base64);

  static Uint8List? _decode(String data) {
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant _PostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64 != widget.base64) _bytes = _decode(widget.base64);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: Mi.line,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: Mi.sub),
        ),
      );
    }
    // Scale to the feed width and keep the source aspect ratio so the full
    // uploaded photo stays visible, including portrait and panoramic images.
    return SizedBox(
      width: double.infinity,
      child: ColoredBox(
        color: Mi.bg,
        child: Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New post sheet
// ---------------------------------------------------------------------------

class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet();

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final TextEditingController _caption = TextEditingController();
  final TextEditingController _animeSearch = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _animeId;
  XFile? _image;
  bool _saving = false;
  late Future<List<Anime>> _animeOptions = AnimeCatalogService.instance.topAnime();
  Timer? _animeSearchDebounce;

  bool get _canPost =>
      !_saving &&
      (_caption.text.trim().isNotEmpty || _animeId != null || _image != null);

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        imageQuality: 60,
      );
      if (picked != null && mounted) setState(() => _image = picked);
    } catch (_) {
      if (mounted) miSnack(context, "Couldn't open the photo picker.");
    }
  }

  void _chooseImageSource() {
    // The camera is only offered on phones; web/desktop use the file picker.
    if (kIsWeb) {
      _pickImage(ImageSource.gallery);
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
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('Take a photo', style: Mi.body()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _caption.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _caption.dispose();
    _animeSearch.dispose();
    _animeSearchDebounce?.cancel();
    super.dispose();
  }

  void _searchAnime(String value) {
    _animeSearchDebounce?.cancel();
    _animeSearchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _animeOptions = value.trim().isEmpty
            ? AnimeCatalogService.instance.topAnime()
            : AnimeCatalogService.instance.searchAnime(value, refresh: true);
      });
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await UserDataService.instance.addPost(
        caption: _caption.text,
        animeId: _animeId,
        image: _image,
      );
      if (mounted) Navigator.of(context).pop();
    } on FormatException {
      if (mounted) {
        setState(() {
          _saving = false;
          _image = null;
        });
        miSnack(context, 'That photo is too large. Please pick a smaller one.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        miSnack(context, "Couldn't post. Please try again.");
      }
    }
  }

  Widget _buildPhotoPicker() {
    final image = _image;
    if (image == null) {
      return OutlinedButton.icon(
        onPressed: _saving ? null : _chooseImageSource,
        style: OutlinedButton.styleFrom(
          foregroundColor: Mi.text,
          side: BorderSide(color: Mi.line),
          backgroundColor: Mi.bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
        label: Text(
          'Add a photo',
          style: Mi.body(weight: FontWeight.w700),
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            // XFile.path is a blob URL on web and a file path elsewhere.
            child: FutureBuilder<Uint8List>(
              future: image.readAsBytes(),
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                  : Container(color: Mi.line),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: MouseRegion(
            cursor: _saving ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: GestureDetector(
            onTap: _saving ? null : () => setState(() => _image = null),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Opacity(
        opacity: ((scale - 0.94) / 0.06).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, (1 - scale) * 14),
            child: child,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New post', style: Mi.title(size: 20)),
            const SizedBox(height: 16),
            Text('Photo (optional)', style: Mi.caption()),
            const SizedBox(height: 8),
            _buildPhotoPicker(),
            const SizedBox(height: 16),
            Text('Tag an anime (optional)', style: Mi.caption()),
            const SizedBox(height: 8),
            TextField(
              controller: _animeSearch,
              onChanged: _searchAnime,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search anime by title',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 118,
              child: FutureBuilder<List<Anime>>(
                future: _animeOptions,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: TextButton.icon(onPressed: () => setState(() => _animeOptions = AnimeCatalogService.instance.topAnime(refresh: true)), icon: const Icon(Icons.refresh), label: const Text('Retry anime list')));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  final animeList = snapshot.data!;
                  return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: animeList.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final anime = animeList[index];
                  final selected = anime.id == _animeId;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                    onTap: () => setState(
                      () => _animeId = selected ? null : anime.id,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 82,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? Mi.accent : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Column(children: [
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              anime.imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(color: Mi.line),
                            ),
                          )),
                          const SizedBox(height: 3),
                          Text(anime.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Mi.caption().copyWith(fontSize: 9)),
                        ]),
                      ),
                    ),
                    ),
                  );
                },
              );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caption,
              minLines: 3,
              maxLines: 5,
              maxLength: 280,
              style: Mi.body(),
              cursorColor: Mi.accent,
              decoration: InputDecoration(
                hintText: "What's on your mind about anime today?",
                hintStyle: Mi.body(color: Mi.sub),
                filled: true,
                fillColor: Mi.bg,
                counterStyle: Mi.caption(),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Mi.accent, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            MouseRegion(
              cursor: _canPost ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: FilledButton(
                onPressed: _canPost ? _submit : null,
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
                        'Post',
                        style: Mi.body(
                          size: 15,
                          color: _canPost ? Colors.white : Mi.sub,
                          weight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

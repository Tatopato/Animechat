import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/anime_catalog.dart';
import '../services/user_data_service.dart';
import '../services/anime_catalog_service.dart';
import '../services/theme_controller.dart';

/// Clean, light, minimal look shared by Home / Search / Profile:
/// off-white background, white cards with hairline borders, one accent color.

class Mi {
  Mi._();

  static bool get isDark => ThemeController.isDarkMode.value;
  static Color get bg => isDark ? const Color(0xFF11111A) : const Color(0xFFF6F3FF);
  static Color get surface => isDark ? const Color(0xFF1D1C29) : Colors.white;
  static Color get tint => isDark ? const Color(0xFF302B46) : const Color(0xFFEFE9FF);
  static Color get line => isDark ? const Color(0xFF373448) : const Color(0xFFE8E2F6);
  static Color get text => isDark ? const Color(0xFFF4F0FC) : const Color(0xFF1F1B2E);
  static Color get sub => isDark ? const Color(0xFFB2ADC7) : const Color(0xFF8782A3);
  static const Color accent = Color(0xFFFF4D94);
  static const Color danger = Color(0xFFE5484D);
  static const Color violet = Color(0xFF7C5CFF);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5C9D), Color(0xFF7C5CFF)],
  );

  static TextStyle title({double size = 26}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: text,
        height: 1.2,
      );

  static TextStyle section() => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: text,
      );

  static TextStyle body({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: 1.4,
      );

  static TextStyle caption() => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: sub,
      );

  static BoxDecoration card({double radius = 18}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x147C5CFF),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      );
}

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}

void miSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Mi.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: Mi.body(color: Colors.white)),
      ),
    );
}

// ---------------------------------------------------------------------------
// Page backdrop
// ---------------------------------------------------------------------------

/// Soft pink-to-lavender wash at the top of a page, fading into the canvas.
class MiBackdrop extends StatelessWidget {
  const MiBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Mi.isDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 320,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0xFF242033), Color(0xFF191824), Color(0xFF11111A)]
                    : const [Color(0xFFFFDCEB), Color(0xFFEDE5FF), Color(0xFFF6F3FF)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header / empty / error
// ---------------------------------------------------------------------------

class MiSectionHeader extends StatelessWidget {
  const MiSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF5C9D), Color(0xFF7C5CFF)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: Mi.section())),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: Mi.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: Mi.body(size: 13, color: Mi.accent, weight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class MiEmpty extends StatelessWidget {
  const MiEmpty({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: Mi.card(),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Mi.sub),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Mi.body(color: Mi.sub),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Mi.accent,
                side: BorderSide(color: Mi.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                actionLabel!,
                style: Mi.body(color: Mi.accent, weight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MiLoading extends StatelessWidget {
  const MiLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: Mi.accent),
        ),
      ),
    );
  }
}

/// Lightweight placeholder used while remote cards are being fetched.
class MiSkeletonBlock extends StatelessWidget {
  const MiSkeletonBlock({super.key, this.width, required this.height, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Mi.line,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class MiFeedSkeleton extends StatelessWidget {
  const MiFeedSkeleton({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var index = 0; index < count; index++) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: Mi.card(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const MiSkeletonBlock(width: 42, height: 42, radius: 24),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MiSkeletonBlock(width: 110, height: 12),
                    SizedBox(height: 7),
                    MiSkeletonBlock(width: 58, height: 9),
                  ]),
                ]),
                const SizedBox(height: 16),
                const MiSkeletonBlock(width: double.infinity, height: 12),
                const SizedBox(height: 12),
                const MiSkeletonBlock(width: double.infinity, height: 170, radius: 12),
                const SizedBox(height: 14),
                const MiSkeletonBlock(width: double.infinity, height: 1, radius: 1),
                const SizedBox(height: 12),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  MiSkeletonBlock(width: 64, height: 11),
                  MiSkeletonBlock(width: 74, height: 11),
                  MiSkeletonBlock(width: 54, height: 11),
                ]),
              ]),
            ),
            if (index < count - 1) const SizedBox(height: 14),
          ],
        ],
      );
}

/// Shown when a Firestore stream fails (usually: Firestore not enabled yet,
/// or the security rules haven't been deployed).
class MiDataError extends StatelessWidget {
  const MiDataError({super.key, this.onRetry, this.text});

  final VoidCallback? onRetry;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return MiEmpty(
      icon: Icons.cloud_off_rounded,
      text: text ?? 'โหลดข้อมูลไม่สำเร็จ\nตรวจสอบอินเทอร์เน็ตแล้วลองอีกครั้ง',
      actionLabel: onRetry == null ? null : 'ลองอีกครั้ง',
      onAction: onRetry,
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

Uint8List? _decodePhoto(String? data) {
  if (data == null || data.isEmpty) return null;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.size = 44});

  final UserProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayName.isEmpty
        ? '?'
        : profile.displayName.characters.first.toUpperCase();

    final fallback = Container(
      color: Mi.accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: Mi.accent,
        ),
      ),
    );

    Widget image = fallback;
    final custom = _decodePhoto(profile.photoBase64);
    if (custom != null) {
      image = Image.memory(
        custom,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (profile.avatar != null) {
      image = Image.asset(
        profile.avatar!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (profile.photoUrl != null) {
      image = Image.network(
        profile.photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: image),
    );
  }
}

// ---------------------------------------------------------------------------
// Anime poster tile + detail sheet
// ---------------------------------------------------------------------------

Future<void> toggleFavorite(
  BuildContext context,
  Anime anime,
  bool currentlyFavorite,
) async {
  try {
    await UserDataService.instance.setFavorite(anime.id, !currentlyFavorite);
  } catch (_) {
    if (context.mounted) {
      miSnack(context, "Couldn't update favorites. Please try again.");
    }
  }
}

class AnimeTile extends StatelessWidget {
  const AnimeTile({super.key, required this.anime, required this.isFavorite});

  final Anime anime;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showAnimeSheet(context, anime),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x337C5CFF),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      anime.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: Mi.line),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => toggleFavorite(context, anime, isFavorite),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: isFavorite ? Mi.accent : Mi.sub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            anime.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Mi.body(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            anime.genreLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Mi.caption().copyWith(color: Mi.violet),
          ),
          const SizedBox(height: 3),
          Text(
            '${anime.score == null ? '—' : '★ ${anime.score!.toStringAsFixed(1)}'}  ·  ${anime.episodes == null ? 'Episodes TBA' : '${anime.episodes} eps'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Mi.caption().copyWith(fontSize: 11),
          ),
          Text(anime.seasonLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.caption().copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

Future<void> showAnimeSheet(BuildContext context, Anime anime) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: anime)),
  );
}

class AnimeDetailsScreen extends StatefulWidget {
  const AnimeDetailsScreen({super.key, required this.anime});

  final Anime anime;

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  late Future<AnimeDetails> _details =
      AnimeCatalogService.instance.animeDetails(widget.anime.id);

  void _retryDetails() => setState(() {
        _details = AnimeCatalogService.instance.animeDetails(widget.anime.id, refresh: true);
      });

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) miSnack(context, 'เปิดลิงก์ไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    return Scaffold(
      backgroundColor: Mi.bg,
      body: MiBackdrop(
        child: CustomScrollView(slivers: [
          SliverAppBar(expandedHeight: 300, pinned: true, backgroundColor: Mi.bg, flexibleSpace: FlexibleSpaceBar(background: Image.network(anime.imageUrl, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, _, _) => ColoredBox(color: Mi.line)), title: Text(anime.title, maxLines: 1, overflow: TextOverflow.ellipsis), titlePadding: const EdgeInsetsDirectional.only(start: 60, bottom: 16))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<AnimeDetails>(
                future: _details,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return MiEmpty(
                      icon: Icons.cloud_off_rounded,
                      text: 'โหลดข้อมูลอนิเมะไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
                      actionLabel: 'ลองอีกครั้ง',
                      onAction: _retryDetails,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Column(children: [
                        MiSkeletonBlock(width: double.infinity, height: 18),
                        SizedBox(height: 12),
                        MiSkeletonBlock(width: double.infinity, height: 88),
                        SizedBox(height: 22),
                        MiSkeletonBlock(width: 120, height: 16),
                        SizedBox(height: 12),
                        MiSkeletonBlock(width: double.infinity, height: 110),
                      ]),
                    );
                  }
                  final details = snapshot.data!;
                  final synopsis = _plainText(details.synopsis);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('ช่องทางรับชม'),
                      if (details.streamingLinks.isEmpty)
                        Text('ไม่มีข้อมูลช่องทางรับชมอย่างเป็นทางการ', style: Mi.caption())
                      else
                        for (final link in details.streamingLinks)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.play_circle_outline, color: Mi.accent),
                            title: Text(link.site, style: Mi.body(weight: FontWeight.w600)),
                            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                            onTap: () => _open(link.url),
                          ),
                      Text('ช่องทางอาจแตกต่างกันตามประเทศ · ข้อมูลจาก AniList', style: Mi.caption()),
                      const SizedBox(height: 24),
                      _sectionTitle('เรื่องย่อ'),
                      const SizedBox(height: 8),
                      Text(synopsis.isEmpty ? 'ไม่มีข้อมูลเรื่องย่อ' : synopsis, style: Mi.body()),
                      const SizedBox(height: 24),
                      _sectionTitle('ตัวละคร'),
                      const SizedBox(height: 10),
                      if (details.characters.isEmpty)
                        Text('ไม่มีข้อมูลตัวละคร', style: Mi.caption())
                      else
                        SizedBox(
                          height: 156,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: details.characters.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final character = details.characters[index];
                              final native = character.nativeName;
                              final displayName = native != null && _containsThai(native)
                                  ? native
                                  : character.name;
                              return SizedBox(
                                width: 92,
                                child: Column(children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: character.imageUrl == null
                                        ? Container(width: 88, height: 112, color: Mi.line)
                                        : Image.network(character.imageUrl!, width: 88, height: 112, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 88, height: 112, color: Mi.line)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Mi.caption()),
                                ]),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      _sectionTitle('ตัวอย่าง'),
                      const SizedBox(height: 8),
                      if (details.trailerUrl == null)
                        Text('ไม่มีข้อมูลตัวอย่าง', style: Mi.caption())
                      else
                        OutlinedButton.icon(
                          onPressed: () => _open(details.trailerUrl!),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: Text('ดูตัวอย่างบน ${details.trailerSite ?? 'YouTube'}'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _plainText(String text) => text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  bool _containsThai(String text) => RegExp(r'[\u0E00-\u0E7F]').hasMatch(text);

  Widget _sectionTitle(String title) => Text(title, style: Mi.section());
}

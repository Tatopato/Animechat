/// Shared (read-only) anime list. Everything a user *does* with it
/// (favorites, posts, recent searches) is stored per account in Firestore.
class Anime {
  const Anime({
    required this.id,
    required this.title,
    required this.genres,
    required this.imageUrl,
    this.score,
    this.season,
    this.seasonYear,
    this.episodes,
  });

  factory Anime.fromAniList(Map<String, dynamic> data) {
    final titles = data['title'] as Map<String, dynamic>? ?? const {};
    final covers = data['coverImage'] as Map<String, dynamic>? ?? const {};
    final rawScore = data['averageScore'];
    final english = (titles['english'] as String?)?.trim();
    final titleOptions = [titles['english'], titles['romaji'], titles['native']]
        .whereType<String>()
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty);
    String? thaiTitle;
    for (final title in titleOptions) {
      if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(title)) {
        thaiTitle = title;
        break;
      }
    }
    return Anime(
      id: '${data['id']}',
      title: thaiTitle ?? (english?.isNotEmpty == true
          ? english!
          : (titles['romaji'] as String?) ?? (titles['native'] as String?) ?? ''),
      genres: List<String>.from(data['genres'] as List? ?? const []),
      imageUrl: (covers['extraLarge'] as String?) ?? (covers['large'] as String?) ?? '',
      score: rawScore is num && rawScore > 0 ? rawScore / 10 : null,
      season: data['season'] as String?,
      seasonYear: data['seasonYear'] as int?,
      episodes: data['episodes'] as int?,
    );
  }

  final String id;
  final String title;
  final List<String> genres;
  final String imageUrl;
  final double? score;
  final String? season;
  final int? seasonYear;
  final int? episodes;

  String get genreLabel => genres.join(' · ');
  String get seasonLabel => season == null
      ? (seasonYear?.toString() ?? 'Season unknown')
      : '${season![0]}${season!.substring(1).toLowerCase()} ${seasonYear ?? ''}'.trim();
}

class AnimeCharacter {
  const AnimeCharacter({required this.name, this.nativeName, this.imageUrl});
  final String name;
  final String? nativeName;
  final String? imageUrl;
}

class AnimeLink {
  const AnimeLink({required this.site, required this.url});
  final String site;
  final String url;
}

class AnimeDetails {
  const AnimeDetails({
    required this.synopsis,
    required this.characters,
    required this.streamingLinks,
    this.trailerUrl,
    this.trailerSite,
  });

  final String synopsis;
  final List<AnimeCharacter> characters;
  final List<AnimeLink> streamingLinks;
  final String? trailerUrl;
  final String? trailerSite;
}

/// Populated only from the remote anime API; no bundled mock catalog.
List<Anime> animeCatalog = <Anime>[];

Anime? animeById(String? id) {
  if (id == null) return null;
  for (final a in animeCatalog) {
    if (a.id == id) return a;
  }
  return null;
}

/// All distinct genres, sorted, for the filter chips.
List<String> get allGenres {
  final set = <String>{};
  for (final a in animeCatalog) {
    set.addAll(a.genres);
  }
  return set.toList()..sort();
}

/// Images that can be picked as a profile picture.
const List<String> avatarChoices = [
  'assets/images/profile1.jpg',
  'assets/images/profile3.jpg',
];

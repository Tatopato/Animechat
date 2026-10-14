import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/anime_catalog.dart';

/// Reads current anime metadata from AniList's public GraphQL API.
/// Catalog responses are cached only in memory for this app session.
class AnimeCatalogService {
  AnimeCatalogService._();
  static final AnimeCatalogService instance = AnimeCatalogService._();

  static const _endpoint = 'https://graphql.anilist.co';
  static const _queryFields = '''
    id
    title { english romaji native }
    coverImage { extraLarge large }
    averageScore
    episodes
    season
    seasonYear
    genres
  ''';

  Future<List<Anime>>? _topRequest;
  final Map<String, Future<List<Anime>>> _searchRequests = {};
  final Map<String, Future<AnimeDetails>> _detailsRequests = {};
  final Map<String, Future<Anime?>> _animeRequests = {};
  final Map<String, Future<List<Anime>>> _favoriteAnimeRequests = {};

  /// Loads the exact saved anime ids for a user's Favorites list in batches.
  Future<List<Anime>> animeByIds(
    Iterable<String> ids, {
    bool refresh = false,
  }) {
    final normalizedIds = ids.toSet().toList()..sort();
    if (normalizedIds.isEmpty) return Future.value(const <Anime>[]);
    final key = normalizedIds.join(',');
    if (refresh) _favoriteAnimeRequests.remove(key);
    final existing = _favoriteAnimeRequests[key];
    if (existing != null) return existing;

    final request = () async {
      final found = <String, Anime>{
        for (final anime in animeCatalog)
          if (normalizedIds.contains(anime.id)) anime.id: anime,
      };
      final numericIds = normalizedIds
          .where((id) => !found.containsKey(id))
          .map(int.tryParse)
          .whereType<int>()
          .toList(growable: false);
      for (var start = 0; start < numericIds.length; start += 50) {
        final batch = numericIds.skip(start).take(50).toList();
        final results = await _request('''
          query {
            Page(page: 1, perPage: ${batch.length}) {
              media(type: ANIME, id_in: [${batch.join(',')}], isAdult: false) {
                $_queryFields
              }
            }
          }
        ''');
        for (final anime in results) {
          found[anime.id] = anime;
        }
      }
      return normalizedIds
          .map((id) => found[id])
          .whereType<Anime>()
          .toList(growable: false);
    }();

    _favoriteAnimeRequests[key] = request;
    request.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_favoriteAnimeRequests[key], request)) {
          _favoriteAnimeRequests.remove(key);
        }
      },
    );
    return request;
  }

  /// Resolves tagged anime for older posts that predate saved poster metadata.
  Future<Anime?> animeById(String id) {
    for (final anime in animeCatalog) {
      if (anime.id == id) return Future.value(anime);
    }
    return _animeRequests.putIfAbsent(id, () async {
      final numericId = int.tryParse(id);
      if (numericId == null) return null;
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: const {'content-type': 'application/json', 'accept': 'application/json'},
        body: jsonEncode({
          'query': 'query (\$id: Int!) { Media(id: \$id, type: ANIME) { $_queryFields } }',
          'variables': {'id': numericId},
        }),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw AnimeApiException('AniList returned ${response.statusCode}.');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['errors'] != null) {
        throw const AnimeApiException('Could not load tagged anime.');
      }
      final data = (body['data'] as Map<String, dynamic>?)?['Media']
          as Map<String, dynamic>?;
      if (data == null) return null;
      final anime = Anime.fromAniList(data);
      final oldIndex = animeCatalog.indexWhere((item) => item.id == anime.id);
      if (oldIndex == -1) {
        animeCatalog.add(anime);
      } else {
        animeCatalog[oldIndex] = anime;
      }
      return anime;
    });
  }

  Future<AnimeDetails> animeDetails(String animeId, {bool refresh = false}) {
    if (refresh) _detailsRequests.remove(animeId);
    return _detailsRequests.putIfAbsent(animeId, () async {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: const {'content-type': 'application/json', 'accept': 'application/json'},
        body: jsonEncode({
          'query': '''
            query (\$id: Int!) {
              Media(id: \$id, type: ANIME) {
                description(asHtml: false)
                trailer { id site }
                characters(page: 1, perPage: 12, sort: ROLE) {
                  nodes { name { full native } image { large } }
                }
                streamingEpisodes { title url site }
                externalLinks { site url type }
              }
            }
          ''',
          'variables': {'id': int.parse(animeId)},
        }),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw AnimeApiException('AniList returned ${response.statusCode}.');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['errors'] != null) {
        throw const AnimeApiException('Could not load anime details.');
      }
      final media = (body['data'] as Map<String, dynamic>?)?['Media']
          as Map<String, dynamic>? ?? const {};
      final trailer = media['trailer'] as Map<String, dynamic>?;
      final trailerId = trailer?['id'] as String?;
      final trailerSite = trailer?['site'] as String?;
      final trailerUrl = trailerId == null || trailerSite == null
          ? null
          : trailerSite.toLowerCase() == 'youtube'
              ? 'https://www.youtube.com/watch?v=$trailerId'
              : trailerSite.toLowerCase() == 'dailymotion'
                  ? 'https://www.dailymotion.com/video/$trailerId'
                  : null;
      final rawCharacters = (media['characters'] as Map<String, dynamic>?)?['nodes']
          as List<dynamic>? ?? const [];
      final characters = rawCharacters.whereType<Map<String, dynamic>>().map((node) {
        final name = node['name'] as Map<String, dynamic>? ?? const {};
        final image = node['image'] as Map<String, dynamic>? ?? const {};
        return AnimeCharacter(
          name: (name['full'] as String?) ?? 'Unknown',
          nativeName: name['native'] as String?,
          imageUrl: image['large'] as String?,
        );
      }).toList(growable: false);
      final streaming = <AnimeLink>[];
      final episodes = media['streamingEpisodes'] as List<dynamic>? ?? const [];
      for (final item in episodes.whereType<Map<String, dynamic>>()) {
        final url = item['url'] as String?;
        if (url != null) streaming.add(AnimeLink(site: (item['site'] as String?) ?? 'Official stream', url: url));
      }
      final links = media['externalLinks'] as List<dynamic>? ?? const [];
      for (final item in links.whereType<Map<String, dynamic>>()) {
        if (item['type'] != 'STREAMING') continue;
        final url = item['url'] as String?;
        if (url != null && !streaming.any((link) => link.url == url)) {
          streaming.add(AnimeLink(site: (item['site'] as String?) ?? 'Streaming service', url: url));
        }
      }
      return AnimeDetails(
        synopsis: (media['description'] as String?) ?? '',
        characters: characters,
        streamingLinks: streaming,
        trailerUrl: trailerUrl,
        trailerSite: trailerSite,
      );
    });
  }

  Future<List<Anime>> topAnime({bool refresh = false}) {
    if (refresh || _topRequest == null) {
      _topRequest = _request('''
        query {
          Page(page: 1, perPage: 30) {
            media(type: ANIME, sort: TRENDING_DESC, isAdult: false) {
              $_queryFields
            }
          }
        }
      ''');
    }
    return _topRequest!;
  }

  Future<List<Anime>> searchAnime(String term, {bool refresh = false}) {
    final key = term.trim().toLowerCase();
    if (key.isEmpty) return topAnime(refresh: refresh);
    if (refresh || !_searchRequests.containsKey(key)) {
      _searchRequests[key] = _request('''
        query {
          Page(page: 1, perPage: 30) {
            media(type: ANIME, search: ${jsonEncode(term.trim())}, sort: SEARCH_MATCH, isAdult: false) {
              $_queryFields
            }
          }
        }
      ''');
    }
    return _searchRequests[key]!;
  }

  Future<List<Anime>> _request(String query) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'content-type': 'application/json', 'accept': 'application/json'},
      body: jsonEncode({'query': query}),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw AnimeApiException('AniList returned ${response.statusCode}.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['errors'] != null) {
      throw AnimeApiException('AniList could not load anime data.');
    }
    final page = (body['data'] as Map<String, dynamic>?)?['Page']
        as Map<String, dynamic>?;
    final records = page?['media'] as List<dynamic>? ?? const [];
    final result = records
        .whereType<Map<String, dynamic>>()
        .map(Anime.fromAniList)
        .where((anime) => anime.title.isNotEmpty && anime.imageUrl.isNotEmpty)
        .toList(growable: false);

    for (final anime in result) {
      final oldIndex = animeCatalog.indexWhere((item) => item.id == anime.id);
      if (oldIndex == -1) {
        animeCatalog.add(anime);
      } else {
        animeCatalog[oldIndex] = anime;
      }
    }
    return result;
  }
}

class AnimeApiException implements Exception {
  const AnimeApiException(this.message);
  final String message;
  @override
  String toString() => message;
}


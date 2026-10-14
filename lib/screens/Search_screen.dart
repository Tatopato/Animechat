import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/account_menu.dart';
import '../constants/minimal_ui.dart';
import '../data/anime_catalog.dart';
import '../services/user_data_service.dart';

/// Search: filter the anime list by title or genre. Recent searches and
/// favorites are stored under the signed-in account.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = UserDataService.instance;
  final TextEditingController _controller = TextEditingController();

  late final Stream<UserProfile> _profile = _service.profileStream();
  late final Stream<UserProfile> _headerProfile = _service.profileStream();
  late final Stream<Set<String>> _favorites = _service.favoriteIdsStream();

  String _query = '';
  String? _genre; // null = All

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Anime> get _results {
    final q = _query.trim().toLowerCase();
    return animeCatalog.where((a) {
      final matchesGenre = _genre == null || a.genres.contains(_genre);
      final matchesQuery = q.isEmpty ||
          a.title.toLowerCase().contains(q) ||
          a.genres.any((g) => g.toLowerCase().contains(q));
      return matchesGenre && matchesQuery;
    }).toList();
  }

  void _setQuery(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
  }

  Future<void> _saveRecent(String value) async {
    if (value.trim().isEmpty) return;
    try {
      await _service.addRecentSearch(value);
    } catch (_) {
      // Recent searches are a convenience; ignore failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    // Poster is 2:3, plus ~70px for the title and genre lines underneath.
    final tileWidth = (MediaQuery.of(context).size.width - 40 - 16) / 2;
    final tileAspect = tileWidth / (tileWidth * 1.5 + 70);

    return Scaffold(
      backgroundColor: Mi.bg,
      body: MiBackdrop(
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<Set<String>>(
          stream: _favorites,
          builder: (context, favSnapshot) {
            final favorites = favSnapshot.data ?? const <String>{};

            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildSearchField(),
                      const SizedBox(height: 14),
                      _buildGenreChips(),
                      if (_query.isEmpty) _buildRecent(),
                      const SizedBox(height: 22),
                      _buildResultCount(results.length),
                      const SizedBox(height: 14),
                      if (favSnapshot.hasError) ...[
                        const MiDataError(),
                        const SizedBox(height: 18),
                      ],
                    ]),
                  ),
                ),
                if (results.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: MiEmpty(
                        icon: Icons.search_off_rounded,
                        text: _query.trim().isEmpty
                            ? 'Nothing here yet.'
                            : 'No results for "${_query.trim()}".',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 20,
                        childAspectRatio: tileAspect,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final anime = results[index];
                          return AnimeTile(
                            anime: anime,
                            isFavorite: favorites.contains(anime.id),
                          );
                        },
                        childCount: results.length,
                      ),
                    ),
                  ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<UserProfile>(
      stream: _headerProfile,
      initialData: user == null ? null : UserProfile.fromData(null, user),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: Mi.title()),
                  const SizedBox(height: 2),
                  Text('Find your next favorite anime', style: Mi.caption()),
                ],
              ),
            ),
            if (profile != null) AccountMenuButton(profile: profile, size: 40),
          ],
        );
      },
    );
  }

  Widget _buildResultCount(int count) {
    final browsing = _query.trim().isEmpty && _genre == null;
    final label = browsing
        ? 'All anime'
        : _genre != null && _query.trim().isEmpty
            ? _genre!
            : 'Results';
    return Row(
      children: [
        Expanded(child: Text(label, style: Mi.section())),
        Text(
          '$count ${count == 1 ? 'title' : 'titles'}',
          style: Mi.caption(),
        ),
      ],
    );
  }

  Widget _buildSearchField() => _searchTextField();

  Widget _searchTextField() {
    return TextField(
      controller: _controller,
      onChanged: (value) => setState(() => _query = value),
      onSubmitted: _saveRecent,
      textInputAction: TextInputAction.search,
      style: Mi.body(size: 15),
      cursorColor: Mi.accent,
      decoration: InputDecoration(
        hintText: 'Search anime or genre',
        hintStyle: Mi.body(size: 15, color: Mi.sub),
        prefixIcon: Icon(Icons.search_rounded, color: Mi.sub),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: Mi.sub, size: 20),
                onPressed: () => _setQuery(''),
              ),
        filled: true,
        fillColor: Mi.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Mi.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Mi.accent, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildGenreChips() {
    final genres = allGenres;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: genres.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = index == 0 ? 'All' : genres[index - 1];
          final selected = index == 0 ? _genre == null : _genre == label;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) =>
                setState(() => _genre = index == 0 ? null : label),
            labelStyle: Mi.body(
              size: 13,
              color: selected ? Colors.white : Mi.text,
              weight: FontWeight.w600,
            ),
            backgroundColor: Mi.tint,
            selectedColor: Mi.accent,
            side: BorderSide(color: selected ? Mi.accent : Colors.transparent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecent() {
    return StreamBuilder<UserProfile>(
      stream: _profile,
      builder: (context, snapshot) {
        final recent = snapshot.data?.recentSearches ?? const <String>[];
        if (recent.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Recent', style: Mi.caption())),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                    onTap: () async {
                      try {
                        await _service.clearRecentSearches();
                      } catch (_) {
                        if (context.mounted) {
                          miSnack(context, "Couldn't clear history.");
                        }
                      }
                    },
                    child: Text(
                      'Clear',
                      style: Mi.body(
                        size: 12,
                        color: Mi.accent,
                        weight: FontWeight.w700,
                      ),
                    ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final term in recent)
                    ActionChip(
                      avatar: Icon(Icons.history_rounded,
                          size: 16, color: Mi.sub),
                      label: Text(term),
                      onPressed: () => _setQuery(term),
                      labelStyle: Mi.body(size: 13),
                      backgroundColor: Mi.surface,
                      side: BorderSide(color: Mi.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

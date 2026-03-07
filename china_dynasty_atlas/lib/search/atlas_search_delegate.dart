import 'package:flutter/material.dart';

import '../models/atlas_models.dart';

enum SearchSelectionType { territory, event, person }

class SearchSelection {
  const SearchSelection({required this.type, required this.id});

  final SearchSelectionType type;
  final String id;
}

class AtlasSearchDelegate extends SearchDelegate<SearchSelection?> {
  AtlasSearchDelegate({
    required this.territories,
    required this.events,
    required this.people,
  });

  final List<Territory> territories;
  final List<HistoricalEvent> events;
  final List<HistoricalPerson> people;

  @override
  String get searchFieldLabel => '搜索国家、事件或人物';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
          tooltip: '清空',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
      tooltip: '返回',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResultList(
      results: _filteredResults(query),
      onSelected: (selection) => close(context, selection),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final normalizedQuery = query.trim();
    final results = normalizedQuery.isEmpty
        ? _featuredResults()
        : _filteredResults(normalizedQuery);

    return _SearchResultList(
      results: results,
      onSelected: (selection) => close(context, selection),
    );
  }

  List<_SearchResult> _featuredResults() {
    final featuredTerritories = territories
        .take(4)
        .map(
          (territory) => _SearchResult(
            selection: SearchSelection(
              type: SearchSelectionType.territory,
              id: territory.id,
            ),
            title: territory.nameZh,
            subtitle: '${territory.nameEn} · 政权',
            keywords: [
              territory.nameZh,
              territory.nameEn,
              territory.id,
              ...territory.aliases,
            ],
            icon: Icons.public,
          ),
        );

    final featuredEvents = events
        .take(6)
        .map(
          (event) => _SearchResult(
            selection: SearchSelection(
              type: SearchSelectionType.event,
              id: event.id,
            ),
            title: event.titleZh,
            subtitle: '${_yearLabel(event.year)} · ${event.locationName}',
            keywords: [
              event.titleZh,
              event.titleEn,
              event.locationName,
              event.id,
              ...event.tags,
            ],
            icon: Icons.auto_stories,
          ),
        );

    final featuredPeople = people
        .take(6)
        .map(
          (person) => _SearchResult(
            selection: SearchSelection(
              type: SearchSelectionType.person,
              id: person.id,
            ),
            title: person.nameZh,
            subtitle: '${person.nameEn} · ${person.role}',
            keywords: [person.nameZh, person.nameEn, person.role, person.id],
            icon: Icons.person,
          ),
        );

    return [...featuredTerritories, ...featuredEvents, ...featuredPeople];
  }

  List<_SearchResult> _filteredResults(String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) return _featuredResults();

    final results = <_SearchResult>[
      ...territories.map(
        (territory) => _SearchResult(
          selection: SearchSelection(
            type: SearchSelectionType.territory,
            id: territory.id,
          ),
          title: territory.nameZh,
          subtitle:
              '${territory.nameEn} · ${_yearLabel(territory.startYear)} - ${_yearLabel(territory.endYear)}',
          keywords: [
            territory.nameZh,
            territory.nameEn,
            territory.id,
            territory.capital,
            ...territory.aliases,
          ],
          icon: Icons.public,
        ),
      ),
      ...events.map(
        (event) => _SearchResult(
          selection: SearchSelection(
            type: SearchSelectionType.event,
            id: event.id,
          ),
          title: event.titleZh,
          subtitle: '${_yearLabel(event.year)} · ${event.locationName}',
          keywords: [
            event.titleZh,
            event.titleEn,
            event.id,
            event.locationName,
            ...event.tags,
          ],
          icon: Icons.auto_stories,
        ),
      ),
      ...people.map(
        (person) => _SearchResult(
          selection: SearchSelection(
            type: SearchSelectionType.person,
            id: person.id,
          ),
          title: person.nameZh,
          subtitle: '${person.nameEn} · ${person.role}',
          keywords: [
            person.nameZh,
            person.nameEn,
            person.id,
            person.role,
            person.bioShort,
          ],
          icon: Icons.person,
        ),
      ),
    ];

    return results.where((result) => result.matches(normalized)).toList();
  }
}

class _SearchResultList extends StatelessWidget {
  const _SearchResultList({required this.results, required this.onSelected});

  final List<_SearchResult> results;
  final ValueChanged<SearchSelection> onSelected;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('没有找到匹配项'));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          leading: CircleAvatar(child: Icon(result.icon)),
          title: Text(result.title),
          subtitle: Text(result.subtitle),
          onTap: () => onSelected(result.selection),
        );
      },
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.selection,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.icon,
  });

  final SearchSelection selection;
  final String title;
  final String subtitle;
  final List<String> keywords;
  final IconData icon;

  bool matches(String query) {
    final lowerKeywords = keywords.map((keyword) => keyword.toLowerCase());
    return lowerKeywords.any((keyword) => keyword.contains(query));
  }
}

String _yearLabel(int year) {
  if (year < 0) {
    return '公元前${year.abs()}年';
  }
  return '公元$year年';
}

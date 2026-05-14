import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
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
  String get searchFieldLabel {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final isZh = AppL10n.useChineseForLocale(locale);
    return isZh ? '搜索国家、事件或人物' : 'Search territories, events, or people';
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    final l10n = AppL10n.of(context);
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
          tooltip: l10n.text('清空', 'Clear'),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    final l10n = AppL10n.of(context);
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
      tooltip: l10n.text('返回', 'Back'),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final l10n = AppL10n.of(context);
    return _SearchResultList(
      results: _filteredResults(query, l10n),
      onSelected: (selection) => close(context, selection),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final l10n = AppL10n.of(context);
    final normalizedQuery = query.trim();
    final results = normalizedQuery.isEmpty
        ? _featuredResults(l10n)
        : _filteredResults(normalizedQuery, l10n);

    return _SearchResultList(
      results: results,
      onSelected: (selection) => close(context, selection),
    );
  }

  List<_SearchResult> _featuredResults(AppL10n l10n) {
    final featuredTerritories = territories
        .take(4)
        .map(
          (territory) => _SearchResult(
            selection: SearchSelection(
              type: SearchSelectionType.territory,
              id: territory.id,
            ),
            title: l10n.displayName(territory.nameZh, territory.nameEn),
            subtitle: l10n.text('政权', 'Territory'),
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
            title: l10n.displayName(event.titleZh, event.titleEn),
            subtitle:
                '${l10n.formatYear(event.year)} · ${l10n.isZh ? event.locationNameZh : event.locationNameEn}',
            keywords: [
              event.titleZh,
              event.titleEn,
              event.locationNameZh,
              event.locationNameEn,
              event.id,
              ...event.tags,
              ...event.tags.map(l10n.tagLabel),
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
            title: l10n.displayName(person.nameZh, person.nameEn),
            subtitle: l10n.roleLabel(person.role),
            keywords: [
              person.nameZh,
              person.nameEn,
              person.role,
              l10n.roleLabel(person.role),
              person.id,
            ],
            icon: Icons.person,
          ),
        );

    return [...featuredTerritories, ...featuredEvents, ...featuredPeople];
  }

  List<_SearchResult> _filteredResults(String rawQuery, AppL10n l10n) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) return _featuredResults(l10n);

    final results = <_SearchResult>[
      ...territories.map(
        (territory) => _SearchResult(
          selection: SearchSelection(
            type: SearchSelectionType.territory,
            id: territory.id,
          ),
          title: l10n.displayName(territory.nameZh, territory.nameEn),
          subtitle:
              '${l10n.formatYear(territory.startYear)} - ${l10n.formatYear(territory.endYear)}',
          keywords: [
            territory.nameZh,
            territory.nameEn,
            territory.summaryZh,
            territory.summaryEn,
            territory.summaryLongZh,
            territory.summaryLongEn,
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
          title: l10n.displayName(event.titleZh, event.titleEn),
          subtitle:
              '${l10n.formatYear(event.year)} · ${l10n.isZh ? event.locationNameZh : event.locationNameEn}',
          keywords: [
            event.titleZh,
            event.titleEn,
            event.id,
            event.locationNameZh,
            event.locationNameEn,
            ...event.tags,
            ...event.tags.map(l10n.tagLabel),
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
          title: l10n.displayName(person.nameZh, person.nameEn),
          subtitle: l10n.roleLabel(person.role),
          keywords: [
            person.nameZh,
            person.nameEn,
            person.id,
            person.role,
            l10n.roleLabel(person.role),
            person.bioShortZh,
            person.bioShortEn,
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
    final l10n = AppL10n.of(context);
    if (results.isEmpty) {
      return Center(child: Text(l10n.text('没有找到匹配项', 'No matches found')));
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/atlas_models.dart';
import '../screens/event_detail_page.dart';
import '../search/atlas_search_delegate.dart';
import '../services/atlas_repository.dart';

class AtlasHomePage extends StatefulWidget {
  const AtlasHomePage({super.key});

  @override
  State<AtlasHomePage> createState() => _AtlasHomePageState();
}

class _AtlasHomePageState extends State<AtlasHomePage> {
  late final Future<AtlasData> _atlasFuture;

  @override
  void initState() {
    super.initState();
    _atlasFuture = AtlasRepository().load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AtlasData>(
      future: _atlasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '数据加载失败: ${snapshot.error}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return AtlasExplorer(data: snapshot.requireData);
      },
    );
  }
}

class AtlasExplorer extends StatefulWidget {
  const AtlasExplorer({super.key, required this.data});

  final AtlasData data;

  @override
  State<AtlasExplorer> createState() => _AtlasExplorerState();
}

class _AtlasExplorerState extends State<AtlasExplorer> {
  final MapController _mapController = MapController();
  final LayerHitNotifier<String> _polygonHitNotifier = ValueNotifier(null);

  late int _selectedYearIndex;
  late String _selectedTerritoryId;
  String? _selectedEventId;
  bool _isMapReady = false;

  AtlasData get _data => widget.data;
  int get _selectedYear => _data.scope.timelineYears[_selectedYearIndex];

  List<TerritorySnapshot> get _currentSnapshots => _data.snapshots
      .where((snapshot) => snapshot.year == _selectedYear)
      .toList(growable: false);

  TerritorySnapshot get _selectedSnapshot {
    for (final snapshot in _currentSnapshots) {
      if (snapshot.territoryId == _selectedTerritoryId) {
        return snapshot;
      }
    }
    return _currentSnapshots.first;
  }

  Territory get _selectedTerritory => _data.territories.firstWhere(
    (territory) => territory.id == _selectedSnapshot.territoryId,
  );

  List<HistoricalEvent> get _territoryEvents {
    final highlighted = _selectedSnapshot.highlightedEventIds;
    final highlightedEvents = highlighted
        .map(_eventById)
        .whereType<HistoricalEvent>()
        .toList(growable: false);
    final highlightedIds = highlightedEvents.map((event) => event.id).toSet();

    final remainingEvents =
        _data.events
            .where(
              (event) =>
                  event.territoryIds.contains(_selectedTerritory.id) &&
                  !highlightedIds.contains(event.id),
            )
            .toList()
          ..sort((a, b) => a.year.compareTo(b.year));

    return [...highlightedEvents, ...remainingEvents];
  }

  HistoricalEvent? get _selectedEvent =>
      _selectedEventId == null ? null : _eventById(_selectedEventId!);

  Map<String, Territory> get _territoriesById => {
    for (final territory in _data.territories) territory.id: territory,
  };

  Map<String, HistoricalPerson> get _peopleById => {
    for (final person in _data.people) person.id: person,
  };

  Map<String, HistoricalEvent> get _eventsById => {
    for (final event in _data.events) event.id: event,
  };

  Map<String, PlaceRecord> get _placesById => {
    for (final place in _data.places) place.id: place,
  };

  Map<String, SourceRecord> get _sourcesById => {
    for (final source in _data.sources) source.id: source,
  };

  Map<String, GeometryAssetRecord> get _geometryAssetsById => {
    for (final geometry in _data.geometryAssets) geometry.id: geometry,
  };

  @override
  void initState() {
    super.initState();
    _selectedYearIndex = 0;
    _selectedTerritoryId = _data.scope.coreTerritoryIds.first;
    _syncSelectionForCurrentYear();
  }

  @override
  void dispose() {
    _polygonHitNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timelineYears = _data.scope.timelineYears;
    final mapPanel = _MapPanel(
      mapController: _mapController,
      snapshots: _currentSnapshots,
      polygonsBySnapshotId: _data.polygonsBySnapshotId,
      polygonsByGeometryId: _data.polygonsByGeometryId,
      territoriesById: _territoriesById,
      selectedTerritoryId: _selectedTerritoryId,
      events: _territoryEvents,
      polygonHitNotifier: _polygonHitNotifier,
      onPolygonTap: _handlePolygonTap,
      onMapReady: _handleMapReady,
    );
    final detailPanel = _DetailPanel(
      scope: _data.scope,
      selectedYear: _selectedYear,
      territory: _selectedTerritory,
      snapshot: _selectedSnapshot,
      events: _territoryEvents,
      selectedEvent: _selectedEvent,
      territoriesById: _territoriesById,
      peopleById: _peopleById,
      placesById: _placesById,
      sourcesById: _sourcesById,
      geometryAssetsById: _geometryAssetsById,
      onEventSelected: _selectEvent,
      onEventOpened: _openEventDetail,
      onPersonSelected: _showPersonDetailsById,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_data.scope.titleZh),
            Text(
              _data.scope.titleEn,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ScopeSummary(
                scope: _data.scope,
                territories: _data.territories,
                selectedYear: _selectedYear,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 1100) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: mapPanel),
                          const SizedBox(width: 16),
                          SizedBox(width: 360, child: detailPanel),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Expanded(flex: 5, child: mapPanel),
                        const SizedBox(height: 16),
                        Expanded(flex: 4, child: detailPanel),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('时间轴', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Slider(
                        value: _selectedYearIndex.toDouble(),
                        min: 0,
                        max: (timelineYears.length - 1).toDouble(),
                        divisions: timelineYears.length - 1,
                        label: yearLabel(_selectedYear),
                        onChanged: (value) {
                          _selectYearIndex(value.round());
                        },
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (
                            var index = 0;
                            index < timelineYears.length;
                            index++
                          )
                            ChoiceChip(
                              label: Text(yearLabel(timelineYears[index])),
                              selected: index == _selectedYearIndex,
                              onSelected: (_) => _selectYearIndex(index),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectYearIndex(int index) {
    if (index == _selectedYearIndex) return;
    setState(() {
      _selectedYearIndex = index;
      _syncSelectionForCurrentYear();
    });
    _moveMapToSelection();
  }

  void _handlePolygonTap() {
    final hitValues = _polygonHitNotifier.value?.hitValues.toList() ?? const [];
    if (hitValues.isEmpty) return;
    _selectTerritory(hitValues.first);
  }

  void _selectTerritory(String territoryId) {
    if (_selectedTerritoryId == territoryId) return;
    setState(() {
      _selectedTerritoryId = territoryId;
      _selectedEventId = _territoryEvents.isEmpty
          ? null
          : _territoryEvents.first.id;
    });
    _moveMapToSelection();
  }

  void _selectEvent(String eventId) {
    setState(() {
      _selectedEventId = eventId;
    });
  }

  void _syncSelectionForCurrentYear() {
    if (_currentSnapshots.isEmpty) {
      return;
    }

    final stillVisible = _currentSnapshots.any(
      (snapshot) => snapshot.territoryId == _selectedTerritoryId,
    );

    if (!stillVisible) {
      _selectedTerritoryId = _currentSnapshots.first.territoryId;
    }

    final eventIds = _territoryEvents.map((event) => event.id).toSet();
    if (_selectedEventId == null || !eventIds.contains(_selectedEventId)) {
      _selectedEventId = _territoryEvents.isEmpty
          ? null
          : _territoryEvents.first.id;
    }
  }

  void _moveMapToSelection() {
    if (!_isMapReady) return;
    final focus = _selectedSnapshot.focus;
    _mapController.move(LatLng(focus.lat, focus.lng), focus.zoom);
  }

  void _handleMapReady() {
    if (_isMapReady) return;
    _isMapReady = true;
    _moveMapToSelection();
  }

  Future<void> _openSearch() async {
    final selection = await showSearch<SearchSelection?>(
      context: context,
      delegate: AtlasSearchDelegate(
        territories: _data.territories,
        events: _data.events,
        people: _data.people,
      ),
    );

    if (!mounted || selection == null) return;
    _applySearchSelection(selection);
  }

  void _applySearchSelection(SearchSelection selection) {
    switch (selection.type) {
      case SearchSelectionType.territory:
        _jumpToTerritory(selection.id);
        return;
      case SearchSelectionType.event:
        final event = _eventById(selection.id);
        if (event == null) return;
        _jumpToEvent(event);
        _openEventDetail(event);
        return;
      case SearchSelectionType.person:
        _showPersonDetailsById(selection.id);
        return;
    }
  }

  void _jumpToTerritory(String territoryId) {
    final snapshot = _nearestSnapshotForTerritory(
      territoryId,
      targetYear: _selectedYear,
    );
    if (snapshot == null) return;

    final yearIndex = _data.scope.timelineYears.indexOf(snapshot.year);
    setState(() {
      _selectedYearIndex = yearIndex >= 0 ? yearIndex : _selectedYearIndex;
      _selectedTerritoryId = snapshot.territoryId;
      _syncSelectionForCurrentYear();
    });
    _moveMapToSelection();
  }

  void _jumpToEvent(HistoricalEvent event) {
    final territoryId = event.territoryIds.isNotEmpty
        ? event.territoryIds.first
        : _selectedTerritoryId;
    final snapshot = _nearestSnapshotForTerritory(
      territoryId,
      targetYear: event.year,
    );

    setState(() {
      if (snapshot != null) {
        final yearIndex = _data.scope.timelineYears.indexOf(snapshot.year);
        if (yearIndex >= 0) {
          _selectedYearIndex = yearIndex;
        }
        _selectedTerritoryId = snapshot.territoryId;
      }
      _selectedEventId = event.id;
      _syncSelectionForCurrentYear();
    });
    _moveMapToSelection();
  }

  TerritorySnapshot? _nearestSnapshotForTerritory(
    String territoryId, {
    required int targetYear,
  }) {
    final snapshots = _data.snapshots
        .where((snapshot) => snapshot.territoryId == territoryId)
        .toList(growable: false);
    if (snapshots.isEmpty) return null;

    snapshots.sort(
      (a, b) =>
          (a.year - targetYear).abs().compareTo((b.year - targetYear).abs()),
    );
    return snapshots.first;
  }

  Future<void> _openEventDetail(HistoricalEvent event) async {
    final territoryNames = event.territoryIds
        .map((id) => _territoriesById[id]?.nameZh ?? id)
        .toList(growable: false);
    final placeNames = event.placeIds
        .map((id) => _placesById[id]?.nameZh ?? id)
        .toList(growable: false);
    final sourceLabels = event.sourceRefs
        .map((id) => _sourcesById[id]?.sourceName ?? id)
        .toList(growable: false);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailPage(
          event: event,
          territoryNames: territoryNames,
          placeNames: placeNames,
          sourceLabels: sourceLabels,
          peopleById: _peopleById,
          onPersonSelected: _showPersonDetails,
        ),
      ),
    );
  }

  void _showPersonDetailsById(String personId) {
    final person = _peopleById[personId];
    if (person == null) return;
    _showPersonDetails(person);
  }

  void _showPersonDetails(HistoricalPerson person) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PersonDetailSheet(
          person: person,
          territoriesById: _territoriesById,
          eventsById: _eventsById,
          placesById: _placesById,
          sourcesById: _sourcesById,
          onTerritorySelected: (territoryId) {
            Navigator.of(context).pop();
            _jumpToTerritory(territoryId);
          },
          onEventSelected: (eventId) {
            Navigator.of(context).pop();
            final event = _eventsById[eventId];
            if (event == null) return;
            _jumpToEvent(event);
            _openEventDetail(event);
          },
        );
      },
    );
  }

  HistoricalEvent? _eventById(String id) {
    for (final event in _data.events) {
      if (event.id == id) return event;
    }
    return null;
  }
}

class _ScopeSummary extends StatelessWidget {
  const _ScopeSummary({
    required this.scope,
    required this.territories,
    required this.selectedYear,
  });

  final ProjectScope scope;
  final List<Territory> territories;
  final int selectedYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SummaryBadge(label: '首版主题', value: scope.themeLabelZh),
            _SummaryBadge(
              label: '核心政权',
              value: territories
                  .map((territory) => territory.nameZh)
                  .join(' / '),
            ),
            _SummaryBadge(label: '当前年份', value: yearLabel(selectedYear)),
            SizedBox(
              width: 320,
              child: Text(scope.mvpFocus, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({
    required this.mapController,
    required this.snapshots,
    required this.polygonsBySnapshotId,
    required this.polygonsByGeometryId,
    required this.territoriesById,
    required this.selectedTerritoryId,
    required this.events,
    required this.polygonHitNotifier,
    required this.onPolygonTap,
    required this.onMapReady,
  });

  final MapController mapController;
  final List<TerritorySnapshot> snapshots;
  final Map<String, List<AtlasPolygonFeature>> polygonsBySnapshotId;
  final Map<String, List<AtlasPolygonFeature>> polygonsByGeometryId;
  final Map<String, Territory> territoriesById;
  final String selectedTerritoryId;
  final List<HistoricalEvent> events;
  final LayerHitNotifier<String> polygonHitNotifier;
  final VoidCallback onPolygonTap;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final polygons = <Polygon<String>>[];
    for (final snapshot in snapshots) {
      final territory = territoriesById[snapshot.territoryId]!;
      final isSelected = snapshot.territoryId == selectedTerritoryId;
      final fillColor = colorFromHex(territory.color);
      final geometryRefs = snapshot.geometryRefs.isNotEmpty
          ? snapshot.geometryRefs
          : null;
      final features = geometryRefs == null
          ? polygonsBySnapshotId[snapshot.id] ?? const []
          : geometryRefs
                .expand(
                  (geometryRef) =>
                      polygonsByGeometryId[geometryRef] ?? const [],
                )
                .toList(growable: false);
      for (final feature in features) {
        polygons.add(
          Polygon<String>(
            points: feature.rings.first
                .map<LatLng>((point) => LatLng(point[1], point[0]))
                .toList(growable: false),
            holePointsList: feature.rings.length > 1
                ? feature.rings
                      .skip(1)
                      .map<List<LatLng>>(
                        (ring) => ring
                            .map<LatLng>((point) => LatLng(point[1], point[0]))
                            .toList(growable: false),
                      )
                      .toList(growable: false)
                : null,
            color: fillColor.withValues(alpha: isSelected ? 0.42 : 0.24),
            borderColor: isSelected ? Colors.white : fillColor,
            borderStrokeWidth: isSelected ? 3.5 : 2.0,
            label: territory.nameZh,
            hitValue: snapshot.territoryId,
          ),
        );
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(35.6, 104.0),
              initialZoom: 4.0,
              onMapReady: onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.china_dynasty_atlas',
              ),
              GestureDetector(
                onTap: onPolygonTap,
                child: PolygonLayer<String>(
                  polygons: polygons,
                  hitNotifier: polygonHitNotifier,
                ),
              ),
              MarkerLayer(
                markers: events
                    .map(
                      (event) => Marker(
                        point: LatLng(event.lat, event.lng),
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black87,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: null,
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      '点击疆域边界可切换政权',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.black.withValues(alpha: 0.68),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      '边界为教学展示级示意图',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.scope,
    required this.selectedYear,
    required this.territory,
    required this.snapshot,
    required this.events,
    required this.selectedEvent,
    required this.territoriesById,
    required this.peopleById,
    required this.placesById,
    required this.sourcesById,
    required this.geometryAssetsById,
    required this.onEventSelected,
    required this.onEventOpened,
    required this.onPersonSelected,
  });

  final ProjectScope scope;
  final int selectedYear;
  final Territory territory;
  final TerritorySnapshot snapshot;
  final List<HistoricalEvent> events;
  final HistoricalEvent? selectedEvent;
  final Map<String, Territory> territoriesById;
  final Map<String, HistoricalPerson> peopleById;
  final Map<String, PlaceRecord> placesById;
  final Map<String, SourceRecord> sourcesById;
  final Map<String, GeometryAssetRecord> geometryAssetsById;
  final ValueChanged<String> onEventSelected;
  final ValueChanged<HistoricalEvent> onEventOpened;
  final ValueChanged<String> onPersonSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capitalNames = territory.capitalPlaceIds
        .map((id) => placesById[id]?.nameZh ?? id)
        .toList(growable: false);
    final snapshotSources = snapshot.sourceRefs
        .map((id) => sourcesById[id])
        .whereType<SourceRecord>()
        .toList(growable: false);
    final snapshotGeometries = snapshot.geometryRefs
        .map((id) => geometryAssetsById[id])
        .whereType<GeometryAssetRecord>()
        .toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(territory.nameZh, style: theme.textTheme.headlineSmall),
            Text(
              territory.nameEn,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: '当前年份', value: yearLabel(selectedYear)),
                _InfoChip(
                  label: '存续时间',
                  value:
                      '${yearLabel(territory.startYear)} - ${yearLabel(territory.endYear)}',
                ),
                _InfoChip(
                  label: '都城',
                  value: capitalNames.isNotEmpty
                      ? capitalNames.join(' / ')
                      : territory.capital,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(territory.summary, style: theme.textTheme.bodyMedium),
            if (territory.summaryLong.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(territory.summaryLong, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorFromHex(territory.color).withValues(alpha: 0.14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(snapshot.headline, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(snapshot.territoryNote),
                  if (snapshot.boundaryHighlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...snapshot.boundaryHighlights.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $item'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (territory.governanceHighlights.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('治理特征', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              ...territory.governanceHighlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item'),
                ),
              ),
            ],
            if (territory.legacy.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('历史遗产', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              ...territory.legacy.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item'),
                ),
              ),
            ],
            if (snapshot.accuracyNote.isNotEmpty ||
                snapshot.sourceNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('边界说明', style: theme.textTheme.titleSmall),
                    if (snapshot.accuracyNote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(snapshot.accuracyNote),
                    ],
                    if (snapshot.sourceNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...snapshot.sourceNotes.map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $note'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (snapshotGeometries.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('几何资产', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              ...snapshotGeometries.map(
                (geometry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${geometry.id} · ${geometry.geometryType} · ${geometry.revision} · ${geometry.simplificationLevel}',
                  ),
                ),
              ),
            ],
            if (snapshotSources.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('数据来源', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              ...snapshotSources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${source.sourceName} · ${source.licenseName} · ${source.approvalStatus}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('代表事件', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final event in events)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: selectedEvent?.id == event.id
                    ? theme.colorScheme.secondaryContainer
                    : null,
                child: ListTile(
                  onTap: () => onEventSelected(event.id),
                  title: Text(event.titleZh),
                  subtitle: Text(
                    '${yearLabel(event.year)} · ${event.locationName}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            if (selectedEvent != null) ...[
              const SizedBox(height: 8),
              Text('事件详情', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _SelectedEventCard(
                event: selectedEvent!,
                territoriesById: territoriesById,
                peopleById: peopleById,
                placesById: placesById,
                sourcesById: sourcesById,
                onOpenEvent: () => onEventOpened(selectedEvent!),
                onPersonSelected: onPersonSelected,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '扩展年份建议: ${scope.recommendedExpansionYears.map(yearLabel).join(' / ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SelectedEventCard extends StatelessWidget {
  const _SelectedEventCard({
    required this.event,
    required this.territoriesById,
    required this.peopleById,
    required this.placesById,
    required this.sourcesById,
    required this.onOpenEvent,
    required this.onPersonSelected,
  });

  final HistoricalEvent event;
  final Map<String, Territory> territoriesById;
  final Map<String, HistoricalPerson> peopleById;
  final Map<String, PlaceRecord> placesById;
  final Map<String, SourceRecord> sourcesById;
  final VoidCallback onOpenEvent;
  final ValueChanged<String> onPersonSelected;

  @override
  Widget build(BuildContext context) {
    final territoryNames = event.territoryIds
        .map((id) => territoriesById[id]?.nameZh ?? id)
        .join(' / ');
    final relatedPeople = event.relatedPeople
        .map((id) => peopleById[id])
        .whereType<HistoricalPerson>()
        .toList(growable: false);
    final placeNames = event.placeIds
        .map((id) => placesById[id]?.nameZh ?? id)
        .toList(growable: false);
    final sourceNames = event.sourceRefs
        .map((id) => sourcesById[id]?.sourceName ?? id)
        .toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.titleZh, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              event.titleEn,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text('${yearLabel(event.year)} · ${event.locationName}'),
            if (placeNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('地点实体: ${placeNames.join(' / ')}'),
            ],
            const SizedBox(height: 6),
            Text('所属政权: $territoryNames'),
            if (event.confidence.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('内容置信度: ${event.confidence}'),
            ],
            const SizedBox(height: 10),
            Text(event.summary),
            if (event.significance.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '历史意义: ${event.significance}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Text(event.content),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: event.tags
                  .map((tag) => Chip(label: Text(tag)))
                  .toList(growable: false),
            ),
            if (relatedPeople.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: relatedPeople
                    .map(
                      (person) => ActionChip(
                        avatar: const Icon(Icons.person, size: 18),
                        label: Text(person.nameZh),
                        onPressed: () => onPersonSelected(person.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onOpenEvent,
                icon: const Icon(Icons.open_in_new),
                label: const Text('查看完整详情'),
              ),
            ),
            if (event.sourceNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '资料说明: ${event.sourceNotes.first}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (sourceNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '来源实体: ${sourceNames.join(' / ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonDetailSheet extends StatelessWidget {
  const _PersonDetailSheet({
    required this.person,
    required this.territoriesById,
    required this.eventsById,
    required this.placesById,
    required this.sourcesById,
    required this.onTerritorySelected,
    required this.onEventSelected,
  });

  final HistoricalPerson person;
  final Map<String, Territory> territoriesById;
  final Map<String, HistoricalEvent> eventsById;
  final Map<String, PlaceRecord> placesById;
  final Map<String, SourceRecord> sourcesById;
  final ValueChanged<String> onTerritorySelected;
  final ValueChanged<String> onEventSelected;

  @override
  Widget build(BuildContext context) {
    final relatedTerritories = person.relatedTerritoryIds
        .map((id) => territoriesById[id])
        .whereType<Territory>()
        .toList(growable: false);
    final relatedEvents = person.relatedEventIds
        .map((id) => eventsById[id])
        .whereType<HistoricalEvent>()
        .toList(growable: false);
    final birthPlace = person.birthPlaceId.isEmpty
        ? null
        : placesById[person.birthPlaceId];
    final deathPlace = person.deathPlaceId.isEmpty
        ? null
        : placesById[person.deathPlaceId];
    final sourceNames = person.sourceRefs
        .map((id) => sourcesById[id]?.sourceName ?? id)
        .toList(growable: false);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              person.nameZh,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${person.nameEn} · ${person.role}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (person.activeYears.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoChip(label: '活跃年代', value: person.activeYears),
            ],
            if (birthPlace != null || deathPlace != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (birthPlace != null)
                    _InfoChip(label: '出生地', value: birthPlace.nameZh),
                  if (deathPlace != null)
                    _InfoChip(label: '逝世地', value: deathPlace.nameZh),
                ],
              ),
            ],
            if (person.bioShort.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('人物简介', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(person.bioShort),
            ],
            if (person.contribution.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('历史作用', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(person.contribution),
            ],
            if (relatedTerritories.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('相关政权', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: relatedTerritories
                    .map(
                      (territory) => ActionChip(
                        avatar: const Icon(Icons.public, size: 18),
                        label: Text(territory.nameZh),
                        onPressed: () => onTerritorySelected(territory.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (relatedEvents.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('相关事件', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final event in relatedEvents)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(event.titleZh),
                    subtitle: Text(
                      '${yearLabel(event.year)} · ${event.locationName}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onEventSelected(event.id),
                  ),
                ),
            ],
            if (person.sourceNotes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('资料说明', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...person.sourceNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $note'),
                ),
              ),
            ],
            if (sourceNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '来源实体: ${sourceNames.join(' / ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String yearLabel(int year) {
  if (year < 0) {
    return '公元前${year.abs()}年';
  }
  return '公元$year年';
}

Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final buffer = StringBuffer();
  if (cleaned.length == 6) {
    buffer.write('ff');
  }
  buffer.write(cleaned);
  return Color(int.parse(buffer.toString(), radix: 16));
}

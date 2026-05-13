import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_l10n.dart';
import '../models/atlas_models.dart';
import '../screens/event_detail_page.dart';
import '../search/atlas_search_delegate.dart';
import '../services/atlas_repository.dart';
import '../services/navigation_service.dart';
import '../state/app_settings.dart';
import '../state/atlas_explorer_controller.dart';

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
          final l10n = AppL10n.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${l10n.text('数据加载失败', 'Failed to load data')}: ${snapshot.error}',
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

class AtlasExplorer extends ConsumerStatefulWidget {
  const AtlasExplorer({super.key, required this.data});

  final AtlasData data;

  @override
  ConsumerState<AtlasExplorer> createState() => _AtlasExplorerState();
}

class _AtlasExplorerState extends ConsumerState<AtlasExplorer> {
  final MapController _mapController = MapController();
  final LayerHitNotifier<String> _polygonHitNotifier = ValueNotifier(null);
  final AtlasNavigationService _navigationService =
      const AtlasNavigationService();
  bool _isMapReady = false;

  AtlasData get _data => widget.data;
  AtlasExplorerController get _controller =>
      ref.read(atlasExplorerControllerProvider(_data));

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
  }

  @override
  void dispose() {
    _polygonHitNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(atlasExplorerControllerProvider(_data));
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final timelineYears = _data.scope.timelineYears;
    final minTimelineYear = timelineYears.first;
    final maxTimelineYear = timelineYears.last;
    final mapPanel = _MapPanel(
      mapController: _mapController,
      snapshots: controller.currentSnapshots,
      polygonsBySnapshotId: _data.polygonsBySnapshotId,
      polygonsByGeometryId: _data.polygonsByGeometryId,
      territoriesById: _territoriesById,
      selectedTerritoryId: controller.selectedTerritoryId,
      events: controller.territoryEvents,
      storylineEvents: controller.activeStoryline != null
          ? controller.activeStoryline!.eventIds
                .map(controller.eventById)
                .whereType<HistoricalEvent>()
                .toList(growable: false)
          : const [],
      storylineEventIndex: controller.storylineEventIndex,
      polygonHitNotifier: _polygonHitNotifier,
      onPolygonTap: _handlePolygonTap,
      onMapReady: _handleMapReady,
    );
    final detailPanel = _DetailPanel(
      scope: _data.scope,
      selectedYear: controller.selectedYear,
      scene: controller.currentScene,
      showWorldContext: controller.showWorldContext,
      visibleSnapshotCount: controller.visibleSnapshotCount,
      worldContextSnapshotCount: controller.worldContextSnapshotCount,
      territory: controller.selectedTerritory,
      snapshot: controller.selectedSnapshot,
      events: controller.territoryEvents,
      selectedEvent: controller.selectedEvent,
      territoriesById: _territoriesById,
      peopleById: _peopleById,
      placesById: _placesById,
      sourcesById: _sourcesById,
      geometryAssetsById: _geometryAssetsById,
      onEventSelected: controller.selectEvent,
      onEventOpened: _openEventDetail,
      onPersonSelected: _showPersonDetailsById,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.displayName(_data.scope.titleZh, _data.scope.titleEn)),
        actions: [
          IconButton(
            onPressed: () => _openStorylinesList(context, controller),
            icon: const Icon(Icons.auto_stories),
            tooltip: l10n.text('故事线', 'Storylines'),
          ),
          TextButton(
            onPressed: () {
              final currentIsZh = l10n.isZh;
              ref
                  .read(appLocaleOverrideProvider.notifier)
                  .setLocale(
                    currentIsZh ? const Locale('en') : const Locale('zh'),
                  );
            },
            child: Text(
              l10n.isZh ? 'EN' : '中',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            tooltip: l10n.text('搜索', 'Search'),
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
                selectedYear: controller.selectedYear,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 1100) {
                      final detailWidth = (constraints.maxWidth * 0.32)
                          .clamp(320.0, 460.0)
                          .toDouble();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: mapPanel),
                          const SizedBox(width: 16),
                          SizedBox(width: detailWidth, child: detailPanel),
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
              if (controller.activeStoryline != null)
                _StorylinePanel(
                  controller: controller,
                  onMapMove: () => _moveMapToSelection(controller),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.text('时间轴', 'Timeline'),
                              style: theme.textTheme.titleMedium,
                            ),
                            const Spacer(),
                            FilterChip(
                              label: Text(
                                '${l10n.text('世界参考层', 'World Reference Layers')} '
                                '(${controller.worldContextSnapshotCount})',
                              ),
                              selected: controller.showWorldContext,
                              onSelected: controller.setShowWorldContext,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${l10n.text('选择年份', 'Selected')}: ${l10n.formatYear(controller.selectedYear)} · '
                              '${l10n.text('地图场景', 'Scene')}: ${l10n.formatYear(controller.activeSceneYear)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: controller.selectedYear
                              .clamp(minTimelineYear, maxTimelineYear)
                              .toDouble(),
                          min: minTimelineYear.toDouble(),
                          max: maxTimelineYear.toDouble(),
                          divisions: maxTimelineYear - minTimelineYear,
                          label: l10n.formatYear(controller.selectedYear),
                          onChanged: (value) {
                            _selectYear(value.round());
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
                                label: Text(
                                  l10n.formatYear(timelineYears[index]),
                                ),
                                selected:
                                    timelineYears[index] ==
                                    controller.activeSceneYear,
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

  void _openStorylinesList(
    BuildContext context,
    AtlasExplorerController controller,
  ) {
    final l10n = AppL10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.text('选择故事线', 'Select Storyline'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _data.storylines.length,
                  itemBuilder: (context, index) {
                    final story = _data.storylines[index];
                    return ListTile(
                      leading: Text(
                        story.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(l10n.isZh ? story.titleZh : story.titleEn),
                      subtitle: Text(
                        l10n.isZh ? story.descriptionZh : story.descriptionEn,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        controller.startStoryline(story);
                        _moveMapToSelection(controller);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectYearIndex(int index) {
    final controller = _controller;
    controller.selectYearIndex(index);
    _moveMapToScene(controller);
  }

  void _selectYear(int year) {
    final controller = _controller;
    controller.selectYear(year);
    _moveMapToScene(controller);
  }

  void _handlePolygonTap() {
    final controller = _controller;
    final hitValues = _polygonHitNotifier.value?.hitValues.toList() ?? const [];
    if (hitValues.isEmpty) return;
    if (controller.selectedTerritoryId == hitValues.first) return;
    controller.selectTerritory(hitValues.first);
    _moveMapToSelection(controller);
  }

  void _moveMapToSelection(AtlasExplorerController controller) {
    if (!_isMapReady) return;
    final focus = controller.selectedSnapshot.focus;
    _mapController.move(LatLng(focus.lat, focus.lng), focus.zoom);
  }

  void _moveMapToScene(AtlasExplorerController controller) {
    if (!_isMapReady) return;
    if (controller.currentScene?.sceneScope == 'world') {
      _mapController.move(const LatLng(25, 20), 2.2);
      return;
    }
    _moveMapToSelection(controller);
  }

  void _handleMapReady() {
    if (_isMapReady) return;
    _isMapReady = true;
    _moveMapToScene(_controller);
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
    _navigationService.applySearchSelection(
      selection: selection,
      controller: _controller,
      onMapSelectionChanged: () => _moveMapToSelection(_controller),
      onEventOpened: _openEventDetail,
      onPersonSelected: _showPersonDetailsById,
    );
  }

  Future<void> _openEventDetail(HistoricalEvent event) async {
    final l10n = AppL10n.of(context);
    final territoryNames = event.territoryIds
        .map((id) {
          final territory = _territoriesById[id];
          if (territory == null) return id;
          return l10n.displayName(territory.nameZh, territory.nameEn);
        })
        .toList(growable: false);
    final placeNames = event.placeIds
        .map((id) {
          final place = _placesById[id];
          if (place == null) return id;
          return l10n.displayName(place.nameZh, place.nameEn);
        })
        .toList(growable: false);
    final sourceLabels = event.sourceRefs
        .map((id) {
          final source = _sourcesById[id];
          if (source == null) return id;
          return l10n.isZh ? source.sourceNameZh : source.sourceNameEn;
        })
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
            final controller = _controller;
            controller.jumpToTerritory(territoryId);
            _moveMapToSelection(controller);
          },
          onEventSelected: (eventId) {
            Navigator.of(context).pop();
            final controller = _controller;
            final event = controller.eventById(eventId);
            if (event == null) return;
            controller.jumpToEvent(event);
            _moveMapToSelection(controller);
            _openEventDetail(event);
          },
        );
      },
    );
  }
}

class _StorylinePanel extends StatelessWidget {
  const _StorylinePanel({required this.controller, required this.onMapMove});

  final AtlasExplorerController controller;
  final VoidCallback onMapMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final story = controller.activeStoryline!;
    final eventIndex = controller.storylineEventIndex;
    final totalEvents = story.eventIds.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${story.emoji} ${l10n.isZh ? story.titleZh : story.titleEn}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${eventIndex + 1} / $totalEvents',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: controller.exitStoryline,
                  tooltip: l10n.text('退出故事', 'Exit Story'),
                  color: theme.colorScheme.onTertiaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.isZh
                  ? story.narrativeIntro.textZh
                  : story.narrativeIntro.textEn,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer.withValues(
                  alpha: 0.9,
                ),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalEvents <= 1 ? 1.0 : eventIndex / (totalEvents - 1),
              color: theme.colorScheme.onTertiaryContainer,
              backgroundColor: theme.colorScheme.onTertiaryContainer.withValues(
                alpha: 0.2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.tonal(
                  onPressed: eventIndex > 0
                      ? () {
                          controller.prevStorylineEvent();
                          onMapMove();
                        }
                      : null,
                  child: Text(l10n.text('上一步', 'Previous')),
                ),
                FilledButton.tonal(
                  onPressed: eventIndex < totalEvents - 1
                      ? () {
                          controller.nextStorylineEvent();
                          onMapMove();
                        }
                      : null,
                  child: Text(l10n.text('下一步', 'Next')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    final l10n = AppL10n.of(context);
    final territoryById = {
      for (final territory in territories) territory.id: territory,
    };
    final coreTerritoryNames = scope.coreTerritoryIds
        .map((id) => territoryById[id])
        .whereType<Territory>()
        .map(
          (territory) => l10n.displayName(territory.nameZh, territory.nameEn),
        )
        .toList(growable: false);
    final visibleCoreTerritories = coreTerritoryNames.take(6).join(' / ');
    final hiddenCoreCount = coreTerritoryNames.length > 6
        ? coreTerritoryNames.length - 6
        : 0;
    final coreTerritorySummary = hiddenCoreCount > 0
        ? '$visibleCoreTerritories +$hiddenCoreCount'
        : visibleCoreTerritories;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SummaryBadge(
              label: l10n.text('首版主题', 'Theme'),
              value: l10n.displayName(scope.themeLabelZh, scope.themeLabelEn),
            ),
            _SummaryBadge(
              label: l10n.text('核心政权', 'Core Territories'),
              value: coreTerritorySummary,
            ),
            _SummaryBadge(
              label: l10n.text('当前年份', 'Selected Year'),
              value: l10n.formatYear(selectedYear),
            ),
            SizedBox(
              width: 320,
              child: Text(
                l10n.displayName(scope.mvpFocusZh, scope.mvpFocusEn),
                style: theme.textTheme.bodyMedium,
              ),
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

class _MapPanel extends StatefulWidget {
  const _MapPanel({
    required this.mapController,
    required this.snapshots,
    required this.polygonsBySnapshotId,
    required this.polygonsByGeometryId,
    required this.territoriesById,
    required this.selectedTerritoryId,
    required this.events,
    required this.storylineEvents,
    required this.storylineEventIndex,
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
  final List<HistoricalEvent> storylineEvents;
  final int storylineEventIndex;
  final LayerHitNotifier<String> polygonHitNotifier;
  final VoidCallback onPolygonTap;
  final VoidCallback onMapReady;

  @override
  State<_MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<_MapPanel> {
  final Map<AtlasPolygonFeature, _CachedPolygonRings> _ringsCache = {};
  final Map<String, List<Polygon<String>>> _polygonListCache = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final baseWorldPolygons = _buildBaseWorldPolygons();
    final polygons = _buildPolygons();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: widget.mapController,
            options: MapOptions(
              initialCenter: const LatLng(35.6, 104.0),
              initialZoom: 4.0,
              onMapReady: widget.onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.china_dynasty_atlas',
              ),
              if (baseWorldPolygons.isNotEmpty)
                PolygonLayer<String>(polygons: baseWorldPolygons),
              GestureDetector(
                onTap: widget.onPolygonTap,
                child: PolygonLayer<String>(
                  polygons: polygons,
                  hitNotifier: widget.polygonHitNotifier,
                ),
              ),
              if (widget.storylineEvents.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // The future path
                    Polyline(
                      points: widget.storylineEvents
                          .map((e) => LatLng(e.lat, e.lng))
                          .toList(growable: false),
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4),
                      strokeWidth: 4.0,
                    ),
                    // The traversed path
                    Polyline(
                      points: widget.storylineEvents
                          .take(widget.storylineEventIndex + 1)
                          .map((e) => LatLng(e.lat, e.lng))
                          .toList(growable: false),
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: widget.events
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
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      l10n.text(
                        '点击疆域边界可切换政权',
                        'Tap territory boundary to switch polity',
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.black.withValues(alpha: 0.68),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      l10n.text(
                        '边界为教学展示级示意图',
                        'Boundaries are educational approximations',
                      ),
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

  List<Polygon<String>> _buildBaseWorldPolygons() {
    const geometryId = 'world_base_modern';
    final cacheKey = 'base|$geometryId';
    final cached = _polygonListCache[cacheKey];
    if (cached != null) return cached;

    final features = widget.polygonsByGeometryId[geometryId] ?? const [];
    final polygons = <Polygon<String>>[];
    for (final feature in features) {
      final cachedRings = _ringsCache.putIfAbsent(
        feature,
        () => _CachedPolygonRings.fromFeature(feature),
      );
      polygons.add(
        Polygon<String>(
          points: cachedRings.points,
          holePointsList: cachedRings.holePointsList,
          color: Theme.of(
            context,
          ).colorScheme.surfaceTint.withValues(alpha: 0.08),
          borderColor: Colors.black.withValues(alpha: 0.34),
          borderStrokeWidth: 1.0,
          hitValue: geometryId,
        ),
      );
    }

    _polygonListCache[cacheKey] = polygons;
    return polygons;
  }

  List<Polygon<String>> _buildPolygons() {
    final l10n = AppL10n.of(context);
    final cacheKey = [
      widget.selectedTerritoryId,
      ...widget.snapshots.map((snapshot) => snapshot.id),
    ].join('|');
    final cached = _polygonListCache[cacheKey];
    if (cached != null) return cached;

    final polygons = <Polygon<String>>[];
    for (final snapshot in widget.snapshots) {
      final territory = widget.territoriesById[snapshot.territoryId]!;
      final isSelected = snapshot.territoryId == widget.selectedTerritoryId;
      final fillColor = colorFromHex(territory.color);
      final geometryRefs = snapshot.geometryRefs.isNotEmpty
          ? snapshot.geometryRefs
          : null;
      final features = geometryRefs == null
          ? widget.polygonsBySnapshotId[snapshot.id] ?? const []
          : geometryRefs
                .expand(
                  (geometryRef) =>
                      widget.polygonsByGeometryId[geometryRef] ?? const [],
                )
                .toList(growable: false);
      for (final feature in features) {
        final cachedRings = _ringsCache.putIfAbsent(
          feature,
          () => _CachedPolygonRings.fromFeature(feature),
        );
        polygons.add(
          Polygon<String>(
            points: cachedRings.points,
            holePointsList: cachedRings.holePointsList,
            color: fillColor.withValues(alpha: isSelected ? 0.42 : 0.24),
            borderColor: isSelected ? Colors.white : fillColor,
            borderStrokeWidth: isSelected ? 3.5 : 2.0,
            label: l10n.displayName(territory.nameZh, territory.nameEn),
            hitValue: snapshot.territoryId,
          ),
        );
      }
    }

    // Keep cache bounded during long sessions.
    if (_polygonListCache.length > 24) {
      _polygonListCache.clear();
    }
    _polygonListCache[cacheKey] = polygons;
    return polygons;
  }
}

class _CachedPolygonRings {
  const _CachedPolygonRings({
    required this.points,
    required this.holePointsList,
  });

  final List<LatLng> points;
  final List<List<LatLng>>? holePointsList;

  factory _CachedPolygonRings.fromFeature(AtlasPolygonFeature feature) {
    return _CachedPolygonRings(
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
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.scope,
    required this.selectedYear,
    required this.scene,
    required this.showWorldContext,
    required this.visibleSnapshotCount,
    required this.worldContextSnapshotCount,
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
  final MapScene? scene;
  final bool showWorldContext;
  final int visibleSnapshotCount;
  final int worldContextSnapshotCount;
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
    final l10n = AppL10n.of(context);
    final capitalNames = territory.capitalPlaceIds
        .map((id) {
          final place = placesById[id];
          if (place == null) return id;
          return l10n.displayName(place.nameZh, place.nameEn);
        })
        .toList(growable: false);
    final snapshotSources = snapshot.sourceRefs
        .map((id) => sourcesById[id])
        .whereType<SourceRecord>()
        .toList(growable: false);
    final snapshotGeometries = snapshot.geometryRefs
        .map((id) => geometryAssetsById[id])
        .whereType<GeometryAssetRecord>()
        .toList(growable: false);
    final territorySummary = l10n.isZh
        ? territory.summaryZh
        : territory.summaryEn;
    final territorySummaryLong = l10n.isZh
        ? territory.summaryLongZh
        : territory.summaryLongEn;
    final governanceHighlights = l10n.isZh
        ? territory.governanceHighlightsZh
        : territory.governanceHighlightsEn;
    final legacy = l10n.isZh ? territory.legacyZh : territory.legacyEn;
    final snapshotHeadline = l10n.isZh
        ? snapshot.headlineZh
        : snapshot.headlineEn;
    final snapshotTerritoryNote = l10n.isZh
        ? snapshot.territoryNoteZh
        : snapshot.territoryNoteEn;
    final snapshotBoundaryHighlights = l10n.isZh
        ? snapshot.boundaryHighlightsZh
        : snapshot.boundaryHighlightsEn;
    final snapshotAccuracyNote = l10n.isZh
        ? snapshot.accuracyNoteZh
        : snapshot.accuracyNoteEn;
    final snapshotSourceNotes = l10n.isZh
        ? snapshot.sourceNotesZh
        : snapshot.sourceNotesEn;
    final sceneTitle = scene == null
        ? l10n.displayName(territory.nameZh, territory.nameEn)
        : l10n.displayName(scene!.titleZh, scene!.titleEn);
    final sceneNotes = scene == null
        ? ''
        : (l10n.isZh ? scene!.notesZh : scene!.notesEn);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(sceneTitle, style: theme.textTheme.headlineSmall),
            if (sceneNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(sceneNotes, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: l10n.text('当前年份', 'Year'),
                  value: l10n.formatYear(selectedYear),
                ),
                _InfoChip(
                  label: l10n.text('当前政权', 'Selected Territory'),
                  value: l10n.displayName(territory.nameZh, territory.nameEn),
                ),
                if (scene != null)
                  _InfoChip(
                    label: l10n.text('覆盖度', 'Coverage'),
                    value: _coverageLabel(l10n, scene!.coverageLevel),
                  ),
                _InfoChip(
                  label: l10n.text('可见政权', 'Visible Polities'),
                  value: visibleSnapshotCount.toString(),
                ),
                if (worldContextSnapshotCount > 0)
                  _InfoChip(
                    label: l10n.text('世界参考层', 'World Reference'),
                    value: showWorldContext
                        ? l10n.text(
                            '$worldContextSnapshotCount 个已显示',
                            '$worldContextSnapshotCount shown',
                          )
                        : l10n.text(
                            '$worldContextSnapshotCount 个已隐藏',
                            '$worldContextSnapshotCount hidden',
                          ),
                  ),
                _InfoChip(
                  label: l10n.text('存续时间', 'Timespan'),
                  value:
                      '${l10n.formatYear(territory.startYear)} - ${l10n.formatYear(territory.endYear)}',
                ),
                _InfoChip(
                  label: l10n.text('都城', 'Capital'),
                  value: capitalNames.isNotEmpty
                      ? capitalNames.join(' / ')
                      : territory.capital,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(territorySummary, style: theme.textTheme.bodyMedium),
            if (territorySummaryLong.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(territorySummaryLong, style: theme.textTheme.bodySmall),
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
                  Text(snapshotHeadline, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(snapshotTerritoryNote),
                  if (snapshotBoundaryHighlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...snapshotBoundaryHighlights.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $item'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (governanceHighlights.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.text('治理特征', 'Governance'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ...governanceHighlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item'),
                ),
              ),
            ],
            if (legacy.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.text('历史遗产', 'Legacy'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ...legacy.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item'),
                ),
              ),
            ],
            if (snapshotAccuracyNote.isNotEmpty ||
                snapshotSourceNotes.isNotEmpty) ...[
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
                    Text(
                      l10n.text('边界说明', 'Boundary Notes'),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (snapshotAccuracyNote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(snapshotAccuracyNote),
                    ],
                    if (snapshotSourceNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...snapshotSourceNotes.map(
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
              Text(
                l10n.text('几何资产', 'Geometry Assets'),
                style: theme.textTheme.titleMedium,
              ),
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
              Text(
                l10n.text('数据来源', 'Sources'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ...snapshotSources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${l10n.isZh ? source.sourceNameZh : source.sourceNameEn} · ${l10n.licenseLabel(source.licenseName)} · ${l10n.approvalStatusLabel(source.approvalStatus)}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.text('代表事件', 'Key Events'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final event in events)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: selectedEvent?.id == event.id
                    ? theme.colorScheme.secondaryContainer
                    : null,
                child: ListTile(
                  onTap: () => onEventSelected(event.id),
                  title: Text(l10n.displayName(event.titleZh, event.titleEn)),
                  subtitle: Text(
                    '${l10n.formatYear(event.year)} · ${l10n.isZh ? event.locationNameZh : event.locationNameEn}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            if (selectedEvent != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.text('事件详情', 'Event Details'),
                style: theme.textTheme.titleMedium,
              ),
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
              '${l10n.text('扩展年份建议', 'Suggested Expansion Years')}: ${scope.recommendedExpansionYears.map(l10n.formatYear).join(' / ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _coverageLabel(AppL10n l10n, String coverageLevel) {
    switch (coverageLevel) {
      case 'global_complete':
        return l10n.text('世界完整场景', 'Complete World Scene');
      case 'global_partial':
        return l10n.text('世界局部覆盖', 'Partial World Coverage');
      case 'placeholder':
        return l10n.text('资料占位', 'Data Placeholder');
      default:
        return coverageLevel;
    }
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
    final l10n = AppL10n.of(context);
    final territoryNames = event.territoryIds
        .map((id) {
          final territory = territoriesById[id];
          if (territory == null) return id;
          return l10n.displayName(territory.nameZh, territory.nameEn);
        })
        .join(' / ');
    final relatedPeople = event.relatedPeople
        .map((id) => peopleById[id])
        .whereType<HistoricalPerson>()
        .toList(growable: false);
    final placeNames = event.placeIds
        .map((id) {
          final place = placesById[id];
          if (place == null) return id;
          return l10n.displayName(place.nameZh, place.nameEn);
        })
        .toList(growable: false);
    final locationName = placeNames.isNotEmpty
        ? placeNames.first
        : (l10n.isZh ? event.locationNameZh : event.locationNameEn);
    final eventSummary = l10n.isZh ? event.summaryZh : event.summaryEn;
    final eventSignificance = l10n.isZh
        ? event.significanceZh
        : event.significanceEn;
    final eventContent = l10n.isZh ? event.contentZh : event.contentEn;
    final sourceNames = event.sourceRefs
        .map((id) {
          final source = sourcesById[id];
          if (source == null) return id;
          return l10n.isZh ? source.sourceNameZh : source.sourceNameEn;
        })
        .toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.displayName(event.titleZh, event.titleEn),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${l10n.formatYear(event.year)} · $locationName'),
            if (placeNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${l10n.text('地点实体', 'Place Entities')}: ${placeNames.join(' / ')}',
              ),
            ],
            const SizedBox(height: 6),
            Text('${l10n.text('所属政权', 'Territories')}: $territoryNames'),
            if (event.confidence.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${l10n.text('内容置信度', 'Confidence')}: ${event.confidence}'),
            ],
            const SizedBox(height: 10),
            Text(eventSummary),
            if (eventSignificance.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${l10n.text('历史意义', 'Significance')}: $eventSignificance',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Text(eventContent),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: event.tags
                  .map((tag) => Chip(label: Text(l10n.tagLabel(tag))))
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
                        label: Text(
                          l10n.displayName(person.nameZh, person.nameEn),
                        ),
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
                label: Text(l10n.text('查看完整详情', 'Open Full Details')),
              ),
            ),
            if (event.sourceNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${l10n.text('资料说明', 'Source Note')}: ${event.sourceNotes.first}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (sourceNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${l10n.text('来源实体', 'Source Entities')}: ${sourceNames.join(' / ')}',
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
    final l10n = AppL10n.of(context);
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
        .map((id) {
          final source = sourcesById[id];
          if (source == null) return id;
          return l10n.isZh ? source.sourceNameZh : source.sourceNameEn;
        })
        .toList(growable: false);
    final bioShort = l10n.isZh ? person.bioShortZh : person.bioShortEn;
    final contribution = l10n.isZh
        ? person.contributionZh
        : person.contributionEn;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              l10n.displayName(person.nameZh, person.nameEn),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(l10n.roleLabel(person.role)),
            if (person.activeYears.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoChip(
                label: l10n.text('活跃年代', 'Active Years'),
                value: person.activeYears,
              ),
            ],
            if (birthPlace != null || deathPlace != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (birthPlace != null)
                    _InfoChip(
                      label: l10n.text('出生地', 'Birth Place'),
                      value: l10n.displayName(
                        birthPlace.nameZh,
                        birthPlace.nameEn,
                      ),
                    ),
                  if (deathPlace != null)
                    _InfoChip(
                      label: l10n.text('逝世地', 'Death Place'),
                      value: l10n.displayName(
                        deathPlace.nameZh,
                        deathPlace.nameEn,
                      ),
                    ),
                ],
              ),
            ],
            if (bioShort.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.text('人物简介', 'Biography'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(bioShort),
            ],
            if (contribution.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.text('历史作用', 'Historical Role'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(contribution),
            ],
            if (relatedTerritories.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.text('相关政权', 'Related Territories'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: relatedTerritories
                    .map(
                      (territory) => ActionChip(
                        avatar: const Icon(Icons.public, size: 18),
                        label: Text(
                          l10n.displayName(territory.nameZh, territory.nameEn),
                        ),
                        onPressed: () => onTerritorySelected(territory.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (relatedEvents.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.text('相关事件', 'Related Events'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final event in relatedEvents)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(l10n.displayName(event.titleZh, event.titleEn)),
                    subtitle: Text(
                      '${l10n.formatYear(event.year)} · ${l10n.isZh ? event.locationNameZh : event.locationNameEn}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onEventSelected(event.id),
                  ),
                ),
            ],
            if (person.sourceNotes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.text('资料说明', 'Source Notes'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                '${l10n.text('来源实体', 'Source Entities')}: ${sourceNames.join(' / ')}',
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

Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final buffer = StringBuffer();
  if (cleaned.length == 6) {
    buffer.write('ff');
  }
  buffer.write(cleaned);
  return Color(int.parse(buffer.toString(), radix: 16));
}

import 'dart:async';

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

const _maxConcurrentGeometryLoads = 4;

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
  final AtlasRepository _geometryRepository = AtlasRepository();
  final Map<String, List<AtlasPolygonFeature>> _loadedPolygonsByGeometryId = {};
  final Map<String, Future<_LoadedPolygonMaps>> _polygonFutureCache = {};
  int _loadedPolygonCacheVersion = 0;
  Timer? _storyPlaybackTimer;
  bool _isMapReady = false;
  bool _isStoryPlaying = false;
  bool _isPresentationMode = false;
  late final Map<String, Territory> _territoriesById;
  late final Map<String, HistoricalPerson> _peopleById;
  late final Map<String, HistoricalEvent> _eventsById;
  late final Map<String, PlaceRecord> _placesById;
  late final Map<String, SourceRecord> _sourcesById;
  late final Map<String, GeometryAssetRecord> _geometryAssetsById;

  AtlasData get _data => widget.data;
  AtlasExplorerController get _controller =>
      ref.read(atlasExplorerControllerProvider(_data));

  @override
  void initState() {
    super.initState();
    _territoriesById = {
      for (final territory in _data.territories) territory.id: territory,
    };
    _peopleById = {for (final person in _data.people) person.id: person};
    _eventsById = {for (final event in _data.events) event.id: event};
    _placesById = {for (final place in _data.places) place.id: place};
    _sourcesById = {for (final source in _data.sources) source.id: source};
    _geometryAssetsById = {
      for (final geometry in _data.geometryAssets) geometry.id: geometry,
    };
    _loadedPolygonsByGeometryId.addAll(_data.polygonsByGeometryId);
  }

  Future<_LoadedPolygonMaps> _loadPolygonsForSnapshots(
    List<TerritorySnapshot> snapshots,
  ) {
    final geometryRefs =
        snapshots
            .expand((snapshot) => snapshot.geometryRefs)
            .toSet()
            .toList(growable: false)
          ..sort((a, b) {
            final priorityComparison =
                _geometryLoadPriority(a, snapshots) -
                _geometryLoadPriority(b, snapshots);
            if (priorityComparison != 0) return priorityComparison;
            return a.compareTo(b);
          });
    final cacheKey = geometryRefs.join('|');
    return _polygonFutureCache.putIfAbsent(cacheKey, () async {
      final geometryAssetsById = _geometryAssetsById;
      final missingGeometryRefs = geometryRefs
          .where((geometryRef) {
            return !_loadedPolygonsByGeometryId.containsKey(geometryRef) &&
                geometryAssetsById.containsKey(geometryRef);
          })
          .toList(growable: false);
      await _loadMissingPolygons(missingGeometryRefs);
      return _mapsFromCache(snapshots, version: _loadedPolygonCacheVersion);
    });
  }

  Future<void> _loadMissingPolygons(List<String> geometryRefs) async {
    for (var index = 0; index < geometryRefs.length;) {
      final end = (index + _maxConcurrentGeometryLoads).clamp(
        0,
        geometryRefs.length,
      );
      final batch = geometryRefs.sublist(index, end);
      final loadedEntries = await Future.wait(
        batch.map((geometryRef) async {
          final geometry = _geometryAssetsById[geometryRef]!;
          final polygons = await _geometryRepository.loadGeoJsonByPath(
            geometryRef,
            geometry.id,
            geometry.assetPath,
          );
          return MapEntry(geometryRef, polygons);
        }),
      );
      for (final entry in loadedEntries) {
        _loadedPolygonsByGeometryId[entry.key] = entry.value;
      }
      _loadedPolygonCacheVersion++;
      if (mounted) setState(() {});
      index = end;
    }
  }

  int _geometryLoadPriority(
    String geometryRef,
    List<TerritorySnapshot> snapshots,
  ) {
    final controller = _controller;
    final storyHighlights = controller.activeStorylineHighlightTerritoryIds;
    for (final snapshot in snapshots) {
      if (!snapshot.geometryRefs.contains(geometryRef)) continue;
      if (snapshot.territoryId == controller.selectedTerritoryId) return 0;
      if (storyHighlights.contains(snapshot.territoryId)) return 1;
      if (controller.civilizationTerritoryIds.contains(snapshot.territoryId)) {
        return 2;
      }
    }
    return 3;
  }

  _LoadedPolygonMaps _mapsFromCache(
    List<TerritorySnapshot> snapshots, {
    required int version,
  }) {
    final geometryRefs = <String>{
      'world_base_modern',
      for (final snapshot in snapshots) ...snapshot.geometryRefs,
    };
    final polygonsBySnapshotId = <String, List<AtlasPolygonFeature>>{};
    for (final snapshot in snapshots) {
      polygonsBySnapshotId[snapshot.id] = snapshot.geometryRefs
          .expand((geometryRef) {
            return _loadedPolygonsByGeometryId[geometryRef] ??
                const <AtlasPolygonFeature>[];
          })
          .toList(growable: false);
    }

    return _LoadedPolygonMaps(
      polygonsBySnapshotId: polygonsBySnapshotId,
      polygonsByGeometryId: {
        for (final geometryRef in geometryRefs)
          if (_loadedPolygonsByGeometryId[geometryRef] case final polygons?)
            geometryRef: polygons,
      },
      version: version,
    );
  }

  @override
  void dispose() {
    _stopStoryPlayback();
    _polygonHitNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(atlasExplorerControllerProvider(_data));
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final timelineYears = _data.scope.timelineYears;
    final focusYears = controller.activeCivilizationFocusYears;
    final minTimelineYear = timelineYears.first;
    final maxTimelineYear = timelineYears.last;
    final currentSnapshots = controller.currentSnapshots;
    final mapPanel = FutureBuilder<_LoadedPolygonMaps>(
      future: _loadPolygonsForSnapshots(currentSnapshots),
      builder: (context, snapshot) {
        final loadedMaps =
            snapshot.data ??
            _mapsFromCache(
              currentSnapshots,
              version: _loadedPolygonCacheVersion,
            );
        return Stack(
          children: [
            _MapPanel(
              mapController: _mapController,
              snapshots: currentSnapshots,
              polygonsBySnapshotId: loadedMaps.polygonsBySnapshotId,
              polygonsByGeometryId: loadedMaps.polygonsByGeometryId,
              geometryAssetsById: _geometryAssetsById,
              territoriesById: _territoriesById,
              selectedTerritoryId: controller.selectedTerritoryId,
              civilizationHighlightTerritoryIds:
                  controller.civilizationTerritoryIds,
              storyHighlightTerritoryIds:
                  controller.activeStorylineHighlightTerritoryIds,
              storylineRoutePoints: controller.activeStorylineRoutePoints,
              storylineRoutePointIndex:
                  controller.activeStorylineRoutePointIndex,
              polygonHitNotifier: _polygonHitNotifier,
              polygonCacheVersion: loadedMaps.version,
              onPolygonTap: _handlePolygonTap,
              onMapReady: _handleMapReady,
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        );
      },
    );
    final detailPanel = _DetailPanel(
      scope: _data.scope,
      selectedYear: controller.selectedYear,
      scene: controller.currentScene,
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

    final storyPanel = controller.activeStoryline != null
        ? _StorylinePanel(
            controller: controller,
            isPlaying: _isStoryPlaying,
            isPresentationMode: _isPresentationMode,
            onMapMove: () => _moveMapToSelection(controller),
            onPlaybackToggle: () => _toggleStoryPlayback(controller),
            onPresentationToggle: _togglePresentationMode,
            onExit: () => _exitStoryline(controller),
          )
        : null;

    if (_isPresentationMode && storyPanel != null) {
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(child: mapPanel),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (constraints.maxWidth * 0.42).clamp(
                          420.0,
                          720.0,
                        ),
                        maxHeight: (constraints.maxHeight * 0.36).clamp(
                          220.0,
                          320.0,
                        ),
                      ),
                      child: SingleChildScrollView(child: storyPanel),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

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
              if (storyPanel != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.sizeOf(context).height * 0.24).clamp(
                      180.0,
                      260.0,
                    ),
                  ),
                  child: SingleChildScrollView(child: storyPanel),
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
                            Text(
                              '${l10n.text('选择年份', 'Selected')}: ${l10n.formatYear(controller.selectedYear)} · '
                              '${l10n.text('地图场景', 'Scene')}: ${l10n.formatYear(controller.activeSceneYear)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l10n.text('文明视角', 'Civilization Lens'),
                              style: theme.textTheme.labelLarge,
                            ),
                            for (final civilization in _data.civilizations)
                              ChoiceChip(
                                label: Text(
                                  l10n.displayName(
                                    civilization.nameZh,
                                    civilization.nameEn,
                                  ),
                                ),
                                selected:
                                    civilization.id ==
                                    controller.activeCivilizationId,
                                onSelected: (_) =>
                                    controller.setCivilization(civilization.id),
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
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: focusYears.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final year = focusYears[index];
                              return ChoiceChip(
                                label: Text(l10n.formatYear(year)),
                                selected: year == controller.activeSceneYear,
                                onSelected: (_) => _selectYear(year),
                              );
                            },
                          ),
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
    _stopStoryPlayback();
    final l10n = AppL10n.of(context);
    final visibleStorylines = _storylinesForActiveCivilization(controller);
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
                child: visibleStorylines.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.text(
                              '当前文明视角暂未配置完整故事线，可先通过地图和关键年份浏览相关政权。',
                              'This civilization lens does not have a full storyline yet. Use the map and focus years to browse related polities.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visibleStorylines.length,
                        itemBuilder: (context, index) {
                          final story = visibleStorylines[index];
                          if (story.arcs.isNotEmpty) {
                            return ExpansionTile(
                              leading: Text(
                                story.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              title: Text(
                                l10n.isZh ? story.titleZh : story.titleEn,
                              ),
                              subtitle: Text(
                                l10n.isZh
                                    ? story.descriptionZh
                                    : story.descriptionEn,
                              ),
                              children: [
                                for (final entry in story.arcs.indexed)
                                  ListTile(
                                    contentPadding:
                                        const EdgeInsetsDirectional.only(
                                          start: 56,
                                          end: 16,
                                        ),
                                    leading: CircleAvatar(
                                      child: Text('${entry.$1 + 1}'),
                                    ),
                                    title: Text(
                                      l10n.displayName(
                                        entry.$2.titleZh,
                                        entry.$2.titleEn,
                                      ),
                                    ),
                                    subtitle: Text(
                                      l10n.displayName(
                                        entry.$2.descriptionZh,
                                        entry.$2.descriptionEn,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _startStoryline(
                                        controller,
                                        story,
                                        arcIndex: entry.$1,
                                      );
                                    },
                                  ),
                              ],
                            );
                          }
                          return ListTile(
                            leading: Text(
                              story.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              l10n.isZh ? story.titleZh : story.titleEn,
                            ),
                            subtitle: Text(
                              l10n.isZh
                                  ? story.descriptionZh
                                  : story.descriptionEn,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              _startStoryline(controller, story);
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

  List<Storyline> _storylinesForActiveCivilization(
    AtlasExplorerController controller,
  ) {
    final storylineIds = controller.activeCivilization.storylineIds;
    if (controller.activeCivilizationId == 'all_world') return _data.storylines;
    if (storylineIds.isEmpty) return const [];
    final storylinesById = {
      for (final storyline in _data.storylines) storyline.id: storyline,
    };
    return storylineIds
        .map((id) => storylinesById[id])
        .whereType<Storyline>()
        .toList(growable: false);
  }

  void _startStoryline(
    AtlasExplorerController controller,
    Storyline story, {
    int arcIndex = 0,
  }) {
    controller.startStoryline(story, arcIndex: arcIndex);
    setState(() {
      _isPresentationMode = false;
    });
    _moveMapToSelection(controller);
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
    final camera = controller.activeStorylineCamera;
    if (camera != null) {
      _mapController.move(LatLng(camera.lat, camera.lng), camera.zoom);
      return;
    }
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

  void _toggleStoryPlayback(AtlasExplorerController controller) {
    if (_isStoryPlaying) {
      _stopStoryPlayback();
      return;
    }
    if (controller.activeStoryline == null ||
        controller.activeStorylineStepCount <= 1) {
      return;
    }
    setState(() => _isStoryPlaying = true);
    _storyPlaybackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final activeController = _controller;
      final isLastStep =
          activeController.storylineEventIndex >=
          activeController.activeStorylineStepCount - 1;
      if (activeController.activeStoryline == null || isLastStep) {
        _stopStoryPlayback();
        return;
      }
      activeController.nextStorylineEvent();
      _moveMapToSelection(activeController);
    });
  }

  void _stopStoryPlayback() {
    _storyPlaybackTimer?.cancel();
    _storyPlaybackTimer = null;
    if (_isStoryPlaying && mounted) {
      setState(() => _isStoryPlaying = false);
    } else {
      _isStoryPlaying = false;
    }
  }

  void _togglePresentationMode() {
    setState(() {
      _isPresentationMode = !_isPresentationMode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _moveMapToSelection(_controller);
    });
  }

  void _exitStoryline(AtlasExplorerController controller) {
    _stopStoryPlayback();
    setState(() => _isPresentationMode = false);
    controller.exitStoryline();
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
  const _StorylinePanel({
    required this.controller,
    required this.isPlaying,
    required this.isPresentationMode,
    required this.onMapMove,
    required this.onPlaybackToggle,
    required this.onPresentationToggle,
    required this.onExit,
  });

  final AtlasExplorerController controller;
  final bool isPlaying;
  final bool isPresentationMode;
  final VoidCallback onMapMove;
  final VoidCallback onPlaybackToggle;
  final VoidCallback onPresentationToggle;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final story = controller.activeStoryline!;
    final arc = controller.activeStoryArc;
    final eventIndex = controller.storylineEventIndex;
    final totalEvents = controller.activeStorylineStepCount;
    final displayIndex = totalEvents == 0 ? 0 : eventIndex + 1;
    final chapter = controller.activeStorylineChapter;
    final titleZh = chapter?.titleZh.isNotEmpty == true
        ? chapter!.titleZh
        : story.titleZh;
    final titleEn = chapter?.titleEn.isNotEmpty == true
        ? chapter!.titleEn
        : story.titleEn;
    final scriptZh = chapter?.scriptZh.isNotEmpty == true
        ? chapter!.scriptZh
        : story.narrativeIntro.textZh;
    final scriptEn = chapter?.scriptEn.isNotEmpty == true
        ? chapter!.scriptEn
        : story.narrativeIntro.textEn;
    final sceneSetting = l10n.isZh
        ? chapter?.sceneSettingZh ?? ''
        : chapter?.sceneSettingEn ?? '';
    final characterBeat = l10n.isZh
        ? chapter?.characterBeatZh ?? ''
        : chapter?.characterBeatEn ?? '';
    final storyQuestion = l10n.isZh
        ? chapter?.storyQuestionZh ?? ''
        : chapter?.storyQuestionEn ?? '';
    final sourceNote = l10n.isZh ? story.sourceNoteZh : story.sourceNoteEn;
    final selectedEvent = controller.selectedEvent;
    final activeCharacters = _activeStoryCharacters(
      controller.activeStoryCharacters,
      chapter,
    );
    final currentRoutePoint = controller.activeStorylineRoutePoints.isEmpty
        ? null
        : controller.activeStorylineRoutePoints[controller
              .activeStorylineRoutePointIndex];
    final yearLabel = chapter?.year != null
        ? l10n.formatYear(chapter!.year!)
        : l10n.formatYear(controller.selectedYear);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: EdgeInsets.all(isPresentationMode ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: onPlaybackToggle,
                  tooltip: l10n.text('播放故事', 'Play story'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${story.emoji} ${l10n.isZh ? titleZh : titleEn}',
                    style:
                        (isPresentationMode
                                ? theme.textTheme.headlineSmall
                                : theme.textTheme.titleMedium)
                            ?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ),
                Text(
                  '$displayIndex / $totalEvents',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isPresentationMode
                        ? Icons.fullscreen_exit
                        : Icons.present_to_all,
                  ),
                  onPressed: onPresentationToggle,
                  tooltip: l10n.text('演示模式', 'Presentation mode'),
                  color: theme.colorScheme.onTertiaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onExit,
                  tooltip: l10n.text('退出故事', 'Exit Story'),
                  color: theme.colorScheme.onTertiaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (arc != null) ...[
              const SizedBox(height: 6),
              Text(
                l10n.displayName(arc.titleZh, arc.titleEn),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer.withValues(
                    alpha: 0.78,
                  ),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (l10n
                  .displayName(arc.coreQuestionZh, arc.coreQuestionEn)
                  .isNotEmpty)
                Text(
                  l10n.displayName(arc.coreQuestionZh, arc.coreQuestionEn),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
            ],
            if (currentRoutePoint != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(yearLabel),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.place, size: 16),
                    label: Text(
                      l10n.isZh
                          ? currentRoutePoint.labelZh
                          : currentRoutePoint.labelEn,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (activeCharacters.isNotEmpty) ...[
              _StoryCharacterStrip(
                characters: activeCharacters,
                isPresentationMode: isPresentationMode,
              ),
              const SizedBox(height: 10),
            ],
            if (chapter?.interactions.isNotEmpty == true) ...[
              _StoryInteractionList(
                interactions: chapter!.interactions,
                characters: controller.activeStoryCharacters,
                isPresentationMode: isPresentationMode,
              ),
              const SizedBox(height: 10),
            ],
            if (sceneSetting.isNotEmpty ||
                characterBeat.isNotEmpty ||
                storyQuestion.isNotEmpty) ...[
              _StoryBeatGrid(
                sceneSetting: sceneSetting,
                characterBeat: characterBeat,
                storyQuestion: storyQuestion,
                isPresentationMode: isPresentationMode,
              ),
              const SizedBox(height: 10),
            ],
            Text(
              l10n.isZh ? scriptZh : scriptEn,
              style:
                  (isPresentationMode
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.9,
                        ),
                      ),
              maxLines: isPresentationMode ? 8 : 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (selectedEvent != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onTertiaryContainer.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.displayName(
                        selectedEvent.titleZh,
                        selectedEvent.titleEn,
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.displayName(
                        selectedEvent.summaryZh,
                        selectedEvent.summaryEn,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.82,
                        ),
                      ),
                      maxLines: isPresentationMode ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            if (sourceNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                sourceNote,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer.withValues(
                    alpha: 0.72,
                  ),
                ),
              ),
            ],
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
                          if (isPlaying) onPlaybackToggle();
                          controller.prevStorylineEvent();
                          onMapMove();
                        }
                      : null,
                  child: Text(l10n.text('上一步', 'Previous')),
                ),
                FilledButton.tonal(
                  onPressed: eventIndex < totalEvents - 1
                      ? () {
                          if (isPlaying) onPlaybackToggle();
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

  List<StoryCharacter> _activeStoryCharacters(
    List<StoryCharacter> characters,
    StoryChapter? chapter,
  ) {
    if (characters.isEmpty) return const [];
    final activeIds = chapter?.activeCharacterIds ?? const <String>[];
    if (activeIds.isEmpty) return characters;
    final activeIdSet = activeIds.toSet();
    return characters
        .where((character) => activeIdSet.contains(character.id))
        .toList(growable: false);
  }
}

class _StoryCharacterStrip extends StatelessWidget {
  const _StoryCharacterStrip({
    required this.characters,
    required this.isPresentationMode,
  });

  final List<StoryCharacter> characters;
  final bool isPresentationMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isPresentationMode ? 96 : 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: characters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _StoryCharacterCard(
            character: characters[index],
            isPresentationMode: isPresentationMode,
          );
        },
      ),
    );
  }
}

class _StoryCharacterCard extends StatelessWidget {
  const _StoryCharacterCard({
    required this.character,
    required this.isPresentationMode,
  });

  final StoryCharacter character;
  final bool isPresentationMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final label = l10n.displayName(character.labelZh, character.labelEn);
    final role = l10n.displayName(character.roleZh, character.roleEn);
    final goal = l10n.displayName(character.goalZh, character.goalEn);
    return Container(
      width: isPresentationMode ? 260 : 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isPresentationMode ? 28 : 24,
            backgroundColor: theme.colorScheme.onTertiaryContainer.withValues(
              alpha: 0.14,
            ),
            child: Text(
              character.avatarSymbol,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer.withValues(
                      alpha: 0.78,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (goal.isNotEmpty)
                  Text(
                    goal,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer.withValues(
                        alpha: 0.66,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryInteractionList extends StatelessWidget {
  const _StoryInteractionList({
    required this.interactions,
    required this.characters,
    required this.isPresentationMode,
  });

  final List<StoryInteraction> interactions;
  final List<StoryCharacter> characters;
  final bool isPresentationMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final interaction in interactions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _StoryInteractionCard(
              interaction: interaction,
              characters: characters,
              isPresentationMode: isPresentationMode,
            ),
          ),
      ],
    );
  }
}

class _StoryInteractionCard extends StatelessWidget {
  const _StoryInteractionCard({
    required this.interaction,
    required this.characters,
    required this.isPresentationMode,
  });

  final StoryInteraction interaction;
  final List<StoryCharacter> characters;
  final bool isPresentationMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final actor = _characterById(interaction.actorId);
    final target = _characterById(interaction.targetId);
    final actorLabel = actor == null
        ? interaction.actorId
        : l10n.displayName(actor.labelZh, actor.labelEn);
    final targetLabel = target == null
        ? l10n.displayName(interaction.targetLabelZh, interaction.targetLabelEn)
        : l10n.displayName(target.labelZh, target.labelEn);
    final relation = l10n.displayName(
      interaction.relationZh,
      interaction.relationEn,
    );
    final action = l10n.displayName(interaction.actionZh, interaction.actionEn);
    final outcome = l10n.displayName(
      interaction.outcomeZh,
      interaction.outcomeEn,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniActorPill(label: actorLabel, character: actor),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: theme.colorScheme.onTertiaryContainer.withValues(
                  alpha: 0.72,
                ),
              ),
              Chip(visualDensity: VisualDensity.compact, label: Text(relation)),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: theme.colorScheme.onTertiaryContainer.withValues(
                  alpha: 0.72,
                ),
              ),
              _MiniActorPill(label: targetLabel, character: target),
            ],
          ),
          if (action.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              action,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer.withValues(
                  alpha: 0.86,
                ),
              ),
              maxLines: isPresentationMode ? 3 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (outcome.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              outcome,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer.withValues(
                  alpha: 0.70,
                ),
                fontStyle: FontStyle.italic,
              ),
              maxLines: isPresentationMode ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  StoryCharacter? _characterById(String id) {
    for (final character in characters) {
      if (character.id == id) return character;
    }
    return null;
  }
}

class _MiniActorPill extends StatelessWidget {
  const _MiniActorPill({required this.label, required this.character});

  final String label;
  final StoryCharacter? character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: character == null
          ? null
          : CircleAvatar(
              child: Text(
                character!.avatarSymbol,
                style: const TextStyle(fontSize: 11),
              ),
            ),
      label: Text(label),
      labelStyle: theme.textTheme.labelSmall,
    );
  }
}

class _StoryBeatGrid extends StatelessWidget {
  const _StoryBeatGrid({
    required this.sceneSetting,
    required this.characterBeat,
    required this.storyQuestion,
    required this.isPresentationMode,
  });

  final String sceneSetting;
  final String characterBeat;
  final String storyQuestion;
  final bool isPresentationMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final items = [
      if (sceneSetting.isNotEmpty)
        (l10n.text('场景', 'Scene'), Icons.landscape, sceneSetting),
      if (characterBeat.isNotEmpty)
        (l10n.text('人物处境', 'Character'), Icons.person, characterBeat),
      if (storyQuestion.isNotEmpty)
        (l10n.text('悬念', 'Tension'), Icons.help_outline, storyQuestion),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          _StoryBeatChip(
            label: item.$1,
            icon: item.$2,
            value: item.$3,
            isPresentationMode: isPresentationMode,
          ),
      ],
    );
  }
}

class _StoryBeatChip extends StatelessWidget {
  const _StoryBeatChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.isPresentationMode,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool isPresentationMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: isPresentationMode ? 420 : 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer.withValues(
                    alpha: 0.82,
                  ),
                ),
                children: [
                  TextSpan(
                    text: '$label：',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedPolygonMaps {
  const _LoadedPolygonMaps({
    required this.polygonsBySnapshotId,
    required this.polygonsByGeometryId,
    required this.version,
  });

  final Map<String, List<AtlasPolygonFeature>> polygonsBySnapshotId;
  final Map<String, List<AtlasPolygonFeature>> polygonsByGeometryId;
  final int version;
}

class _ScopeSummary extends StatelessWidget {
  const _ScopeSummary({required this.scope, required this.selectedYear});

  final ProjectScope scope;
  final int selectedYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

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
              label: l10n.text('地图范围', 'Map Scope'),
              value: l10n.displayName(scope.themeLabelZh, scope.themeLabelEn),
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
    required this.geometryAssetsById,
    required this.territoriesById,
    required this.selectedTerritoryId,
    required this.civilizationHighlightTerritoryIds,
    required this.storyHighlightTerritoryIds,
    required this.storylineRoutePoints,
    required this.storylineRoutePointIndex,
    required this.polygonHitNotifier,
    required this.polygonCacheVersion,
    required this.onPolygonTap,
    required this.onMapReady,
  });

  final MapController mapController;
  final List<TerritorySnapshot> snapshots;
  final Map<String, List<AtlasPolygonFeature>> polygonsBySnapshotId;
  final Map<String, List<AtlasPolygonFeature>> polygonsByGeometryId;
  final Map<String, GeometryAssetRecord> geometryAssetsById;
  final Map<String, Territory> territoriesById;
  final String selectedTerritoryId;
  final Set<String> civilizationHighlightTerritoryIds;
  final List<String> storyHighlightTerritoryIds;
  final List<StoryRoutePoint> storylineRoutePoints;
  final int storylineRoutePointIndex;
  final LayerHitNotifier<String> polygonHitNotifier;
  final int polygonCacheVersion;
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
              if (widget.storylineRoutePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // The future path
                    Polyline(
                      points: widget.storylineRoutePoints
                          .map((point) => LatLng(point.lat, point.lng))
                          .toList(growable: false),
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4),
                      strokeWidth: 4.0,
                    ),
                    // The traversed path
                    Polyline(
                      points: widget.storylineRoutePoints
                          .take(widget.storylineRoutePointIndex + 1)
                          .map((point) => LatLng(point.lat, point.lng))
                          .toList(growable: false),
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              if (widget.storylineRoutePoints.isNotEmpty)
                MarkerLayer(
                  markers: widget.storylineRoutePoints
                      .asMap()
                      .entries
                      .map(
                        (entry) => Marker(
                          point: LatLng(entry.value.lat, entry.value.lng),
                          width: entry.key == widget.storylineRoutePointIndex
                              ? 28
                              : 18,
                          height: entry.key == widget.storylineRoutePointIndex
                              ? 28
                              : 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  entry.key == widget.storylineRoutePointIndex
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            child: entry.key == widget.storylineRoutePointIndex
                                ? Icon(
                                    Icons.person_pin_circle,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  )
                                : null,
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
      ...widget.civilizationHighlightTerritoryIds,
      ...widget.storyHighlightTerritoryIds,
      widget.polygonCacheVersion,
      ...widget.snapshots.map((snapshot) => snapshot.id),
    ].join('|');
    final cached = _polygonListCache[cacheKey];
    if (cached != null) return cached;

    final polygons = <Polygon<String>>[];
    final areaBySnapshotId = {
      for (final snapshot in widget.snapshots)
        snapshot.id: _snapshotApproxArea(snapshot),
    };
    final orderedSnapshots = [...widget.snapshots]
      ..sort((a, b) {
        final aContext = _isContextBoundary(_boundaryMeaningFor(a));
        final bContext = _isContextBoundary(_boundaryMeaningFor(b));
        if (aContext != bContext) return aContext ? -1 : 1;
        final aCivilizationHighlighted = _isCivilizationHighlighted(
          a.territoryId,
        );
        final bCivilizationHighlighted = _isCivilizationHighlighted(
          b.territoryId,
        );
        if (aCivilizationHighlighted != bCivilizationHighlighted) {
          return aCivilizationHighlighted ? 1 : -1;
        }
        final areaComparison = (areaBySnapshotId[b.id] ?? 0).compareTo(
          areaBySnapshotId[a.id] ?? 0,
        );
        if (areaComparison != 0) return areaComparison;
        final aHighlighted = _isStoryHighlighted(a.territoryId);
        final bHighlighted = _isStoryHighlighted(b.territoryId);
        if (aHighlighted != bHighlighted) return aHighlighted ? 1 : -1;
        final aSelected = a.territoryId == widget.selectedTerritoryId;
        final bSelected = b.territoryId == widget.selectedTerritoryId;
        if (aSelected != bSelected) return aSelected ? 1 : -1;
        return 0;
      });
    for (final snapshot in orderedSnapshots) {
      final territory = widget.territoriesById[snapshot.territoryId]!;
      final isSelected = snapshot.territoryId == widget.selectedTerritoryId;
      final isStoryHighlighted = _isStoryHighlighted(snapshot.territoryId);
      final isCivilizationHighlighted = _isCivilizationHighlighted(
        snapshot.territoryId,
      );
      final hasCivilizationLens =
          widget.civilizationHighlightTerritoryIds.isNotEmpty;
      final fillColor = colorFromHex(territory.color);
      final isContextBoundary = _isContextBoundary(
        _boundaryMeaningFor(snapshot),
      );
      final fillOpacity = isStoryHighlighted
          ? (isContextBoundary ? 0.34 : 0.48)
          : isSelected
          ? (isContextBoundary ? 0.30 : 0.42)
          : widget.storyHighlightTerritoryIds.isNotEmpty
          ? isCivilizationHighlighted
                ? (isContextBoundary ? 0.08 : 0.16)
                : (isContextBoundary ? 0.04 : 0.08)
          : hasCivilizationLens
          ? isCivilizationHighlighted
                ? (isContextBoundary ? 0.12 : 0.28)
                : (isContextBoundary ? 0.04 : 0.09)
          : (isContextBoundary ? 0.10 : 0.24);
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
            color: fillColor.withValues(alpha: fillOpacity),
            borderColor: isStoryHighlighted
                ? Colors.white
                : isSelected
                ? Colors.white
                : fillColor.withValues(
                    alpha: isCivilizationHighlighted
                        ? (isContextBoundary ? 0.65 : 1)
                        : (isContextBoundary ? 0.25 : 0.45),
                  ),
            borderStrokeWidth: isStoryHighlighted
                ? 4.0
                : isSelected
                ? 3.5
                : isCivilizationHighlighted
                ? (isContextBoundary ? 1.1 : 2.0)
                : (isContextBoundary ? 0.8 : 1.1),
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

  bool _isStoryHighlighted(String territoryId) {
    return widget.storyHighlightTerritoryIds.contains(territoryId);
  }

  bool _isCivilizationHighlighted(String territoryId) {
    return widget.civilizationHighlightTerritoryIds.isEmpty ||
        widget.civilizationHighlightTerritoryIds.contains(territoryId);
  }

  double _snapshotApproxArea(TerritorySnapshot snapshot) {
    final features = snapshot.geometryRefs
        .expand(
          (geometryRef) => widget.polygonsByGeometryId[geometryRef] ?? const [],
        )
        .toList(growable: false);
    var total = 0.0;
    for (final feature in features) {
      if (feature.rings.isEmpty || feature.rings.first.isEmpty) continue;
      var minLng = feature.rings.first.first[0];
      var maxLng = minLng;
      var minLat = feature.rings.first.first[1];
      var maxLat = minLat;
      for (final point in feature.rings.first) {
        final lng = point[0];
        final lat = point[1];
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
      }
      total += (maxLng - minLng).abs() * (maxLat - minLat).abs();
    }
    return total;
  }

  String _boundaryMeaningFor(TerritorySnapshot snapshot) {
    for (final geometryRef in snapshot.geometryRefs) {
      final boundaryMeaning =
          widget.geometryAssetsById[geometryRef]?.boundaryMeaning;
      if (boundaryMeaning != null && boundaryMeaning.isNotEmpty) {
        return boundaryMeaning;
      }
    }
    return '';
  }

  bool _isContextBoundary(String boundaryMeaning) {
    return const {
      'claimed',
      'disputed',
      'frontier_command',
      'influence',
      'schematic',
      'tributary_or_vassal',
    }.contains(boundaryMeaning);
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
                    label: l10n.text('同代世界', 'World Scene'),
                    value: l10n.text(
                      '$worldContextSnapshotCount 个政权',
                      '$worldContextSnapshotCount polities',
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
                    '• ${geometry.id} · ${geometry.geometryType} · ${geometry.revision} · ${geometry.simplificationLevel} · ${geometry.boundaryMeaning}',
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
              l10n.text('视角事件', 'Lens Events'),
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
                  subtitle: Text(_eventSubtitle(l10n, event)),
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
          ],
        ),
      ),
    );
  }

  String _eventSubtitle(AppL10n l10n, HistoricalEvent event) {
    final locationName = l10n.isZh
        ? event.locationNameZh
        : event.locationNameEn;
    if (locationName.isEmpty) return l10n.formatYear(event.year);
    return '${l10n.formatYear(event.year)} · $locationName';
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

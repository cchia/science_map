import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/atlas_models.dart';

final atlasExplorerControllerProvider =
    ChangeNotifierProvider.family<AtlasExplorerController, AtlasData>(
      (ref, data) => AtlasExplorerController(data),
    );

const _chinaFocusTerritoryIds = {
  'cao_wei',
  'eastern_han',
  'eastern_wu',
  'northern_wei',
  'qin',
  'qing_dynasty',
  'republic_of_china',
  'shu_han',
  'sui_dynasty',
  'tang_dynasty',
  'western_han',
  'xin',
  'cliopatria_kuomintang',
  'cliopatria_later_zhou_dynasty',
};

const _chinaFocusIdTerms = {
  'china',
  'shang',
  'zhou',
  'qin',
  'han',
  'chu',
  'wei',
  'shu',
  'wu',
  'yue',
  'qi',
  'yan',
  'zhao',
  'jin',
  'sui',
  'tang',
  'song',
  'liao',
  'xia',
  'yuan',
  'ming',
  'qing',
  'tibet',
  'dali',
  'nanzhao',
  'mongol',
  'taiping',
};

class AtlasExplorerController extends ChangeNotifier {
  AtlasExplorerController(this.data)
    : _selectedYear = data.scope.timelineYears.first,
      _selectedTerritoryId = data.scope.coreTerritoryIds.first {
    _syncSelectionForCurrentYear();
  }

  final AtlasData data;

  int _selectedYear;
  String _selectedTerritoryId;
  String? _selectedEventId;
  bool _showWorldContext = false;

  late final Map<String, TerritorySnapshot> _snapshotsById = {
    for (final snapshot in data.snapshots) snapshot.id: snapshot,
  };
  late final Map<String, List<TerritorySnapshot>> _snapshotsByTerritoryId =
      _groupSnapshotsByTerritory();
  late final Map<String, HistoricalEvent> _eventsById = {
    for (final event in data.events) event.id: event,
  };
  late final Map<String, Territory> _territoriesById = {
    for (final territory in data.territories) territory.id: territory,
  };

  Storyline? _activeStoryline;
  int _activeStoryArcIndex = 0;
  int _storylineEventIndex = 0;

  int get selectedYearIndex => _nearestTimelineYearIndex(_selectedYear);
  String get selectedTerritoryId => _selectedTerritoryId;
  String? get selectedEventId => _selectedEventId;
  int get selectedYear => _selectedYear;
  int get activeSceneYear => currentScene?.displayYear ?? _selectedYear;
  bool get showWorldContext => _showWorldContext;

  Storyline? get activeStoryline => _activeStoryline;
  StoryArc? get activeStoryArc {
    final story = _activeStoryline;
    if (story == null || story.arcs.isEmpty) return null;
    if (_activeStoryArcIndex < 0 || _activeStoryArcIndex >= story.arcs.length) {
      return null;
    }
    return story.arcs[_activeStoryArcIndex];
  }

  int get activeStoryArcIndex => _activeStoryArcIndex;
  int get storylineEventIndex => _storylineEventIndex;
  int get activeStorylineStepCount {
    final chapters = activeStoryChapters;
    if (chapters.isNotEmpty) return chapters.length;
    return activeStoryEventIds.length;
  }

  StoryChapter? get activeStorylineChapter {
    final chapters = activeStoryChapters;
    if (chapters.isEmpty) return null;
    if (_storylineEventIndex < 0 || _storylineEventIndex >= chapters.length) {
      return null;
    }
    return chapters[_storylineEventIndex];
  }

  StoryMapCamera? get activeStorylineCamera => activeStorylineChapter?.camera;

  List<StoryChapter> get activeStoryChapters {
    final arc = activeStoryArc;
    if (arc != null && arc.chapters.isNotEmpty) return arc.chapters;
    return _activeStoryline?.chapters ?? const [];
  }

  List<String> get activeStoryEventIds {
    final arc = activeStoryArc;
    if (arc != null && arc.eventIds.isNotEmpty) return arc.eventIds;
    return _activeStoryline?.eventIds ?? const [];
  }

  List<StoryCharacter> get activeStoryCharacters {
    final arc = activeStoryArc;
    if (arc != null && arc.characters.isNotEmpty) return arc.characters;
    return _activeStoryline?.characters ?? const [];
  }

  List<StoryRoutePoint> get activeStoryRoutePointsBase {
    final arc = activeStoryArc;
    if (arc != null && arc.routePoints.isNotEmpty) return arc.routePoints;
    return _activeStoryline?.routePoints ?? const [];
  }

  List<String> get activeStorylineHighlightTerritoryIds {
    final chapter = activeStorylineChapter;
    if (chapter != null && chapter.highlightTerritoryIds.isNotEmpty) {
      return chapter.highlightTerritoryIds;
    }
    final arc = activeStoryArc;
    if (arc != null && arc.territoryIds.isNotEmpty) return arc.territoryIds;
    final story = _activeStoryline;
    if (story == null) return const [];
    if (story.territoryIds.isNotEmpty) return story.territoryIds;
    return const [];
  }

  List<StoryRoutePoint> get activeStorylineRoutePoints {
    final routePoints = activeStoryRoutePointsBase;
    if (routePoints.isNotEmpty) return routePoints;
    return activeStoryEventIds
        .map(eventById)
        .whereType<HistoricalEvent>()
        .map(StoryRoutePoint.fromEvent)
        .toList(growable: false);
  }

  int get activeStorylineRoutePointIndex {
    final routePoints = activeStorylineRoutePoints;
    if (routePoints.isEmpty) return 0;
    final chapter = activeStorylineChapter;
    if (chapter != null && chapter.routePointId.isNotEmpty) {
      final index = routePoints.indexWhere(
        (point) => point.id == chapter.routePointId,
      );
      if (index >= 0) return index;
    }
    return _storylineEventIndex.clamp(0, routePoints.length - 1);
  }

  List<TerritorySnapshot> get activeSceneSnapshots {
    final scene = currentScene;
    if (scene == null) return const [];
    return scene.territorySnapshotIds
        .map((snapshotId) => _snapshotsById[snapshotId])
        .whereType<TerritorySnapshot>()
        .toList(growable: false);
  }

  List<TerritorySnapshot> get worldContextSnapshots => activeSceneSnapshots;

  int get worldContextSnapshotCount => worldContextSnapshots.length;

  List<TerritorySnapshot> get currentSnapshots {
    final snapshots = activeSceneSnapshots;
    if (_showWorldContext) return snapshots;
    if (snapshots.isEmpty) return const [];

    final focusTerritoryIds = {
      _selectedTerritoryId,
      ...activeStorylineHighlightTerritoryIds,
      if (activeStorylineChapter?.eventId case final eventId?)
        ...?eventById(eventId)?.territoryIds,
    };
    final seenTerritoryIds = <String>{};
    final focusedSnapshots = <TerritorySnapshot>[
      ...snapshots.where((snapshot) {
        if (!focusTerritoryIds.contains(snapshot.territoryId)) return false;
        return seenTerritoryIds.add(snapshot.territoryId);
      }),
      ..._chinaFocusSnapshots(
        snapshots,
        seenTerritoryIds: seenTerritoryIds,
      ),
    ];
    if (focusedSnapshots.isNotEmpty) return focusedSnapshots;
    return [snapshots.first];
  }

  int get visibleSnapshotCount => currentSnapshots.length;

  MapScene? get currentScene {
    if (data.mapScenes.isEmpty) return null;
    var bestScene = data.mapScenes.first;
    var bestDistance = (bestScene.displayYear - _selectedYear).abs();
    for (var index = 1; index < data.mapScenes.length; index++) {
      final scene = data.mapScenes[index];
      final distance = (scene.displayYear - _selectedYear).abs();
      if (distance < bestDistance) {
        bestScene = scene;
        bestDistance = distance;
      }
    }
    return bestScene;
  }

  TerritorySnapshot get selectedSnapshot {
    if (currentSnapshots.isEmpty) {
      // Fallback: return the first snapshot from all snapshots if current year has none
      return data.snapshots.first;
    }
    for (final snapshot in currentSnapshots) {
      if (snapshot.territoryId == _selectedTerritoryId) {
        return snapshot;
      }
    }
    return currentSnapshots.first;
  }

  Territory get selectedTerritory =>
      _territoriesById[selectedSnapshot.territoryId]!;

  HistoricalEvent? get selectedEvent =>
      _selectedEventId == null ? null : eventById(_selectedEventId!);

  List<HistoricalEvent> get territoryEvents {
    final highlightedEvents = selectedSnapshot.highlightedEventIds
        .map(eventById)
        .whereType<HistoricalEvent>()
        .toList(growable: false);
    final highlightedIds = highlightedEvents.map((event) => event.id).toSet();

    final remainingEvents =
        data.events
            .where(
              (event) =>
                  event.territoryIds.contains(selectedTerritory.id) &&
                  !highlightedIds.contains(event.id),
            )
            .toList()
          ..sort((a, b) => a.year.compareTo(b.year));

    return [...highlightedEvents, ...remainingEvents];
  }

  HistoricalEvent? eventById(String id) {
    return _eventsById[id];
  }

  List<TerritorySnapshot> _chinaFocusSnapshots(
    List<TerritorySnapshot> snapshots,
    {Set<String>? seenTerritoryIds}
  ) {
    final seenIds = seenTerritoryIds ?? <String>{};
    return snapshots.where((snapshot) {
      if (!_isChinaFocusTerritory(snapshot.territoryId)) return false;
      return seenIds.add(snapshot.territoryId);
    }).toList(growable: false);
  }

  bool _isChinaFocusTerritory(String territoryId) {
    if (_chinaFocusTerritoryIds.contains(territoryId)) return true;
    final idTerms = territoryId.toLowerCase().split('_').toSet();
    if (_chinaFocusIdTerms.any(idTerms.contains)) {
      return true;
    }
    final territory = _territoriesById[territoryId];
    final nameZh = territory?.nameZh ?? '';
    return nameZh.contains('中国') ||
        nameZh.contains('商') ||
        nameZh.contains('周') ||
        nameZh.contains('秦') ||
        nameZh.contains('汉') ||
        nameZh.contains('魏') ||
        nameZh.contains('蜀') ||
        nameZh.contains('吴') ||
        nameZh.contains('晋') ||
        nameZh.contains('隋') ||
        nameZh.contains('唐') ||
        nameZh.contains('宋') ||
        nameZh.contains('元') ||
        nameZh.contains('明') ||
        nameZh.contains('清');
  }

  void selectYearIndex(int index) {
    selectYear(data.scope.timelineYears[index]);
  }

  void selectYear(int year) {
    if (year == _selectedYear) return;
    _selectedYear = year;
    _syncSelectionForCurrentYear();
    notifyListeners();
  }

  void setShowWorldContext(bool value) {
    if (_showWorldContext == value) return;
    _showWorldContext = value;
    _syncSelectionForCurrentYear();
    notifyListeners();
  }

  void selectTerritory(String territoryId) {
    if (_selectedTerritoryId == territoryId) return;
    _selectedTerritoryId = territoryId;
    _selectedEventId = territoryEvents.isEmpty
        ? null
        : territoryEvents.first.id;
    notifyListeners();
  }

  void selectEvent(String eventId) {
    if (_selectedEventId == eventId) return;
    _selectedEventId = eventId;
    notifyListeners();
  }

  void jumpToTerritory(String territoryId) {
    final snapshot = _nearestSnapshotForTerritory(
      territoryId,
      targetYear: selectedYear,
    );
    if (snapshot == null) return;

    _selectedYear = snapshot.year;
    _selectedTerritoryId = snapshot.territoryId;
    _syncSelectionForCurrentYear();
    notifyListeners();
  }

  void jumpToEvent(HistoricalEvent event) {
    final territoryId = event.territoryIds.isNotEmpty
        ? event.territoryIds.first
        : _selectedTerritoryId;
    final snapshot = _nearestSnapshotForTerritory(
      territoryId,
      targetYear: event.year,
    );
    if (snapshot != null) {
      _selectedYear = event.year;
      _selectedTerritoryId = snapshot.territoryId;
    }
    _selectedEventId = event.id;
    _syncSelectionForCurrentYear();
    notifyListeners();
  }

  void startStoryline(Storyline story, {int arcIndex = 0}) {
    _activeStoryline = story;
    _activeStoryArcIndex = arcIndex;
    _storylineEventIndex = 0;
    _showWorldContext = false;
    _syncStorylineState();
    notifyListeners();
  }

  void selectStoryArc(int arcIndex) {
    final story = _activeStoryline;
    if (story == null) return;
    if (arcIndex < 0 || arcIndex >= story.arcs.length) return;
    _activeStoryArcIndex = arcIndex;
    _storylineEventIndex = 0;
    _syncStorylineState();
    notifyListeners();
  }

  void exitStoryline() {
    _activeStoryline = null;
    notifyListeners();
  }

  void nextStorylineEvent() {
    if (_activeStoryline == null) return;
    if (_storylineEventIndex < activeStorylineStepCount - 1) {
      _storylineEventIndex++;
      _syncStorylineState();
      notifyListeners();
    }
  }

  void prevStorylineEvent() {
    if (_activeStoryline == null) return;
    if (_storylineEventIndex > 0) {
      _storylineEventIndex--;
      _syncStorylineState();
      notifyListeners();
    }
  }

  void setStorylineEventIndex(int index) {
    if (_activeStoryline == null) return;
    if (index >= 0 && index < activeStorylineStepCount) {
      _storylineEventIndex = index;
      _syncStorylineState();
      notifyListeners();
    }
  }

  void _syncStorylineState() {
    if (_activeStoryline == null) return;
    final chapter = activeStorylineChapter;
    if (chapter != null) {
      if (chapter.eventId.isNotEmpty) {
        final event = eventById(chapter.eventId);
        if (event != null) {
          jumpToEvent(event);
          return;
        }
      }
      if (chapter.year != null) {
        _selectedYear = chapter.year!;
      }
      if (chapter.highlightTerritoryIds.isNotEmpty) {
        final snapshot = _nearestSnapshotForTerritory(
          chapter.highlightTerritoryIds.first,
          targetYear: chapter.year ?? _selectedYear,
        );
        if (snapshot != null) {
          _selectedTerritoryId = snapshot.territoryId;
        }
      }
      _syncSelectionForCurrentYear();
      return;
    }
    final eventIds = activeStoryEventIds;
    if (eventIds.isEmpty) return;

    final eventId = eventIds[_storylineEventIndex];
    final event = eventById(eventId);
    if (event != null) {
      jumpToEvent(event);
    }
  }

  TerritorySnapshot? _nearestSnapshotForTerritory(
    String territoryId, {
    required int targetYear,
  }) {
    final snapshots = _snapshotsByTerritoryId[territoryId] ?? const [];
    if (snapshots.isEmpty) return null;

    var bestSnapshot = snapshots.first;
    var bestDistance = (bestSnapshot.year - targetYear).abs();
    for (var index = 1; index < snapshots.length; index++) {
      final snapshot = snapshots[index];
      final distance = (snapshot.year - targetYear).abs();
      if (distance < bestDistance) {
        bestSnapshot = snapshot;
        bestDistance = distance;
      }
    }
    return bestSnapshot;
  }

  void _syncSelectionForCurrentYear() {
    if (currentSnapshots.isEmpty) return;

    final stillVisible = currentSnapshots.any(
      (snapshot) => snapshot.territoryId == _selectedTerritoryId,
    );
    if (!stillVisible) {
      _selectedTerritoryId = currentSnapshots.first.territoryId;
    }

    final eventIds = territoryEvents.map((event) => event.id).toSet();
    if (_selectedEventId == null || !eventIds.contains(_selectedEventId)) {
      _selectedEventId = territoryEvents.isEmpty
          ? null
          : territoryEvents.first.id;
    }
  }

  int _nearestTimelineYearIndex(int year) {
    var bestIndex = 0;
    var bestDistance = (data.scope.timelineYears.first - year).abs();
    for (var index = 1; index < data.scope.timelineYears.length; index++) {
      final distance = (data.scope.timelineYears[index] - year).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  Map<String, List<TerritorySnapshot>> _groupSnapshotsByTerritory() {
    final grouped = <String, List<TerritorySnapshot>>{};
    for (final snapshot in data.snapshots) {
      grouped.putIfAbsent(snapshot.territoryId, () => []).add(snapshot);
    }
    return grouped;
  }
}

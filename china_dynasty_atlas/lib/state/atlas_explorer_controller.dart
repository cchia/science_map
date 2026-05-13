import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/atlas_models.dart';

final atlasExplorerControllerProvider =
    ChangeNotifierProvider.family<AtlasExplorerController, AtlasData>(
      (ref, data) => AtlasExplorerController(data),
    );

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
  bool _showWorldContext = true;

  Storyline? _activeStoryline;
  int _storylineEventIndex = 0;

  int get selectedYearIndex => _nearestTimelineYearIndex(_selectedYear);
  String get selectedTerritoryId => _selectedTerritoryId;
  String? get selectedEventId => _selectedEventId;
  int get selectedYear => _selectedYear;
  int get activeSceneYear => currentScene?.displayYear ?? _selectedYear;
  bool get showWorldContext => _showWorldContext;

  Storyline? get activeStoryline => _activeStoryline;
  int get storylineEventIndex => _storylineEventIndex;

  List<TerritorySnapshot> get activeSceneSnapshots => data.snapshots
      .where((snapshot) => snapshot.year == activeSceneYear)
      .toList(growable: false);

  List<TerritorySnapshot> get worldContextSnapshots => activeSceneSnapshots
      .where((snapshot) => snapshot.id.startsWith('cliopatria_'))
      .toList(growable: false);

  int get worldContextSnapshotCount => worldContextSnapshots.length;

  List<TerritorySnapshot> get currentSnapshots {
    final snapshots = activeSceneSnapshots;
    if (_showWorldContext) return snapshots;
    return snapshots
        .where((snapshot) => !snapshot.id.startsWith('cliopatria_'))
        .toList(growable: false);
  }

  int get visibleSnapshotCount => currentSnapshots.length;

  MapScene? get currentScene {
    if (data.mapScenes.isEmpty) return null;
    final scenes = [...data.mapScenes]
      ..sort(
        (a, b) => (a.displayYear - _selectedYear).abs().compareTo(
          (b.displayYear - _selectedYear).abs(),
        ),
      );
    return scenes.first;
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
      data.territories.firstWhere((t) => t.id == selectedSnapshot.territoryId);

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
    for (final event in data.events) {
      if (event.id == id) return event;
    }
    return null;
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

  void startStoryline(Storyline story) {
    _activeStoryline = story;
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
    if (_storylineEventIndex < _activeStoryline!.eventIds.length - 1) {
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
    if (index >= 0 && index < _activeStoryline!.eventIds.length) {
      _storylineEventIndex = index;
      _syncStorylineState();
      notifyListeners();
    }
  }

  void _syncStorylineState() {
    if (_activeStoryline == null) return;
    if (_activeStoryline!.eventIds.isEmpty) return;

    final eventId = _activeStoryline!.eventIds[_storylineEventIndex];
    final event = eventById(eventId);
    if (event != null) {
      jumpToEvent(event);
    }
  }

  TerritorySnapshot? _nearestSnapshotForTerritory(
    String territoryId, {
    required int targetYear,
  }) {
    final snapshots = data.snapshots
        .where((snapshot) => snapshot.territoryId == territoryId)
        .toList(growable: false);
    if (snapshots.isEmpty) return null;

    snapshots.sort(
      (a, b) =>
          (a.year - targetYear).abs().compareTo((b.year - targetYear).abs()),
    );
    return snapshots.first;
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
}

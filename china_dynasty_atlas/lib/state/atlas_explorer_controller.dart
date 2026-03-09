import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/atlas_models.dart';

final atlasExplorerControllerProvider =
    ChangeNotifierProvider.family<AtlasExplorerController, AtlasData>(
      (ref, data) => AtlasExplorerController(data),
    );

class AtlasExplorerController extends ChangeNotifier {
  AtlasExplorerController(this.data)
    : _selectedYearIndex = 0,
      _selectedTerritoryId = data.scope.coreTerritoryIds.first {
    _syncSelectionForCurrentYear();
  }

  final AtlasData data;

  int _selectedYearIndex;
  String _selectedTerritoryId;
  String? _selectedEventId;

  int get selectedYearIndex => _selectedYearIndex;
  String get selectedTerritoryId => _selectedTerritoryId;
  String? get selectedEventId => _selectedEventId;
  int get selectedYear => data.scope.timelineYears[_selectedYearIndex];

  List<TerritorySnapshot> get currentSnapshots => data.snapshots
      .where((snapshot) => snapshot.year == selectedYear)
      .toList(growable: false);

  TerritorySnapshot get selectedSnapshot {
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

    final remainingEvents = data.events
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
    if (index == _selectedYearIndex) return;
    _selectedYearIndex = index;
    _syncSelectionForCurrentYear();
    notifyListeners();
  }

  void selectTerritory(String territoryId) {
    if (_selectedTerritoryId == territoryId) return;
    _selectedTerritoryId = territoryId;
    _selectedEventId = territoryEvents.isEmpty ? null : territoryEvents.first.id;
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

    final yearIndex = data.scope.timelineYears.indexOf(snapshot.year);
    if (yearIndex >= 0) {
      _selectedYearIndex = yearIndex;
    }
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
      final yearIndex = data.scope.timelineYears.indexOf(snapshot.year);
      if (yearIndex >= 0) {
        _selectedYearIndex = yearIndex;
      }
      _selectedTerritoryId = snapshot.territoryId;
    }
    _selectedEventId = event.id;
    _syncSelectionForCurrentYear();
    notifyListeners();
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
      _selectedEventId = territoryEvents.isEmpty ? null : territoryEvents.first.id;
    }
  }
}

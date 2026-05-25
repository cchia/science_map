import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/atlas_models.dart';

const _jsonComputeThresholdChars = 256 * 1024;
const _geoJsonComputeThresholdChars = 16 * 1024;

Map<String, dynamic> _decodeJsonObject(String raw) {
  return Map<String, dynamic>.from(json.decode(raw) as Map);
}

List<Map<String, dynamic>> _decodeJsonList(String raw) {
  final decoded = json.decode(raw) as List<dynamic>;
  return decoded
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList(growable: false);
}

class AtlasRepository {
  Future<AtlasData> load() async {
    final scopeJson = await _loadJsonObject('assets/config/project_scope.json');
    final scope = ProjectScope.fromJson(scopeJson);
    return _loadFromGlobalSchema(scope);
  }

  Future<Map<String, dynamic>> _loadJsonObject(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return raw.length <= _jsonComputeThresholdChars
        ? _decodeJsonObject(raw)
        : compute(_decodeJsonObject, raw);
  }

  Future<List<Map<String, dynamic>>> _loadJsonList(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return raw.length <= _jsonComputeThresholdChars
        ? _decodeJsonList(raw)
        : compute(_decodeJsonList, raw);
  }

  Future<AtlasData> _loadFromGlobalSchema(ProjectScope scope) async {
    final globalJson = await Future.wait([
      _loadJsonList('assets/global/territories.json'),
      _loadJsonList('assets/global/territory_snapshots.json'),
      _loadJsonList('assets/global/events.json'),
      _loadJsonList('assets/global/people.json'),
      _loadJsonList('assets/global/places.json'),
      _loadJsonList('assets/global/sources.json'),
      _loadJsonList('assets/global/geometry_manifest.json'),
    ]);
    final territoriesJson = globalJson[0];
    final snapshotsJson = globalJson[1];
    final eventsJson = globalJson[2];
    final peopleJson = globalJson[3];
    final placesJson = globalJson[4];
    final sourcesJson = globalJson[5];
    final geometryManifestJson = globalJson[6];
    final places = placesJson.map(_placeFromGlobal).toList(growable: false);
    final placesById = {for (final place in places) place.id: place};
    final sources = sourcesJson.map(_sourceFromGlobal).toList(growable: false);
    final sourcesById = {for (final source in sources) source.id: source};
    final geometryAssets = geometryManifestJson
        .map(_geometryAssetFromGlobal)
        .toList(growable: false);
    final geometryById = {
      for (final geometry in geometryAssets) geometry.id: geometry,
    };

    final territories = territoriesJson
        .map((json) => _territoryFromGlobal(json, placesById))
        .toList(growable: false);
    final snapshots = snapshotsJson
        .map((json) => _snapshotFromGlobal(json, sourcesById))
        .toList(growable: false);
    final events = eventsJson
        .map((json) => _eventFromGlobal(json, placesById, sourcesById))
        .toList(growable: false);
    final people = peopleJson
        .map((json) => _personFromGlobal(json, sourcesById))
        .toList(growable: false);

    List<Storyline> storylines = [];
    try {
      final storylinesJson = await _loadJsonList(
        'assets/global/storylines.json',
      );
      storylines = storylinesJson
          .map((json) => Storyline.fromJson(json))
          .toList(growable: false);
    } catch (e) {
      debugPrint('No storylines.json found or failed to parse: $e');
    }

    List<MapScene> mapScenes = [];
    try {
      final mapScenesJson = await _loadJsonList(
        'assets/global/map_scenes.json',
      );
      mapScenes = mapScenesJson
          .map((json) => MapScene.fromJson(json))
          .toList(growable: false);
    } catch (e) {
      debugPrint('No map_scenes.json found or failed to parse: $e');
    }

    final polygonsByGeometryId = <String, List<AtlasPolygonFeature>>{};

    final worldBaseGeometry = geometryById['world_base_modern'];
    if (worldBaseGeometry != null &&
        !polygonsByGeometryId.containsKey(worldBaseGeometry.id)) {
      polygonsByGeometryId[worldBaseGeometry.id] = await loadGeoJsonByPath(
        'world_base_modern',
        worldBaseGeometry.id,
        worldBaseGeometry.assetPath,
      );
    }

    return AtlasData(
      scope: scope,
      territories: territories,
      snapshots: snapshots,
      events: events,
      people: people,
      polygonsBySnapshotId: const {},
      polygonsByGeometryId: polygonsByGeometryId,
      places: places,
      sources: sources,
      geometryAssets: geometryAssets,
      controlZones: const [],
      storylines: storylines,
      mapScenes: mapScenes,
    );
  }

  Territory _territoryFromGlobal(
    Map<String, dynamic> json,
    Map<String, PlaceRecord> placesById,
  ) {
    final names = json['names'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final localizedNames =
        names['localizedNames'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final capitalPlaceIds = List<String>.from(
      json['capitalPlaceIds'] as List<dynamic>? ?? const [],
    );
    final capitalName = capitalPlaceIds.isEmpty
        ? ''
        : _localizedPlaceName(placesById[capitalPlaceIds.first]);

    final type = json['territoryType'] as String? ?? 'dynasty';

    final startJson =
        json['start'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final endJson = json['end'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return Territory(
      id: json['id'] as String,
      nameZh:
          (localizedNames['zh-Hans'] as String?) ??
          (names['primaryName'] as String? ?? ''),
      nameEn:
          (localizedNames['en'] as String?) ??
          (names['primaryName'] as String? ?? ''),
      type: type,
      summaryZh: json['summary'] as String? ?? '',
      summaryEn:
          json['summaryEn'] as String? ?? (json['summary'] as String? ?? ''),
      startDate: _historicalDate(startJson),
      endDate: _historicalDate(endJson),
      capital: capitalName,
      color: json['color'] as String? ?? _territoryColor(json['id'] as String),
      predecessors: List<String>.from(
        json['predecessorIds'] as List<dynamic>? ?? const [],
      ),
      successors: List<String>.from(
        json['successorIds'] as List<dynamic>? ?? const [],
      ),
      aliases: List<String>.from(
        names['aliases'] as List<dynamic>? ?? const [],
      ),
      summaryLongZh: json['summaryLong'] as String? ?? '',
      summaryLongEn:
          json['summaryLongEn'] as String? ??
          (json['summaryLong'] as String? ?? ''),
      governanceHighlightsZh: List<String>.from(
        json['governanceHighlights'] as List<dynamic>? ?? const [],
      ),
      governanceHighlightsEn: List<String>.from(
        json['governanceHighlightsEn'] as List<dynamic>? ??
            json['governanceHighlights'] as List<dynamic>? ??
            const [],
      ),
      legacyZh: List<String>.from(json['legacy'] as List<dynamic>? ?? const []),
      legacyEn: List<String>.from(
        json['legacyEn'] as List<dynamic>? ??
            json['legacy'] as List<dynamic>? ??
            const [],
      ),
      sourceRefs: List<String>.from(
        json['sourceRefs'] as List<dynamic>? ?? const [],
      ),
      capitalPlaceIds: capitalPlaceIds,
    );
  }

  TerritorySnapshot _snapshotFromGlobal(
    Map<String, dynamic> json,
    Map<String, SourceRecord> sourcesById,
  ) {
    final accuracy =
        json['accuracy'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final sourceRefs = List<String>.from(
      json['sourceRefs'] as List<dynamic>? ?? const [],
    );
    final disputeNotesZh = List<String>.from(
      json['disputeNotes'] as List<dynamic>? ?? const [],
    );
    final disputeNotesEn = List<String>.from(
      json['disputeNotesEn'] as List<dynamic>? ??
          json['disputeNotes'] as List<dynamic>? ??
          const [],
    );
    final sourceNotesZh = [
      for (final sourceRef in sourceRefs)
        if (sourcesById[sourceRef] != null)
          sourcesById[sourceRef]!.sourceNameZh,
      ...disputeNotesZh,
    ];
    final sourceNotesEn = [
      for (final sourceRef in sourceRefs)
        if (sourcesById[sourceRef] != null)
          sourcesById[sourceRef]!.sourceNameEn,
      ...disputeNotesEn,
    ];

    return TerritorySnapshot(
      id: json['id'] as String,
      territoryId: json['territoryId'] as String,
      year: json['displayYear'] as int? ?? 0,
      geoJsonAsset: '',
      focus: SnapshotFocus.fromJson(
        json['mapFocus'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      headlineZh: json['headline'] as String? ?? '',
      headlineEn:
          json['headlineEn'] as String? ?? (json['headline'] as String? ?? ''),
      territoryNoteZh: json['territoryNote'] as String? ?? '',
      territoryNoteEn:
          json['territoryNoteEn'] as String? ??
          (json['territoryNote'] as String? ?? ''),
      highlightedEventIds: List<String>.from(
        json['highlightedEventIds'] as List<dynamic>? ?? const [],
      ),
      boundaryHighlightsZh: List<String>.from(
        json['boundaryHighlights'] as List<dynamic>? ?? const [],
      ),
      boundaryHighlightsEn: List<String>.from(
        json['boundaryHighlightsEn'] as List<dynamic>? ??
            json['boundaryHighlights'] as List<dynamic>? ??
            const [],
      ),
      accuracyNoteZh: accuracy['note'] as String? ?? '',
      accuracyNoteEn:
          accuracy['noteEn'] as String? ?? (accuracy['note'] as String? ?? ''),
      sourceNotesZh: sourceNotesZh,
      sourceNotesEn: sourceNotesEn,
      sourceRefs: sourceRefs,
      geometryRefs: List<String>.from(
        json['geometryRefs'] as List<dynamic>? ?? const [],
      ),
      controlZoneIds: List<String>.from(
        json['controlZones'] as List<dynamic>? ?? const [],
      ),
      reviewStatus: json['reviewStatus'] as String? ?? '',
      accuracyLevel: accuracy['level'] as String? ?? '',
    );
  }

  HistoricalEvent _eventFromGlobal(
    Map<String, dynamic> json,
    Map<String, PlaceRecord> placesById,
    Map<String, SourceRecord> sourcesById,
  ) {
    final title = json['title'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final localizedTitle =
        title['localized'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final placeIds = List<String>.from(
      json['placeIds'] as List<dynamic>? ?? const [],
    );
    final firstPlace = placeIds.isEmpty ? null : placesById[placeIds.first];
    final locationNameZh = firstPlace?.nameZh ?? '';
    final locationNameEn = (firstPlace?.nameEn.isNotEmpty ?? false)
        ? firstPlace!.nameEn
        : (firstPlace?.nameZh ?? '');
    final sourceRefs = List<String>.from(
      json['sourceRefs'] as List<dynamic>? ?? const [],
    );
    final sourceNotes = [
      for (final sourceRef in sourceRefs)
        if (sourcesById[sourceRef] != null)
          sourcesById[sourceRef]!.sourceNameZh,
    ];

    final startJson =
        json['start'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return HistoricalEvent(
      id: json['id'] as String,
      titleZh:
          (localizedTitle['zh-Hans'] as String?) ??
          (json['displayTitle'] as String? ?? ''),
      titleEn:
          (localizedTitle['en'] as String?) ??
          (title['primary'] as String? ?? ''),
      startDate: _historicalDate(startJson),
      territoryIds: List<String>.from(
        json['territoryIds'] as List<dynamic>? ?? const [],
      ),
      locationNameZh: locationNameZh,
      locationNameEn: locationNameEn,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      summaryZh: json['summary'] as String? ?? '',
      summaryEn:
          json['summaryEn'] as String? ?? (json['summary'] as String? ?? ''),
      contentZh: json['content'] as String? ?? '',
      contentEn:
          json['contentEn'] as String? ?? (json['content'] as String? ?? ''),
      tags: List<String>.from(json['tags'] as List<dynamic>? ?? const []),
      relatedPeople: List<String>.from(
        json['relatedPersonIds'] as List<dynamic>? ?? const [],
      ),
      significanceZh: json['significance'] as String? ?? '',
      significanceEn:
          json['significanceEn'] as String? ??
          (json['significance'] as String? ?? ''),
      consequencesZh: List<String>.from(
        json['consequences'] as List<dynamic>? ?? const [],
      ),
      consequencesEn: List<String>.from(
        json['consequencesEn'] as List<dynamic>? ??
            json['consequences'] as List<dynamic>? ??
            const [],
      ),
      sourceNotes: sourceNotes,
      sourceRefs: sourceRefs,
      placeIds: placeIds,
      confidence: json['confidence'] as String? ?? '',
    );
  }

  HistoricalPerson _personFromGlobal(
    Map<String, dynamic> json,
    Map<String, SourceRecord> sourcesById,
  ) {
    final names = json['names'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final localizedNames =
        names['localizedNames'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final roles = List<String>.from(
      json['roles'] as List<dynamic>? ?? const [],
    );
    final sourceRefs = List<String>.from(
      json['sourceRefs'] as List<dynamic>? ?? const [],
    );
    final sourceNotes = [
      for (final sourceRef in sourceRefs)
        if (sourcesById[sourceRef] != null)
          sourcesById[sourceRef]!.sourceNameZh,
    ];

    return HistoricalPerson(
      id: json['id'] as String,
      nameZh:
          (localizedNames['zh-Hans'] as String?) ??
          (names['primaryName'] as String? ?? ''),
      nameEn:
          (localizedNames['en'] as String?) ??
          (names['primaryName'] as String? ?? ''),
      role: roles.isEmpty ? '' : roles.first,
      bioShortZh: json['bioShort'] as String? ?? '',
      bioShortEn:
          json['bioShortEn'] as String? ?? (json['bioShort'] as String? ?? ''),
      bioLongZh: json['bioLong'] as String? ?? '',
      bioLongEn:
          json['bioLongEn'] as String? ?? (json['bioLong'] as String? ?? ''),
      activeYears: json['activeRange'] as String? ?? '',
      relatedTerritoryIds: List<String>.from(
        json['relatedTerritoryIds'] as List<dynamic>? ?? const [],
      ),
      relatedEventIds: List<String>.from(
        json['relatedEventIds'] as List<dynamic>? ?? const [],
      ),
      contributionZh: json['contribution'] as String? ?? '',
      contributionEn:
          json['contributionEn'] as String? ??
          (json['contribution'] as String? ?? ''),
      sourceNotes: sourceNotes,
      sourceRefs: sourceRefs,
      birthPlaceId: json['birthPlaceId'] as String? ?? '',
      deathPlaceId: json['deathPlaceId'] as String? ?? '',
    );
  }

  PlaceRecord _placeFromGlobal(Map<String, dynamic> json) {
    final names = json['names'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final localizedNames =
        names['localizedNames'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return PlaceRecord(
      id: json['id'] as String,
      primaryName: names['primaryName'] as String? ?? '',
      nameZh:
          (localizedNames['zh-Hans'] as String?) ??
          (names['primaryName'] as String? ?? ''),
      nameEn:
          (localizedNames['en'] as String?) ??
          (names['primaryName'] as String? ?? ''),
      placeType: json['placeType'] as String? ?? '',
      modernCountryCode: json['modernCountryCode'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      parentPlaceId: json['parentPlaceId'] as String? ?? '',
      aliases: List<String>.from(json['aliases'] as List<dynamic>? ?? const []),
      sourceRefs: List<String>.from(
        json['sourceRefs'] as List<dynamic>? ?? const [],
      ),
    );
  }

  SourceRecord _sourceFromGlobal(Map<String, dynamic> json) {
    return SourceRecord(
      id: json['id'] as String,
      sourceNameZh:
          json['sourceNameZh'] as String? ??
          (json['sourceName'] as String? ?? ''),
      sourceNameEn:
          json['sourceNameEn'] as String? ??
          (json['sourceName'] as String? ?? ''),
      sourceType: json['sourceType'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      licenseName: json['licenseName'] as String? ?? '',
      licenseUrl: json['licenseUrl'] as String? ?? '',
      commercialUseAllowed: json['commercialUseAllowed'] as bool? ?? false,
      redistributionAllowed: json['redistributionAllowed'] as bool? ?? false,
      modificationAllowed: json['modificationAllowed'] as bool? ?? false,
      attributionRequired: json['attributionRequired'] as bool? ?? false,
      attributionText: json['attributionText'] as String? ?? '',
      approvalStatus: json['approvalStatus'] as String? ?? '',
      reviewDate: json['reviewDate'] as String? ?? '',
      reviewOwner: json['reviewOwner'] as String? ?? '',
      notesZh: json['notesZh'] as String? ?? (json['notes'] as String? ?? ''),
      notesEn: json['notesEn'] as String? ?? (json['notes'] as String? ?? ''),
    );
  }

  GeometryAssetRecord _geometryAssetFromGlobal(Map<String, dynamic> json) {
    return GeometryAssetRecord(
      id: json['id'] as String,
      assetPath: json['assetPath'] as String? ?? '',
      geometryType: json['geometryType'] as String? ?? '',
      regionScope: json['regionScope'] as String? ?? '',
      simplificationLevel: json['simplificationLevel'] as String? ?? '',
      licenseSourceId: json['licenseSourceId'] as String? ?? '',
      derivedFromSourceIds: List<String>.from(
        json['derivedFromSourceIds'] as List<dynamic>? ?? const [],
      ),
      projection: json['projection'] as String? ?? '',
      revision: json['revision'] as String? ?? '',
      editorNotes: json['editorNotes'] as String? ?? '',
      boundaryMeaning: json['boundaryMeaning'] as String? ?? '',
      accuracyTier: json['accuracyTier'] as String? ?? '',
      reviewStatus: json['reviewStatus'] as String? ?? '',
    );
  }

  HistoricalDate _historicalDate(Map<String, dynamic> date) {
    return HistoricalDate(
      year: (date['year'] as num?)?.toInt() ?? 0,
      month: (date['month'] as num?)?.toInt(),
      day: (date['day'] as num?)?.toInt(),
      datePrecision: date['datePrecision'] as String? ?? 'exact_year',
      displayLabel: date['displayLabel'] as String? ?? '',
    );
  }

  String _localizedPlaceName(PlaceRecord? place) {
    if (place == null) return '';
    if (place.nameZh.isNotEmpty) return place.nameZh;
    if (place.nameEn.isNotEmpty) return place.nameEn;
    return place.primaryName;
  }

  String _territoryColor(String territoryId) {
    switch (territoryId) {
      case 'qin':
        return '#B85C38';
      case 'western_han':
        return '#D9A441';
      case 'xin':
        return '#8F6F9C';
      case 'eastern_han':
        return '#4E7A52';
      default:
        return '#607D8B';
    }
  }

  Future<List<AtlasPolygonFeature>> loadGeoJsonByPath(
    String snapshotId,
    String geometryId,
    String assetPath,
  ) async {
    final raw = await rootBundle.loadString(assetPath);
    final payload = <String, dynamic>{
      'snapshotId': snapshotId,
      'geometryId': geometryId,
      'raw': raw,
    };
    final parsed = raw.length <= _geoJsonComputeThresholdChars
        ? _parseGeoJsonFeaturesInIsolate(payload)
        : await compute(_parseGeoJsonFeaturesInIsolate, payload);
    return parsed
        .map(
          (feature) => AtlasPolygonFeature(
            snapshotId: feature['snapshotId'] as String,
            geometryId: feature['geometryId'] as String,
            rings: (feature['rings'] as List<dynamic>)
                .map<List<List<double>>>(
                  (ring) => (ring as List<dynamic>)
                      .map<List<double>>(
                        (point) => [
                          (point as List<dynamic>)[0] as double,
                          point[1] as double,
                        ],
                      )
                      .toList(growable: false),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }
}

List<Map<String, dynamic>> _parseGeoJsonFeaturesInIsolate(
  Map<String, dynamic> payload,
) {
  final snapshotId = payload['snapshotId'] as String;
  final geometryId = payload['geometryId'] as String;
  final raw = payload['raw'] as String;

  final decoded = Map<String, dynamic>.from(json.decode(raw) as Map);
  final features = (decoded['features'] as List<dynamic>)
      .map((feature) => Map<String, dynamic>.from(feature as Map))
      .toList(growable: false);

  final polygons = <Map<String, dynamic>>[];
  for (final feature in features) {
    final geometry = Map<String, dynamic>.from(feature['geometry'] as Map);
    final type = geometry['type'] as String;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    if (type == 'Polygon') {
      polygons.add({
        'snapshotId': snapshotId,
        'geometryId': geometryId,
        'rings': _parsePolygonCoordinatesInIsolate(coordinates),
      });
    } else if (type == 'MultiPolygon') {
      for (final polygon in coordinates) {
        polygons.add({
          'snapshotId': snapshotId,
          'geometryId': geometryId,
          'rings': _parsePolygonCoordinatesInIsolate(polygon as List<dynamic>),
        });
      }
    }
  }

  return polygons;
}

List<List<List<double>>> _parsePolygonCoordinatesInIsolate(
  List<dynamic> polygon,
) {
  return polygon
      .map(
        (ring) => (ring as List<dynamic>)
            .map<List<double>>((point) {
              final coords = point as List<dynamic>;
              return <double>[
                _clampCoordinate((coords[0] as num).toDouble(), -180, 180),
                _clampCoordinate((coords[1] as num).toDouble(), -90, 90),
              ];
            })
            .toList(growable: false),
      )
      .toList(growable: false);
}

double _clampCoordinate(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

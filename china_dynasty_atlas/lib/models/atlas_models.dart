class ProjectScope {
  const ProjectScope({
    required this.projectId,
    required this.titleZh,
    required this.titleEn,
    required this.themeId,
    required this.themeLabelZh,
    required this.themeLabelEn,
    required this.mvpFocus,
    required this.coreTerritoryIds,
    required this.timelineYears,
    required this.recommendedExpansionYears,
  });

  factory ProjectScope.fromJson(Map<String, dynamic> json) {
    return ProjectScope(
      projectId: json['projectId'] as String,
      titleZh: json['titleZh'] as String,
      titleEn: json['titleEn'] as String,
      themeId: json['themeId'] as String,
      themeLabelZh: json['themeLabelZh'] as String,
      themeLabelEn: json['themeLabelEn'] as String,
      mvpFocus: json['mvpFocus'] as String,
      coreTerritoryIds: List<String>.from(
        json['coreTerritoryIds'] as List<dynamic>,
      ),
      timelineYears: List<int>.from(json['timelineYears'] as List<dynamic>),
      recommendedExpansionYears: List<int>.from(
        json['recommendedExpansionYears'] as List<dynamic>,
      ),
    );
  }

  final String projectId;
  final String titleZh;
  final String titleEn;
  final String themeId;
  final String themeLabelZh;
  final String themeLabelEn;
  final String mvpFocus;
  final List<String> coreTerritoryIds;
  final List<int> timelineYears;
  final List<int> recommendedExpansionYears;
}

class Territory {
  const Territory({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.type,
    required this.summary,
    required this.startYear,
    required this.endYear,
    required this.capital,
    required this.color,
    required this.predecessors,
    required this.successors,
    required this.aliases,
    required this.summaryLong,
    required this.governanceHighlights,
    required this.legacy,
    required this.sourceRefs,
    required this.capitalPlaceIds,
  });

  factory Territory.fromJson(Map<String, dynamic> json) {
    return Territory(
      id: json['id'] as String,
      nameZh: json['nameZh'] as String,
      nameEn: json['nameEn'] as String,
      type: json['type'] as String,
      summary: json['summary'] as String,
      startYear: json['startYear'] as int,
      endYear: json['endYear'] as int,
      capital: json['capital'] as String,
      color: json['color'] as String,
      predecessors: List<String>.from(json['predecessors'] as List<dynamic>),
      successors: List<String>.from(json['successors'] as List<dynamic>),
      aliases: List<String>.from(json['aliases'] as List<dynamic>),
      summaryLong: (json['summaryLong'] as String?) ?? '',
      governanceHighlights: List<String>.from(
        (json['governanceHighlights'] as List<dynamic>? ?? const []),
      ),
      legacy: List<String>.from((json['legacy'] as List<dynamic>? ?? const [])),
      sourceRefs: List<String>.from(
        (json['sourceRefs'] as List<dynamic>? ?? const []),
      ),
      capitalPlaceIds: List<String>.from(
        (json['capitalPlaceIds'] as List<dynamic>? ?? const []),
      ),
    );
  }

  final String id;
  final String nameZh;
  final String nameEn;
  final String type;
  final String summary;
  final int startYear;
  final int endYear;
  final String capital;
  final String color;
  final List<String> predecessors;
  final List<String> successors;
  final List<String> aliases;
  final String summaryLong;
  final List<String> governanceHighlights;
  final List<String> legacy;
  final List<String> sourceRefs;
  final List<String> capitalPlaceIds;
}

class SnapshotFocus {
  const SnapshotFocus({
    required this.lat,
    required this.lng,
    required this.zoom,
  });

  factory SnapshotFocus.fromJson(Map<String, dynamic> json) {
    return SnapshotFocus(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      zoom: (json['zoom'] as num).toDouble(),
    );
  }

  final double lat;
  final double lng;
  final double zoom;
}

class TerritorySnapshot {
  const TerritorySnapshot({
    required this.id,
    required this.territoryId,
    required this.year,
    required this.geoJsonAsset,
    required this.focus,
    required this.headline,
    required this.territoryNote,
    required this.highlightedEventIds,
    required this.boundaryHighlights,
    required this.accuracyNote,
    required this.sourceNotes,
    required this.sourceRefs,
    required this.geometryRefs,
    required this.controlZoneIds,
    required this.reviewStatus,
    required this.accuracyLevel,
  });

  factory TerritorySnapshot.fromJson(Map<String, dynamic> json) {
    return TerritorySnapshot(
      id: json['id'] as String,
      territoryId: json['territoryId'] as String,
      year: json['year'] as int,
      geoJsonAsset: json['geoJsonAsset'] as String,
      focus: SnapshotFocus.fromJson(json['focus'] as Map<String, dynamic>),
      headline: json['headline'] as String,
      territoryNote: json['territoryNote'] as String,
      highlightedEventIds: List<String>.from(
        json['highlightedEventIds'] as List<dynamic>,
      ),
      boundaryHighlights: List<String>.from(
        (json['boundaryHighlights'] as List<dynamic>? ?? const []),
      ),
      accuracyNote: (json['accuracyNote'] as String?) ?? '',
      sourceNotes: List<String>.from(
        (json['sourceNotes'] as List<dynamic>? ?? const []),
      ),
      sourceRefs: List<String>.from(
        (json['sourceRefs'] as List<dynamic>? ?? const []),
      ),
      geometryRefs: List<String>.from(
        (json['geometryRefs'] as List<dynamic>? ?? const []),
      ),
      controlZoneIds: List<String>.from(
        (json['controlZoneIds'] as List<dynamic>? ?? const []),
      ),
      reviewStatus: (json['reviewStatus'] as String?) ?? '',
      accuracyLevel: (json['accuracyLevel'] as String?) ?? '',
    );
  }

  final String id;
  final String territoryId;
  final int year;
  final String geoJsonAsset;
  final SnapshotFocus focus;
  final String headline;
  final String territoryNote;
  final List<String> highlightedEventIds;
  final List<String> boundaryHighlights;
  final String accuracyNote;
  final List<String> sourceNotes;
  final List<String> sourceRefs;
  final List<String> geometryRefs;
  final List<String> controlZoneIds;
  final String reviewStatus;
  final String accuracyLevel;
}

class HistoricalEvent {
  const HistoricalEvent({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.year,
    required this.territoryIds,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.summary,
    required this.content,
    required this.tags,
    required this.relatedPeople,
    required this.significance,
    required this.consequences,
    required this.sourceNotes,
    required this.sourceRefs,
    required this.placeIds,
    required this.confidence,
  });

  factory HistoricalEvent.fromJson(Map<String, dynamic> json) {
    return HistoricalEvent(
      id: json['id'] as String,
      titleZh: json['titleZh'] as String,
      titleEn: json['titleEn'] as String,
      year: json['year'] as int,
      territoryIds: List<String>.from(json['territoryIds'] as List<dynamic>),
      locationName: json['locationName'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      summary: json['summary'] as String,
      content: json['content'] as String,
      tags: List<String>.from(json['tags'] as List<dynamic>),
      relatedPeople: List<String>.from(json['relatedPeople'] as List<dynamic>),
      significance: (json['significance'] as String?) ?? '',
      consequences: List<String>.from(
        (json['consequences'] as List<dynamic>? ?? const []),
      ),
      sourceNotes: List<String>.from(
        (json['sourceNotes'] as List<dynamic>? ?? const []),
      ),
      sourceRefs: List<String>.from(
        (json['sourceRefs'] as List<dynamic>? ?? const []),
      ),
      placeIds: List<String>.from(
        (json['placeIds'] as List<dynamic>? ?? const []),
      ),
      confidence: (json['confidence'] as String?) ?? '',
    );
  }

  final String id;
  final String titleZh;
  final String titleEn;
  final int year;
  final List<String> territoryIds;
  final String locationName;
  final double lat;
  final double lng;
  final String summary;
  final String content;
  final List<String> tags;
  final List<String> relatedPeople;
  final String significance;
  final List<String> consequences;
  final List<String> sourceNotes;
  final List<String> sourceRefs;
  final List<String> placeIds;
  final String confidence;
}

class HistoricalPerson {
  const HistoricalPerson({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.role,
    required this.bioShort,
    required this.activeYears,
    required this.relatedTerritoryIds,
    required this.relatedEventIds,
    required this.contribution,
    required this.sourceNotes,
    required this.sourceRefs,
    required this.birthPlaceId,
    required this.deathPlaceId,
  });

  factory HistoricalPerson.fromJson(Map<String, dynamic> json) {
    return HistoricalPerson(
      id: json['id'] as String,
      nameZh: json['nameZh'] as String,
      nameEn: json['nameEn'] as String,
      role: json['role'] as String,
      bioShort: (json['bioShort'] as String?) ?? '',
      activeYears: (json['activeYears'] as String?) ?? '',
      relatedTerritoryIds: List<String>.from(
        (json['relatedTerritoryIds'] as List<dynamic>? ?? const []),
      ),
      relatedEventIds: List<String>.from(
        (json['relatedEventIds'] as List<dynamic>? ?? const []),
      ),
      contribution: (json['contribution'] as String?) ?? '',
      sourceNotes: List<String>.from(
        (json['sourceNotes'] as List<dynamic>? ?? const []),
      ),
      sourceRefs: List<String>.from(
        (json['sourceRefs'] as List<dynamic>? ?? const []),
      ),
      birthPlaceId: (json['birthPlaceId'] as String?) ?? '',
      deathPlaceId: (json['deathPlaceId'] as String?) ?? '',
    );
  }

  final String id;
  final String nameZh;
  final String nameEn;
  final String role;
  final String bioShort;
  final String activeYears;
  final List<String> relatedTerritoryIds;
  final List<String> relatedEventIds;
  final String contribution;
  final List<String> sourceNotes;
  final List<String> sourceRefs;
  final String birthPlaceId;
  final String deathPlaceId;
}

class AtlasPolygonFeature {
  const AtlasPolygonFeature({
    required this.snapshotId,
    required this.geometryId,
    required this.rings,
  });

  final String snapshotId;
  final String geometryId;
  final List<List<List<double>>> rings;
}

class PlaceRecord {
  const PlaceRecord({
    required this.id,
    required this.primaryName,
    required this.nameZh,
    required this.nameEn,
    required this.placeType,
    required this.modernCountryCode,
    required this.lat,
    required this.lng,
    required this.parentPlaceId,
    required this.aliases,
    required this.sourceRefs,
  });

  final String id;
  final String primaryName;
  final String nameZh;
  final String nameEn;
  final String placeType;
  final String modernCountryCode;
  final double lat;
  final double lng;
  final String parentPlaceId;
  final List<String> aliases;
  final List<String> sourceRefs;
}

class SourceRecord {
  const SourceRecord({
    required this.id,
    required this.sourceName,
    required this.sourceType,
    required this.sourceUrl,
    required this.licenseName,
    required this.licenseUrl,
    required this.commercialUseAllowed,
    required this.redistributionAllowed,
    required this.modificationAllowed,
    required this.attributionRequired,
    required this.attributionText,
    required this.approvalStatus,
    required this.reviewDate,
    required this.reviewOwner,
    required this.notes,
  });

  final String id;
  final String sourceName;
  final String sourceType;
  final String sourceUrl;
  final String licenseName;
  final String licenseUrl;
  final bool commercialUseAllowed;
  final bool redistributionAllowed;
  final bool modificationAllowed;
  final bool attributionRequired;
  final String attributionText;
  final String approvalStatus;
  final String reviewDate;
  final String reviewOwner;
  final String notes;
}

class GeometryAssetRecord {
  const GeometryAssetRecord({
    required this.id,
    required this.assetPath,
    required this.geometryType,
    required this.regionScope,
    required this.simplificationLevel,
    required this.licenseSourceId,
    required this.derivedFromSourceIds,
    required this.projection,
    required this.revision,
    required this.editorNotes,
  });

  final String id;
  final String assetPath;
  final String geometryType;
  final String regionScope;
  final String simplificationLevel;
  final String licenseSourceId;
  final List<String> derivedFromSourceIds;
  final String projection;
  final String revision;
  final String editorNotes;
}

class ControlZoneRecord {
  const ControlZoneRecord({
    required this.id,
    required this.snapshotId,
    required this.zoneType,
    required this.geometryRef,
    required this.label,
    required this.description,
    required this.fillColor,
    required this.fillOpacity,
    required this.strokeColor,
    required this.strokeWidth,
    required this.confidence,
    required this.sourceRefs,
  });

  final String id;
  final String snapshotId;
  final String zoneType;
  final String geometryRef;
  final String label;
  final String description;
  final String fillColor;
  final double fillOpacity;
  final String strokeColor;
  final double strokeWidth;
  final String confidence;
  final List<String> sourceRefs;
}

class AtlasData {
  const AtlasData({
    required this.scope,
    required this.territories,
    required this.snapshots,
    required this.events,
    required this.people,
    required this.polygonsBySnapshotId,
    required this.polygonsByGeometryId,
    required this.places,
    required this.sources,
    required this.geometryAssets,
    required this.controlZones,
  });

  final ProjectScope scope;
  final List<Territory> territories;
  final List<TerritorySnapshot> snapshots;
  final List<HistoricalEvent> events;
  final List<HistoricalPerson> people;
  final Map<String, List<AtlasPolygonFeature>> polygonsBySnapshotId;
  final Map<String, List<AtlasPolygonFeature>> polygonsByGeometryId;
  final List<PlaceRecord> places;
  final List<SourceRecord> sources;
  final List<GeometryAssetRecord> geometryAssets;
  final List<ControlZoneRecord> controlZones;
}

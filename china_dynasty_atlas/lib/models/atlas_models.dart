class ProjectScope {
  const ProjectScope({
    required this.projectId,
    required this.titleZh,
    required this.titleEn,
    required this.themeId,
    required this.themeLabelZh,
    required this.themeLabelEn,
    required this.mvpFocusZh,
    required this.mvpFocusEn,
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
      mvpFocusZh: (json['mvpFocusZh'] as String?) ?? json['mvpFocus'] as String,
      mvpFocusEn:
          (json['mvpFocusEn'] as String?) ??
          (json['mvpFocus'] as String? ?? ''),
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
  final String mvpFocusZh;
  final String mvpFocusEn;
  final List<String> coreTerritoryIds;
  final List<int> timelineYears;
  final List<int> recommendedExpansionYears;

  String get mvpFocus => mvpFocusZh;
}

class HistoricalDate {
  const HistoricalDate({
    required this.year,
    this.month,
    this.day,
    this.datePrecision = 'exact_year',
    this.displayLabel = '',
  });

  factory HistoricalDate.fromJson(Map<String, dynamic> json) {
    return HistoricalDate(
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt(),
      day: (json['day'] as num?)?.toInt(),
      datePrecision: json['datePrecision'] as String? ?? 'exact_year',
      displayLabel: json['displayLabel'] as String? ?? '',
    );
  }

  final int year;
  final int? month;
  final int? day;
  final String datePrecision;
  final String displayLabel;
}

class Territory {
  const Territory({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.type,
    required this.summaryZh,
    required this.summaryEn,
    required this.startDate,
    required this.endDate,
    required this.capital,
    required this.color,
    required this.predecessors,
    required this.successors,
    required this.aliases,
    required this.summaryLongZh,
    required this.summaryLongEn,
    required this.governanceHighlightsZh,
    required this.governanceHighlightsEn,
    required this.legacyZh,
    required this.legacyEn,
    required this.sourceRefs,
    required this.capitalPlaceIds,
  });

  factory Territory.fromJson(Map<String, dynamic> json) {
    final startDateJson = json['startDate'] as Map?;
    final endDateJson = json['endDate'] as Map?;
    final startDate = startDateJson != null
        ? HistoricalDate.fromJson(Map<String, dynamic>.from(startDateJson))
        : HistoricalDate(year: (json['startYear'] as num?)?.toInt() ?? 0);
    final endDate = endDateJson != null
        ? HistoricalDate.fromJson(Map<String, dynamic>.from(endDateJson))
        : HistoricalDate(year: (json['endYear'] as num?)?.toInt() ?? 0);

    return Territory(
      id: json['id'] as String,
      nameZh: json['nameZh'] as String,
      nameEn: json['nameEn'] as String,
      type: json['type'] as String,
      summaryZh: json['summaryZh'] as String? ?? json['summary'] as String,
      summaryEn: json['summaryEn'] as String? ?? json['summary'] as String,
      startDate: startDate,
      endDate: endDate,
      capital: json['capital'] as String,
      color: json['color'] as String,
      predecessors: List<String>.from(json['predecessors'] as List<dynamic>),
      successors: List<String>.from(json['successors'] as List<dynamic>),
      aliases: List<String>.from(json['aliases'] as List<dynamic>),
      summaryLongZh: (json['summaryLongZh'] as String?) ?? (json['summaryLong'] as String? ?? ''),
      summaryLongEn: (json['summaryLongEn'] as String?) ?? (json['summaryLong'] as String? ?? ''),
      governanceHighlightsZh: List<String>.from(
        (json['governanceHighlightsZh'] as List<dynamic>? ??
            json['governanceHighlights'] as List<dynamic>? ??
            const []),
      ),
      governanceHighlightsEn: List<String>.from(
        (json['governanceHighlightsEn'] as List<dynamic>? ??
            json['governanceHighlights'] as List<dynamic>? ??
            const []),
      ),
      legacyZh: List<String>.from(
        (json['legacyZh'] as List<dynamic>? ?? json['legacy'] as List<dynamic>? ?? const []),
      ),
      legacyEn: List<String>.from(
        (json['legacyEn'] as List<dynamic>? ?? json['legacy'] as List<dynamic>? ?? const []),
      ),
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
  final String summaryZh;
  final String summaryEn;
  final HistoricalDate startDate;
  final HistoricalDate endDate;
  final String capital;
  final String color;
  final List<String> predecessors;
  final List<String> successors;
  final List<String> aliases;
  final String summaryLongZh;
  final String summaryLongEn;
  final List<String> governanceHighlightsZh;
  final List<String> governanceHighlightsEn;
  final List<String> legacyZh;
  final List<String> legacyEn;
  final List<String> sourceRefs;
  final List<String> capitalPlaceIds;

  int get startYear => startDate.year;
  int get endYear => endDate.year;
  String get summary => summaryZh;
  String get summaryLong => summaryLongZh;
  List<String> get governanceHighlights => governanceHighlightsZh;
  List<String> get legacy => legacyZh;
}

class SnapshotFocus {
  const SnapshotFocus({
    required this.lat,
    required this.lng,
    required this.zoom,
  });

  factory SnapshotFocus.fromJson(Map<String, dynamic> json) {
    return SnapshotFocus(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
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
    required this.headlineZh,
    required this.headlineEn,
    required this.territoryNoteZh,
    required this.territoryNoteEn,
    required this.highlightedEventIds,
    required this.boundaryHighlightsZh,
    required this.boundaryHighlightsEn,
    required this.accuracyNoteZh,
    required this.accuracyNoteEn,
    required this.sourceNotesZh,
    required this.sourceNotesEn,
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
      year: (json['year'] as num?)?.toInt() ?? 0,
      geoJsonAsset: json['geoJsonAsset'] as String? ?? '',
      focus: SnapshotFocus.fromJson(
        json['focus'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      headlineZh: json['headlineZh'] as String? ?? json['headline'] as String,
      headlineEn: json['headlineEn'] as String? ?? json['headline'] as String,
      territoryNoteZh: json['territoryNoteZh'] as String? ?? json['territoryNote'] as String,
      territoryNoteEn: json['territoryNoteEn'] as String? ?? json['territoryNote'] as String,
      highlightedEventIds: List<String>.from(
        json['highlightedEventIds'] as List<dynamic>,
      ),
      boundaryHighlightsZh: List<String>.from(
        (json['boundaryHighlightsZh'] as List<dynamic>? ??
            json['boundaryHighlights'] as List<dynamic>? ??
            const []),
      ),
      boundaryHighlightsEn: List<String>.from(
        (json['boundaryHighlightsEn'] as List<dynamic>? ??
            json['boundaryHighlights'] as List<dynamic>? ??
            const []),
      ),
      accuracyNoteZh: (json['accuracyNoteZh'] as String?) ?? (json['accuracyNote'] as String? ?? ''),
      accuracyNoteEn: (json['accuracyNoteEn'] as String?) ?? (json['accuracyNote'] as String? ?? ''),
      sourceNotesZh: List<String>.from(
        (json['sourceNotesZh'] as List<dynamic>? ??
            json['sourceNotes'] as List<dynamic>? ??
            const []),
      ),
      sourceNotesEn: List<String>.from(
        (json['sourceNotesEn'] as List<dynamic>? ??
            json['sourceNotes'] as List<dynamic>? ??
            const []),
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
  final String headlineZh;
  final String headlineEn;
  final String territoryNoteZh;
  final String territoryNoteEn;
  final List<String> highlightedEventIds;
  final List<String> boundaryHighlightsZh;
  final List<String> boundaryHighlightsEn;
  final String accuracyNoteZh;
  final String accuracyNoteEn;
  final List<String> sourceNotesZh;
  final List<String> sourceNotesEn;
  final List<String> sourceRefs;
  final List<String> geometryRefs;
  final List<String> controlZoneIds;
  final String reviewStatus;
  final String accuracyLevel;

  String get headline => headlineZh;
  String get territoryNote => territoryNoteZh;
  List<String> get boundaryHighlights => boundaryHighlightsZh;
  String get accuracyNote => accuracyNoteZh;
  List<String> get sourceNotes => sourceNotesZh;
}

class HistoricalEvent {
  const HistoricalEvent({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.startDate,
    required this.territoryIds,
    required this.locationNameZh,
    required this.locationNameEn,
    required this.lat,
    required this.lng,
    required this.summaryZh,
    required this.summaryEn,
    required this.contentZh,
    required this.contentEn,
    required this.tags,
    required this.relatedPeople,
    required this.significanceZh,
    required this.significanceEn,
    required this.consequencesZh,
    required this.consequencesEn,
    required this.sourceNotes,
    required this.sourceRefs,
    required this.placeIds,
    required this.confidence,
  });

  factory HistoricalEvent.fromJson(Map<String, dynamic> json) {
    final startDateJson = json['startDate'] as Map?;
    final startDate = startDateJson != null
        ? HistoricalDate.fromJson(Map<String, dynamic>.from(startDateJson))
        : HistoricalDate(year: (json['year'] as num?)?.toInt() ?? 0);

    return HistoricalEvent(
      id: json['id'] as String,
      titleZh: json['titleZh'] as String,
      titleEn: json['titleEn'] as String,
      startDate: startDate,
      territoryIds: List<String>.from(json['territoryIds'] as List<dynamic>),
      locationNameZh:
          (json['locationNameZh'] as String?) ??
          (json['locationName'] as String? ?? ''),
      locationNameEn:
          (json['locationNameEn'] as String?) ??
          (json['locationName'] as String? ?? ''),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      summaryZh: (json['summaryZh'] as String?) ?? (json['summary'] as String? ?? ''),
      summaryEn: (json['summaryEn'] as String?) ?? (json['summary'] as String? ?? ''),
      contentZh: (json['contentZh'] as String?) ?? (json['content'] as String? ?? ''),
      contentEn: (json['contentEn'] as String?) ?? (json['content'] as String? ?? ''),
      tags: List<String>.from(json['tags'] as List<dynamic>),
      relatedPeople: List<String>.from(json['relatedPeople'] as List<dynamic>),
      significanceZh:
          (json['significanceZh'] as String?) ??
          (json['significance'] as String? ?? ''),
      significanceEn:
          (json['significanceEn'] as String?) ??
          (json['significance'] as String? ?? ''),
      consequencesZh: List<String>.from(
        (json['consequencesZh'] as List<dynamic>? ??
            json['consequences'] as List<dynamic>? ??
            const []),
      ),
      consequencesEn: List<String>.from(
        (json['consequencesEn'] as List<dynamic>? ??
            json['consequences'] as List<dynamic>? ??
            const []),
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
  final HistoricalDate startDate;
  final List<String> territoryIds;
  final String locationNameZh;
  final String locationNameEn;
  final double lat;
  final double lng;
  final String summaryZh;
  final String summaryEn;
  final String contentZh;
  final String contentEn;
  final List<String> tags;
  final List<String> relatedPeople;
  final String significanceZh;
  final String significanceEn;
  final List<String> consequencesZh;
  final List<String> consequencesEn;
  final List<String> sourceNotes;
  final List<String> sourceRefs;
  final List<String> placeIds;
  final String confidence;

  int get year => startDate.year;
  String get locationName => locationNameZh;
  String get summary => summaryZh;
  String get content => contentZh;
  String get significance => significanceZh;
  List<String> get consequences => consequencesZh;
}

class HistoricalPerson {
  const HistoricalPerson({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.role,
    required this.bioShortZh,
    required this.bioShortEn,
    required this.bioLongZh,
    required this.bioLongEn,
    required this.activeYears,
    required this.relatedTerritoryIds,
    required this.relatedEventIds,
    required this.contributionZh,
    required this.contributionEn,
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
      bioShortZh:
          (json['bioShortZh'] as String?) ?? (json['bioShort'] as String? ?? ''),
      bioShortEn:
          (json['bioShortEn'] as String?) ?? (json['bioShort'] as String? ?? ''),
      bioLongZh:
          (json['bioLongZh'] as String?) ?? (json['bioLong'] as String? ?? ''),
      bioLongEn:
          (json['bioLongEn'] as String?) ?? (json['bioLong'] as String? ?? ''),
      activeYears: (json['activeYears'] as String?) ?? '',
      relatedTerritoryIds: List<String>.from(
        (json['relatedTerritoryIds'] as List<dynamic>? ?? const []),
      ),
      relatedEventIds: List<String>.from(
        (json['relatedEventIds'] as List<dynamic>? ?? const []),
      ),
      contributionZh:
          (json['contributionZh'] as String?) ??
          (json['contribution'] as String? ?? ''),
      contributionEn:
          (json['contributionEn'] as String?) ??
          (json['contribution'] as String? ?? ''),
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
  final String bioShortZh;
  final String bioShortEn;
  final String bioLongZh;
  final String bioLongEn;
  final String activeYears;
  final List<String> relatedTerritoryIds;
  final List<String> relatedEventIds;
  final String contributionZh;
  final String contributionEn;
  final List<String> sourceNotes;
  final List<String> sourceRefs;
  final String birthPlaceId;
  final String deathPlaceId;

  String get bioShort => bioShortZh;
  String get bioLong => bioLongZh;
  String get contribution => contributionZh;
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
    required this.sourceNameZh,
    required this.sourceNameEn,
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
    required this.notesZh,
    required this.notesEn,
  });

  final String id;
  final String sourceNameZh;
  final String sourceNameEn;
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
  final String notesZh;
  final String notesEn;

  String get sourceName => sourceNameZh;
  String get notes => notesZh;
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

class StoryNarrative {
  const StoryNarrative({
    required this.textZh,
    required this.textEn,
    required this.coreQuestionZh,
    required this.coreQuestionEn,
  });

  factory StoryNarrative.fromJson(Map<String, dynamic> json) {
    return StoryNarrative(
      textZh: json['text_zh'] as String? ?? '',
      textEn: json['text_en'] as String? ?? '',
      coreQuestionZh: json['core_question_zh'] as String? ?? '',
      coreQuestionEn: json['core_question_en'] as String? ?? '',
    );
  }

  final String textZh;
  final String textEn;
  final String coreQuestionZh;
  final String coreQuestionEn;
}

class Storyline {
  const Storyline({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.emoji,
    required this.themeType,
    required this.descriptionZh,
    required this.descriptionEn,
    required this.eventIds,
    required this.narrativeIntro,
  });

  factory Storyline.fromJson(Map<String, dynamic> json) {
    return Storyline(
      id: json['id'] as String,
      titleZh: json['title_zh'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📜',
      themeType: json['theme_type'] as String? ?? 'general',
      descriptionZh: json['description_zh'] as String? ?? '',
      descriptionEn: json['description_en'] as String? ?? '',
      eventIds: List<String>.from(json['events'] as List<dynamic>? ?? const []),
      narrativeIntro: StoryNarrative.fromJson(
        json['narrative_intro'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String id;
  final String titleZh;
  final String titleEn;
  final String emoji;
  final String themeType;
  final String descriptionZh;
  final String descriptionEn;
  final List<String> eventIds;
  final StoryNarrative narrativeIntro;
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
    required this.storylines,
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
  final List<Storyline> storylines;
}

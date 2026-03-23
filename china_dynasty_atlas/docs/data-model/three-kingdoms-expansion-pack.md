# Three Kingdoms Expansion Pack

This pack defines a practical, copy-ready expansion path from the current Qin-Han scope into the Three Kingdoms era.

## Scope

- Theme: `Three Kingdoms Transition`
- Core territories: `cao_wei`, `shu_han`, `eastern_wu`
- Delivery target: one usable MVP package that fits the current app architecture

## Recommended Timeline (MVP)

- `220 CE`: Han end / Cao Wei founding context
- `229 CE`: Eastern Wu formal founding
- `263 CE`: Fall of Shu Han
- Optional next step: `280 CE` (Jin unification)

These years preserve continuity with the current `220` handoff and keep geometry workload manageable.

## Data Checklist

Prepare these files in `assets/global/`:

- `territories.json` (append new territory records)
- `territory_snapshots.json` (append 3-4 snapshots)
- `events.json` (append event cards)
- `people.json` (append person cards)
- `places.json` (append place entities)
- `sources.json` (append source/provenance records)
- `geometry_manifest.json` (append geometry metadata)

Prepare these geometry files in `assets/geojson/`:

- `cao_wei_220_main_v1.geojson`
- `shu_han_221_main_v1.geojson`
- `eastern_wu_229_main_v1.geojson`
- `shu_han_263_main_v1.geojson` (if 263 included in timeline)

## Naming and ID Convention

- Territory IDs: `cao_wei`, `shu_han`, `eastern_wu`
- Snapshot IDs: `<territory>_<year>` (example: `cao_wei_220`)
- Geometry IDs: `<territory>_<year>_main_v1`
- Event IDs: `<topic>_<year>` (example: `wei_founding_220`)
- Person IDs: lowercase snake_case (example: `cao_pi`, `liu_bei`, `sun_quan`)

## Territory Skeleton

Use this shape for each new territory (fill both Zh/En narrative fields):

```json
{
  "id": "cao_wei",
  "names": {
    "primaryName": "Cao Wei",
    "localizedNames": { "en": "Cao Wei", "zh-Hans": "曹魏" },
    "aliases": []
  },
  "territoryType": "dynasty",
  "start": { "year": 220, "datePrecision": "exact_year", "displayLabel": "220 CE" },
  "end": { "year": 265, "datePrecision": "exact_year", "displayLabel": "265 CE" },
  "capitalPlaceIds": ["luoyang"],
  "predecessorIds": ["eastern_han"],
  "successorIds": ["western_jin"],
  "summary": "中文摘要",
  "summaryEn": "English summary",
  "summaryLong": "中文长摘要",
  "summaryLongEn": "English long summary",
  "governanceHighlights": ["中文要点1"],
  "governanceHighlightsEn": ["English point 1"],
  "legacy": ["中文遗产1"],
  "legacyEn": ["English legacy 1"],
  "color": "#5E6C8A",
  "sourceRefs": ["editorial_internal_v1"]
}
```

## Snapshot Skeleton

```json
{
  "id": "cao_wei_220",
  "territoryId": "cao_wei",
  "validFrom": { "year": 220, "datePrecision": "exact_year", "displayLabel": "220 CE" },
  "validTo": { "year": 220, "datePrecision": "exact_year", "displayLabel": "220 CE" },
  "displayYear": 220,
  "geometryRefs": ["cao_wei_220_main_v1"],
  "controlZones": [],
  "mapFocus": { "lat": 35.0, "lng": 112.0, "zoom": 4.2 },
  "headline": "中文标题",
  "headlineEn": "English headline",
  "territoryNote": "中文说明",
  "territoryNoteEn": "English note",
  "boundaryHighlights": ["中文边界说明1"],
  "boundaryHighlightsEn": ["English boundary note 1"],
  "accuracy": {
    "level": "medium",
    "note": "中文精度说明",
    "noteEn": "English accuracy note"
  },
  "disputeNotes": ["中文争议说明"],
  "disputeNotesEn": ["English dispute note"],
  "sourceRefs": ["editorial_internal_v1"],
  "reviewStatus": "approved",
  "highlightedEventIds": ["wei_founding_220"]
}
```

## Minimum Event Set (Suggested)

- `han_end_220` (already exists; reuse in cross-link)
- `wei_founding_220`
- `shu_founding_221`
- `wu_founding_229`
- `zhuge_northern_campaign_228`
- `shu_fall_263`

For each event, fill:

- `summary / summaryEn`
- `content / contentEn`
- `significance / significanceEn`
- `consequences / consequencesEn`
- tags in Chinese first (current app maps to English labels)

## Minimum People Set (Suggested)

- `cao_pi`
- `liu_bei`
- `sun_quan`
- `zhuge_liang`
- `simayi`

For each person, fill:

- `bioShort / bioShortEn`
- `bioLong / bioLongEn`
- `contribution / contributionEn`

## Source and License Requirements

Every added geometry should have:

- one internal editorial source record
- optional external reference-only records
- explicit `approvalStatus`
- clear `notes` and `notesEn`

Do not import third-party geometry directly without commercial permission compatibility.

## Acceptance Criteria

- English mode has no Chinese leakage in:
  - Theme / scope summary
  - Key events list
  - Boundary notes
  - Event detail tags and place labels
- Chinese mode remains fully Chinese
- `flutter analyze` and `flutter test` both pass
- all newly added records have source references

## Execution Order

1. Add new places (`places.json`) for capitals and campaign regions
2. Add three territories (`territories.json`)
3. Add snapshots and geometry manifest entries
4. Add events and people
5. Run UI pass for year switching and event linking
6. Run analyze/test and fix regressions


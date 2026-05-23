#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');

const files = {
  pubspec: path.join(projectRoot, 'pubspec.yaml'),
  scope: path.join(projectRoot, 'assets/config/project_scope.json'),
  manifest: path.join(projectRoot, 'assets/global/geometry_manifest.json'),
  snapshots: path.join(projectRoot, 'assets/global/territory_snapshots.json'),
  mapScenes: path.join(projectRoot, 'assets/global/map_scenes.json'),
  cliopatriaTranslations: path.join(projectRoot, 'assets/global/cliopatria_name_translations.json'),
};

const requiredManifestFields = [
  'id',
  'assetPath',
  'geometryType',
  'regionScope',
  'projection',
];

const plannedManifestFields = [
  'boundaryMeaning',
  'accuracyTier',
  'reviewStatus',
];

const validBoundaryMeanings = new Set([
  'core_admin',
  'military_control',
  'frontier_command',
  'tributary_or_vassal',
  'claimed',
  'influence',
  'disputed',
  'schematic',
]);

const validAccuracyTiers = new Set([
  'source_exact',
  'derived_scholarly',
  'community_reference',
  'editorial_schematic',
  'placeholder',
]);

const validReviewStatuses = new Set(['draft', 'approved', 'placeholder']);

const validSceneCompleteness = new Set(['complete_scene', 'partial_scene', 'placeholder']);

const validCoverageLevels = new Set(['global_complete', 'global_partial', 'placeholder']);

const minCliopatriaSnapshotsPerTimelineYear = 5;

const issues = [];

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function addIssue(level, code, message) {
  issues.push({ level, code, message });
}

function relative(filePath) {
  return path.relative(projectRoot, filePath);
}

function hasDuplicateIds(records, label) {
  const seen = new Set();
  for (const record of records) {
    if (!record.id) continue;
    if (seen.has(record.id)) {
      addIssue('error', 'duplicate_id', `${label} has duplicate id: ${record.id}`);
    }
    seen.add(record.id);
  }
}

function getPubspecAssetPrefixes() {
  const raw = fs.readFileSync(files.pubspec, 'utf8');
  const prefixes = [];
  for (const line of raw.split(/\r?\n/)) {
    const match = line.match(/^\s*-\s+(assets\/.+)$/);
    if (match) prefixes.push(match[1].trim());
  }
  return prefixes;
}

function isDeclaredAsset(assetPath, prefixes) {
  return prefixes.some((prefix) => assetPath === prefix || assetPath.startsWith(prefix));
}

function validateMethodRef(record) {
  if (!record.methodRef) return;

  const absolutePath = path.join(projectRoot, record.methodRef);
  if (!fs.existsSync(absolutePath)) {
    addIssue('error', 'missing_method_ref', `${record.id} references missing methodRef: ${record.methodRef}`);
  }
}

function isCliopatriaGeometry(record) {
  if (!record) return false;
  return (
    record.licenseSourceId === 'seshat_cliopatria' ||
    (record.derivedFromSourceIds || []).includes('seshat_cliopatria')
  );
}

function isCliopatriaSnapshot(snapshot, manifestById) {
  if (!snapshot) return false;
  if (snapshot.id.startsWith('cliopatria_')) return true;
  if ((snapshot.sourceRefs || []).includes('seshat_cliopatria')) return true;
  return (snapshot.geometryRefs || []).some((geometryRef) => isCliopatriaGeometry(manifestById.get(geometryRef)));
}

function validateGeoJson(assetPath, geometryId) {
  const absolutePath = path.join(projectRoot, assetPath);
  if (!fs.existsSync(absolutePath)) {
    addIssue('error', 'missing_asset', `${geometryId} references missing asset: ${assetPath}`);
    return;
  }

  let geojson;
  try {
    geojson = readJson(absolutePath);
  } catch (error) {
    addIssue('error', 'invalid_json', `${assetPath} is not valid JSON: ${error.message}`);
    return;
  }

  if (geojson.type !== 'FeatureCollection') {
    addIssue('error', 'geojson_type', `${assetPath} must be a FeatureCollection, got ${geojson.type}`);
    return;
  }

  if (!Array.isArray(geojson.features)) {
    addIssue('error', 'geojson_features', `${assetPath} must have a features array`);
    return;
  }

  if (geojson.features.length === 0) {
    addIssue('error', 'empty_geojson', `${assetPath} has no features`);
  }

  for (const [index, feature] of geojson.features.entries()) {
    if (!feature || feature.type !== 'Feature') {
      addIssue('error', 'geojson_feature_type', `${assetPath} feature ${index} is not a Feature`);
      continue;
    }

    const geometry = feature.geometry;
    if (!geometry) {
      addIssue('error', 'missing_geometry', `${assetPath} feature ${index} has no geometry`);
      continue;
    }

    if (!['Polygon', 'MultiPolygon'].includes(geometry.type)) {
      addIssue(
        'warning',
        'unsupported_geometry',
        `${assetPath} feature ${index} has unsupported geometry type: ${geometry.type}`,
      );
      continue;
    }

    if (!Array.isArray(geometry.coordinates)) {
      addIssue('error', 'missing_coordinates', `${assetPath} feature ${index} has no coordinates array`);
      continue;
    }

    validateCoordinates(geometry.coordinates, assetPath, index);
  }
}

function validateCoordinates(value, assetPath, featureIndex) {
  if (!Array.isArray(value)) return;

  if (value.length >= 2 && typeof value[0] === 'number' && typeof value[1] === 'number') {
    const [lng, lat] = value;
    const epsilon = 1e-9;
    if (lng < -180 - epsilon || lng > 180 + epsilon || lat < -90 - epsilon || lat > 90 + epsilon) {
      addIssue(
        'error',
        'invalid_coordinate',
        `${assetPath} feature ${featureIndex} has invalid lon/lat coordinate: [${lng}, ${lat}]`,
      );
    }
    return;
  }

  for (const item of value) validateCoordinates(item, assetPath, featureIndex);
}

function validateManifest(manifest, pubspecAssetPrefixes) {
  hasDuplicateIds(manifest, 'geometry_manifest');

  for (const record of manifest) {
    for (const field of requiredManifestFields) {
      if (record[field] === undefined || record[field] === '') {
        addIssue('error', 'manifest_required_field', `${record.id || '<missing id>'} is missing ${field}`);
      }
    }

    for (const field of plannedManifestFields) {
      if (record[field] === undefined || record[field] === '') {
        addIssue(
          'warning',
          'manifest_planned_field',
          `${record.id || '<missing id>'} should declare ${field} before Phase 0 is complete`,
        );
      }
    }

    if (record.boundaryMeaning && !validBoundaryMeanings.has(record.boundaryMeaning)) {
      addIssue('error', 'boundary_meaning', `${record.id} has invalid boundaryMeaning: ${record.boundaryMeaning}`);
    }

    if (record.id.startsWith('cliopatria_xianbei_') && record.boundaryMeaning === 'core_admin') {
      addIssue(
        'error',
        'nomadic_boundary_meaning',
        `${record.id} should be marked as influence/disputed context, not core_admin`,
      );
    }

    if (record.accuracyTier && !validAccuracyTiers.has(record.accuracyTier)) {
      addIssue('error', 'accuracy_tier', `${record.id} has invalid accuracyTier: ${record.accuracyTier}`);
    }

    if (record.reviewStatus && !validReviewStatuses.has(record.reviewStatus)) {
      addIssue('error', 'review_status', `${record.id} has invalid reviewStatus: ${record.reviewStatus}`);
    }

    if (record.assetPath && !isDeclaredAsset(record.assetPath, pubspecAssetPrefixes)) {
      addIssue('error', 'undeclared_asset', `${record.id} asset is not declared in pubspec assets: ${record.assetPath}`);
    }

    validateMethodRef(record);

    if (
      record.accuracyTier &&
      ['source_exact', 'derived_scholarly'].includes(record.accuracyTier) &&
      record.licenseSourceId === 'editorial_internal_v1'
    ) {
      addIssue(
        'error',
        'overstated_accuracy',
        `${record.id} cannot be ${record.accuracyTier} when its only license source is editorial_internal_v1`,
      );
    }

    if (record.assetPath) validateGeoJson(record.assetPath, record.id);
  }
}

function validateSnapshots(snapshots, manifestById, territoriesById) {
  hasDuplicateIds(snapshots, 'territory_snapshots');

  for (const snapshot of snapshots) {
    if (!territoriesById.has(snapshot.territoryId)) {
      addIssue('error', 'snapshot_territory_ref', `${snapshot.id} references unknown territory: ${snapshot.territoryId}`);
    }

    if (!Array.isArray(snapshot.geometryRefs)) {
      addIssue('error', 'snapshot_geometry_refs', `${snapshot.id} must have a geometryRefs array`);
      continue;
    }

    if (snapshot.geometryRefs.length === 0) {
      addIssue('warning', 'empty_geometry_refs', `${snapshot.id} has no geometryRefs`);
    }

    for (const geometryRef of snapshot.geometryRefs) {
      if (!manifestById.has(geometryRef)) {
        addIssue('error', 'missing_geometry_ref', `${snapshot.id} references unknown geometry: ${geometryRef}`);
      }
    }

    validateChinesePeriodBoundary(snapshot);
  }

  validateThreeKingdomsScene(snapshots);
  validateFiveDynastiesScene(snapshots);
}

function validateChinesePeriodBoundary(snapshot) {
  const invalidRanges = [
    { territoryId: 'western_han', after: 8, label: 'Western Han' },
    { territoryId: 'xin', after: 23, label: 'Xin' },
    { territoryId: 'eastern_han', after: 220, label: 'Eastern Han' },
  ];
  for (const range of invalidRanges) {
    if (snapshot.territoryId === range.territoryId && snapshot.displayYear > range.after) {
      addIssue(
        'error',
        'chinese_period_out_of_range',
        `${snapshot.id} maps ${range.label} to ${snapshot.displayYear}, after its configured end year ${range.after}`,
      );
    }
  }
}

function validateThreeKingdomsScene(snapshots) {
  const sceneMembers = snapshots.filter((snapshot) => snapshot.displayYear === 229);
  const territories = new Set(sceneMembers.map((snapshot) => snapshot.territoryId));
  const required = ['cao_wei', 'shu_han', 'eastern_wu'];

  for (const territoryId of required) {
    if (!territories.has(territoryId)) {
      addIssue('error', 'incomplete_scene', `229 CE Three Kingdoms scene is missing ${territoryId}`);
    }
  }
}

function validateFiveDynastiesScene(snapshots) {
  const sceneMembers = snapshots.filter(
    (snapshot) => snapshot.displayYear === 907 && snapshot.territoryId === 'five_dynasties',
  );
  for (const snapshot of sceneMembers) {
    const note = [
      snapshot.territoryNote,
      snapshot.territoryNoteEn,
      snapshot.headline,
      snapshot.headlineEn,
    ]
      .filter(Boolean)
      .join(' ');

    const isPlaceholderLike = /placeholder|示意|暂无|资料/.test(note) || snapshot.reviewStatus === 'placeholder';
    if (!isPlaceholderLike) {
      addIssue(
        'warning',
        'five_dynasties_placeholder',
        `${snapshot.id} is in 907 CE but is not clearly marked as placeholder/schematic`,
      );
    }
  }
}

function validateScope(scope, snapshots) {
  const snapshotYears = new Set(snapshots.map((snapshot) => snapshot.displayYear));

  for (const year of scope.timelineYears || []) {
    if (!snapshotYears.has(year)) {
      addIssue('error', 'timeline_without_snapshot', `timelineYears includes ${year}, but no snapshot uses it`);
    }
  }

  for (const eventOnlyYear of [220, 221, 263]) {
    if ((scope.timelineYears || []).includes(eventOnlyYear)) {
      addIssue(
        'error',
        'event_year_in_timeline',
        `${eventOnlyYear} should stay as an event year, not a default timeline map year`,
      );
    }
  }
}

function validateCliopatriaTranslations(translations, mapScenes, snapshots, territoriesById, manifestById) {
  if (!translations || Array.isArray(translations) || typeof translations !== 'object') {
    addIssue('error', 'translation_dictionary', 'cliopatria_name_translations.json must be an object');
    return;
  }

  const snapshotsById = new Map(snapshots.map((snapshot) => [snapshot.id, snapshot]));
  for (const scene of mapScenes) {
    for (const snapshotId of scene.territorySnapshotIds || []) {
      const snapshot = snapshotsById.get(snapshotId);
      if (!isCliopatriaSnapshot(snapshot, manifestById)) continue;
      const territory = territoriesById.get(snapshot.territoryId);
      const primaryName = territory?.names?.primaryName;
      if (!primaryName) continue;
      const localizedNames = territory.names?.localizedNames || {};
      if (!translations[primaryName] && localizedNames['zh-Hans'] === primaryName) {
        addIssue('warning', 'missing_cliopatria_translation', `${primaryName} appears in default scenes without zh-Hans translation`);
      }
      if (
        translations[primaryName] &&
        localizedNames['zh-Hans'] !== translations[primaryName] &&
        !localizedNames['zh-Hans']?.includes(translations[primaryName])
      ) {
        addIssue(
          'error',
          'stale_cliopatria_translation',
          `${primaryName} has zh-Hans "${localizedNames['zh-Hans']}", expected "${translations[primaryName]}"`,
        );
      }
      if (!territory.summary || !territory.summaryLong) {
        addIssue('warning', 'missing_cliopatria_summary', `${primaryName} is missing zh-Hans summary fields`);
      }
      if (territory.summary && territory.summary.includes(`${primaryName} 是`)) {
        addIssue('warning', 'english_name_in_cliopatria_summary', `${primaryName} summary still starts with an English name`);
      }
    }
  }
}

function validateMapScenes(mapScenes, scope, snapshots, manifestById) {
  hasDuplicateIds(mapScenes, 'map_scenes');

  const snapshotsById = new Map(snapshots.map((snapshot) => [snapshot.id, snapshot]));
  const sceneYears = new Set();

  for (const scene of mapScenes) {
    if (typeof scene.id !== 'string' || scene.id.length === 0) {
      addIssue('error', 'scene_id', 'map_scenes entry is missing id');
    }

    if (typeof scene.displayYear !== 'number') {
      addIssue('error', 'scene_display_year', `${scene.id || '<missing id>'} must have numeric displayYear`);
    } else {
      sceneYears.add(scene.displayYear);
    }

    if (!Array.isArray(scene.territorySnapshotIds)) {
      addIssue('error', 'scene_snapshot_ids', `${scene.id} must have territorySnapshotIds array`);
      continue;
    }

    if (scene.territorySnapshotIds.length === 0) {
      addIssue('error', 'scene_empty', `${scene.id} has no territorySnapshotIds`);
    }

    if (!validSceneCompleteness.has(scene.completeness)) {
      addIssue('error', 'scene_completeness', `${scene.id} has invalid completeness: ${scene.completeness}`);
    }

    if (scene.sceneScope !== 'world') {
      addIssue('error', 'scene_scope', `${scene.id} must declare sceneScope: world`);
    }

    if (!validCoverageLevels.has(scene.coverageLevel)) {
      addIssue('error', 'scene_coverage_level', `${scene.id} has invalid coverageLevel: ${scene.coverageLevel}`);
    }

    for (const snapshotId of scene.territorySnapshotIds) {
      const snapshot = snapshotsById.get(snapshotId);
      if (!snapshot) {
        addIssue('error', 'scene_missing_snapshot', `${scene.id} references unknown snapshot: ${snapshotId}`);
        continue;
      }

      if (snapshot.displayYear !== scene.displayYear) {
        addIssue(
          'warning',
          'scene_year_mismatch',
          `${scene.id} (${scene.displayYear}) references ${snapshotId} with displayYear ${snapshot.displayYear}`,
        );
      }

      if (
        scene.completeness !== 'placeholder' &&
        !isCliopatriaSnapshot(snapshot, manifestById)
      ) {
        addIssue(
          'error',
          'default_scene_non_cliopatria',
          `${scene.id} includes non-Cliopatria default snapshot: ${snapshotId}`,
        );
      }
    }

    if (scene.completeness === 'placeholder') {
      const note = [scene.notes, scene.notesEn, scene.title?.['zh-Hans'], scene.title?.en]
        .filter(Boolean)
        .join(' ');
      if (!/placeholder|占位|资料|缺口|unavailable|not available/i.test(note)) {
        addIssue('warning', 'scene_placeholder_note', `${scene.id} is placeholder but lacks a clear data-gap note`);
      }
    }

    if (scene.coverageLevel === 'global_partial' && scene.completeness !== 'placeholder') {
      const cliopatriaSnapshotCount = scene.territorySnapshotIds.filter((snapshotId) =>
        isCliopatriaSnapshot(snapshotsById.get(snapshotId), manifestById),
      ).length;
      if (cliopatriaSnapshotCount < minCliopatriaSnapshotsPerTimelineYear) {
        addIssue(
          'error',
          'insufficient_world_context',
          `${scene.id} only has ${cliopatriaSnapshotCount} Cliopatria world-context snapshots; expected at least ${minCliopatriaSnapshotsPerTimelineYear}`,
        );
      }
    }
  }

  for (const year of scope.timelineYears || []) {
    if (!sceneYears.has(year)) {
      addIssue('error', 'timeline_without_scene', `timelineYears includes ${year}, but no map scene uses it`);
    }
  }
}

function printIssues() {
  const errors = issues.filter((issue) => issue.level === 'error');
  const warnings = issues.filter((issue) => issue.level === 'warning');

  for (const issue of issues) {
    const prefix = issue.level === 'error' ? 'ERROR' : 'WARN';
    console.log(`${prefix} [${issue.code}] ${issue.message}`);
  }

  console.log('');
  console.log(`Boundary data validation complete: ${errors.length} error(s), ${warnings.length} warning(s).`);

  if (errors.length > 0) process.exitCode = 1;
}

function main() {
  for (const [label, filePath] of Object.entries(files)) {
    if (!fs.existsSync(filePath)) {
      addIssue('error', 'missing_file', `Missing required ${label} file: ${relative(filePath)}`);
    }
  }

  if (issues.some((issue) => issue.level === 'error')) {
    printIssues();
    return;
  }

  const manifest = readJson(files.manifest);
  const snapshots = readJson(files.snapshots);
  const mapScenes = readJson(files.mapScenes);
  const scope = readJson(files.scope);
  const cliopatriaTranslations = readJson(files.cliopatriaTranslations);
  const pubspecAssetPrefixes = getPubspecAssetPrefixes();
  const manifestById = new Map(manifest.map((record) => [record.id, record]));
  const territories = readJson(path.join(projectRoot, 'assets/global/territories.json'));
  const territoriesById = new Map(territories.map((record) => [record.id, record]));

  validateManifest(manifest, pubspecAssetPrefixes);
  validateSnapshots(snapshots, manifestById, territoriesById);
  validateScope(scope, snapshots);
  validateMapScenes(mapScenes, scope, snapshots, manifestById);
  validateCliopatriaTranslations(cliopatriaTranslations, mapScenes, snapshots, territoriesById, manifestById);

  printIssues();
}

main();

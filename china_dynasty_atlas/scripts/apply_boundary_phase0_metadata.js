#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
const manifestPath = path.join(projectRoot, 'assets/global/geometry_manifest.json');
const snapshotsPath = path.join(projectRoot, 'assets/global/territory_snapshots.json');

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const snapshots = JSON.parse(fs.readFileSync(snapshotsPath, 'utf8'));

function isEditorial(record) {
  return (
    record.licenseSourceId === 'editorial_internal_v1' ||
    record.simplificationLevel === 'mvp_schematic' ||
    record.simplificationLevel === 'product_tracing_sample'
  );
}

function isWorldHistorical(record) {
  return record.licenseSourceId === 'world_historical_gis_data' || record.sourceType === 'world_historical_gis';
}

function isCommunityThreeKingdoms(record) {
  return record.sourceType === 'eserica_geojson' || record.licenseSourceId === 'eserica_geojson_map';
}

function inferRegionScope(record) {
  if (record.regionScope) return record.regionScope;
  if (record.assetPath?.includes('/world/')) return 'world';
  return 'china';
}

function normalizeManifestRecord(record) {
  record.geometryType ??= 'Polygon';
  record.regionScope = inferRegionScope(record);
  record.projection ??= 'EPSG:4326';

  if (!record.licenseSourceId && isWorldHistorical(record)) {
    record.licenseSourceId = 'world_historical_gis_data';
  }

  if (!record.licenseSourceId && isCommunityThreeKingdoms(record)) {
    record.licenseSourceId = 'eserica_geojson_map';
  }

  record.derivedFromSourceIds ??= record.licenseSourceId ? [record.licenseSourceId] : [];

  if (isEditorial(record)) {
    record.boundaryMeaning ??= 'schematic';
    record.accuracyTier ??= 'editorial_schematic';
    record.reviewStatus ??= 'draft';
    return;
  }

  if (isWorldHistorical(record)) {
    record.boundaryMeaning ??= 'core_admin';
    record.accuracyTier ??= 'community_reference';
    record.reviewStatus ??= 'draft';
    return;
  }

  if (isCommunityThreeKingdoms(record)) {
    record.boundaryMeaning ??= 'core_admin';
    record.accuracyTier ??= 'community_reference';
    record.reviewStatus ??= 'draft';
    return;
  }

  record.boundaryMeaning ??= 'schematic';
  record.accuracyTier ??= 'editorial_schematic';
  record.reviewStatus ??= 'draft';
}

for (const record of manifest) normalizeManifestRecord(record);

const fiveDynasties = snapshots.find((snapshot) => snapshot.id === 'five_dynasties_schematic');
if (fiveDynasties) {
  fiveDynasties.reviewStatus = 'placeholder';
  fiveDynasties.accuracy = {
    level: 'low',
    tier: 'placeholder',
    note: '五代十国目前只有示意占位图，不能作为真实边界使用。',
    noteEn: 'Five Dynasties and Ten Kingdoms currently uses a placeholder schematic and must not be treated as an authoritative boundary.',
  };
}

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
fs.writeFileSync(snapshotsPath, `${JSON.stringify(snapshots, null, 2)}\n`);

console.log('Applied Phase 0 boundary metadata.');

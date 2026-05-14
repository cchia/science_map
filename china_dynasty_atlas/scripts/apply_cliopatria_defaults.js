#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
const files = {
  manifest: path.join(projectRoot, 'assets/global/geometry_manifest.json'),
  snapshots: path.join(projectRoot, 'assets/global/territory_snapshots.json'),
  scenes: path.join(projectRoot, 'assets/global/map_scenes.json'),
  territories: path.join(projectRoot, 'assets/global/territories.json'),
};

const preferBroaderWhenPresent = {
  'British Colonial Empire': [
    'British Africa',
    'British Raj',
    'Kingdom of Great Britain',
  ],
  'Habsburg Monarchy': [
    'Kingdom of Hungary',
    'Principality of Transylvania',
  ],
  'Macedonian Empire': [
    'Kingdom of Lysimachus',
    'Laomedon',
    'Perdiccas',
  ],
  'Portuguese Empire': [
    'Kingdom of Portugal',
  ],
  'Republic of China': [
    'Kuomintang',
  ],
  'Spanish Empire': [
    'Kingdom of Spain',
  ],
  'Xiongnu': [
    'Southern Xiongnu',
  ],
};

const preferSpecificWhenPresent = {
  'Kingdom of Norway': [
    'Denmark-Norway',
  ],
};

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function isCliopatriaGeometry(geometry) {
  if (!geometry) return false;
  return (
    geometry.licenseSourceId === 'seshat_cliopatria' ||
    (geometry.derivedFromSourceIds || []).includes('seshat_cliopatria')
  );
}

function isCliopatriaSnapshot(snapshot, manifestById) {
  if (snapshot.id.startsWith('cliopatria_')) return true;
  if ((snapshot.sourceRefs || []).includes('seshat_cliopatria')) return true;
  return (snapshot.geometryRefs || []).some((geometryRef) =>
    isCliopatriaGeometry(manifestById.get(geometryRef)),
  );
}

function appendOnce(text, addition) {
  if (!text) return addition;
  if (text.includes(addition)) return text;
  return `${text} ${addition}`;
}

function territoryNameForSnapshot(snapshotId, snapshotsById, territoriesById) {
  const snapshot = snapshotsById.get(snapshotId);
  const territory = snapshot ? territoriesById.get(snapshot.territoryId) : null;
  return territory?.names?.primaryName || snapshot?.territoryId || snapshotId;
}

function filterOverlappingDefaults(snapshotIds, snapshotsById, territoriesById) {
  const ids = [...snapshotIds];
  const names = new Set(ids.map((id) => territoryNameForSnapshot(id, snapshotsById, territoriesById)));
  const hiddenNames = new Set();

  for (const [broader, children] of Object.entries(preferBroaderWhenPresent)) {
    if (!names.has(broader)) continue;
    for (const child of children) {
      hiddenNames.add(child);
    }
  }

  for (const [specific, obsoleteComposites] of Object.entries(preferSpecificWhenPresent)) {
    if (!names.has(specific)) continue;
    for (const obsolete of obsoleteComposites) {
      hiddenNames.add(obsolete);
    }
  }

  return ids.filter((id) => !hiddenNames.has(territoryNameForSnapshot(id, snapshotsById, territoriesById)));
}

function sortSceneSnapshots(snapshotIds, snapshotsById) {
  return [...snapshotIds].sort((a, b) => {
    const aSnapshot = snapshotsById.get(a);
    const bSnapshot = snapshotsById.get(b);
    const aPrefixed = a.startsWith('cliopatria_');
    const bPrefixed = b.startsWith('cliopatria_');
    if (aPrefixed !== bPrefixed) return aPrefixed ? 1 : -1;
    return (aSnapshot?.territoryId || a).localeCompare(bSnapshot?.territoryId || b);
  });
}

function main() {
  const manifest = readJson(files.manifest);
  const snapshots = readJson(files.snapshots);
  const scenes = readJson(files.scenes);
  const territories = readJson(files.territories);
  const manifestById = new Map(manifest.map((record) => [record.id, record]));
  const snapshotsById = new Map(snapshots.map((snapshot) => [snapshot.id, snapshot]));
  const territoriesById = new Map(territories.map((territory) => [territory.id, territory]));
  const snapshotsByYear = new Map();

  for (const snapshot of snapshots) {
    if (!snapshotsByYear.has(snapshot.displayYear)) {
      snapshotsByYear.set(snapshot.displayYear, []);
    }
    snapshotsByYear.get(snapshot.displayYear).push(snapshot);
  }

  let removed = 0;
  let retained = 0;
  const emptyScenes = [];

  for (const scene of scenes) {
    const yearSnapshots = snapshotsByYear.get(scene.displayYear) || [];
    const cliopatriaSnapshotIds = yearSnapshots
      .filter((snapshot) => isCliopatriaSnapshot(snapshot, manifestById))
      .map((snapshot) => snapshot.id);
    const nextIds = sortSceneSnapshots(
      filterOverlappingDefaults(new Set(cliopatriaSnapshotIds), snapshotsById, territoriesById),
      snapshotsById,
    );
    const before = scene.territorySnapshotIds || [];

    removed += before.filter((snapshotId) => !nextIds.includes(snapshotId)).length;
    retained += nextIds.length;
    scene.territorySnapshotIds = nextIds;

    if (nextIds.length === 0) {
      emptyScenes.push(scene.id);
    }

    scene.completeness = scene.completeness === 'placeholder' ? 'placeholder' : 'partial_scene';
    scene.sceneType = 'world_context_scene';
    scene.sceneScope = 'world';
    scene.coverageLevel = scene.coverageLevel === 'placeholder' ? 'placeholder' : 'global_partial';
    scene.notes = appendOnce(
      scene.notes,
      '默认显示层已切换为 Cliopatria 统一世界参考底座；项目内专题边界保留为后续审核/对照数据，不再进入默认场景。',
    );
    scene.notesEn = appendOnce(
      scene.notesEn,
      'The default display layer now uses Cliopatria as the unified world reference base; project-specific specialist boundaries remain for later review/comparison and are no longer included in default scenes.',
    );
  }

  if (emptyScenes.length > 0) {
    throw new Error(`Cliopatria migration would leave empty scenes: ${emptyScenes.join(', ')}`);
  }

  writeJson(files.scenes, scenes);
  console.log(`Cliopatria default migration complete: retained ${retained} scene refs, removed ${removed} non-default refs.`);
}

main();

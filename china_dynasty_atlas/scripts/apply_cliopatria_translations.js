#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
const files = {
  translations: path.join(projectRoot, 'assets/global/cliopatria_name_translations.json'),
  territories: path.join(projectRoot, 'assets/global/territories.json'),
  snapshots: path.join(projectRoot, 'assets/global/territory_snapshots.json'),
  scenes: path.join(projectRoot, 'assets/global/map_scenes.json'),
};

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function replaceKnownNames(value, translations) {
  if (typeof value !== 'string' || value.length === 0) return value;
  let next = value;
  for (const [englishName, chineseName] of translations) {
    next = next.split(englishName).join(chineseName);
  }
  return next;
}

function isCliopatriaSnapshot(snapshot) {
  return snapshot.id.startsWith('cliopatria_') || (snapshot.sourceRefs || []).includes('seshat_cliopatria');
}

function formatYearZh(year) {
  if (typeof year !== 'number') return '未知年代';
  if (year < 0) return `公元前${Math.abs(year)}年`;
  return `公元${year}年`;
}

function formatYearEn(year) {
  if (typeof year !== 'number') return 'unknown date';
  if (year < 0) return `${Math.abs(year)} BCE`;
  return `${year} CE`;
}

function setCliopatriaSummary(territory, translatedName) {
  const startYear = territory.start?.year;
  const endYear = territory.end?.year;
  const timespanZh = `${formatYearZh(startYear)}至${formatYearZh(endYear)}`;
  const timespanEn = `${formatYearEn(startYear)} to ${formatYearEn(endYear)}`;

  territory.summary = `${translatedName}是 Cliopatria 世界历史数据集中的参考政权，时间范围约为${timespanZh}。`;
  territory.summaryEn = `${territory.names.primaryName} is a reference polity from Cliopatria, covering approximately ${timespanEn}.`;
  territory.summaryLong = `${translatedName}用于默认时间轴的同代世界地图展示。其边界来自 Seshat Cliopatria，适合大洲级观察世界格局，但不应视为已经逐地审核的高精度历史边界。`;
  territory.summaryLongEn = `${territory.names.primaryName} is used in the default timeline's same-era world map. Its boundary comes from Seshat Cliopatria and is suitable for continental-scale context, but should not be treated as a fully reviewed high-precision historical boundary.`;
}

function main() {
  const translationMap = readJson(files.translations);
  const translations = Object.entries(translationMap).sort((a, b) => b[0].length - a[0].length);
  const territories = readJson(files.territories);
  const snapshots = readJson(files.snapshots);
  const scenes = readJson(files.scenes);
  const territoriesById = new Map(territories.map((territory) => [territory.id, territory]));
  const snapshotsById = new Map(snapshots.map((snapshot) => [snapshot.id, snapshot]));
  const defaultTerritoryIds = new Set();

  for (const scene of scenes) {
    for (const snapshotId of scene.territorySnapshotIds || []) {
      const snapshot = snapshotsById.get(snapshotId);
      if (snapshot) defaultTerritoryIds.add(snapshot.territoryId);
    }
  }

  let translatedTerritories = 0;
  let summarizedTerritories = 0;
  for (const territory of territories) {
    if (!territory.id.startsWith('cliopatria_') && !defaultTerritoryIds.has(territory.id)) continue;
    const primaryName = territory.names?.primaryName;
    const translatedName = translationMap[primaryName];

    territory.names.localizedNames = territory.names.localizedNames || {};
    const currentZhName = territory.names.localizedNames['zh-Hans'];
    if (!translatedName) {
      if (!currentZhName || currentZhName === primaryName) {
        territory.names.localizedNames['zh-Hans'] = `${primaryName}（待译）`;
        translatedTerritories += 1;
      }
      if (territory.id.startsWith('cliopatria_') || !territory.summary || !territory.summaryLong) {
        const beforeSummary = JSON.stringify({
          summary: territory.summary,
          summaryEn: territory.summaryEn,
          summaryLong: territory.summaryLong,
          summaryLongEn: territory.summaryLongEn,
        });
        setCliopatriaSummary(territory, territory.names.localizedNames['zh-Hans']);
        const afterSummary = JSON.stringify({
          summary: territory.summary,
          summaryEn: territory.summaryEn,
          summaryLong: territory.summaryLong,
          summaryLongEn: territory.summaryLongEn,
        });
        if (beforeSummary !== afterSummary) summarizedTerritories += 1;
      }
      continue;
    }

    if (!currentZhName || currentZhName === primaryName || currentZhName.endsWith('（待译）')) {
      territory.names.localizedNames['zh-Hans'] = translatedName;
      translatedTerritories += 1;
    }
    const beforeSummary = JSON.stringify({
      summary: territory.summary,
      summaryEn: territory.summaryEn,
      summaryLong: territory.summaryLong,
      summaryLongEn: territory.summaryLongEn,
    });
    if (territory.id.startsWith('cliopatria_') || !territory.summary || !territory.summaryLong) {
      setCliopatriaSummary(territory, territory.names.localizedNames['zh-Hans'] || translatedName);
    }
    const afterSummary = JSON.stringify({
      summary: territory.summary,
      summaryEn: territory.summaryEn,
      summaryLong: territory.summaryLong,
      summaryLongEn: territory.summaryLongEn,
    });
    if (beforeSummary !== afterSummary) summarizedTerritories += 1;
  }

  let translatedSnapshots = 0;
  for (const snapshot of snapshots) {
    if (!isCliopatriaSnapshot(snapshot)) continue;
    const before = JSON.stringify({
      headline: snapshot.headline,
      territoryNote: snapshot.territoryNote,
      boundaryHighlights: snapshot.boundaryHighlights,
      disputeNotes: snapshot.disputeNotes,
    });

    snapshot.headline = replaceKnownNames(snapshot.headline, translations);
    snapshot.territoryNote = replaceKnownNames(snapshot.territoryNote, translations);
    snapshot.boundaryHighlights = (snapshot.boundaryHighlights || []).map((item) =>
      replaceKnownNames(item, translations),
    );
    snapshot.disputeNotes = (snapshot.disputeNotes || []).map((item) => replaceKnownNames(item, translations));

    const after = JSON.stringify({
      headline: snapshot.headline,
      territoryNote: snapshot.territoryNote,
      boundaryHighlights: snapshot.boundaryHighlights,
      disputeNotes: snapshot.disputeNotes,
    });
    if (before !== after) translatedSnapshots += 1;
  }

  const untranslated = [];
  for (const territoryId of defaultTerritoryIds) {
    const territory = territoriesById.get(territoryId);
    const primaryName = territory?.names?.primaryName;
    if (primaryName && !translationMap[primaryName]) {
      untranslated.push(primaryName);
    }
  }

  writeJson(files.territories, territories);
  writeJson(files.snapshots, snapshots);

  console.log(
    `Translated ${translatedTerritories} Cliopatria territories, summarized ${summarizedTerritories} territories, and updated ${translatedSnapshots} snapshots.`,
  );
  if (untranslated.length > 0) {
    console.log('Untranslated default Cliopatria names:');
    for (const name of [...new Set(untranslated)].sort()) console.log(`- ${name}`);
  }
}

main();

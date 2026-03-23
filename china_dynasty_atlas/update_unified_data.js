const fs = require('fs');

// 1. Update territories.json
const territoriesPath = 'china_dynasty_atlas/assets/global/territories.json';
let territories = JSON.parse(fs.readFileSync(territoriesPath, 'utf8'));

const newTerritories = [
  {
    "id": "jin_dynasty",
    "territoryType": "dynasty",
    "parentCivilizationId": "chinese",
    "start": { "year": 266, "datePrecision": "exact_year" },
    "end": { "year": 420, "datePrecision": "exact_year" },
    "capitalPlaceIds": [],
    "names": {
      "primaryName": "Jin Dynasty",
      "localizedNames": { "zh-Hans": "晋朝", "en": "Jin Dynasty" },
      "aliases": []
    },
    "summary": "结束三国分裂局面，短暂统一中国。",
    "summaryEn": "Ended the Three Kingdoms period and briefly reunified China.",
    "color": "#8C6A5D",
    "sourceRefs": ["world_historical_gis_data"]
  },
  {
    "id": "northern_wei",
    "territoryType": "dynasty",
    "parentCivilizationId": "chinese",
    "start": { "year": 386, "datePrecision": "exact_year" },
    "end": { "year": 534, "datePrecision": "exact_year" },
    "capitalPlaceIds": [],
    "names": {
      "primaryName": "Northern Wei",
      "localizedNames": { "zh-Hans": "北魏", "en": "Northern Wei" },
      "aliases": ["Toba Wei"]
    },
    "summary": "南北朝时期北方的强大王朝，推动了民族大融合。",
    "summaryEn": "A powerful northern dynasty during the Northern and Southern dynasties period, promoting ethnic integration.",
    "color": "#4A6E8C",
    "sourceRefs": ["world_historical_gis_data"]
  },
  {
    "id": "sui_dynasty",
    "territoryType": "dynasty",
    "parentCivilizationId": "chinese",
    "start": { "year": 581, "datePrecision": "exact_year" },
    "end": { "year": 618, "datePrecision": "exact_year" },
    "capitalPlaceIds": [],
    "names": {
      "primaryName": "Sui Dynasty",
      "localizedNames": { "zh-Hans": "隋朝", "en": "Sui Dynasty" },
      "aliases": []
    },
    "summary": "结束了长达近三百年的分裂局面，重新统一全国。",
    "summaryEn": "Reunified China after nearly three centuries of division.",
    "color": "#7B4F3A",
    "sourceRefs": ["world_historical_gis_data"]
  },
  {
    "id": "song_dynasty",
    "territoryType": "dynasty",
    "parentCivilizationId": "chinese",
    "start": { "year": 960, "datePrecision": "exact_year" },
    "end": { "year": 1279, "datePrecision": "exact_year" },
    "capitalPlaceIds": [],
    "names": {
      "primaryName": "Song Dynasty",
      "localizedNames": { "zh-Hans": "宋朝", "en": "Song Dynasty" },
      "aliases": []
    },
    "summary": "经济、文化和科技高度繁荣的时代。",
    "summaryEn": "An era of high economic, cultural, and technological prosperity.",
    "color": "#A62B2B",
    "sourceRefs": ["world_historical_gis_data"]
  },
  {
    "id": "ming_dynasty",
    "territoryType": "dynasty",
    "parentCivilizationId": "chinese",
    "start": { "year": 1368, "datePrecision": "exact_year" },
    "end": { "year": 1644, "datePrecision": "exact_year" },
    "capitalPlaceIds": [],
    "names": {
      "primaryName": "Ming Dynasty",
      "localizedNames": { "zh-Hans": "明朝", "en": "Ming Dynasty" },
      "aliases": []
    },
    "summary": "中国历史上最后一个由汉族建立的大一统王朝。",
    "summaryEn": "The last unified dynasty established by the Han people in Chinese history.",
    "color": "#CD5C5C",
    "sourceRefs": ["world_historical_gis_data"]
  },
  {
    "id": "qing_dynasty",
    "territoryType": "dynasty",
    "parentCivilizationId": "chinese",
    "start": { "year": 1636, "datePrecision": "exact_year" },
    "end": { "year": 1912, "datePrecision": "exact_year" },
    "capitalPlaceIds": [],
    "names": {
      "primaryName": "Qing Dynasty",
      "localizedNames": { "zh-Hans": "清朝", "en": "Qing Dynasty" },
      "aliases": ["Manchu Empire"]
    },
    "summary": "中国历史上最后一个封建王朝，奠定了现代中国的版图基础。",
    "summaryEn": "The last imperial dynasty of China, laying the territorial foundation of modern China.",
    "color": "#E6A817",
    "sourceRefs": ["world_historical_gis_data"]
  },
  {
    "id": "republic_of_china",
    "territoryType": "republic",
    "parentCivilizationId": "chinese",
    "start": { "year": 1912, "datePrecision": "exact_year" },
    "end": { "year": 1949, "datePrecision": "exact_year" },
    "capitalPlaceIds": [],
    "names": {
      "primaryName": "Republic of China",
      "localizedNames": { "zh-Hans": "中华民国", "en": "Republic of China" },
      "aliases": ["ROC"]
    },
    "summary": "亚洲第一个民主共和国。",
    "summaryEn": "The first democratic republic in Asia.",
    "color": "#18458A",
    "sourceRefs": ["world_historical_gis_data"]
  }
];

newTerritories.forEach(nt => {
  if (!territories.find(t => t.id === nt.id)) {
    territories.push(nt);
  }
});

fs.writeFileSync(territoriesPath, JSON.stringify(territories, null, 2));

// 2. Update territory_snapshots.json
const snapshotsPath = 'china_dynasty_atlas/assets/global/territory_snapshots.json';
let snapshots = JSON.parse(fs.readFileSync(snapshotsPath, 'utf8'));

// Update existing ones
const updates = {
  "qin_-221": { year: -323, geom: "qin_dynasty_unified_323bc" },
  "western_han_-141": { year: -200, geom: "han_dynasty_unified_200bc" },
  "tang_dynasty_800": { year: 800, geom: "tang_dynasty_unified_800" },
  "mongol_empire_1279": { year: 1279, geom: "yuan_dynasty_unified_1279" }
};

snapshots.forEach(s => {
  if (updates[s.id]) {
    s.geometryRefs = [updates[s.id].geom];
    s.displayYear = updates[s.id].year;
    s.validFrom.year = updates[s.id].year;
    s.validTo.year = updates[s.id].year;
  }
});

const newSnapshots = [
  {
    id: "jin_dynasty_400", territoryId: "jin_dynasty", displayYear: 400,
    validFrom: { year: 400, datePrecision: "exact_year" },
    validTo: { year: 400, datePrecision: "exact_year" },
    geometryRefs: ["jin_dynasty_unified_400"],
    mapFocus: { lat: 31.0, lng: 118.0, zoom: 4.0 },
    headline: "东晋与十六国", headlineEn: "Eastern Jin and Sixteen Kingdoms",
    sourceRefs: ["world_historical_gis_data"], reviewStatus: "approved"
  },
  {
    id: "northern_wei_400", territoryId: "northern_wei", displayYear: 400,
    validFrom: { year: 400, datePrecision: "exact_year" },
    validTo: { year: 400, datePrecision: "exact_year" },
    geometryRefs: ["northern_wei_unified_400"],
    mapFocus: { lat: 39.0, lng: 113.0, zoom: 4.0 },
    headline: "北魏崛起", headlineEn: "Rise of Northern Wei",
    sourceRefs: ["world_historical_gis_data"], reviewStatus: "approved"
  },
  {
    id: "sui_dynasty_600", territoryId: "sui_dynasty", displayYear: 600,
    validFrom: { year: 600, datePrecision: "exact_year" },
    validTo: { year: 600, datePrecision: "exact_year" },
    geometryRefs: ["sui_dynasty_unified_600"],
    mapFocus: { lat: 34.0, lng: 108.0, zoom: 4.0 },
    headline: "大唐前夜的大一统", headlineEn: "Reunification on the eve of Tang",
    sourceRefs: ["world_historical_gis_data"], reviewStatus: "approved"
  },
  {
    id: "song_dynasty_1000", territoryId: "song_dynasty", displayYear: 1000,
    validFrom: { year: 1000, datePrecision: "exact_year" },
    validTo: { year: 1000, datePrecision: "exact_year" },
    geometryRefs: ["song_dynasty_unified_1000"],
    mapFocus: { lat: 34.0, lng: 114.0, zoom: 4.0 },
    headline: "北宋时期的经济与文化繁荣", headlineEn: "Economic and cultural prosperity during Northern Song",
    sourceRefs: ["world_historical_gis_data"], reviewStatus: "approved"
  },
  {
    id: "ming_dynasty_1530", territoryId: "ming_dynasty", displayYear: 1530,
    validFrom: { year: 1530, datePrecision: "exact_year" },
    validTo: { year: 1530, datePrecision: "exact_year" },
    geometryRefs: ["ming_dynasty_unified_1530"],
    mapFocus: { lat: 39.9, lng: 116.4, zoom: 4.0 },
    headline: "大明王朝的中后期", headlineEn: "Middle and late Ming Dynasty",
    sourceRefs: ["world_historical_gis_data"], reviewStatus: "approved"
  },
  {
    id: "qing_dynasty_1650", territoryId: "qing_dynasty", displayYear: 1650,
    validFrom: { year: 1650, datePrecision: "exact_year" },
    validTo: { year: 1650, datePrecision: "exact_year" },
    geometryRefs: ["qing_dynasty_unified_1650"],
    mapFocus: { lat: 39.9, lng: 116.4, zoom: 4.0 },
    headline: "清朝初年入关与统一", headlineEn: "Early Qing dynasty conquest and unification",
    sourceRefs: ["world_historical_gis_data"], reviewStatus: "approved"
  },
  {
    id: "roc_1920", territoryId: "republic_of_china", displayYear: 1920,
    validFrom: { year: 1920, datePrecision: "exact_year" },
    validTo: { year: 1920, datePrecision: "exact_year" },
    geometryRefs: ["roc_unified_1920"],
    mapFocus: { lat: 35.0, lng: 110.0, zoom: 4.0 },
    headline: "北洋政府时期的中华民国", headlineEn: "Republic of China under Beiyang Government",
    sourceRefs: ["world_historical_gis_data"], reviewStatus: "approved"
  }
];

newSnapshots.forEach(ns => {
  if (!snapshots.find(s => s.id === ns.id)) {
    snapshots.push(ns);
  }
});

fs.writeFileSync(snapshotsPath, JSON.stringify(snapshots, null, 2));

// 3. Update project_scope.json
const scopePath = 'china_dynasty_atlas/assets/config/project_scope.json';
let scope = JSON.parse(fs.readFileSync(scopePath, 'utf8'));

// add years and territories
const additionalYears = [-323, 400, 600, 1000, 1530, 1920];
additionalYears.forEach(y => {
  if (!scope.timelineYears.includes(y)) scope.timelineYears.push(y);
});
scope.timelineYears.sort((a, b) => a - b);

const additionalTerritories = ["jin_dynasty", "northern_wei", "sui_dynasty", "song_dynasty", "ming_dynasty", "qing_dynasty", "republic_of_china"];
additionalTerritories.forEach(t => {
  if (!scope.coreTerritoryIds.includes(t)) scope.coreTerritoryIds.push(t);
});

fs.writeFileSync(scopePath, JSON.stringify(scope, null, 2));
console.log("Updated config files");

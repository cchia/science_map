const fs = require('fs');
const path = require('path');

const inputDir = 'data_references/world_history_gis/world-historical-gis-data/output_geojson';
const outputDir = 'china_dynasty_atlas/assets/geojson/unified';

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Map of year/file to the empires we want to extract
const targets = [
  { file: '323BC.geojson', nameMatch: 'Qin', outFile: 'qin_dynasty_-323' },
  { file: '200BC.geojson', nameMatch: 'Han Empire', outFile: 'han_dynasty_-200' },
  { file: '400.geojson', nameMatch: 'Jin Empire', outFile: 'jin_dynasty_400' },
  { file: '400.geojson', nameMatch: 'Toba Wei', outFile: 'northern_wei_400' },
  { file: '600.geojson', nameMatch: 'Sui Empire', outFile: 'sui_dynasty_600' },
  { file: '800.geojson', nameMatch: 'Tang Empire', outFile: 'tang_dynasty_800' }, // might already exist, but we will overwrite or keep unified
  { file: '1000.geojson', nameMatch: 'Song Empire', outFile: 'song_dynasty_1000' },
  { file: '1279.geojson', nameMatch: 'Great Khanate', outFile: 'yuan_dynasty_1279' },
  { file: '1530.geojson', nameMatch: 'Ming Chinese Empire', outFile: 'ming_dynasty_1530' },
  { file: '1650.geojson', nameMatch: 'Manchu Empire', outFile: 'qing_dynasty_1650' },
  { file: '1920.geojson', nameMatch: 'China', outFile: 'roc_1920' },
];

for (const target of targets) {
  const inputPath = path.join(inputDir, target.file);
  if (!fs.existsSync(inputPath)) {
    console.log(`File not found: ${inputPath}`);
    continue;
  }

  const data = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const feature = data.features.find(f => {
    const name = f.properties.name || f.properties.NAME || '';
    return name.toLowerCase() === target.nameMatch.toLowerCase();
  });

  if (feature) {
    const outFeatureCollection = {
      type: "FeatureCollection",
      features: [feature]
    };
    const outPath = path.join(outputDir, `${target.outFile}.geojson`);
    fs.writeFileSync(outPath, JSON.stringify(outFeatureCollection, null, 2));
    console.log(`Extracted ${target.nameMatch} to ${outPath}`);
  } else {
    console.log(`Could not find ${target.nameMatch} in ${target.file}`);
  }
}

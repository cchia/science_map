const fs = require('fs');
const files = fs.readdirSync('data_references/world_history_gis/world-historical-gis-data/output_geojson').filter(f => f.endsWith('.geojson'));

for (const file of files) {
  const data = JSON.parse(fs.readFileSync('data_references/world_history_gis/world-historical-gis-data/output_geojson/' + file));
  const chineseFeatures = data.features.filter(f => {
    const name = (f.properties.name || '').toLowerCase();
    return name.includes('china') || name.includes('dynasty') || name.includes('empire') || name.includes('han') || name.includes('tang') || name.includes('song') || name.includes('yuan') || name.includes('ming') || name.includes('qing') || name.includes('qin') || name.includes('wei') || name.includes('shu') || name.includes('wu') || name.includes('jin');
  });
  if (chineseFeatures.length > 0) {
    console.log(file, '->', chineseFeatures.map(f => f.properties.name).join(', '));
  }
}

const fs = require('fs');

const manifest = JSON.parse(fs.readFileSync('/Users/cchia/projects/science_map/china_dynasty_atlas/assets/global/geometry_manifest.json'));
const foundV3 = manifest.filter(m => m.id.includes('v3') && (m.id.includes('wei') || m.id.includes('shu') || m.id.includes('wu')));
console.log(foundV3.map(f => f.id));

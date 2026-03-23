const fs = require('fs');

const snapshotsPath = '/Users/cchia/projects/science_map/china_dynasty_atlas/assets/global/territory_snapshots.json';
let snapshots = JSON.parse(fs.readFileSync(snapshotsPath, 'utf8'));

const updates = {
  "xin_8": { year: 8, geom: "han_dynasty_unified_200bc" },
  "eastern_han_25": { year: 25, geom: "han_dynasty_unified_200bc" },
  "cao_wei_220": { year: 220, geom: "han_dynasty_unified_200bc" },
  "shu_han_221": { year: 221, geom: "han_dynasty_unified_200bc" },
  "eastern_wu_229": { year: 229, geom: "han_dynasty_unified_200bc" },
  "cao_wei_229": { year: 229, geom: "han_dynasty_unified_200bc" },
  "shu_han_229": { year: 229, geom: "han_dynasty_unified_200bc" },
  "shu_han_263": { year: 263, geom: "han_dynasty_unified_200bc" }
};

snapshots.forEach(s => {
  if (updates[s.id]) {
    s.geometryRefs = [updates[s.id].geom];
    // Keep their original display years!
    s.displayYear = updates[s.id].year;
    s.validFrom.year = updates[s.id].year;
    s.validTo.year = updates[s.id].year;
  }
});

fs.writeFileSync(snapshotsPath, JSON.stringify(snapshots, null, 2));
console.log("Updated territory_snapshots.json via script!");

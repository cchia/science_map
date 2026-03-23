const fs = require('fs');

const scopePath = '/Users/cchia/projects/science_map/china_dynasty_atlas/assets/config/project_scope.json';
let scope = JSON.parse(fs.readFileSync(scopePath, 'utf8'));

// Make sure we have the correct years in the timeline
const correctYears = [-323, -200, 8, 25, 220, 221, 229, 263, 400, 600, 800, 1000, 1279, 1530, 1650, 1920];
correctYears.forEach(y => {
  if (!scope.timelineYears.includes(y)) scope.timelineYears.push(y);
});

// Remove -141, -221 if they were replaced
scope.timelineYears = scope.timelineYears.filter(y => y !== -141 && y !== -221);
scope.timelineYears.sort((a, b) => a - b);

fs.writeFileSync(scopePath, JSON.stringify(scope, null, 2));
console.log("Updated project_scope.json via script!");

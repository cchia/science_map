const fs = require('fs');
const path = require('path');

const inputDir = '/Users/cchia/projects/science_map/data_references/world_history_gis/world-historical-gis-data/output_geojson';
const outputDir = '/Users/cchia/projects/science_map/china_dynasty_atlas/assets/geojson/world';

if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

// List of target empires to extract
const targets = [
    // Ancient
    'Roman Empire', 'Parthia', 'Maurya', 'Macedon and Hellenic League', 
    // Late Antiquity / Early Medieval
    'Sasanian Empire', 'Byzantine Empire', 'Frankish Kingdom', 'Visigothic Kingdom', 'Gupta Empire',
    // Medieval (800 CE)
    'Carolingian Empire', 'Umayyad Caliphate', 'Abbasid Caliphate', 'Tang Empire',
    // High Medieval (1279 CE)
    'Holy Roman Empire', 'Khmer Empire', 'Chagatai Khanate', 'Great Khanate', 'Ilkhanate', 'Khanate of the Golden Horde',
    // Early Modern (1492 CE, 1530 CE)
    'Ottoman Empire', 'Inca Empire', 'Aztec Empire', 'Ming Empire', 'Safavid Empire', 'Mughal Empire',
    // Modern (1880 CE, 1914 CE)
    'British Empire', 'French Empire', 'Russian Empire', 'Qing Empire'
];

const files = fs.readdirSync(inputDir).filter(f => f.endsWith('.geojson'));

let extractedCount = 0;

files.forEach(file => {
    const yearStr = file.replace('.geojson', '');
    const data = JSON.parse(fs.readFileSync(path.join(inputDir, file), 'utf8'));
    
    data.features.forEach(feature => {
        if (!feature.properties || !feature.properties.name) return;
        const name = feature.properties.name;
        
        // Use exact match or include check for empires
        if (targets.includes(name) || targets.some(t => name.includes(t))) {
            // Normalize name for filename
            let safeName = name.toLowerCase().replace(/[^a-z0-9]+/g, '_');
            // special rename for Great Khanate
            if (safeName === 'great_khanate') safeName = 'yuan_dynasty';
            const outName = `${safeName}_${yearStr.toLowerCase()}.geojson`;
            
            // Create a single-feature FeatureCollection
            const outGeoJson = {
                type: "FeatureCollection",
                features: [feature]
            };
            
            fs.writeFileSync(path.join(outputDir, outName), JSON.stringify(outGeoJson));
            console.log(`Extracted: ${outName}`);
            extractedCount++;
        }
    });
});

console.log(`Extraction complete. Total files created/updated: ${extractedCount}`);


# Qin-Han Boundary Reconstruction Notes

## Goal

This note records how the four China MVP snapshots were upgraded from teaching-grade polygons to single-boundary tracing samples for the product UI, and then refined again in a higher-detail `v4` pass.

## What Changed

- `qin_-221`: tightened the unification-year outline so later Qin southern consolidation is not projected backward.
- `western_han_-141`: removed the overly large far-west and far-south footprint that made the map resemble a later Western Han maximum extent.
- `xin_8`: kept the inherited Han-shaped outline while trimming overstated western and southern reach.
- `eastern_han_25`: shrank the western and northwestern edge to better fit the early restoration period instead of a later consolidated Eastern Han outline.

## Licensing Position

- Final product geometry is stored as internal editorial tracing assets under the active `*_main_v5` and `*_main_v4` geometry sources.
- No third-party polygon geometry was copied into the app assets.
- Public-domain reference used for calibration:
  - Wikimedia Commons `Han Dynasty Map with greatwall protectorates and other areas.PNG`
- Reference-only comparison source:
  - Wikimedia Commons `Qin empire 210 BCE.png`
- Academic-only source kept out of product geometry:
  - `CHGIS`

## Method

1. Keep the product-safe output as self-produced GeoJSON.
2. Use historical reference maps only to calibrate relative westward reach, coastline placement, and period-appropriate outer boundaries.
3. Prefer under-claiming frontier extent over drawing a later maximum imperial footprint too early.
4. Keep uncertainty in metadata and notes rather than showing multiple default map layers.

## Current Accuracy Level

- The new assets are better than the original teaching-grade polygons for product storytelling.
- They are still editorial reconstructions, not county-level historical GIS.
- For a future production pass, the next upgrade should be traced vector geometry built in GIS against a documented multi-source base map workflow.

## v4 Precision Pass

- `v4` focuses on shape precision, not new UI structure.
- The main improvements are:
  - more articulated Bohai and eastern coast transitions
  - better separation between Qin, Western Han, Xin, and early Eastern Han outlines
  - smoother but more period-specific southern arcs
  - less rounded, less interchangeable west-to-south edge shapes

## Western Han 141 BCE v3 Sample

- `western_han_-141` was the first tracing-sample snapshot in the project and has since been further refined in `v4`.
- The `v3` sample intentionally removes two major historical overstatements:
  - it does not draw the post-111 BCE Lingnan annexation as if it already belonged to Han in 141 BCE
  - it does not draw the post-60 BCE Western Regions protectorate footprint as if it already existed at Emperor Wu's accession
- References used for calibration:
  - Wikimedia Commons `Han Dynasty Map with greatwall protectorates and other areas.PNG` (public domain)
  - Wikimedia Commons `Western Han Mawangdui Silk Map.JPG` (public domain mark)
- Final output remains self-produced GeoJSON:
  - `assets/geojson/western_han_-141_main_v5.geojson`

## Single-Boundary Direction

- The product UI now uses one visible boundary per year.
- Older `core / frontier` working assets were removed from the active data layer.
- The current main-boundary tracing samples are:
  - `assets/geojson/qin_-221_main_v5.geojson`
  - `assets/geojson/western_han_-141_main_v5.geojson`
  - `assets/geojson/xin_8_main_v5.geojson`
  - `assets/geojson/eastern_han_25_main_v5.geojson`

## Additional v3 Samples

- `qin_-221_main_v5`:
  - tightens the unification-year outline and refines the Bohai turn, east coast, and southern turn
- `western_han_-141_main_v5`:
  - better distinguishes the western expansion staging zone, Bohai turn, Shandong peninsula, and lower Yangtze-to-south transition
- `xin_8_main_v5`:
  - keeps the inherited Han-shaped imperial outline but places it more clearly between the broader Western Han and the more contracted Eastern Han restoration outline
- `eastern_han_25_main_v5`:
  - aligns the map to the early restoration footprint with a clearer west and south contraction than both the Xin outline and the later mature Eastern Han envelope

## Western Han 141 BCE v5

- `western_han_-141` received a focused `v5` precision pass after the broader `v4` upgrade.
- This pass concentrated on:
  - the Shandong peninsula projection
  - the Bohai turn and east-coast articulation
  - the lower Yangtze to southern frontier closure
- Additional comparison reference:
  - Wikimedia Commons `Han commanderies and kingdoms CE 2.jpg` (reference only)
- Current active file:
  - `assets/geojson/western_han_-141_main_v5.geojson`

## Qin 221 BCE v5

- `qin_-221` received a focused `v5` precision pass after the broader `v4` upgrade.
- This pass concentrated on:
  - the Bohai turn
  - the east-coast articulation
  - the southern closure of the unification-year outline
- Current active file:
  - `assets/geojson/qin_-221_main_v5.geojson`

## Eastern Han 25 CE v5

- `eastern_han_25` received a focused `v5` precision pass after the broader `v4` upgrade.
- This pass concentrated on:
  - clearer western contraction
  - a more restrained southern closure
  - more visible separation from the inherited Xin outline
- Current active file:
  - `assets/geojson/eastern_han_25_main_v5.geojson`

## Xin 8 CE v5

- `xin_8` received a focused `v5` precision pass after the broader `v4` upgrade.
- This pass concentrated on:
  - preserving the inherited Han frame without reverting to a full Western Han maximum-like outline
  - keeping the east coast articulated while tightening the west and south into a clearer middle position
  - improving visual separation from the more contracted Eastern Han 25 restoration footprint
- Current active file:
  - `assets/geojson/xin_8_main_v5.geojson`

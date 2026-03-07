# Commercial Data Source Notes

This document tracks boundary and metadata sources for a future commercial history product.
It is a product decision aid, not legal advice. Before shipping, review the original license
text and any source-specific terms again.

## Source Categories

### Safe or Promising For Product Use

| Source | Coverage | Typical Use | License / Access | Commercial Use | Redistribution | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [OpenHistoricalMap](https://www.openhistoricalmap.org/copyright) | Global, uneven historical coverage | Historical boundary and feature reference, sometimes direct product data | Mostly `CC0`; some individual elements may carry `CC BY` or `CC BY-SA` tags | Yes, in general | Yes, but check tagged exceptions | Best open candidate for global historical data, but quality varies by region and era. Always inspect `license=*` tags for reused features. |
| [Wikidata](https://www.wikidata.org/wiki/Wikidata:Licensing) | Global entities and metadata | People, places, dynasties, aliases, dates, linking metadata | `CC0` | Yes | Yes | Excellent for structured metadata, not a boundary source. Good for IDs, multilingual labels, and date ranges. |
| [Natural Earth](https://www.naturalearthdata.com/about/terms-of-use/) | Global modern geography | Modern fallback borders, coastlines, physical basemap context | Public domain | Yes | Yes | Useful for modern layers and base cartography, not a historical boundary dataset. |
| [geoBoundaries gbOpen](https://www.geoboundaries.org/) | Global modern admin boundaries | Modern country/admin fallback and present-day reference overlays | `CC BY 4.0` | Yes | Yes, with attribution | Good for modern periods and present-day context. Prefer the `gbOpen` release for commercial compatibility. |
| [Atlas of Historical County Boundaries](https://digital.newberry.org/ahcb/project.html) | United States historical counties | High-quality US historical boundaries | `CC0` | Yes | Yes | Strong source for US expansion later if the product adds American historical layers. |
| [Euratlas historical vector data](https://www.euratlas.net/eshop/en/home/3-georeferenced-historical-vector-data.html) | Europe | Historical vector boundaries | Paid commercial license | Yes, via agreement | Per contract | Good commercial route for Europe if you want higher-quality licensed data instead of open community data. |

### Use As Research / Validation Only

| Source | Coverage | Why Useful | Why Not Direct Product Data |
| --- | --- | --- | --- |
| [CHGIS](https://chgis.fas.harvard.edu/data/chgis/v6) | China, dynastic period | Very strong academic base for Chinese historical admin changes and source notes | Explicitly says free for academic research only; no commercial use or redistribution |
| [CShapes](https://icr.ethz.ch/data/cshapes/) | Global sovereign boundaries, mostly 1886+ | Helpful for recent historical state boundary research | `CC BY-NC-SA 4.0`, so not suitable for direct commercial use |
| [OldMapsOnline](https://oldmapsonline.org/en) | Historical map discovery portal | Good for finding scans and validation references | It is an aggregator; usage rights depend on the hosting institution |
| [World Historical Gazetteer](https://whgazetteer.org/licensing/) | Global historical places | Useful gazetteer and place reconciliation source | Some public datasets are `CC BY 4.0`, but platform content is not uniformly commercial-friendly; evaluate dataset by dataset |

## Recommended Product Strategy

### 1. Split All Sources Into Three Buckets

- `product-approved`: can ship in app/web product
- `reference-only`: may guide editing, cannot be redistributed in product
- `pending-review`: not yet approved by product/legal review

### 2. Preferred Stack For A Global History App

- Historical boundaries: `OpenHistoricalMap` where quality is acceptable, otherwise self-produced geometry
- Modern fallback boundaries: `Natural Earth` and `geoBoundaries gbOpen`
- Entity metadata: `Wikidata`
- Region-specific commercial upgrades: paid data like `Euratlas` where open coverage is weak

### 3. Do Not Mix Licenses Blindly

The main risk is not "using one bad source", but mixing:

- `CC0`
- `CC BY`
- `share alike`
- `non-commercial`
- contract-only commercial data

inside the same exported GeoJSON or app bundle without tracking provenance. Every shipped geometry
should map back to one approved source record in your license ledger.

## Practical Recommendations By Product Stage

### MVP

- Use `OpenHistoricalMap` plus self-edited geometry for historical periods
- Use `Natural Earth` / `geoBoundaries` for modern context layers
- Use `Wikidata` for people/place metadata
- Keep every imported file tagged with provenance and license notes

### Commercial Beta

- Replace weak open historical areas with self-produced or contract-licensed geometry
- Freeze a source review process before adding new regions
- Add attribution UI and an in-app data credits page

### Scaled Product

- Maintain per-region source ownership rules
- Version every geometry file and ledger record
- Run periodic audits for attribution and redistribution compatibility

## Minimum Review Questions For Any New Source

1. Can we use it commercially?
2. Can we redistribute raw or derived data in app bundles?
3. Can we modify and simplify the geometry?
4. Is attribution required in product UI?
5. Is there share-alike or contract lock-in?
6. Is coverage strong enough to avoid region-by-region rewrites?

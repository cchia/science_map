# Data License Ledger Template

Use this template to approve every boundary, gazetteer, basemap, and metadata source before it
enters the product repository or build pipeline.

## Required Fields

| Field | Meaning |
| --- | --- |
| `source_id` | Stable internal ID, e.g. `ohm_world_polities` |
| `source_name` | Human-readable dataset or provider name |
| `category` | `historical_boundary`, `modern_boundary`, `gazetteer`, `people_metadata`, `imagery_reference`, `vendor_contract` |
| `region_scope` | Global or region name, e.g. `global`, `china`, `europe` |
| `time_scope` | Covered years or era, e.g. `1886-2019`, `Qin-Han`, `modern` |
| `product_use_case` | Why this source is being considered |
| `source_url` | Canonical landing page |
| `download_url` | Exact file or API endpoint if applicable |
| `license_name` | `CC0`, `CC BY 4.0`, `custom contract`, etc. |
| `license_url` | Direct link to legal terms |
| `commercial_use_allowed` | `yes`, `no`, `unknown`, `contract` |
| `redistribution_allowed` | Can the data or derivative file ship in product repos/builds? |
| `modification_allowed` | Can you simplify, merge, clip, or transform it? |
| `attribution_required` | `yes` or `no` |
| `attribution_text` | Exact text to use in app/site/docs |
| `share_alike_obligation` | `none`, `possible`, or exact terms |
| `approval_status` | `approved`, `reference_only`, `pending_review`, `blocked` |
| `review_owner` | Person responsible for license decision |
| `review_date` | Latest review date |
| `evidence_notes` | Short summary of what the terms actually say |
| `downstream_files` | Which project files were created from this source |
| `risk_notes` | Any concerns: uneven quality, unclear rights, per-feature exceptions |

## Decision Rules

### `approved`

Use only when all of the following are true:

- commercial use is allowed
- modification is allowed
- redistribution or derived-product shipping is allowed
- attribution obligations are understood
- no unresolved legal ambiguity remains

### `reference_only`

Use when the source is valuable for research or manual QA but should not be shipped directly:

- non-commercial academic datasets
- institution-scoped scanned maps with unclear reuse rights
- community sources with mixed per-feature licensing not yet filtered

### `pending_review`

Use when the source looks promising but you have not yet reviewed the original license text.

### `blocked`

Use when the terms are incompatible with the product:

- no commercial use
- no redistribution
- no derivatives
- impossible attribution burden

## Suggested Workflow

1. Add a source record before downloading or importing any data.
2. Save a copy of the exact license URL and quote the relevant clause in `evidence_notes`.
3. Mark the source as `pending_review`.
4. Change to `approved`, `reference_only`, or `blocked` after review.
5. Record every generated GeoJSON or transformed output in `downstream_files`.
6. Re-review if the source version or license page changes.

## Attribution Policy

Maintain one central credits page in the product and link each approved source to the exact
attribution text it requires. Also keep a short attribution variant for mobile UI when space is
limited.

Example:

```text
Historical features include data derived from OpenHistoricalMap (public domain unless otherwise noted).
Modern administrative boundaries include geoBoundaries (CC BY 4.0).
Entity metadata includes Wikidata (CC0).
```

## Repository Practice

- Keep the ledger in version control.
- Do not merge new source-derived files unless a ledger row exists.
- Store raw downloads outside the app bundle when redistribution is not allowed.
- Keep derived files traceable back to one or more approved source IDs.

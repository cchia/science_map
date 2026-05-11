# 历史疆域边界数据规划

本文档用于重新规划 `china_dynasty_atlas` 的历史疆域数据策略。目标不是继续零散修补
GeoJSON，而是建立一套可复用、可追溯、可审核的历史地图数据生产流程。

## 为什么需要重做规划

现有数据已经可以渲染地图，但边界精度和数据可信度还没有形成统一标准：

- 有些边界是手工示意图，有些来自社区项目，有些来自全球历史 GIS 数据集。
- 不同时期的精度差异很大，但数据中没有足够清楚地标记。
- 三国、五胡十六国、南北朝、五代十国等分裂时期，不能用单一朝代边界或粗略占位图表达。
- 时间轴混用了“事件年份”和“地图场景年份”。建国或灭亡年份不一定适合作为完整地图快照。
- 虽然已经有 `sources.json` 和 `geometry_manifest.json`，但还没有强制每个边界文件走同一套来源、精度、审核流程。

新的地图数据应该能回答三个问题：

- 这个 polygon 表达的历史含义是什么？
- 它来自哪个来源，或通过什么方法重建？
- 在当前产品缩放级别下，它的可信度有多高？

## 产品层面的边界定义

历史疆域不应默认显示成现代国界式的硬边界。每个边界图层都必须说明它代表哪一种历史控制关系。

### 边界含义类型

每个几何图层应使用以下类型之一：

- `core_admin`：直接治理的核心行政区域。
- `military_control`：军事控制区，行政控制可能不稳定。
- `frontier_command`：边郡、都护府、军镇、羁縻府州等边疆治理结构。
- `tributary_or_vassal`：属国、附庸、朝贡或名义从属区域。
- `claimed`：声称拥有但实际控制不足的区域。
- `influence`：势力范围、贸易影响区、文化或政治影响区。
- `disputed`：多方争夺或归属有争议的区域。
- `schematic`：资料不足时的编辑性示意边界。

中国早期王朝和分裂时期应优先表达 `core_admin`，必要时叠加边疆、争议和影响区。不要把所有控制关系压成一个实心大 polygon，除非 UI 中明确标记为示意。

### 地图快照含义

`displayYear` 应理解为“代表性地图场景”，不一定代表这一整年的精确边界。

例子：

- `229 CE` 适合作为三国地图场景，因为曹魏、蜀汉、东吴已经形成完整三方格局。
- `220 CE` 不适合作为完整三国地图场景，因为它主要是曹魏代汉的事件节点。
- `221 CE` 不适合作为完整三国地图场景，因为它主要是蜀汉建国的事件节点。
- `263 CE` 不适合作为完整三国地图场景，因为蜀汉已经灭亡。

建国、灭亡、战役等年份通常应放入 `events.json`，而不是默认加入地图时间轴。除非产品明确要展示“过渡态地图”。

## 精度等级

每个地图几何文件必须声明精度等级。

### `source_exact`

用于直接来自学术 GIS 数据、可验证的数字化历史地图，或明确记录处理过程的权威来源。

要求：

- 有 source record，记录来源、许可、访问方式。
- 有处理脚本或处理方法文档。
- 知道原始数据粒度，例如郡县级、省级、帝国轮廓级。
- 至少经过一次人工对照审核。

### `derived_scholarly`

用于根据学术资料、历史地图集、行政区划单位或多份参考资料重建的边界。

要求：

- 主要区域都有来源说明。
- 有方法说明，解释如何从原始资料拼接成 polygon。
- 对边疆、争议区和资料不确定处写入 `disputeNotes`。

### `community_reference`

用于来自社区项目、游戏 mod、公开爱好者历史地图或非学术开源仓库的数据。

要求：

- 记录仓库地址和 license。
- 在独立验证前，不应标为高精度。
- UI 和说明文字中避免使用“精确”“权威”等表述。

### `editorial_schematic`

用于团队自行手绘或粗略估计的边界。

要求：

- 数据和 UI 都必须标记为示意。
- 不应与高可信图层混在一起而没有视觉区分。
- 除非产品明确需要示意叙事，否则应视为临时版本。

### `placeholder`

仅用于资料缺失时保持产品流程完整。

要求：

- 不能作为正式边界展示。
- 必须有替换计划或 TODO。
- UI 中应隐藏、弱化或显示“数据暂缺”状态。

## 数据来源策略

没有一个数据源能覆盖所有地区和时期，因此需要分层使用来源。

### 中国核心数据

优先级建议：

- CHGIS：用于历史行政地理、地点、长时段中国 GIS 基础数据。
- 可合法使用的学术历史地图集或数字化资料。
- 公共领域或许可明确的历史地图，用于视觉校验。
- 社区 GeoJSON 只能作为辅助参考或临时数据。

中国疆域应尽量从行政单位重建，而不是直接套用帝国外轮廓。分裂时期尤其应该从郡、州、道、府、路等单位出发，按代表年份归属进行 dissolve。

### 世界背景数据

优先级建议：

- 开源世界历史 GIS 数据集，用于全球背景和大范围帝国。
- Natural Earth 仅用于现代底图或地理参考，不用于历史疆域。
- 能找到区域性学术数据时，优先使用区域数据。

世界背景在早期版本中可以低于中国数据精度，但仍然必须标记来源和精度等级。

### 资料缺口处理

当找不到合适数据时：

- 使用 `placeholder` 或 `editorial_schematic`。
- 明确记录缺失原因。
- 宁愿显示“资料不足”，也不要画一个看起来很精确但实际误导用户的边界。

## 分裂时期处理原则

分裂时期需要展示的是一个“政治场景”，而不是某个单独政权。

### 通用规则

- 只有当主要并立政权都能显示时，才把某一年加入默认时间轴。
- 不要为了建国或灭亡事件加入单一政权年份，除非 UI 明确显示为事件场景。
- 事件年份继续保留在 `events.json`。
- 后续应引入 `map_scenes.json`，用场景管理多政权快照。

### 三国

默认地图场景：

- `229 CE`：曹魏、蜀汉、东吴完整并立。

事件年份：

- `220 CE`：东汉结束、曹魏建立。
- `221 CE`：蜀汉建立。
- `263 CE`：蜀汉灭亡。
- `280 CE`：西晋统一，可作为之后的统一场景。

推荐重建方法：

- 使用郡县级或州郡级底图。
- 为代表年份 `229 CE` 建立行政单位归属表。
- 按魏、蜀、吴分别 dissolve。
- 争议区和频繁变化的边境不要强行并入核心区，应独立标记为 `disputed` 或 `military_control`。

### 五胡十六国与南北朝

不能只用“东晋 + 北魏”代表整个时期。

建议场景：

- `317 CE`：东晋建立与北方分裂。
- `376 CE`：前秦强盛、淝水之战前夜。
- `400 CE`：东晋、北魏崛起与北方诸政权。
- `439 CE`：北魏统一北方。
- `479 CE` 或 `500 CE`：南北朝成熟对峙。

每个场景都应显示当时主要政权；如果只显示部分政权，必须标记为 partial scene。

### 五代十国

不能用晚唐或北宋轮廓代替五代十国。

建议场景：

- `907 CE`：唐亡、后梁建立及主要割据政权。
- `923 CE`：后唐及十国并立。
- `951 CE`：后周与南方诸国。
- `960 CE`：北宋建立。
- `979 CE`：北宋灭北汉后的整合。

在没有真实小国边界前，`907 CE` 应标记为 `placeholder`，或从默认权威时间轴中隐藏。

## 数据模型建议

现有 `Territory`、`TerritorySnapshot`、`GeometryAsset` 可以继续作为基础，但需要增加更严格的字段。

### GeometryAsset 建议字段

```json
{
  "id": "cao_wei_229_core_admin_v1",
  "assetPath": "assets/geojson/china/three_kingdoms/cao_wei_229_core_admin_v1.geojson",
  "geometryType": "Polygon",
  "regionScope": "china",
  "boundaryMeaning": "core_admin",
  "accuracyTier": "derived_scholarly",
  "sourceRefs": ["chgis", "historical_atlas_reference"],
  "methodRef": "methods/three_kingdoms_229_reconstruction.md",
  "projection": "EPSG:4326",
  "revision": "v1",
  "reviewStatus": "draft"
}
```

### TerritorySnapshot 建议字段

```json
{
  "id": "three_kingdoms_scene_229_cao_wei",
  "territoryId": "cao_wei",
  "displayYear": 229,
  "sceneId": "three_kingdoms_229",
  "geometryRefs": ["cao_wei_229_core_admin_v1", "cao_wei_229_disputed_v1"],
  "snapshotRole": "scene_member",
  "mapCompleteness": "complete_scene",
  "accuracy": {
    "level": "medium",
    "tier": "derived_scholarly",
    "note": "基于 229 CE 代表场景的州郡归属重建。"
  }
}
```

### MapScene 新模型

后续可新增 `map_scenes.json`，专门管理完整地图场景。

```json
{
  "id": "three_kingdoms_229",
  "displayYear": 229,
  "title": {
    "zh-Hans": "三国鼎立",
    "en": "Three Kingdoms"
  },
  "territorySnapshotIds": [
    "three_kingdoms_scene_229_cao_wei",
    "three_kingdoms_scene_229_shu_han",
    "three_kingdoms_scene_229_eastern_wu"
  ],
  "completeness": "complete_scene",
  "notes": "代表孙权称帝后三国并立格局完全形成的场景。"
}
```

短期内仍可用 `displayYear` 关联多个 snapshots。等分裂时期增多后，再引入 `map_scenes.json` 会更稳。

## 数据生产流程

所有新边界数据都应经过以下流程。

### 1. 数据接收

- 记录候选来源、license、URL 和覆盖范围。
- 原始文件放在 `data_references/` 或有文档说明的外部位置。
- 不直接修改原始文件。

### 2. 标准化

- 转为 GeoJSON。
- 统一坐标系为 EPSG:4326。
- 规范字段、名称和编码。
- 输出到 `assets/geojson/...`。

### 3. 重建

分裂时期应：

- 将基础行政单位分配给代表年份的不同政权。
- 按政权 dissolve。
- 对争议区、边疆区、军事控制区保留单独图层。
- 输出核心区、争议区、影响区等多层 GeoJSON。

### 4. 自动校验

至少检查：

- 每个 GeoJSON 都是 `FeatureCollection`。
- 每个 `assetPath` 文件真实存在，并且在 `pubspec.yaml` 的资产目录下。
- 每个 `geometryRef` 都能在 `geometry_manifest.json` 中找到。
- 每个地图年份都包含应有的场景成员。
- 坐标是合法经纬度。
- 面积不为零，也没有明显超出预期范围。
- 高可信资产不能只引用 `editorial_internal_v1`。

### 5. 人工审核

人工审核应检查：

- 年份是否适合做地图场景。
- 是否漏掉同一时期的重要并立政权。
- 边疆和争议说明是否充分。
- UI 是否夸大了边界精度。

### 6. 发布

默认地图只展示 `approved` 或明确标记为 `draft` 的数据。`placeholder` 数据应隐藏或弱化显示。

## 文件组织建议

后续建议逐步迁移到如下结构：

```text
assets/
  geojson/
    china/
      qin_han/
      three_kingdoms/
      northern_southern_dynasties/
      five_dynasties_ten_kingdoms/
    world/
global/
  geometry_manifest.json
  territory_snapshots.json
  map_scenes.json
docs/
  data-model/
    historical-boundary-data-plan.md
  data-methods/
    three_kingdoms_229_reconstruction.md
    five_dynasties_source_gap.md
```

当前扁平的 `assets/geojson/` 结构可以保留兼容，但新数据应逐步进入按时期分组的目录。

## MVP 重置路线

### Phase 0：冻结现有精度声明

- 把现有手绘图、社区图、粗略图标记为 `draft`、`community_reference` 或 `editorial_schematic`。
- 移除没有依据的 “high precision” 表述。
- 保持产品可用，但明确显示不确定性。

### Phase 1：定义标准地图场景

用代表性场景替代事件年份：

- 秦汉统一与过渡场景。
- `229 CE` 三国鼎立场景。
- 五胡十六国 / 南北朝的一到两个代表场景。
- 五代十国仅在有足够数据时加入默认时间轴。
- 统一王朝使用经过审核的中国或世界历史 GIS 数据。

### Phase 2：重建三国 229 场景

- 选择一个州郡级或郡县级底图。
- 建立 229 年行政单位归属表。
- 按魏、蜀、吴 dissolve。
- 标记争议和边疆区域。
- 保留 `220`、`221`、`263` 为事件，不作为默认地图年份。

### Phase 3：加入校验脚本

新增脚本检查：

- geometry manifest 是否完整。
- snapshot 是否都能找到 geometry。
- GeoJSON 格式是否统一。
- 时间轴场景是否完整。

这些脚本应在新增地图前运行。

### Phase 4：逐段重建分裂时期

优先顺序：

- 三国。
- 五胡十六国 / 南北朝。
- 五代十国。
- 宋、辽、西夏、金。

不要把 partial scene 和 complete scene 混在一起而不标记。

## 需要决策的问题

正式重建前需要决定：

- 产品是否宁愿少显示，也要避免显示不准确地图？
- 不确定边界是否默认显示，还是放到“实验数据”开关后面？
- 是否可以使用非商业学术资料作为视觉校验，同时自行存储派生边界？
- `map_scenes.json` 是现在就加，还是先用 `territory_snapshots.json` 和 `timelineYears` 约束？

## 立即建议

- 默认三国地图只保留 `229 CE`。
- `220`、`221`、`263` 不进入默认地图时间轴，只作为事件节点。
- 现有五代十国图标记为 `placeholder`，不要当真实边界。
- 在继续导入更多 GeoJSON 前，先写自动校验脚本。
- 真正重建从三国 229 开始，因为范围清楚、产品价值高、争议可控。
# Historical Boundary Data Plan

This document resets the boundary-data strategy for the atlas. The goal is to stop treating historical
maps as one-off GeoJSON fixes and instead build a repeatable pipeline for accurate, source-backed,
reviewable territorial snapshots.

## Why Reset

The current data can render polygons, but the accuracy model is too loose:

- Some boundaries are editorial sketches, while others come from community or global datasets.
- Precision varies by period without a clear quality label.
- Split periods such as Three Kingdoms, Sixteen Kingdoms, Northern and Southern Dynasties, and Five Dynasties and Ten Kingdoms need multi-state snapshots, not single-dynasty placeholders.
- The timeline mixes founding/fall event years with map years. A founding year often does not represent a complete geopolitical map.
- Source and license metadata exists, but the workflow does not yet force every shipped polygon through the same provenance and review steps.

The new strategy should make every map answer three questions:

- What historical claim is this polygon making?
- Which source or method supports it?
- How confident are we that it is accurate at the current zoom level?

## Product Definition

The atlas should not present every boundary as a modern hard border. Each polygon must be classified by what it represents.

### Boundary Meaning

Use one of these meanings for every geometry layer:

- `core_admin`: directly governed administrative territory.
- `military_control`: militarily held area with unstable civil administration.
- `frontier_command`: frontier commandery, protectorate, garrison zone, or comparable structure.
- `tributary_or_vassal`: subordinate polity or tributary zone.
- `claimed`: claimed but not reliably controlled territory.
- `influence`: sphere of influence, trade corridor, or cultural-political influence.
- `disputed`: contested territory with competing claims.
- `schematic`: editorial approximation used only when no better source is available.

For early Chinese dynasties and fragmentation periods, the default should be `core_admin` plus optional frontier and disputed layers. Do not collapse these into one opaque polygon unless the UI clearly labels it as schematic.

### Snapshot Meaning

A `displayYear` is a representative map state, not necessarily a complete annual truth. Use it only when the whole geopolitical scene can be shown coherently.

Examples:

- `229 CE` is a good Three Kingdoms snapshot because Wei, Shu, and Wu are all visible as the classic tripartite structure.
- `220 CE` is not a full Three Kingdoms snapshot because it primarily represents Wei after Han's end.
- `221 CE` is not a full Three Kingdoms snapshot because it primarily represents Shu's founding.
- `263 CE` is not a full Three Kingdoms snapshot because Shu has collapsed.

Founding and fall years should usually become events, not timeline map years, unless the map deliberately shows a transition state.

## Accuracy Tiers

Every geometry asset must declare one of these tiers.

### `source_exact`

Use when the geometry is directly derived from a scholarly GIS source or digitized historical map with documented processing.

Requirements:

- Source record with license or access notes.
- Processing script committed or documented.
- Original source granularity known.
- Geometry reviewed against at least one visual reference.

### `derived_scholarly`

Use when boundaries are reconstructed from academic sources, historical atlases, administrative units, or multiple references, but not directly exported from a canonical GIS layer.

Requirements:

- Source references for each major region.
- Method note explaining how the polygon was assembled.
- Known uncertainty zones listed in `disputeNotes`.

### `community_reference`

Use when geometry comes from a community project, game mod, public historical-map project, or non-academic open source repository.

Requirements:

- Repository and license recorded.
- It must be reviewed before being presented as anything stronger than medium confidence.
- UI notes should avoid calling it "precise" unless independently verified.

### `editorial_schematic`

Use when the team draws or approximates the shape manually.

Requirements:

- Label as schematic in data and UI.
- Do not mix with high-confidence layers without visual distinction.
- Treat as temporary unless the period intentionally uses schematic storytelling.

### `placeholder`

Use only to keep the product navigable while data is missing.

Requirements:

- Not shown as an authoritative boundary.
- Must have a replacement issue or TODO.
- Should be visually muted or hidden behind a "data unavailable" state.

## Source Strategy

No single data source will cover all regions and eras well. Use a source hierarchy.

### China Core

Priority sources:

- CHGIS for historical administrative geography, places, and long-period Chinese GIS foundations.
- Digitized scholarly historical atlases where licensing and usage allow.
- Public-domain or permissively licensed historical maps as visual references.
- Community GeoJSON only as secondary or temporary geometry.

China-specific work should favor administrative-unit reconstruction over empire-outline guessing. For split periods, build states from prefectures, commanderies, circuits, or known local units when possible.

### World Context

Priority sources:

- Open world historical GIS datasets for broad global context.
- Natural Earth only for basemaps and modern reference geometry, not historical claims.
- Region-specific scholarly datasets where available.

World context may stay at lower precision than China in early releases, but every asset still needs a tier and source.

### Gap Filling

When no adequate dataset exists:

- Create a `placeholder` or `editorial_schematic` asset.
- Document the missing source problem.
- Prefer a conservative blank state over a misleading precise-looking polygon.

## Split-Period Policy

Fragmentation periods require special rules because the map must show a scene, not just an entity.

### General Rules

- Use one timeline snapshot only when the main competing states can be displayed together.
- Avoid single-state snapshots unless the UI explicitly says "founding context" or "collapse context."
- Keep event years available in `events.json`, but do not force them into `timelineYears`.
- Prefer a multi-polity `mapScene` concept in future schema work.

### Three Kingdoms

Canonical map snapshot:

- `229 CE`: Cao Wei, Shu Han, and Eastern Wu all visible.

Event-only years:

- `220 CE`: Han end and Wei founding.
- `221 CE`: Shu founding.
- `263 CE`: Shu fall.
- `280 CE`: Jin unification, if added later as a transition or new dynasty snapshot.

Recommended reconstruction method:

- Use commandery-level or prefecture-level polygons where possible.
- Assign each unit to Wei, Shu, or Wu for the representative year.
- Dissolve assigned polygons per state.
- Preserve disputed or changing frontiers as separate `disputed` or `military_control` layers when the evidence is unclear.

### Sixteen Kingdoms and Northern/Southern Dynasties

Do not represent the whole period with only `jin_dynasty` and `northern_wei`.

Suggested snapshots:

- `317 CE`: Eastern Jin establishment and northern fragmentation context.
- `376 CE`: Former Qin near its peak before Fei River.
- `400 CE`: Eastern Jin, Northern Wei rise, and remaining northern/surrounding powers.
- `439 CE`: Northern Wei unification of northern China.
- `479 CE` or `500 CE`: Northern/Southern Dynasties mature split.

Each snapshot should show all major states present at that time or be labeled as partial.

### Five Dynasties and Ten Kingdoms

Do not use late Tang or Song as a precise substitute for the period.

Suggested snapshots:

- `907 CE`: Tang collapse and Later Liang start, with major regional regimes if data exists.
- `923 CE`: Later Tang and major Ten Kingdoms scene.
- `951 CE`: Later Zhou and southern kingdoms.
- `960 CE`: Song founding context.
- `979 CE`: Song consolidation after Northern Han.

Until real geometries are available, `907 CE` should be marked `placeholder` or hidden from default authoritative timeline mode.

## Proposed Data Model Additions

The existing `Territory`, `TerritorySnapshot`, and `GeometryAsset` model is a good base. Add stricter fields and prepare for scene-level rendering.

### Geometry Asset

Recommended additions to each geometry manifest record:

```json
{
  "id": "cao_wei_229_core_admin_v1",
  "assetPath": "assets/geojson/china/three_kingdoms/cao_wei_229_core_admin_v1.geojson",
  "geometryType": "Polygon",
  "regionScope": "china",
  "boundaryMeaning": "core_admin",
  "accuracyTier": "derived_scholarly",
  "sourceRefs": ["chgis", "historical_atlas_reference"],
  "methodRef": "methods/three_kingdoms_229_reconstruction.md",
  "projection": "EPSG:4326",
  "revision": "v1",
  "reviewStatus": "draft"
}
```

### Territory Snapshot

Recommended additions:

```json
{
  "id": "three_kingdoms_scene_229_cao_wei",
  "territoryId": "cao_wei",
  "displayYear": 229,
  "sceneId": "three_kingdoms_229",
  "geometryRefs": ["cao_wei_229_core_admin_v1", "cao_wei_229_disputed_v1"],
  "snapshotRole": "scene_member",
  "mapCompleteness": "complete_scene",
  "accuracy": {
    "level": "medium",
    "tier": "derived_scholarly",
    "note": "Reconstructed from commandery-level assignment for the representative 229 CE scene."
  }
}
```

### Map Scene

Add later as `map_scenes.json` when the UI needs stronger control over multi-state snapshots.

```json
{
  "id": "three_kingdoms_229",
  "displayYear": 229,
  "title": {
    "zh-Hans": "三国鼎立",
    "en": "Three Kingdoms"
  },
  "territorySnapshotIds": [
    "three_kingdoms_scene_229_cao_wei",
    "three_kingdoms_scene_229_shu_han",
    "three_kingdoms_scene_229_eastern_wu"
  ],
  "completeness": "complete_scene",
  "notes": "Represents the classic tripartite scene after Eastern Wu's formal founding."
}
```

For now, the project can keep using `displayYear` across snapshots. The scene model becomes necessary once we add split-period completeness rules and UI labels.

## Processing Pipeline

All new boundary data should move through this pipeline.

### 1. Intake

- Record candidate source, license, URL, and coverage.
- Download raw files into `data_references/` or an external documented location.
- Never edit raw source files in place.

### 2. Normalize

- Convert to GeoJSON.
- Reproject to EPSG:4326.
- Normalize fields and names.
- Store processed output under `assets/geojson/...`.

### 3. Reconstruct

For split periods:

- Assign base units to territories for the representative year.
- Dissolve units by territory.
- Keep contested units separate when needed.
- Produce separate layers for core, frontier, disputed, and influence zones.

### 4. Validate

Automated checks should verify:

- Every geometry file is `FeatureCollection`.
- Every referenced `assetPath` exists and is declared in `pubspec.yaml`.
- Every `geometryRef` exists in `geometry_manifest.json`.
- Every map year has all expected scene members.
- Polygon coordinates are valid longitude/latitude pairs.
- Area is not zero or wildly outside expected bounds.
- No high-confidence asset uses `editorial_internal_v1` only.

### 5. Review

Manual review should check:

- Period appropriateness.
- Missing peer states.
- Frontier and dispute notes.
- Whether UI labels overstate precision.

### 6. Publish

Only `approved` or explicitly labeled `draft` assets should ship in normal views. `placeholder` assets should be hidden or visually muted.

## File Organization

Recommended future layout:

```text
assets/
  geojson/
    china/
      qin_han/
      three_kingdoms/
      northern_southern_dynasties/
      five_dynasties_ten_kingdoms/
    world/
global/
  geometry_manifest.json
  territory_snapshots.json
  map_scenes.json
docs/
  data-model/
    historical-boundary-data-plan.md
  data-methods/
    three_kingdoms_229_reconstruction.md
    five_dynasties_source_gap.md
```

The current flat `assets/geojson/` layout can remain for compatibility, but new work should move toward period folders.

## MVP Reset Plan

### Phase 0: Freeze Current Accuracy Claims

- Mark existing hand-drawn and community polygons as `draft`, `community_reference`, or `editorial_schematic`.
- Remove misleading labels such as "high precision" unless the data has been reviewed.
- Keep the app usable, but make uncertainty explicit.

### Phase 1: Define Canonical Timeline Scenes

Replace event-driven map years with representative scenes:

- Qin/Han unification and transition scenes.
- `229 CE` Three Kingdoms scene.
- One or two Sixteen Kingdoms/Northern-Southern scenes.
- One Five Dynasties scene only if adequate geometry exists.
- Later unified dynasties from reviewed world or China-specific data.

### Phase 2: Rebuild Three Kingdoms Properly

- Choose one base administrative unit dataset.
- Build a 229 assignment table.
- Dissolve by Wei, Shu, and Wu.
- Add notes for disputed frontiers and fast-changing regions.
- Keep 220, 221, and 263 as events, not default map years.

### Phase 3: Add Validation Scripts

Create scripts for:

- Geometry manifest validation.
- Snapshot-to-geometry validation.
- GeoJSON schema validation.
- Timeline scene completeness validation.

These scripts should run before adding new maps.

### Phase 4: Rebuild Fragmentation Periods

Work period by period:

- Three Kingdoms.
- Sixteen Kingdoms / Northern and Southern Dynasties.
- Five Dynasties and Ten Kingdoms.
- Song-Liao-Xixia-Jin.

Do not mix partial and complete scenes without clear UI labeling.

## Decisions Needed

Before rebuilding data, decide:

- Should the product prioritize scholarly accuracy over visual completeness when data is missing?
- Should uncertain polygons be visible by default, or hidden behind an "experimental data" toggle?
- Are we willing to use non-commercial academic references only as visual validation, while storing our own derived geometry?
- Should `map_scenes.json` be added now, or should we first enforce scene completeness through `territory_snapshots.json` and `timelineYears`?

## Immediate Recommendations

- Keep only `229 CE` as the default Three Kingdoms map scene.
- Remove or demote any `220`, `221`, and `263` boundary snapshots from default timeline rendering unless shown as event context.
- Mark current Five Dynasties geometry as `placeholder`, not a real boundary.
- Add validation scripts before importing more GeoJSON.
- Start the real rebuild with Three Kingdoms 229 because it has clear product value and bounded scope.

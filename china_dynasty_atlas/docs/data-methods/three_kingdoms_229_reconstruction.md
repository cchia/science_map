# 三国 229 场景边界重建方法

本文档记录 `three_kingdoms_scene_229` 的边界数据方法。当前版本是 **v0 社区参考草案**，目标是先把产品场景、数据结构和校验流程跑通；它不是最终学术重建版。

## 场景定义

- 场景 ID：`three_kingdoms_scene_229`
- 代表年份：`229 CE`
- 场景标题：三国鼎立
- 场景性质：中国核心分裂场景完整，全球覆盖仍为 `global_partial`
- 场景成员：
  - `cao_wei_229`
  - `shu_han_229`
  - `eastern_wu_229`

选择 `229 CE` 的原因：

- 曹魏已经代汉建立。
- 蜀汉已经建立。
- 孙权在 229 年称帝，东吴国家建制完成。
- 魏、蜀、吴三方并立格局在产品叙事上最清楚。

不把 `220`、`221`、`263` 作为默认完整地图场景：

- `220` 主要是曹魏建国事件。
- `221` 主要是蜀汉建国事件。
- `263` 蜀汉已灭亡，不再是三国鼎立场景。

## 当前 v0 数据来源

当前 v0 使用社区项目 `eSerica-geojson-map` 的三国郡域 GeoJSON 作为底图参考，并按魏、蜀、吴归属进行合并。

当前几何资产：

| Territory | Geometry ID | Asset Path | Accuracy Tier |
|---|---|---|---|
| 曹魏 | `cao_wei_229_core_admin_v0` | `assets/geojson/unified/cao_wei_220.geojson` | `community_reference` |
| 蜀汉 | `shu_han_229_core_admin_v0` | `assets/geojson/unified/shu_han_221.geojson` | `community_reference` |
| 东吴 | `eastern_wu_229_core_admin_v0` | `assets/geojson/unified/eastern_wu_229.geojson` | `community_reference` |

注意：曹魏和蜀汉的文件名仍保留早期临时命名，但 manifest ID 已统一为 229 场景语义。后续重建时应把文件路径也迁移到 `assets/geojson/china/three_kingdoms/`。

## 当前 v0 处理方法

1. 读取社区项目中的三国郡域 polygons。
2. 根据手工归属清单把郡域分配给曹魏、蜀汉、东吴。
3. 使用 Turf.js 将同一政权下的 polygons dissolve 成 `MultiPolygon`。
4. 输出为项目可读取的 `FeatureCollection`。
5. 在 `geometry_manifest.json` 中标记：
   - `boundaryMeaning: core_admin`
   - `accuracyTier: community_reference`
   - `reviewStatus: draft`
   - `methodRef: docs/data-methods/three_kingdoms_229_reconstruction.md`

## 已知问题

当前版本不能作为精确历史边界：

- 社区项目本身并非学术 GIS 数据。
- 部分郡域边界参考游戏地图或兴趣绘制，不能直接视为真实行政边界。
- 229 年的局部边境并不稳定，尤其是汉中、江淮、荆州、交州与西南边缘。
- 目前没有单独拆分 `disputed`、`military_control`、`frontier_command` 图层。
- 当前 dissolve 后的 polygon 表达的是核心区草案，不表达军事实控强弱。

## 下一版目标

v1 应从“社区参考草案”升级为“可审查的派生学术重建”。

### 输入数据

优先寻找或建立：

- 229 年前后州郡 / 郡县级单位底图。
- 每个行政单位在 229 年的政权归属表。
- 对争议地区的独立标记。
- 参考来源清单，包括 CHGIS、历史地图集、论文或可信历史地理资料。

### 输出图层

每个政权至少输出：

- `*_229_core_admin_v1`
- `*_229_disputed_v1`（如适用）
- `*_229_military_control_v1`（如适用）
- `*_229_frontier_command_v1`（如适用）

### 审核要求

v1 必须满足：

- 每个行政单位有归属来源或注释。
- 每个 geometry 有 `methodRef`。
- 每个争议区写入 `disputeNotes`。
- `three_kingdoms_scene_229` 仍保持三方完整。
- 校验脚本 `scripts/validate_boundary_data.js` 通过。

## 建议的归属表格式

后续可新增：

`data_references/three_kingdoms/three_kingdoms_229_unit_assignments.csv`

建议字段：

```csv
unit_id,unit_name_zh,unit_name_en,assigned_territory,boundary_meaning,confidence,source_refs,notes
hanzhong,汉中,Hanzhong,shu_han,core_admin,medium,"source_a;source_b","229 年归属与军事态势需复核"
jiangxia,江夏,Jiangxia,eastern_wu,disputed,low,"source_a","江夏一带应拆分或标为争议"
```

## 发布状态

当前状态：

- 可用于产品结构验证。
- 可用于说明“三国鼎立”场景的 UI 和数据模型。
- 不应标记为 `source_exact` 或 `derived_scholarly`。
- 不应在文案中称为高精度历史边界。

下一步：

1. 建立 229 单位归属表。
2. 找到可合法使用的州郡级底图。
3. 生成 v1 core/disputed/frontier 图层。
4. 用新图层替换当前 v0 社区草案。

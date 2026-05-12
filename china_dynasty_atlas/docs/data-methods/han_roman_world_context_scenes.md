# 汉代同代世界场景数据说明

本文档记录 `-1`、`100`、`200` 年附近的汉、罗马、安息同代世界场景。当前目标是建立“同一年代显示多个世界强权”的产品结构，不是完成精确全球历史 GIS。

## 已建场景

| Scene ID | Display Year | Included Polities | Status |
|---|---:|---|---|
| `roman_empire_scene_-1` | -1 | 西汉、安息、罗马 | partial scene |
| `eastern_han_rome_parthia_scene_100` | 100 | 东汉、匈奴、贵霜、安息、罗马 | community-reference scene |
| `late_han_rome_parthia_scene_200` | 200 | 东汉晚期、贵霜、安息、罗马 | community-reference scene |

## 当前数据策略

已接入的世界同代场景遵循以下规则：

- 有可用 GeoJSON 的政权先显示。
- 年份不完全匹配的边界必须标记为 `placeholder` 或代理数据。
- 没有可靠边界的政权先记录为数据缺口，不绘制成精确边界。
- 场景的 `coverageLevel` 保持 `global_partial`，避免误解为完整世界地图。

## 已接入的 Cliopatria 参考边界

`100 CE` 和 `200 CE` 的罗马、安息、贵霜，以及 `100 CE` 匈奴，已从 Seshat Cliopatria 提取为项目内 GeoJSON。Cliopatria 采用 CC BY 4.0 许可，项目中以 `seshat_cliopatria` 作为来源记录。

| Snapshot ID | Geometry | Cliopatria Name | Covered Range |
|---|---|---|---|
| `roman_empire_100_context` | `roman_empire_100_cliopatria` | Roman Empire | 91-105 CE |
| `roman_empire_200_context` | `roman_empire_200_cliopatria` | Roman Empire | 197-206 CE |
| `parthia_100_context` | `parthia_100_cliopatria` | Parthian Empire | 51-113 CE |
| `parthia_200_context` | `parthia_200_cliopatria` | Parthian Empire | 197-206 CE |
| `kushan_empire_100_context` | `kushan_empire_100_cliopatria` | Kushan Empire | 91-116 CE |
| `kushan_empire_200_context` | `kushan_empire_200_cliopatria` | Kushan Empire | 184-214 CE |
| `xiongnu_100_context` | `xiongnu_100_cliopatria` | Xiongnu | 91-105 CE |

这些边界适合大洲级同屏展示，当前标记为 `community_reference`，不能声称为高精度学术复原。

## 当前代理边界

| Snapshot ID | Proxy Geometry | Reason |
|---|---|---|
| `western_han_-1_context` | `han_dynasty_unified_200bc` | 暂无公元前 1 年专用西汉边界 |
| `eastern_han_100_context` | `eastern_han_25_main_v5` | 暂无 100 CE 东汉专用边界 |
| `eastern_han_200_context` | `eastern_han_25_main_v5` | 暂无东汉末年实控范围边界 |

这些代理边界只能用于产品结构验证和同屏体验，不应在 UI 或文案中称为高精度历史边界。

## 资料缺口

优先补充以下政权和年份：

- 北匈奴 / 南匈奴：`100 CE` 已接入 Cliopatria 的 Xiongnu 参考层，但仍需要区分北匈奴、南匈奴、迁徙、附属、军事压力和直接控制。
- `200 CE` 匈奴：Cliopatria 有 `Huns` 记录，但不应直接等同于汉代匈奴，暂不接入。
- 罗马帝国：可进一步加入 `117 CE` 图拉真最大版图场景，用于解释罗马峰值，而不是只用 `100` / `200`。
- 东汉：`100 CE` 和 `184-220 CE`，后者应分离中央名义疆域与军阀实控范围。

## 后续重建要求

下一版应做到：

1. 每个同代强权有匹配年份或足够接近的来源边界。
2. 代理 snapshot 替换后，`reviewStatus` 从 `placeholder` 降为 `draft` 或升为 `approved`，取决于来源质量。
3. 贵霜和匈奴不应只作为文字说明，若加入地图必须有明确 `boundaryMeaning`：
   - `core_admin`
   - `military_control`
   - `frontier_command`
   - `influence`
   - `disputed`
4. 每个场景继续标注 `global_partial`，直到世界主要区域都有可解释边界。

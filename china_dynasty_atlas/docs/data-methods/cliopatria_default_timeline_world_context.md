# 默认时间轴世界同代政权参考层

本文档记录默认时间轴的 Cliopatria 批量世界政权参考层。当前策略是把 Cliopatria 作为默认时间轴的统一世界底座；项目内专题边界继续保留为后续审核、对照或精修数据，但不再进入默认场景。

## 数据来源

- Source ID: `seshat_cliopatria`
- Repository: `Seshat-Global-History-Databank/cliopatria`
- License: CC BY 4.0
- Data file: `cliopatria.geojson.zip`
- Projection: EPSG:4326

Cliopatria 提供的是世界历史政权的大洲级参考边界。它适合用于“同年代世界格局”展示，但不应直接声明为高精度、专题学术复原边界。

## 批量接入规则

对 `project_scope.json` 中每个 `timelineYears` 年份：

1. 查找 Cliopatria 中 `FromYear <= displayYear <= ToYear` 的 polity feature。
2. 排除名称以括号开头的重复/组合记录。
3. 排除 `Personal union`、`Allegiance` 等非直接政权边界记录。
4. 先接入面积不小于 `100,000 km²` 的世界尺度政权，避免默认地图被微型或城市级记录淹没。
5. 默认 scene 只保留 Cliopatria 来源快照；本项目自有或其他来源快照从 `territorySnapshotIds` 移除，但源数据不删除。
6. 默认 scene 过滤明显重复的整体/子层组合，例如马其顿帝国与继承者碎片、匈奴与南匈奴、英帝国与英属区域子层、西葡帝国与本土王国等；被过滤的快照仍保留在数据集中，后续可做“全部参考层”开关。
7. 中国主线默认地图也使用 Cliopatria geometry；`scripts/import_cliopatria_china_defaults.py` 会补入西汉、东汉、三国三方、隋、唐、清、中华民国等默认年份需要的中国主线边界。
8. 为缺失 territory 自动生成 `cliopatria_*` territory 记录。
9. 使用 `assets/global/cliopatria_name_translations.json` 为 Cliopatria 政权名补中文；词典未覆盖的名称暂时保留英文并等待审核。
10. 每个生成的 geometry 标记为：
   - `accuracyTier: community_reference`
   - `reviewStatus: draft`
   - `methodRef: docs/data-methods/cliopatria_default_timeline_world_context.md`

## 生成范围

本轮为所有默认时间轴年份生成或挂接世界参考政权：

| Year | Added Cliopatria Snapshots |
|---:|---:|
| -323 | 11 |
| -200 | 16 |
| -1 | 11 |
| 8 | 13 |
| 25 | 15 |
| 100 | 15 |
| 200 | 15 |
| 229 | 17 |
| 400 | 26 |
| 600 | 27 |
| 800 | 33 |
| 907 | 46 |
| 1000 | 50 |
| 1279 | 31 |
| 1530 | 53 |
| 1650 | 47 |
| 1920 | 54 |

默认场景当前挂接 `480` 个 Cliopatria 来源世界参考快照。

## 重要限制

这些图层解决的是“每个年代都有世界其他政权”这个产品问题，不代表已经完成所有历史边界研究。

限制包括：

- 面积小于 `100,000 km²` 的政权暂未批量进入默认场景。
- 前现代边界常包含影响范围、附属关系、松散联盟和军事压力，不应全部读作现代硬边界。
- 游牧联盟或边疆活动区（例如 100/200/229 CE 的鲜卑）可标记为 `influence`，允许与农耕帝国北缘重叠；渲染层会以更淡样式显示，避免误读为同级硬边界。
- 默认层会隐藏部分明显重复的整体/子层组合，但这不是几何拓扑去重；仍可能存在需要专题审核的历史重叠、附庸、殖民或争议边界。
- 25 CE 东汉场景使用 Cliopatria 最接近的 30-42 CE `Han Dynasty` 记录，因为上游没有覆盖 25 CE 的汉朝主边界。
- 1920 CE 中华民国场景使用 Cliopatria 最接近的 1915 CE `Republic of China` 记录，因为上游没有覆盖 1920 CE 的中华民国主边界；同场景隐藏 `Kuomintang` 子层以减少重复。
- 同一年多个来源可能对同一政权有不同空间解释，默认时间轴当前采用 Cliopatria 的单一版本。
- 中国主线政权、三国、宋辽西夏等项目内专题快照仍保留在数据集中，但默认 scene 不再引用它们。
- Cliopatria 的泛称 `Han Dynasty` 不直接映射为西汉或东汉；当前默认场景使用已存在的 Cliopatria 来源快照，避免同年同时显示西汉和东汉。
- Cliopatria 的 `Xin Dynasty` 若覆盖到 25 CE，不直接进入东汉重建场景；项目内新朝结束于 23 CE。
- `global_partial` 仍然保留，因为这不是完整、逐国、逐边界审核后的全球政治地图。

## 当前场景覆盖报告

| Year | Scene ID | Total Snapshots | Cliopatria World References |
|---:|---|---:|---:|
| -323 | `qin_unification_scene_-323` | 11 | 11 |
| -200 | `western_han_and_parthia_scene_-200` | 16 | 16 |
| -1 | `roman_empire_scene_-1` | 11 | 11 |
| 8 | `xin_transition_scene_8` | 13 | 13 |
| 25 | `eastern_han_restoration_scene_25` | 15 | 15 |
| 100 | `eastern_han_rome_parthia_scene_100` | 15 | 15 |
| 200 | `late_han_rome_parthia_scene_200` | 15 | 15 |
| 229 | `three_kingdoms_scene_229` | 17 | 17 |
| 400 | `eastern_jin_northern_wei_scene_400` | 26 | 26 |
| 600 | `sui_and_goguryeo_scene_600` | 27 | 27 |
| 800 | `tang_world_scene_800` | 33 | 33 |
| 907 | `five_dynasties_placeholder_scene_907` | 46 | 46 |
| 1000 | `song_liao_xixia_scene_1000` | 50 | 50 |
| 1279 | `mongol_yuan_scene_1279` | 31 | 31 |
| 1530 | `ming_scene_1530` | 53 | 53 |
| 1650 | `qing_and_early_modern_world_scene_1650` | 47 | 47 |
| 1920 | `republic_of_china_scene_1920` | 54 | 54 |

`scripts/validate_boundary_data.js` 会检查每个非 placeholder 的 `global_partial` 场景至少保留 5 个 Cliopatria 世界参考快照，并阻止非 Cliopatria snapshot 回到默认 scene。

## 后续升级

下一阶段应考虑：

1. 把 `100,000 km²` 阈值改为按时期/地区配置，而不是全局固定值。
2. 对关键年份生成更完整的 `Cliopatria coverage report`，列出被纳入和被过滤的政权。
3. 把 `core_admin`、`influence`、`tributary_or_vassal`、`disputed` 区分得更细。
4. 为用户提供“主要政权 / 全量参考层”开关，避免默认地图过密。
5. 对重点地区逐步用更可靠的专题数据替换 Cliopatria 参考边界。

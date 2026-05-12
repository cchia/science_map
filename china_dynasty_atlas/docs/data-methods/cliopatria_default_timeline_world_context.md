# 默认时间轴世界同代政权参考层

本文档记录默认时间轴的 Cliopatria 批量世界政权参考层。目标是让每一个默认年份都不再只是中国主线地图，而是至少显示同一年世界上其他主要政权的疆域。

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
5. 如果该年份的 scene 已经包含本项目自有快照，则不重复添加同一 territory。
6. 为缺失 territory 自动生成 `cliopatria_*` territory 记录。
7. 每个生成的 geometry 标记为：
   - `accuracyTier: community_reference`
   - `reviewStatus: draft`
   - `methodRef: docs/data-methods/cliopatria_default_timeline_world_context.md`

## 生成范围

本轮为所有默认时间轴年份生成或挂接世界参考政权：

| Year | Added Cliopatria Snapshots |
|---:|---:|
| -323 | 14 |
| -200 | 15 |
| -1 | 10 |
| 8 | 13 |
| 25 | 15 |
| 100 | 12 |
| 200 | 12 |
| 229 | 15 |
| 400 | 26 |
| 600 | 26 |
| 800 | 32 |
| 907 | 46 |
| 1000 | 50 |
| 1279 | 31 |
| 1530 | 55 |
| 1650 | 49 |
| 1920 | 58 |

合计生成或挂接 `479` 个世界参考快照。

## 重要限制

这些图层解决的是“每个年代都有世界其他政权”这个产品问题，不代表已经完成所有历史边界研究。

限制包括：

- 面积小于 `100,000 km²` 的政权暂未批量进入默认场景。
- 前现代边界常包含影响范围、附属关系、松散联盟和军事压力，不应全部读作现代硬边界。
- 同一年多个来源可能对同一政权有不同空间解释，当前采用 Cliopatria 的单一版本。
- 中国主线政权、三国、宋辽西夏等已有本项目快照时，仍优先使用项目内快照。
- `global_partial` 仍然保留，因为这不是完整、逐国、逐边界审核后的全球政治地图。

## 后续升级

下一阶段应考虑：

1. 把 `100,000 km²` 阈值改为按时期/地区配置，而不是全局固定值。
2. 对关键年份生成完整 `Cliopatria coverage report`，列出被纳入和被过滤的政权。
3. 把 `core_admin`、`influence`、`tributary_or_vassal`、`disputed` 区分得更细。
4. 为用户提供“主要政权 / 全量参考层”开关，避免默认地图过密。
5. 对重点地区逐步用更可靠的专题数据替换 Cliopatria 参考边界。

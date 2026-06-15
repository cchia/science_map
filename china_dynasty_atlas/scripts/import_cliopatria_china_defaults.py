#!/usr/bin/env python3
"""Import missing China-focused default snapshots from upstream Cliopatria.

This keeps default maps on Cliopatria geometry while restoring major China
polities that were skipped when older project-specific boundaries existed.
"""

from __future__ import annotations

import copy
import json
import re
import urllib.request
import zipfile
from io import BytesIO
from pathlib import Path
from typing import TypedDict


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CLIOPATRIA_ZIP_URL = (
    "https://github.com/Seshat-Global-History-Databank/cliopatria/raw/main/"
    "cliopatria.geojson.zip"
)


class Target(TypedDict, total=False):
    display_year: int
    source_year: int
    source_name: str
    territory_id: str
    label_zh: str
    label_en: str
    source_note_zh: str
    source_note_en: str


TARGETS: list[Target] = [
    {
        "display_year": -323,
        "source_year": -323,
        "source_name": "Warring States China",
        "territory_id": "cliopatria_warring_states_china",
        "label_zh": "战国时期中国",
        "label_en": "Warring States China",
    },
    {
        "display_year": -200,
        "source_year": -200,
        "source_name": "Han Dynasty",
        "territory_id": "western_han",
        "label_zh": "西汉",
        "label_en": "Western Han",
    },
    {
        "display_year": -1,
        "source_year": -1,
        "source_name": "Han Dynasty",
        "territory_id": "western_han",
        "label_zh": "西汉",
        "label_en": "Western Han",
    },
    {
        "display_year": 8,
        "source_year": 8,
        "source_name": "Xin Dynasty",
        "territory_id": "xin",
        "label_zh": "新朝",
        "label_en": "Xin Dynasty",
    },
    {
        "display_year": 25,
        "source_year": 30,
        "source_name": "Han Dynasty",
        "territory_id": "eastern_han",
        "label_zh": "东汉",
        "label_en": "Eastern Han",
        "source_note_zh": "Cliopatria 没有覆盖 25 CE 的汉朝主边界；此处采用最接近的 30-42 CE 记录作为东汉重建期参考。",
        "source_note_en": "Cliopatria has no main Han boundary for 25 CE; this uses the nearest 30-42 CE record as an Eastern Han restoration reference.",
    },
    {
        "display_year": 100,
        "source_year": 100,
        "source_name": "Han Dynasty",
        "territory_id": "eastern_han",
        "label_zh": "东汉",
        "label_en": "Eastern Han",
    },
    {
        "display_year": 200,
        "source_year": 200,
        "source_name": "Han Dynasty",
        "territory_id": "eastern_han",
        "label_zh": "东汉",
        "label_en": "Eastern Han",
    },
    {
        "display_year": 229,
        "source_year": 229,
        "source_name": "Cao Wei",
        "territory_id": "cao_wei",
        "label_zh": "曹魏",
        "label_en": "Cao Wei",
    },
    {
        "display_year": 229,
        "source_year": 229,
        "source_name": "Shu Han",
        "territory_id": "shu_han",
        "label_zh": "蜀汉",
        "label_en": "Shu Han",
    },
    {
        "display_year": 229,
        "source_year": 229,
        "source_name": "Eastern Wu",
        "territory_id": "eastern_wu",
        "label_zh": "东吴",
        "label_en": "Eastern Wu",
    },
    {
        "display_year": 400,
        "source_year": 400,
        "source_name": "Northern Wei",
        "territory_id": "northern_wei",
        "label_zh": "北魏",
        "label_en": "Northern Wei",
    },
    {
        "display_year": 600,
        "source_year": 600,
        "source_name": "Sui Dynasty",
        "territory_id": "sui_dynasty",
        "label_zh": "隋朝",
        "label_en": "Sui Dynasty",
    },
    {
        "display_year": 800,
        "source_year": 800,
        "source_name": "Tang Dynasty",
        "territory_id": "tang_dynasty",
        "label_zh": "唐朝",
        "label_en": "Tang Dynasty",
    },
    {
        "display_year": 1000,
        "source_year": 1000,
        "source_name": "Northern Song",
        "territory_id": "cliopatria_northern_song",
        "label_zh": "北宋",
        "label_en": "Northern Song",
    },
    {
        "display_year": 1000,
        "source_year": 1000,
        "source_name": "Liao Dynasty",
        "territory_id": "cliopatria_liao_dynasty",
        "label_zh": "辽朝",
        "label_en": "Liao Dynasty",
    },
    {
        "display_year": 1000,
        "source_year": 1000,
        "source_name": "Western Xia",
        "territory_id": "cliopatria_western_xia",
        "label_zh": "西夏",
        "label_en": "Western Xia",
    },
    {
        "display_year": 1279,
        "source_year": 1279,
        "source_name": "Mongol Empire",
        "territory_id": "mongol_empire",
        "label_zh": "蒙古帝国 / 元朝",
        "label_en": "Mongol Empire / Yuan Dynasty",
    },
    {
        "display_year": 1530,
        "source_year": 1530,
        "source_name": "Ming Dynasty",
        "territory_id": "ming_dynasty",
        "label_zh": "明朝",
        "label_en": "Ming Dynasty",
    },
    {
        "display_year": 1650,
        "source_year": 1650,
        "source_name": "Qing Dynasty",
        "territory_id": "qing_dynasty",
        "label_zh": "清朝",
        "label_en": "Qing Dynasty",
    },
    {
        "display_year": 1920,
        "source_year": 1915,
        "source_name": "Republic of China",
        "territory_id": "republic_of_china",
        "label_zh": "中华民国",
        "label_en": "Republic of China",
        "source_note_zh": "Cliopatria 没有覆盖 1920 CE 的中华民国主边界；此处采用最接近的 1915 CE 记录作为北洋政府时期名义疆域参考。",
        "source_note_en": "Cliopatria has no main Republic of China boundary for 1920 CE; this uses the nearest 1915 CE record as a nominal Beiyang-era reference.",
    },
]


def read_json(path: Path):
    return json.loads(path.read_text())


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return slug or "polity"


def year_suffix(year: int) -> str:
    return f"bce_{abs(year)}" if year < 0 else str(year)


def display_year_label(year: int) -> str:
    return f"公元前{abs(year)}年" if year < 0 else f"公元{year}年"


def load_upstream_features():
    with urllib.request.urlopen(CLIOPATRIA_ZIP_URL, timeout=60) as response:
        archive_bytes = response.read()
    with zipfile.ZipFile(BytesIO(archive_bytes)) as archive:
        with archive.open(archive.namelist()[0]) as source:
            return json.load(source)["features"]


def choose_feature(features, source_name: str, source_year: int):
    candidates = []
    accepted_names = {source_name, f"({source_name})"}
    for feature in features:
        properties = feature.get("properties", {})
        if properties.get("Name") not in accepted_names:
            continue
        from_year = properties.get("FromYear")
        to_year = properties.get("ToYear")
        if from_year <= source_year <= to_year:
            candidates.append(feature)
    if not candidates:
        raise RuntimeError(f"No Cliopatria feature for {source_name} at {source_year}")
    candidates.sort(
        key=lambda feature: 0
        if not feature["properties"]["Name"].startswith("(")
        else 1
    )
    return candidates[0]


def geometry_type(feature) -> str:
    return feature.get("geometry", {}).get("type", "MultiPolygon")


def main() -> None:
    manifest_path = PROJECT_ROOT / "assets/global/geometry_manifest.json"
    snapshots_path = PROJECT_ROOT / "assets/global/territory_snapshots.json"
    territories_path = PROJECT_ROOT / "assets/global/territories.json"
    geojson_dir = PROJECT_ROOT / "assets/geojson/runtime"
    manifest = read_json(manifest_path)
    snapshots = read_json(snapshots_path)
    territories = read_json(territories_path)
    manifest_by_id = {record["id"]: record for record in manifest}
    snapshots_by_id = {record["id"]: record for record in snapshots}
    territories_by_id = {record["id"]: record for record in territories}
    features = load_upstream_features()

    added_or_updated = 0
    for target in TARGETS:
        geometry_id = f"cliopatria_{slugify(target['source_name'])}_{year_suffix(target['display_year'])}"
        snapshot_id = f"{geometry_id}_context"
        asset_path = f"assets/geojson/runtime/{geometry_id}.geojson"
        output_path = PROJECT_ROOT / asset_path
        if (
            geometry_id in manifest_by_id
            and snapshot_id in snapshots_by_id
            and output_path.exists()
        ):
            continue

        feature = choose_feature(features, target["source_name"], target["source_year"])
        source_props = feature["properties"]
        source_from = source_props.get("FromYear")
        source_to = source_props.get("ToYear")

        output_feature = copy.deepcopy(feature)
        output_feature["properties"] = {
            **source_props,
            "displayYear": target["display_year"],
            "sourceYear": target["source_year"],
            "mappedTerritoryId": target["territory_id"],
        }
        write_json(
            output_path,
            {
                "type": "FeatureCollection",
                "features": [output_feature],
            },
        )

        if target["territory_id"] not in territories_by_id:
            territory_record = {
                "id": target["territory_id"],
                "territoryType": "polity",
                "parentCivilizationId": "chinese",
                "start": {
                    "year": source_from,
                    "datePrecision": "representative_year",
                },
                "end": {
                    "year": source_to,
                    "datePrecision": "representative_year",
                },
                "capitalPlaceIds": [],
                "names": {
                    "primaryName": target["source_name"],
                    "localizedNames": {
                        "zh-Hans": target["label_zh"],
                        "en": target["label_en"],
                    },
                    "aliases": [],
                },
                "summary": f"{target['label_zh']}是 Cliopatria 世界历史数据集中的中国主线参考政权。",
                "summaryEn": f"{target['label_en']} is a China-focused reference polity from Cliopatria.",
                "summaryLong": f"{target['label_zh']}用于默认时间轴的中国主线地图展示。其边界来自 Seshat Cliopatria，适合大洲级观察世界格局，但不应视为已经逐地审核的高精度历史边界。",
                "summaryLongEn": f"{target['label_en']} is used for China-focused coverage in the default timeline. Its boundary comes from Seshat Cliopatria and is suitable for continental-scale context, but should not be treated as a fully reviewed high-precision historical boundary.",
                "color": "#8A6F3D",
                "sourceRefs": ["seshat_cliopatria"],
            }
            territories.append(territory_record)
            territories_by_id[target["territory_id"]] = territory_record

        manifest_record = {
            "id": geometry_id,
            "assetPath": asset_path,
            "geometryType": geometry_type(feature),
            "regionScope": "world",
            "simplificationLevel": "cliopatria_world_context",
            "licenseSourceId": "seshat_cliopatria",
            "derivedFromSourceIds": ["seshat_cliopatria"],
            "projection": "EPSG:4326",
            "revision": "v1",
            "editorNotes": (
                f"{target['source_name']} extent from Seshat Cliopatria source "
                f"record {source_from}-{source_to}, mapped to {target['label_en']} "
                f"for default China coverage."
            ),
            "boundaryMeaning": "core_admin",
            "accuracyTier": "community_reference",
            "reviewStatus": "draft",
            "methodRef": "docs/data-methods/cliopatria_default_timeline_world_context.md",
        }
        if geometry_id in manifest_by_id:
            manifest_by_id[geometry_id].update(manifest_record)
        else:
            manifest.append(manifest_record)
            manifest_by_id[geometry_id] = manifest_record

        source_note_zh = target.get("source_note_zh", "")
        source_note_en = target.get("source_note_en", "")
        territory_note = (
            f"来源于 Seshat Cliopatria，原始年份范围为 {source_from}-{source_to}。"
            f"用于默认时间轴的中国主线 Cliopatria 覆盖。"
        )
        territory_note_en = (
            f"Sourced from Seshat Cliopatria, original year range {source_from}-{source_to}. "
            "Used for default timeline China coverage from Cliopatria."
        )
        if source_note_zh:
            territory_note = f"{territory_note}{source_note_zh}"
        if source_note_en:
            territory_note_en = f"{territory_note_en} {source_note_en}"
        snapshot_record = {
            "id": snapshot_id,
            "territoryId": target["territory_id"],
            "validFrom": {
                "year": target["display_year"],
                "datePrecision": "representative_year",
                "displayLabel": display_year_label(target["display_year"]),
            },
            "validTo": {
                "year": target["display_year"],
                "datePrecision": "representative_year",
                "displayLabel": display_year_label(target["display_year"]),
            },
            "displayYear": target["display_year"],
            "geometryRefs": [geometry_id],
            "controlZones": [],
            "mapFocus": {"lat": 35.3, "lng": 104, "zoom": 4.1},
            "headline": f"{target['label_zh']}是 {target['display_year']} 年默认世界场景中的 Cliopatria 中国主线边界。",
            "headlineEn": f"{target['label_en']} is the Cliopatria China-focused boundary in the default {target['display_year']} world scene.",
            "territoryNote": territory_note,
            "territoryNoteEn": territory_note_en,
            "boundaryHighlights": [
                "Cliopatria 中国主线参考边界",
                "用于默认世界场景，替代项目内旧手工/专题边界",
                "后续仍需专题历史 GIS 审核",
            ],
            "boundaryHighlightsEn": [
                "Cliopatria China-focused reference boundary",
                "Used in the default world scene instead of older project-specific/manual boundaries",
                "Still requires specialist historical GIS review",
            ],
            "accuracy": {
                "level": "medium",
                "tier": "community_reference",
                "note": "来源于 Seshat Cliopatria，适合作为同代世界参考层，不代表高精度中国历史边界。",
                "noteEn": "Sourced from Seshat Cliopatria as a same-era world reference layer; not a high-precision China historical boundary claim.",
            },
            "disputeNotes": [
                "中国前现代疆域存在核心行政区、边疆控制、附属关系和争议区差异，本层按 Cliopatria 原始边界显示。"
            ],
            "disputeNotesEn": [
                "Premodern Chinese territorial extent can differ across core administration, frontier control, dependencies, and disputed zones; this layer follows the original Cliopatria boundary."
            ],
            "sourceRefs": ["seshat_cliopatria"],
            "reviewStatus": "draft",
            "highlightedEventIds": [],
        }
        if snapshot_id in snapshots_by_id:
            snapshots_by_id[snapshot_id].update(snapshot_record)
        else:
            snapshots.append(snapshot_record)
            snapshots_by_id[snapshot_id] = snapshot_record
        added_or_updated += 1

    write_json(manifest_path, manifest)
    write_json(snapshots_path, snapshots)
    write_json(territories_path, territories)
    print(f"Imported or updated {added_or_updated} Cliopatria China default snapshots.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Import Cliopatria world-context snapshots for every configured timeline year.

The app timeline is intentionally curated, but each configured year should have
enough same-era world polygons to support map storytelling. This script imports
large Cliopatria polity features for any timeline year that is not already
covered by existing generated assets.
"""

from __future__ import annotations

import copy
import json
import re
import urllib.request
import zipfile
from io import BytesIO
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CLIOPATRIA_ZIP_URL = (
    "https://github.com/Seshat-Global-History-Databank/cliopatria/raw/main/"
    "cliopatria.geojson.zip"
)
MIN_AREA_KM2 = 100_000
EARLY_WORLD_CONTEXT_MIN_AREA_KM2 = 25_000
SIXTEEN_KINGDOMS_MIN_AREA_KM2 = 30_000
FIVE_DYNASTIES_MIN_AREA_KM2 = 20_000
MODERN_CHINA_MIN_AREA_KM2 = 50_000
FIVE_DYNASTIES_POLITIES = {
    "Former Jin",
    "Former Shu",
    "Later Liang Dynasty",
    "Later Tang",
    "Later Jin",
    "Later Han",
    "Later Zhou",
    "Northern Han",
    "Later Shu",
    "Southern Wu",
    "Southern Tang",
    "Wuyue",
    "Southern Han",
    "Southern Chu",
    "Jingnan",
    "Min",
    "Qi Kingdom",
    "Liao Dynasty",
    "Northern Song",
}
MODERN_CHINA_POLITIES = {
    "People's Republic of China",
    "Republic of China",
    "Communist Party of China",
    "Democratic People's Republic of Korea",
    "Republic of Korea",
    "Japan",
}
WARRING_STATES_MIN_AREA_KM2 = 3_000
WARRING_STATES_POLITIES = {
    "Qin",
    "Zhao",
    "Wei",
    "Han",
    "Yan",
    "Chu",
    "Qi",
    "Song",
    "Lu",
    "Zheng",
    "Wey",
    "Later Zhou",
    "Xu",
    "Yue",
}
SPRING_AUTUMN_MIN_AREA_KM2 = 2_500
SPRING_AUTUMN_POLITIES = {
    "Zhou Dynasty",
    "Qin",
    "Jin",
    "Qi",
    "Chu",
    "Wu",
    "Yue",
    "Yan",
    "Lu",
    "Song",
    "Zheng",
    "Wey",
    "Cai",
    "Chen",
    "Cao",
    "Teng",
    "Xu",
    "Zhu",
    "Later Zhou",
}
SIXTEEN_KINGDOMS_POLITIES = {
    "Cheng Han",
    "Former Zhao",
    "Later Zhao",
    "Former Liang",
    "Former Yan",
    "Former Qin",
    "Later Qin",
    "Later Yan",
    "Western Qin",
    "Later Liang",
    "Southern Liang",
    "Southern Yan",
    "Western Liang",
    "Northern Liang",
    "Northern Yan",
    "Xia",
}
EXCLUDED_NAME_PATTERNS = (
    "Allegiance of",
    "Alliance between",
    "Personal union",
    "Vassalage of",
)
PALETTE = (
    "#8A6F3D",
    "#5E7C99",
    "#9B5E5E",
    "#5E8A6F",
    "#7A5E99",
    "#997A5E",
    "#4F7F8F",
    "#8F6F4F",
    "#6F8F4F",
    "#704F8F",
)


def read_json(path: Path):
    return json.loads(path.read_text())


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_") or "polity"


def year_suffix(year: int) -> str:
    return f"bce_{abs(year)}" if year < 0 else str(year)


def format_year_zh(year: int) -> str:
    return f"公元前{abs(year)}年" if year < 0 else f"公元{year}年"


def format_year_en(year: int) -> str:
    return f"{abs(year)} BCE" if year < 0 else f"{year} CE"


def stable_color(seed: str) -> str:
    total = sum(ord(char) for char in seed)
    return PALETTE[total % len(PALETTE)]


def load_upstream_features():
    with urllib.request.urlopen(CLIOPATRIA_ZIP_URL, timeout=60) as response:
        archive_bytes = response.read()
    with zipfile.ZipFile(BytesIO(archive_bytes)) as archive:
        with archive.open(archive.namelist()[0]) as source:
            return json.load(source)["features"]


def is_direct_polity(properties: dict, year: int) -> bool:
    name = properties.get("Name", "")
    if not name or name.startswith("("):
        return False
    if any(pattern in name for pattern in EXCLUDED_NAME_PATTERNS):
        return False
    from_year = properties.get("FromYear")
    to_year = properties.get("ToYear")
    if not isinstance(from_year, int) or not isinstance(to_year, int):
        return False
    if not from_year <= year <= to_year:
        return False
    if name == "Xin Dynasty" and year > 23:
        return False
    if name == "Han Dynasty" and year > 220:
        return False
    area = properties.get("Area") or 0
    if -770 <= year <= -451 and name in SPRING_AUTUMN_POLITIES:
        return area >= SPRING_AUTUMN_MIN_AREA_KM2
    if -475 <= year <= -221 and name in WARRING_STATES_POLITIES:
        return area >= WARRING_STATES_MIN_AREA_KM2
    if 300 <= year <= 450 and name in SIXTEEN_KINGDOMS_POLITIES:
        return area >= SIXTEEN_KINGDOMS_MIN_AREA_KM2
    if 900 <= year <= 979 and name in FIVE_DYNASTIES_POLITIES:
        return area >= FIVE_DYNASTIES_MIN_AREA_KM2
    if year >= 1949 and name in MODERN_CHINA_POLITIES:
        return area >= MODERN_CHINA_MIN_AREA_KM2
    if year <= -700:
        return area >= EARLY_WORLD_CONTEXT_MIN_AREA_KM2
    return area >= MIN_AREA_KM2


def territory_id_for(name: str, year: int, territories_by_primary_name: dict) -> str:
    if name == "Western Jin" and year >= 317:
        return "cliopatria_eastern_jin"
    if name == "Han Dynasty":
        return "western_han" if year <= 5 else "eastern_han"
    if name == "Southern Song" and year < 1127:
        return "cliopatria_northern_song"
    if name == "Han" and year <= -221:
        return "cliopatria_han_state"
    if name == "Later Zhou":
        return "cliopatria_later_zhou_dynasty" if year >= 900 else "cliopatria_later_zhou"
    if name == "Qin Dynasty":
        return "qin"
    if name == "Xin Dynasty":
        return "xin"
    if name == "Northern Wei":
        return "northern_wei"
    if name in {"Sui Dynasty", "Tang Dynasty", "Ming Dynasty", "Qing Dynasty"}:
        return {
            "Sui Dynasty": "sui_dynasty",
            "Tang Dynasty": "tang_dynasty",
            "Ming Dynasty": "ming_dynasty",
            "Qing Dynasty": "qing_dynasty",
        }[name]
    if name == "Mongol Empire":
        return "mongol_empire"
    if name == "Republic of China":
        return "republic_of_china"
    return territories_by_primary_name.get(name, f"cliopatria_{slugify(name)}")


def boundary_meaning_for(name: str) -> str:
    if name in {"Xianbei", "Wusun", "Yuezhi"}:
        return "influence"
    return "core_admin"


def ensure_territory(
    territories: list,
    territories_by_id: dict,
    translations: dict,
    name: str,
    territory_id: str,
    from_year: int,
    to_year: int,
) -> None:
    if territory_id in territories_by_id:
        return
    label_zh = translations.get(name, f"{name}（待译）")
    record = {
        "id": territory_id,
        "territoryType": "polity",
        "parentCivilizationId": "world_context",
        "start": {"year": from_year, "datePrecision": "representative_year"},
        "end": {"year": to_year, "datePrecision": "representative_year"},
        "capitalPlaceIds": [],
        "names": {
            "primaryName": name,
            "localizedNames": {"zh-Hans": label_zh, "en": name},
            "aliases": [],
        },
        "summary": (
            f"{label_zh}是 Cliopatria 世界历史数据集中的参考政权，"
            f"时间范围约为{format_year_zh(from_year)}至{format_year_zh(to_year)}。"
        ),
        "summaryEn": (
            f"{name} is a reference polity from Cliopatria, covering "
            f"approximately {format_year_en(from_year)} to {format_year_en(to_year)}."
        ),
        "summaryLong": (
            f"{label_zh}用于默认时间轴的同代世界地图展示。其边界来自 "
            "Seshat Cliopatria，适合大洲级观察世界格局，但不应视为已经逐地审核的高精度历史边界。"
        ),
        "summaryLongEn": (
            f"{name} is used in the default timeline's same-era world map. Its boundary "
            "comes from Seshat Cliopatria and is suitable for continental-scale context, "
            "but should not be treated as a fully reviewed high-precision historical boundary."
        ),
        "color": stable_color(name),
        "sourceRefs": ["seshat_cliopatria"],
    }
    territories.append(record)
    territories_by_id[territory_id] = record


def ensure_scene(scenes: list, scenes_by_year: dict, year: int) -> None:
    if year in scenes_by_year:
        return
    suffix = year_suffix(year)
    scene = {
        "id": f"world_story_scene_{suffix}",
        "displayYear": year,
        "title": {
            "zh-Hans": f"{format_year_zh(year)}同代世界故事场景",
            "en": f"{format_year_en(year)} Same-Era World Story Scene",
        },
        "territorySnapshotIds": [],
        "completeness": "partial_scene",
        "sceneType": "world_context_scene",
        "notes": "由 Cliopatria 自动生成的细粒度时间轴同代世界参考场景。",
        "notesEn": "A finer-grained same-era world reference scene generated from Cliopatria.",
        "sceneScope": "world",
        "coverageLevel": "global_partial",
    }
    scenes.append(scene)
    scenes_by_year[year] = scene


def remove_generated_record(
    *,
    geometry_id: str,
    snapshot_id: str,
    manifest: list,
    snapshots: list,
    manifest_by_id: dict,
    snapshots_by_id: dict,
) -> None:
    if snapshot_id in snapshots_by_id:
        snapshots[:] = [snapshot for snapshot in snapshots if snapshot["id"] != snapshot_id]
        snapshots_by_id.pop(snapshot_id, None)
    if geometry_id in manifest_by_id:
        asset_path = manifest_by_id[geometry_id].get("assetPath")
        if asset_path:
            output_path = PROJECT_ROOT / asset_path
            if output_path.exists():
                output_path.unlink()
        manifest[:] = [record for record in manifest if record["id"] != geometry_id]
        manifest_by_id.pop(geometry_id, None)


def geometry_type(feature: dict) -> str:
    return feature.get("geometry", {}).get("type", "MultiPolygon")


def main() -> None:
    scope_path = PROJECT_ROOT / "assets/config/project_scope.json"
    manifest_path = PROJECT_ROOT / "assets/global/geometry_manifest.json"
    snapshots_path = PROJECT_ROOT / "assets/global/territory_snapshots.json"
    territories_path = PROJECT_ROOT / "assets/global/territories.json"
    scenes_path = PROJECT_ROOT / "assets/global/map_scenes.json"
    translations_path = PROJECT_ROOT / "assets/global/cliopatria_name_translations.json"
    geojson_dir = PROJECT_ROOT / "assets/geojson/world/cliopatria"

    scope = read_json(scope_path)
    manifest = read_json(manifest_path)
    snapshots = read_json(snapshots_path)
    territories = read_json(territories_path)
    scenes = read_json(scenes_path)
    translations = read_json(translations_path)

    manifest_by_id = {record["id"]: record for record in manifest}
    snapshots_by_id = {record["id"]: record for record in snapshots}
    territories_by_id = {record["id"]: record for record in territories}
    territories_by_primary_name = {
        record.get("names", {}).get("primaryName"): record["id"]
        for record in territories
        if record.get("names", {}).get("primaryName")
    }
    scenes_by_year = {scene["displayYear"]: scene for scene in scenes}
    features = load_upstream_features()

    for geometry_id, snapshot_id in (
        ("cliopatria_xin_dynasty_25", "cliopatria_xin_dynasty_25_context"),
        ("cliopatria_han_dynasty_229", "cliopatria_han_dynasty_229_context"),
    ):
        remove_generated_record(
            geometry_id=geometry_id,
            snapshot_id=snapshot_id,
            manifest=manifest,
            snapshots=snapshots,
            manifest_by_id=manifest_by_id,
            snapshots_by_id=snapshots_by_id,
        )

    for record in manifest:
        if record["id"].startswith("cliopatria_xianbei_"):
            record["boundaryMeaning"] = "influence"

    imported = 0
    created_scenes = 0
    for year in scope["timelineYears"]:
        if year not in scenes_by_year:
            ensure_scene(scenes, scenes_by_year, year)
            created_scenes += 1

        candidates = [
            feature
            for feature in features
            if is_direct_polity(feature.get("properties", {}), year)
        ]
        candidates.sort(
            key=lambda feature: (
                feature["properties"].get("Name", ""),
                -(feature["properties"].get("Area") or 0),
            )
        )
        seen_names = set()
        for feature in candidates:
            properties = feature["properties"]
            name = properties["Name"]
            if name in seen_names:
                continue
            seen_names.add(name)
            from_year = properties["FromYear"]
            to_year = properties["ToYear"]
            territory_id = territory_id_for(name, year, territories_by_primary_name)
            geometry_id = f"cliopatria_{slugify(name)}_{year_suffix(year)}"
            snapshot_id = f"{geometry_id}_context"
            asset_path = f"assets/geojson/world/cliopatria/{geometry_id}.geojson"
            output_path = PROJECT_ROOT / asset_path

            ensure_territory(
                territories,
                territories_by_id,
                translations,
                name,
                territory_id,
                from_year,
                to_year,
            )

            if geometry_id not in manifest_by_id or not output_path.exists():
                output_feature = copy.deepcopy(feature)
                output_feature["properties"] = {
                    **properties,
                    "displayYear": year,
                    "sourceYear": year,
                    "mappedTerritoryId": territory_id,
                }
                write_json(
                    output_path,
                    {"type": "FeatureCollection", "features": [output_feature]},
                )
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
                        f"Generated from Cliopatria feature '{name}' covering "
                        f"{from_year}-{to_year}; displayed at {year}."
                    ),
                    "boundaryMeaning": boundary_meaning_for(name),
                    "accuracyTier": "community_reference",
                    "reviewStatus": "draft",
                    "methodRef": "docs/data-methods/cliopatria_default_timeline_world_context.md",
                }
                if geometry_id in manifest_by_id:
                    manifest_by_id[geometry_id].update(manifest_record)
                else:
                    manifest.append(manifest_record)
                    manifest_by_id[geometry_id] = manifest_record

            if snapshot_id not in snapshots_by_id:
                snapshot_record = {
                    "id": snapshot_id,
                    "territoryId": territory_id,
                    "displayYear": year,
                    "validFrom": from_year,
                    "validTo": to_year,
                    "geometryRefs": [geometry_id],
                    "mapFocus": {"lat": 20, "lng": 20, "zoom": 2.2},
                    "headline": f"{translations.get(name, name)}（{format_year_zh(year)}）",
                    "headlineEn": f"{name} ({format_year_en(year)})",
                    "territoryNote": (
                        f"来源于 Seshat Cliopatria，原始年份范围为 {from_year}-{to_year}。"
                    ),
                    "territoryNoteEn": (
                        f"Generated from Seshat Cliopatria, original year range {from_year}-{to_year}."
                    ),
                    "boundaryHighlights": [
                        "大洲级世界历史参考边界，适合故事场景和同代格局展示。"
                    ],
                    "boundaryHighlightsEn": [
                        "Continental-scale world-history reference boundary for story scenes and same-era context."
                    ],
                    "accuracy": {
                        "level": "community_reference",
                        "note": "Cliopatria 参考边界，尚未逐地人工审核。",
                        "noteEn": "Cliopatria reference boundary; not manually reviewed place by place.",
                    },
                    "disputeNotes": [
                        "前现代边界可能混合核心控制、影响范围、附庸关系或争议区域。"
                    ],
                    "disputeNotesEn": [
                        "Premodern boundaries may mix core control, influence, vassalage, or disputed zones."
                    ],
                    "sourceRefs": ["seshat_cliopatria"],
                    "reviewStatus": "draft",
                    "highlightedEventIds": [],
                }
                snapshots.append(snapshot_record)
                snapshots_by_id[snapshot_id] = snapshot_record
                imported += 1

    write_json(manifest_path, manifest)
    write_json(snapshots_path, snapshots)
    write_json(territories_path, territories)
    write_json(scenes_path, scenes)
    print(
        f"Imported {imported} timeline Cliopatria snapshots and created {created_scenes} scenes."
    )


if __name__ == "__main__":
    main()

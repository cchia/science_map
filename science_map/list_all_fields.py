#!/usr/bin/env python3
"""
列出所有event JSON文件中出现过的field
"""

import json
from collections import defaultdict
from pathlib import Path

EVENTS_DIR = Path("assets/events")

all_fields_zh = set()
all_fields_en = set()
field_combinations = []

# 扫描所有event文件
for event_file in EVENTS_DIR.glob("*.json"):
    with open(event_file, "r", encoding="utf-8") as f:
        try:
            event_data = json.load(f)
            fields_zh = event_data.get("field", [])
            fields_en = event_data.get("field_en", [])

            if fields_zh:
                all_fields_zh.update(fields_zh)
            if fields_en:
                all_fields_en.update(fields_en)

            if fields_zh or fields_en:
                field_combinations.append(
                    {
                        "event": event_data.get("id", "unknown"),
                        "fields_zh": fields_zh,
                        "fields_en": fields_en,
                    }
                )
        except Exception as e:
            print(f"Error reading {event_file}: {e}")

print("=" * 60)
print("所有出现过的中文field:")
print("=" * 60)
for field in sorted(all_fields_zh):
    print(f"  - {field}")

print(f"\n总计: {len(all_fields_zh)} 个不同的中文field")

print("\n" + "=" * 60)
print("所有出现过的英文field:")
print("=" * 60)
for field in sorted(all_fields_en):
    print(f"  - {field}")

print(f"\n总计: {len(all_fields_en)} 个不同的英文field")

# 保存详细列表
with open("all_fields_list.json", "w", encoding="utf-8") as f:
    json.dump(
        {
            "fields_zh": sorted(list(all_fields_zh)),
            "fields_en": sorted(list(all_fields_en)),
            "field_combinations": field_combinations,
        },
        f,
        ensure_ascii=False,
        indent=2,
    )

print("\n详细列表已保存到 all_fields_list.json")

#!/usr/bin/env python3
"""
扫描所有event文件，找出influence_chain中引用的缺失event和people
"""

import json
import os
from pathlib import Path

# 路径
EVENTS_DIR = Path("assets/events")
PEOPLE_DIR = Path("assets/people")
EVENTS_INDEX = Path("assets/events_index.json")
PEOPLE_INDEX = Path("assets/people_index.json")

# 读取现有索引
with open(EVENTS_INDEX, "r", encoding="utf-8") as f:
    existing_events = set(json.load(f))

with open(PEOPLE_INDEX, "r", encoding="utf-8") as f:
    existing_people = set(json.load(f))

# 收集所有引用的event ID和person ID
referenced_events = set()
referenced_people = set()
all_person_ids = {}  # event_id -> person_id 映射

# 扫描所有event文件
for event_file in EVENTS_DIR.glob("*.json"):
    with open(event_file, "r", encoding="utf-8") as f:
        event_data = json.load(f)

    event_id = event_data.get("id")
    person_id = event_data.get("personId")

    if event_id:
        all_person_ids[event_id] = person_id
        if person_id:
            if isinstance(person_id, list):
                referenced_people.update(person_id)
            else:
                referenced_people.add(person_id)

    # 检查influence_chain
    influence_chain = event_data.get("influence_chain", {})

    # influenced_by
    for item in influence_chain.get("influenced_by", []):
        ref_id = item.get("id")
        if ref_id:
            referenced_events.add(ref_id)

    # influenced
    for item in influence_chain.get("influenced", []):
        ref_id = item.get("id")
        if ref_id:
            referenced_events.add(ref_id)

# 找出缺失的
missing_events = referenced_events - existing_events
missing_people = referenced_people - existing_people

# 为缺失的event找出对应的person_id
missing_people_from_events = set()
for event_id in missing_events:
    person_id_val = all_person_ids.get(event_id)
    if person_id_val:
        p_ids = person_id_val if isinstance(person_id_val, list) else [person_id_val]
        for p_id in p_ids:
            if p_id and p_id not in existing_people:
                missing_people_from_events.add(p_id)

# 合并缺失的people
all_missing_people = missing_people | missing_people_from_events

print("=" * 60)
print("缺失的 Event:")
print("=" * 60)
for event_id in sorted(missing_events):
    person_id = all_person_ids.get(event_id, "未知")
    print(f"  - {event_id} (person: {person_id})")

print(f"\n总计: {len(missing_events)} 个缺失的event")

print("\n" + "=" * 60)
print("缺失的 People:")
print("=" * 60)
for person_id in sorted(all_missing_people):
    print(f"  - {person_id}")

print(f"\n总计: {len(all_missing_people)} 个缺失的people")

# 保存到文件
with open("missing_events_people.json", "w", encoding="utf-8") as f:
    json.dump(
        {
            "missing_events": sorted(list(missing_events)),
            "missing_people": sorted(list(all_missing_people)),
            "event_person_map": {
                eid: all_person_ids.get(eid) for eid in missing_events
            },
        },
        f,
        ensure_ascii=False,
        indent=2,
    )

print("\n结果已保存到 missing_events_people.json")

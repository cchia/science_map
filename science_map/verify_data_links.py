#!/usr/bin/env python3
"""
验证科学地图项目中的数据链接完整性。

检查以下链接：
1. (Event -> Person): 确保 event.personId 在 people_index 中。
2. (Person -> Event): 确保 person.events 数组中的所有 ID 都在 events_index 中。
3. (Event -> Event): 确保 event.influence_chain 中的所有 ID 都在 events_index 中。
"""

import json
import sys
from pathlib import Path

# --- 配置 ---
EVENTS_INDEX_FILE = Path("assets/events_index.json")
PEOPLE_INDEX_FILE = Path("assets/people_index.json")
EVENTS_DIR = Path("assets/events")
PEOPLE_DIR = Path("assets/people")
# --- 结束配置 ---


def load_index(index_file: Path) -> set:
    """从索引文件加载所有有效的ID到
    一个 set 中，以便快速查找。"""
    if not index_file.exists():
        print(f"[FATAL] 索引文件未找到: {index_file}")
        sys.exit(1)

    with open(index_file, "r", encoding="utf-8") as f:
        try:
            return set(json.load(f))
        except json.JSONDecodeError as e:
            print(f"[FATAL] 索引文件 {index_file} JSON 格式错误: {e}")
            sys.exit(1)


def verify_event_links(
    event_id: str, valid_event_ids: set, valid_person_ids: set
) -> int:
    """检查单个事件文件的所有内部链接。"""
    errors = 0
    file_path = EVENTS_DIR / f"{event_id}.json"

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"  [ERROR] 事件索引中的 '{event_id}' 缺少对应的 JSON 文件: {file_path}")
        return 1  # 计为1个错误
    except json.JSONDecodeError as e:
        print(f"  [ERROR] 事件文件 {file_path} JSON 格式错误: {e}")
        return 1

    # 1. 检查 Event -> Person (personId)
    person_id = data.get("personId")
    if person_id and person_id not in valid_person_ids:
        print(f"  [ERROR] 事件 '{event_id}' 引用了不存在的人物 'personId': {person_id}")
        errors += 1

    # 2. 检查 Event -> Event (influence_chain)
    chain = data.get("influence_chain", {})
    if chain:  # 确保 chain 不是 None
        # 检查 'influenced_by'
        for item in chain.get("influenced_by", []):
            link_id = item.get("id")
            if link_id and link_id not in valid_event_ids:
                print(
                    f"  [ERROR] 事件 '{event_id}' (influenced_by) 引用了不存在的事件: {link_id}"
                )
                errors += 1

        # 检查 'influenced'
        for item in chain.get("influenced", []):
            link_id = item.get("id")
            if link_id and link_id not in valid_event_ids:
                print(
                    f"  [ERROR] 事件 '{event_id}' (influenced) 引用了不存在的事件: {link_id}"
                )
                errors += 1

    return errors


def verify_person_links(person_id: str, valid_event_ids: set) -> int:
    """检查单个人物文件的所有内部链接。"""
    errors = 0
    file_path = PEOPLE_DIR / f"{person_id}.json"

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"  [ERROR] 人物索引中的 '{person_id}' 缺少对应的 JSON 文件: {file_path}")
        return 1
    except json.JSONDecodeError as e:
        print(f"  [ERROR] 人物文件 {file_path} JSON 格式错误: {e}")
        return 1

    # 1. 检查 Person -> Event (events 数组)
    event_links = data.get("events", [])
    for event_id in event_links:
        if event_id not in valid_event_ids:
            print(f"  [ERROR] 人物 '{person_id}' 引用了不存在的事件: {event_id}")
            errors += 1

    return errors


def main():
    print("=" * 60)
    print("开始验证知识图谱链接...")
    print("=" * 60)

    total_errors = 0

    # 1. 加载所有有效的 ID
    print(f"[INFO] 正在从 {EVENTS_INDEX_FILE} 加载事件索引...")
    valid_event_ids = load_index(EVENTS_INDEX_FILE)
    print(f"[INFO] 找到 {len(valid_event_ids)} 个有效的事件 ID。")

    print(f"[INFO] 正在从 {PEOPLE_INDEX_FILE} 加载人物索引...")
    valid_person_ids = load_index(PEOPLE_INDEX_FILE)
    print(f"[INFO] 找到 {len(valid_person_ids)} 个有效的人物 ID。")

    # 2. 验证每个事件文件
    print("\n" + "-" * 20 + " 正在检查事件文件 " + "-" * 20)
    for event_id in valid_event_ids:
        total_errors += verify_event_links(event_id, valid_event_ids, valid_person_ids)

    # 3. 验证每个人物文件
    print("\n" + "-" * 20 + " 正在检查人物文件 " + "-" * 20)
    for person_id in valid_person_ids:
        total_errors += verify_person_links(person_id, valid_event_ids)

    # 4. 总结报告
    print("\n" + "=" * 60)
    if total_errors == 0:
        print("✅ 验证成功！所有链接均有效。")
    else:
        print(f"❌ 验证失败。共发现 {total_errors} 个断开的链接。")
        print("请修复上述 [ERROR] 消息。")
        sys.exit(1)  # 以错误码退出


if __name__ == "__main__":
    main()

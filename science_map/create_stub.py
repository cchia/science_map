#!/usr/bin/env python3
"""
自动创建在 influence_chain 中被引用但尚不存在的 "stub" 事件。

工作流程:
1. 读取 events_index.json 获取所有“已知”事件。
2. 遍历所有已知的 event json 文件，收集 influence_chain 中的所有 ID。
3. 将“被引用的ID”与“已知的ID”进行比较，找出“缺失的ID”。
4. 为所有“缺失的ID”自动创建最小化的 stub json 文件。
5. 将这些新的 stub ID 添加回 events_index.json。
"""

import json
import sys
from pathlib import Path

# --- 配置 ---
EVENTS_INDEX_FILE = Path("assets/events_index.json")
EVENTS_DIR = Path("assets/events")
PEOPLE_INDEX_FILE = Path("assets/people_index.json")
PEOPLE_DIR = Path("assets/people")
# --- 结束配置 ---


def load_index(index_file: Path) -> set:
    """从索引文件加载所有有效的ID。"""
    if not index_file.exists():
        print(f"[FATAL] 索引文件未找到: {index_file}")
        sys.exit(1)

    with open(index_file, "r", encoding="utf-8") as f:
        try:
            return set(json.load(f))
        except json.JSONDecodeError as e:
            print(f"[FATAL] 索引文件 {index_file} JSON 格式错误: {e}")
            sys.exit(1)


def find_all_referenced_ids(existing_ids: set) -> set:
    """遍历所有事件和人物，收集所有被引用的事件 ID。"""
    import re

    all_referenced_ids = set()

    print(f"[INFO] 正在扫描 {len(existing_ids)} 个现有事件的链接...")

    # 1. 检查事件文件中的引用
    for event_id in existing_ids:
        file_path = EVENTS_DIR / f"{event_id}.json"

        if not file_path.exists():
            # verify_data_links.py 已经报告过这个错误，这里跳过
            continue

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            print(f"  (Warning: 无法读取 {file_path}, 跳过)")
            continue

        # 1.1 检查 Event -> Event (influence_chain)
        chain = data.get("influence_chain", {})
        if chain:  # 确保 chain 不是 None
            for item in chain.get("influenced_by", []):
                link_id = item.get("id")
                if link_id:
                    all_referenced_ids.add(link_id)

            for item in chain.get("influenced", []):
                link_id = item.get("id")
                if link_id:
                    all_referenced_ids.add(link_id)

        # 1.2 检查文本字段中的反引号引用 (如 `event_id`)
        text_fields = [
            "summary",
            "story",
            "simple_explanation",
            "impact",
            "applications",
            "fun_facts",
            "quiz",
        ]
        for field_name in text_fields:
            field_data = data.get(field_name)
            if field_data is None:
                continue

            # 处理字典类型的字段（如 summary, story, impact）
            if isinstance(field_data, dict):
                for key in [
                    "text",
                    "text_en",
                    "description",
                    "description_en",
                    "question",
                    "question_en",
                    "explanation",
                    "explanation_en",
                ]:
                    text = field_data.get(key, "")
                    if text and isinstance(text, str):
                        # 查找反引号中的ID (格式: `event_id`)
                        matches = re.findall(r"`([a-z_]+_[0-9BC]+)`", text)
                        all_referenced_ids.update(matches)

            # 处理列表类型的字段（如 applications, fun_facts）
            elif isinstance(field_data, list):
                for item in field_data:
                    if isinstance(item, dict):
                        for key in [
                            "text",
                            "text_en",
                            "title",
                            "title_en",
                            "description",
                            "description_en",
                        ]:
                            text = item.get(key, "")
                            if text and isinstance(text, str):
                                matches = re.findall(r"`([a-z_]+_[0-9BC]+)`", text)
                                all_referenced_ids.update(matches)

            # 处理字符串类型的字段
            elif isinstance(field_data, str):
                matches = re.findall(r"`([a-z_]+_[0-9BC]+)`", field_data)
                all_referenced_ids.update(matches)

    # 2. 检查人物文件中的 events 字段
    if PEOPLE_INDEX_FILE.exists() and PEOPLE_DIR.exists():
        try:
            with open(PEOPLE_INDEX_FILE, "r", encoding="utf-8") as f:
                person_ids = json.load(f)

            print(f"[INFO] 正在扫描 {len(person_ids)} 个人物文件的事件引用...")

            for person_id in person_ids:
                person_file = PEOPLE_DIR / f"{person_id}.json"
                if not person_file.exists():
                    continue

                try:
                    with open(person_file, "r", encoding="utf-8") as f:
                        person_data = json.load(f)

                    # 检查 events 字段
                    events = person_data.get("events", [])
                    if isinstance(events, list):
                        for event_id in events:
                            if event_id and isinstance(event_id, str):
                                all_referenced_ids.add(event_id)
                except Exception:
                    print(f"  (Warning: 无法读取 {person_file}, 跳过)")
                    continue
        except Exception as e:
            print(f"  (Warning: 无法读取人物索引或文件: {e})")

    return all_referenced_ids


def create_stub_file(event_id: str):
    """为给定的 event_id 创建一个最小化的 stub json 文件。"""
    file_path = EVENTS_DIR / f"{event_id}.json"
    if file_path.exists():
        return  # 安全起见，如果文件已存在则不操作

    print(f"  -> 正在创建存根: {event_id}")

    # 尝试从ID猜测年份
    year = 0
    try:
        year_str = event_id.split("_")[-1]
        if year_str.startswith("BC"):
            year = -int(year_str[2:])
        else:
            year = int(year_str.split("AD")[-1])  # 处理 'AD1830'
    except (ValueError, IndexError):
        print(f"    (警告: 无法从ID解析年份: {event_id})")

    # 尝试从ID猜测标题
    title_parts = event_id.split("_")
    # 移除年份部分
    if str(abs(year)) in title_parts[-1]:
        title_parts = title_parts[:-1]

    title = " ".join([part.capitalize() for part in title_parts])
    if not title:
        title = event_id.replace("_", " ").capitalize()

    stub_data = {
        "id": event_id,
        "title": title,
        "title_en": title,
        "year": year,
        "is_stub": True,
    }

    try:
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(stub_data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"  [ERROR] 写入 {file_path} 失败: {e}")


def main():
    print("=" * 60)
    print("开始自动创建缺失的“存根”(Stub)事件...")
    print("=" * 60)

    # 1. 加载所有有效的 ID
    existing_ids = load_index(EVENTS_INDEX_FILE)

    # 2. 查找所有被引用的 ID
    all_referenced = find_all_referenced_ids(existing_ids)

    # 3. 找出差异
    missing_ids = all_referenced - existing_ids

    if not missing_ids:
        print("✅ 恭喜！没有发现缺失的“存根”事件。")
        print("您的 `verify_data_links.py` 脚本现在应该可以通过了！")
        return

    print(f"[INFO] 发现 {len(missing_ids)} 个缺失的“存根”事件。")
    print("-" * 60)

    # 4. 为所有“缺失的ID”创建文件
    for event_id in missing_ids:
        create_stub_file(event_id)

    print("-" * 60)
    print("[INFO] 存根文件创建完毕。")

    # 5. 更新 events_index.json
    print(f"[INFO] 正在更新 {EVENTS_INDEX_FILE}...")
    new_index_list = sorted(list(existing_ids | missing_ids))

    try:
        with open(EVENTS_INDEX_FILE, "w", encoding="utf-8") as f:
            json.dump(new_index_list, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"  [ERROR] 写入 {EVENTS_INDEX_FILE} 失败: {e}")

    print("\n" + "=" * 60)
    print("✅ 自动存根(Stub)创建完成！")
    print(f"总事件数从 {len(existing_ids)} 增加到 {len(new_index_list)}。")
    print("请再次运行 'verify_data_links.py' 来确认所有链接均已修复。")
    print("=" * 60)


if __name__ == "__main__":
    main()

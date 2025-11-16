#!/usr/bin/env python3
"""
将所有event的field标准化为11个标准领域
"""

import json
from pathlib import Path

EVENTS_DIR = Path("assets/events")

# 标准field映射
FIELD_MAPPING_ZH = {
    # 物理学相关
    "物理学": "物理学",
    "物理": "物理学",
    "力学": "物理学",
    "热力学": "物理学",
    "光学": "物理学",
    "量子力学": "物理学",
    "统计力学": "物理学",
    "流体静力学": "物理学",
    "静力学": "物理学",
    "运动学": "物理学",
    "材料力学": "物理学",
    "气体动力学": "物理学",
    "液压学": "物理学",
    "引力": "物理学",
    "时空": "物理学",
    "气象学": "物理学",
    "Pneumatics": "物理学",
    # 数学相关
    "数学": "数学",
    "几何学": "数学",
    "三角学": "数学",
    "微积分": "数学",
    "微积分 (雏形)": "数学",
    "概率论": "数学",
    "组合数学": "数学",
    "逻辑": "数学",
    "逻辑学": "数学",
    # 哲学相关
    "哲学": "哲学",
    "自然哲学": "哲学",
    "形而上学": "哲学",
    "认识论": "哲学",
    "本体论": "哲学",
    "伦理学": "哲学",
    "宗教": "哲学",
    "神秘主义": "哲学",
    # 天文学相关
    "天文学": "天文学",
    "宇宙学": "天文学",
    "观测": "天文学",
    # 化学相关
    "化学": "化学",
    # 生物学相关
    "生物学": "生物学",
    # 工程学相关
    "工程学": "工程学",
    "发明": "工程学",
    "工业革命": "工程学",
    "材料科学": "工程学",
    "仪器制造": "工程学",
    "科学插画": "工程学",
    # 地理学相关
    "地理学": "地理学",
    # 医学相关
    "医学": "医学",
    # 计算机相关
    "计算机": "计算机",
    "计算机科学": "计算机",
    # 其他 -> 综合
    "科学方法": "综合",
    "音乐": "综合",
}

FIELD_MAPPING_EN = {
    # Physics related
    "Physics": "Physics",
    "Mechanics": "Physics",
    "Thermodynamics": "Physics",
    "Optics": "Physics",
    "Quantum Mechanics": "Physics",
    "Statistical Mechanics": "Physics",
    "Hydrostatics": "Physics",
    "Statics": "Physics",
    "Kinematics": "Physics",
    "Mechanics of Materials": "Physics",
    "Pneumatics": "Physics",
    "Hydraulics": "Physics",
    "Gravitation": "Physics",
    "Spacetime": "Physics",
    "Meteorology": "Physics",
    # Mathematics related
    "Mathematics": "Mathematics",
    "Geometry": "Mathematics",
    "Trigonometry": "Mathematics",
    "Calculus": "Mathematics",
    "Calculus (Proto)": "Mathematics",
    "Probability Theory": "Mathematics",
    "Combinatorics": "Mathematics",
    "Logic": "Mathematics",
    # Philosophy related
    "Philosophy": "Philosophy",
    "Natural Philosophy": "Philosophy",
    "Metaphysics": "Philosophy",
    "Epistemology": "Philosophy",
    "Ontology": "Philosophy",
    "Ethics": "Philosophy",
    "Religion": "Philosophy",
    "Mysticism": "Philosophy",
    # Astronomy related
    "Astronomy": "Astronomy",
    "Cosmology": "Astronomy",
    "Observation": "Astronomy",
    # Chemistry related
    "Chemistry": "Chemistry",
    # Biology related
    "Biology": "Biology",
    # Engineering related
    "Engineering": "Engineering",
    "Invention": "Engineering",
    "Industrial Revolution": "Engineering",
    "Materials Science": "Engineering",
    "Instrumentation": "Engineering",
    "Scientific Illustration": "Engineering",
    # Geography related
    "Geography": "Geography",
    # Medicine related
    "Medicine": "Medicine",
    # Computer Science related
    "Computer Science": "Computer Science",
    # Others -> Comprehensive
    "Scientific Method": "Comprehensive",
    "Music": "Comprehensive",
}

# 标准field列表
STANDARD_FIELDS_ZH = [
    "物理学",
    "数学",
    "哲学",
    "天文学",
    "化学",
    "生物学",
    "工程学",
    "地理学",
    "医学",
    "计算机",
    "综合",
]

STANDARD_FIELDS_EN = [
    "Physics",
    "Mathematics",
    "Philosophy",
    "Astronomy",
    "Chemistry",
    "Biology",
    "Engineering",
    "Geography",
    "Medicine",
    "Computer Science",
    "Comprehensive",
]


def map_fields(fields, mapping):
    """将field列表映射到标准field"""
    mapped = set()
    for field in fields:
        mapped_field = mapping.get(
            field,
            "综合"
            if isinstance(field, str) and any(c in field for c in "中文")
            else "Comprehensive",
        )
        if mapped_field not in ["综合", "Comprehensive"] or len(mapped) == 0:
            mapped.add(mapped_field)
    # 如果没有映射到任何field，使用"综合"
    if not mapped:
        mapped.add(
            "综合"
            if isinstance(fields[0], str) and any(ord(c) > 127 for c in fields[0])
            else "Comprehensive"
        )
    return sorted(list(mapped))


def standardize_event_fields(event_file):
    """标准化单个event文件的field"""
    with open(event_file, "r", encoding="utf-8") as f:
        event_data = json.load(f)

    original_fields_zh = event_data.get("field", [])
    original_fields_en = event_data.get("field_en", [])

    # 映射field
    new_fields_zh = map_fields(original_fields_zh, FIELD_MAPPING_ZH)
    new_fields_en = map_fields(original_fields_en, FIELD_MAPPING_EN)

    # 更新event数据
    event_data["field"] = new_fields_zh
    event_data["field_en"] = new_fields_en

    # 保存
    with open(event_file, "w", encoding="utf-8") as f:
        json.dump(event_data, f, ensure_ascii=False, indent=4)

    return {
        "event": event_data.get("id"),
        "original_zh": original_fields_zh,
        "new_zh": new_fields_zh,
        "original_en": original_fields_en,
        "new_en": new_fields_en,
    }


# 处理所有event文件
changes = []
for event_file in sorted(EVENTS_DIR.glob("*.json")):
    try:
        change = standardize_event_fields(event_file)
        changes.append(change)
        print(f"✅ {change['event']}: {change['original_zh']} -> {change['new_zh']}")
    except Exception as e:
        print(f"❌ Error processing {event_file}: {e}")

# 保存变更记录
with open("field_standardization_log.json", "w", encoding="utf-8") as f:
    json.dump(changes, f, ensure_ascii=False, indent=2)

print(f"\n✅ 完成！共处理 {len(changes)} 个事件")
print("变更记录已保存到 field_standardization_log.json")

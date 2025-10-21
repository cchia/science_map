#!/usr/bin/env python3
import json
import re

# 读取文件
with open("assets/events/euclid_elements.json", "r", encoding="utf-8") as f:
    content = f.read()

print("原始文件已读取")


# 只在JSON字符串值内部替换中文引号
# 使用正则表达式匹配 "key": "value" 格式，只替换value内的中文引号
def replace_chinese_quotes_in_values(match):
    prefix = match.group(1)  # "key":  部分
    value = match.group(2)  # value 部分
    suffix = match.group(3)  # 结尾的 " 部分

    # 在value内部替换中文引号为转义的英文引号
    value = value.replace('"', '\\"').replace('"', '\\"')

    return prefix + value + suffix


# 匹配 JSON 字符串值的模式: "key": "value"
# 处理多行字符串值
pattern = r'("(?:[^"\\]|\\.)*":\s*")([^"]*(?:\\"[^"]*)*)"'

# 由于JSON可能很复杂，我们采用更简单的方法：
# 先解析JSON，然后递归处理所有字符串值


def fix_chinese_quotes(obj):
    """递归修复对象中的中文引号"""
    if isinstance(obj, dict):
        return {k: fix_chinese_quotes(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [fix_chinese_quotes(item) for item in obj]
    elif isinstance(obj, str):
        # 只替换字符串中的中文引号
        return obj.replace('"', '"').replace('"', '"')
    else:
        return obj


try:
    # 解析JSON
    data = json.loads(content)
    print("JSON解析成功")

    # 修复中文引号
    fixed_data = fix_chinese_quotes(data)
    print("已修复所有中文引号")

    # 写回文件，保持格式
    with open("assets/events/euclid_elements.json", "w", encoding="utf-8") as f:
        json.dump(fixed_data, f, ensure_ascii=False, indent=4)

    print("✅ 文件已保存")

    # 验证
    with open("assets/events/euclid_elements.json", "r", encoding="utf-8") as f:
        json.load(f)
    print("✅ JSON格式验证成功")

except json.JSONDecodeError as e:
    print(f"❌ JSON解析失败: {e}")
    print(f"   位置: 第 {e.lineno} 行, 第 {e.colno} 列")
    print("\n由于JSON格式错误，无法使用JSON解析方法")
    print("尝试使用正则表达式方法...")

    # 备用方法：直接在文本中替换
    # 但这样可能会影响JSON结构，所以要小心
    # 我们需要确保只替换在引号内的中文引号

#!/usr/bin/env python3
import json
import re

# 读取文件
with open("assets/events/euclid_elements.json", "r", encoding="utf-8") as f:
    content = f.read()

# 只替换中文引号，保留英文引号
content = content.replace('"', '"').replace('"', '"')

# 写回文件
with open("assets/events/euclid_elements.json", "w", encoding="utf-8") as f:
    f.write(content)

print("已修复中文引号")

# 验证 JSON 格式
try:
    with open("assets/events/euclid_elements.json", "r", encoding="utf-8") as f:
        json.load(f)
    print("JSON 格式验证成功")
except json.JSONDecodeError as e:
    print(f"JSON 格式错误: {e}")

#!/usr/bin/env python3
import json

# 读取文件
with open("assets/events/euclid_elements.json", "r", encoding="utf-8") as f:
    content = f.read()

# 统计中文引号
before_count = content.count('"') + content.count('"')
print(f"修复前中文引号数量: {before_count}")

# 替换所有中文引号为转义的英文引号
content = content.replace('"', '\\"').replace('"', '\\"')

# 统计修复后
after_count = content.count('"') + content.count('"')
print(f"修复后中文引号数量: {after_count}")

# 写回文件
with open("assets/events/euclid_elements.json", "w", encoding="utf-8") as f:
    f.write(content)

print(f"已替换 {before_count} 个中文引号")

# 验证 JSON 格式
try:
    with open("assets/events/euclid_elements.json", "r", encoding="utf-8") as f:
        json.load(f)
    print("✅ JSON 格式验证成功")
except json.JSONDecodeError as e:
    print(f"❌ JSON 格式错误: {e}")
    print(f"   位置: 第 {e.lineno} 行, 第 {e.colno} 列")

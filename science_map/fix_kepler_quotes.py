#!/usr/bin/env python3
# -*- coding: utf-8 -*-


def fix_quotes_in_file(file_path):
    """替换文件中的中文引号为英文引号"""

    # 读取文件
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 统计替换前的中文引号数量
    chinese_quotes_before = content.count('"') + content.count('"')
    print(f"替换前中文引号数量: {chinese_quotes_before}")

    # 替换中文引号为英文引号
    content = content.replace('"', '\\"')
    content = content.replace('"', '\\"')

    # 统计替换后的中文引号数量
    chinese_quotes_after = content.count('"') + content.count('"')
    print(f"替换后中文引号数量: {chinese_quotes_after}")

    # 写回文件
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"✅ 已成功替换 {file_path} 中的中文引号")
    print(f"   共替换: {chinese_quotes_before - chinese_quotes_after} 个引号")


if __name__ == "__main__":
    fix_quotes_in_file("assets/events/kepler_laws.json")

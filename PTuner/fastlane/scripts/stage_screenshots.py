#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把设计导出的截图目录整理成 Fastlane deliver 需要的目录布局。

Fastlane deliver 通过图片分辨率推断 screenshotDisplayType，因此本脚本只负责
目录与文件名，不关心设备类型本身的正确性（分辨率不对时 deliver 会报错）。

输入目录约定（源目录下按平台/设备分子目录，目录名带语言后缀）：

    <source>/ios/iphone-6.5-<lang>/*.jpg
    <source>/ios/iphone-灵动岛必填-<lang>/*.jpg
    <source>/ios/ipad-13横屏-<lang>/*.jpg
    <source>/<macos-subdir>/macos-<lang>/*.jpg
        --macos-subdir 默认 MacOS，可改 custom 等。

输出布局：

    <dest>/screenshots/<locale>/<i>_APP_IPHONE_65_<i>.jpg
    <dest>/screenshots/<locale>/<i>_APP_IPHONE_6_3_<i>.jpg
    <dest>/screenshots/<locale>/<i>_APP_IPAD_PRO_3GEN_129_<i>.jpg
    <dest>/screenshots_macos/<locale>/<i>_APP_DESKTOP_<i>.jpg

文件名前缀决定 App Store Connect 上的排序（deliver 最后按文件名的自然序重排）。

用法：
    python3 stage_screenshots.py --source ~/Downloads/ptuner-Screenshots
    python3 stage_screenshots.py --source ... --dest .. --dry-run
    # 跳过 iphone-6.5，且 macOS 子目录叫 custom：
    python3 stage_screenshots.py --source ... \
        --exclude-prefixes iphone-6.5- --macos-subdir custom
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

# 源目录语言后缀 -> App Store Connect locale
# 同时收录简体与繁体写法，设计导出目录的命名不统一时都能识别。
LANGUAGE_LOCALES = {
    "英语": "en-US",
    "英文": "en-US",
    "简体中文": "zh-Hans",
    "繁体中文": "zh-Hant",
    "繁體中文": "zh-Hant",
    "日语": "ja",
    "日文": "ja",
    "韩语": "ko",
    "韩文": "ko",
    "德语": "de-DE",
    "德文": "de-DE",
    "法语": "fr-FR",
    "法文": "fr-FR",
    "西班牙": "es-ES",
    "西班牙语": "es-ES",
    "意大利语": "it",
    "意大利文": "it",
}

# (平台子目录, 设备目录前缀, 输出根目录, screenshotDisplayType)
# 由 build_device_specs() 运行时构建，使 macOS 子目录可在 CLI 覆盖。
def build_device_specs(macos_subdir):
    return [
        ("ios", "iphone-6.5-", "screenshots", "APP_IPHONE_65"),
        # iPhone 灵动岛 6.3" 在 App Store Connect 的 displayType 是 APP_IPHONE_61
        # (fastlane 2.238.0 注释：IPHONE_61 = "6.3\"")，没有 APP_IPHONE_6_3 这种值。
        ("ios", "iphone-灵动岛必填-", "screenshots", "APP_IPHONE_61"),
        ("ios", "ipad-13横屏-", "screenshots", "APP_IPAD_PRO_3GEN_129"),
        (macos_subdir, "macos-", "screenshots_macos", "APP_DESKTOP"),
    ]

# 保留模块级 DEVICE_SPECS，保持旧 import/测试代码不破，但实际构建改用上面的函数。
DEVICE_SPECS = build_device_specs("MacOS")

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def natural_key(path: Path):
    """按文件名中的数字分段排序，保证 2 排在 10 前面。"""
    return [int(part) if part.isdigit() else part.lower()
            for part in re.split(r"(\d+)", path.name)]


def parse_language(dir_name: str, prefix: str) -> str:
    """从设备目录名中取出语言后缀并映射为 locale；无法识别时返回 None。"""
    if not dir_name.startswith(prefix):
        return None
    return LANGUAGE_LOCALES.get(dir_name[len(prefix):])


def collect(source: Path, specs, exclude_prefixes) -> dict:
    """返回 {(dest_root, locale, display_type): [源文件...]}，已按自然序排列。

    exclude_prefixes: 一组设备目录前缀（如 {"iphone-6.5-"}），整条设备类型会被跳过。
    """
    jobs = {}
    for platform_dir, prefix, dest_root, display_type in specs:
        if prefix in exclude_prefixes:
            continue
        base = source / platform_dir
        if not base.is_dir():
            continue
        for device_dir in sorted(base.iterdir()):
            if not device_dir.is_dir():
                continue
            locale = parse_language(device_dir.name, prefix)
            if locale is None:
                continue
            files = sorted((p for p in device_dir.iterdir()
                            if p.suffix.lower() in IMAGE_EXTENSIONS),
                           key=natural_key)
            if files:
                jobs[(dest_root, locale, display_type)] = files
    return jobs


def stage(jobs: dict, dest: Path, dry_run: bool) -> int:
    # 先按 (平台, 语言) 整体清一次目录：同一语言下的多个设备类型共用一个目录，
    # 逐个 job 清理会把前一个设备类型刚写入的文件删掉。
    locale_dirs = {(dest_root, locale) for (dest_root, locale, _) in jobs}
    for dest_root, locale in sorted(locale_dirs):
        target_dir = dest / dest_root / locale
        if dry_run:
            continue
        target_dir.mkdir(parents=True, exist_ok=True)
        # 清掉上一轮的图片，避免残留文件被一并上传
        for stale in target_dir.iterdir():
            if stale.is_file() and stale.suffix.lower() in IMAGE_EXTENSIONS:
                stale.unlink()

    written = 0
    for (dest_root, locale, display_type), files in sorted(jobs.items()):
        target_dir = dest / dest_root / locale
        print(f"{dest_root}/{locale} {display_type}: {len(files)} 张")
        for index, src in enumerate(files):
            name = f"{index}_{display_type}_{index}{src.suffix.lower()}"
            dst = target_dir / name
            print(f"    {src.name} -> {name}")
            if not dry_run:
                shutil.copy2(src, dst)
            written += 1
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description="整理截图到 Fastlane 目录布局")
    parser.add_argument("--source", required=True, help="设计导出目录")
    parser.add_argument("--dest", default=str(Path(__file__).resolve().parent.parent),
                        help="输出根目录（默认取脚本所在目录的上级，即 fastlane 目录）。"
                             "配合 --locales 指到临时目录即可只上传部分语言")
    parser.add_argument("--locales", default="",
                        help="只整理这些 locale（逗号分隔），默认全部")
    parser.add_argument("--exclude-prefixes", default="",
                        help="逗号分隔的设备目录前缀列表，匹配的设备类型整条跳过。"
                             "例：--exclude-prefixes iphone-6.5-")
    parser.add_argument("--macos-subdir", default="MacOS",
                        help="macOS 截图在源目录下的子目录名，默认 MacOS；"
                             "下载包通常叫 custom。")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不写文件")
    args = parser.parse_args()

    source = Path(args.source).expanduser().resolve()
    dest = Path(args.dest).expanduser().resolve()
    if not source.is_dir():
        sys.exit(f"源目录不存在: {source}")

    specs = build_device_specs(args.macos_subdir)
    exclude = {p for p in args.exclude_prefixes.split(",") if p}
    jobs = collect(source, specs, exclude)
    if not jobs:
        sys.exit(f"没有在 {source} 下匹配到任何截图，请检查目录命名")

    wanted = [item.strip() for item in args.locales.split(",") if item.strip()]
    if wanted:
        unknown = sorted(set(wanted) - {locale for (_, locale, _) in jobs})
        if unknown:
            sys.exit(f"源目录里没有这些语言的截图: {', '.join(unknown)}")
        jobs = {key: files for key, files in jobs.items() if key[1] in wanted}

    total = stage(jobs, dest, args.dry_run)

    locales = sorted({locale for (_, locale, _) in jobs})
    print(f"\n{'[dry-run] ' if args.dry_run else ''}共 {total} 张，"
          f"{len(jobs)} 个语言/设备组合，语言: {', '.join(locales)}")
    missing = sorted(set(LANGUAGE_LOCALES.values()) - set(locales))
    if missing:
        print(f"注意：以下语言没有提供截图，将保持现状: {', '.join(missing)}")


if __name__ == "__main__":
    main()

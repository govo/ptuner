#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把导出的 App 预览视频按语言铺成 Fastlane deliver 需要的目录布局。

deliver 通过 app_previews_path 上传预览视频，要求：

    <app_previews_path>/<locale>/<含设备标记的文件名>.mp4

文件名必须包含设备类型标记（如 IPHONE_65），deliver 据此推断 previewType。

关键点：deliver 对不合格视频只打一条日志就**静默跳过**（时长超范围 / 分辨率
不符 / 超出 500MB 都走这个分支），全部被跳过时任务仍算成功。因此本脚本在上传
前用 ffprobe 预校验，不达标直接报错退出，避免"上传成功但一条都没传上去"。

用法：
    python3 stage_app_previews.py --zh-video /path/9月中文.mp4 --en-video /path/9月英文.mp4
    python3 stage_app_previews.py ... --locales zh-Hans,en-US --dry-run
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

# App 支持的商店语言，以及其中哪些用中文视频（其余一律用英文视频）
ALL_LOCALES = ["de-DE", "en-US", "es-ES", "fr-FR", "it", "ja", "ko", "zh-Hans", "zh-Hant"]
DEFAULT_ZH_LOCALES = ["zh-Hans"]

# 苹果规定的预览视频时长区间（秒），与 deliver 的校验保持一致
MIN_DURATION = 15.0
MAX_DURATION = 30.0

# 设备标记 -> 苹果规定的可接受分辨率。竖屏与横屏共用同一组尺寸，
# 比较前统一归一化成 (短边, 长边)，见 normalize_resolution。
# iPhone 6.3"（灵动岛）在 ASC 的预览类型是 IPHONE_61——不是 IPHONE_6_3；
# 它与 6.5" 同样接受 886x1920，分辨率无法区分两者，只能靠文件名标记。
PREVIEW_SPECS = {
    "APP_IPHONE_61": {(886, 1920)},
    "APP_IPHONE_65": {(886, 1920)},
    "APP_IPHONE_55": {(1080, 1920)},
    "APP_IPAD_PRO_3GEN_129": {(1200, 1600)},
}

# 苹果 App 预览规格只列出 H.264 与 ProRes 422 (HQ)，但实测 HEVC 能被
# App Store Connect 正常接收并处理完成（状态 COMPLETE），故仅提示不拦截。
ACCEPTED_VIDEO_CODECS = {"h264", "prores"}


def probe(path: Path) -> dict:
    """用 ffprobe 读取视频流信息；ffprobe 缺失或读取失败时返回 None。"""
    cmd = [
        "ffprobe", "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=codec_name,width,height",
        "-show_entries", "format=duration",
        "-of", "json", str(path),
    ]
    try:
        raw = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None

    data = json.loads(raw)
    streams = data.get("streams") or []
    if not streams:
        return None
    stream = streams[0]

    duration = None
    try:
        duration = float(data["format"]["duration"])
    except (KeyError, TypeError, ValueError):
        pass

    return {
        "codec": stream.get("codec_name"),
        "width": stream.get("width"),
        "height": stream.get("height"),
        "duration": duration,
    }


def normalize_resolution(width: int, height: int):
    """归一化成 (短边, 长边)，竖屏与横屏因此可以共用一组规格。"""
    return (width, height) if width <= height else (height, width)


def validate(path: Path, display_type: str) -> list:
    """校验单个视频，返回问题列表（空列表表示通过）。"""
    problems = []
    info = probe(path)
    if info is None:
        return [f"无法读取视频信息（缺 ffprobe 或文件损坏）: {path}"]

    duration = info["duration"]
    if duration is None:
        problems.append("无法确定时长，deliver 可能仍会尝试上传")
    elif not (MIN_DURATION <= duration <= MAX_DURATION):
        problems.append(
            f"时长 {duration:.2f}s 超出苹果规定的 {MIN_DURATION:.0f}~{MAX_DURATION:.0f}s"
            f"（deliver 会静默跳过）"
        )

    if info["width"] and info["height"]:
        actual = normalize_resolution(info["width"], info["height"])
        allowed = PREVIEW_SPECS[display_type]
        if actual not in allowed:
            want = " 或 ".join(f"{w}x{h}" for w, h in sorted(allowed))
            problems.append(
                f"分辨率 {info['width']}x{info['height']} 不符 {display_type} 规定"
                f"（应为 {want}，deliver 会静默跳过）"
            )
    else:
        problems.append("无法确定分辨率")

    if info["codec"] and info["codec"] not in ACCEPTED_VIDEO_CODECS:
        print(f"    提示：编码为 {info['codec']}，苹果规格页只列 H.264 / ProRes 422，"
              f"实测可被接收；若上传后被拒需转码为 H.264")

    return problems


def build_jobs(args) -> dict:
    """返回 {locale: 源视频路径}。"""
    if not args.zh_video.is_file():
        sys.exit(f"中文视频不存在: {args.zh_video}")
    if not args.en_video.is_file():
        sys.exit(f"英文视频不存在: {args.en_video}")

    zh_locales = {item.strip() for item in args.zh_locales.split(",") if item.strip()}
    unknown = sorted(zh_locales - set(ALL_LOCALES))
    if unknown:
        sys.exit(f"不认识的中文语言: {', '.join(unknown)}")

    locales = [item.strip() for item in args.locales.split(",") if item.strip()] or ALL_LOCALES
    unknown = sorted(set(locales) - set(ALL_LOCALES))
    if unknown:
        sys.exit(f"不支持的语言: {', '.join(unknown)}")

    return {
        locale: (args.zh_video if locale in zh_locales else args.en_video)
        for locale in locales
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="整理 App 预览视频到 Fastlane 目录布局")
    parser.add_argument("--zh-video", required=True, type=Path, help="简体中文预览视频")
    parser.add_argument("--en-video", required=True, type=Path, help="其他语言共用的英文预览视频")
    parser.add_argument("--zh-locales", default=",".join(DEFAULT_ZH_LOCALES),
                        help=f"使用中文视频的语言（逗号分隔），默认 {','.join(DEFAULT_ZH_LOCALES)}")
    parser.add_argument("--display-type", default="APP_IPHONE_65",
                        choices=sorted(PREVIEW_SPECS), help="设备类型，默认 APP_IPHONE_65")
    parser.add_argument("--locales", default="", help="只整理这些语言（逗号分隔），默认全部")
    parser.add_argument("--dest", default=str(Path(__file__).resolve().parent.parent),
                        help="输出根目录（默认取脚本所在目录的上级，即 fastlane 目录）")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不写文件")
    args = parser.parse_args()

    args.zh_video = args.zh_video.expanduser().resolve()
    args.en_video = args.en_video.expanduser().resolve()
    dest = Path(args.dest).expanduser().resolve()

    jobs = build_jobs(args)
    prefix = args.display_type.replace("APP_", "")

    # 逐语言先校验，全部通过后再落盘，避免铺到一半才失败留下半套文件
    failures = {}
    for locale, source in sorted(jobs.items()):
        print(f"{locale}: {source.name}")
        problems = validate(source, args.display_type)
        if problems:
            failures[locale] = problems
        for problem in problems:
            print(f"    错误：{problem}")
    if failures:
        sys.exit(f"\n{len(failures)} 个语言的视频不达标，已中止，未写入任何文件")

    total_bytes = 0
    for locale, source in sorted(jobs.items()):
        target_dir = dest / "app_previews" / locale
        name = f"0_{args.display_type}_0{source.suffix.lower()}"
        print(f"{locale}: {source.name} -> app_previews/{locale}/{name}")
        if not args.dry_run:
            target_dir.mkdir(parents=True, exist_ok=True)
            # 清掉上一轮的视频，避免残留文件被一并上传
            for stale in target_dir.iterdir():
                if stale.is_file() and stale.suffix.lower() in {".mp4", ".mov", ".m4v"}:
                    stale.unlink()
            shutil.copy2(source, target_dir / name)
        total_bytes += source.stat().st_size

    size_mb = total_bytes / (1024.0 * 1024.0)
    print(f"\n{'[dry-run] ' if args.dry_run else ''}共 {len(jobs)} 个语言，"
          f"合计 {size_mb:.1f}MB，设备类型 {args.display_type}")
    zh = sorted(locale for locale in jobs if locale in
                {item.strip() for item in args.zh_locales.split(",") if item.strip()})
    print(f"中文视频: {', '.join(zh)}；英文视频: "
          f"{', '.join(sorted(set(jobs) - set(zh)))}")


if __name__ == "__main__":
    main()

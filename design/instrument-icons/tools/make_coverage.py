#!/usr/bin/env python3
"""Write instrument-coverage.md from the app catalog and the icon manifest."""

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
CATALOG = REPO / "PTuner" / "PTuner" / "Resources" / "Instruments.json"
MANIFEST = ROOT / "manifest.json"

NOT_COVERED = {
    "nyckelharpa": "结构特殊（键控弓弦），暂不收录",
    "sarangi": "演奏弦与共鸣弦结构特殊，暂不收录",
    "ektara": "民间单弦乐器，暂不收录",
    "dotara": "地区差异较大的民间弹拨乐器，暂不收录",
    "kantele": "民间齐特类乐器，暂不收录",
    "gusli": "民间齐特类乐器，暂不收录",
    "bandura": "民间齐特类乐器，暂不收录",
}


def main():
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    families = {f["id"]: f for f in catalog["families"]}
    by_id = {item["instrumentID"]: item for item in manifest}
    reuse = {}
    for item in manifest:
        for instrument_id in item.get("reuseFor", []):
            reuse[instrument_id] = item

    lines = [
        "# 乐器图标覆盖说明",
        "",
        f"素材目录：`design/instrument-icons/`。当前收录 **{len(manifest)}** 件常见乐器，"
        f"覆盖 `Instruments.json` 中 {len(by_id) + len(reuse)} / {len(catalog['instruments'])} 件乐器"
        "（含复用同一图标的相近乐器）。",
        "",
        "本轮只产出图片素材，未修改任何 Swift 代码、`Instruments.json`、"
        "`Localizations.json` 或 `Assets.xcassets`。",
        "",
        "## 收录的图标",
        "",
        "| 文件 | 乐器 | English | 族 | 1x / 2x / 3x | 可复用于 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for item in manifest:
        reused = "、".join(item.get("reuseFor", [])) or "-"
        lines.append(
            f"| [{item['file']}](svg/{item['file']}.svg) | {item['nameZh']} | {item['nameEn']} | "
            f"{families[item['familyID']]['shortNameKey']} | "
            f"[1x](png/1x/{item['file']}.png) / [2x](png/2x/{item['file']}.png) / "
            f"[3x](png/3x/{item['file']}.png) | {reused} |"
        )

    lines += [
        "",
        "## 全部乐器清单与覆盖状态",
        "",
        "按 `Instruments.json` 中的族顺序与乐器顺序排列。",
        "",
        "| 族 | 乐器 ID | 中文名 | English | 状态 | 图标 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    loc = json.loads((REPO / "PTuner" / "PTuner" / "Localizations.json").read_text(encoding="utf-8"))
    en = loc.get("en", {})
    for family in sorted(catalog["families"], key=lambda f: f["order"]):
        instruments = sorted(
            (i for i in catalog["instruments"] if i["familyID"] == family["id"]),
            key=lambda i: i["order"],
        )
        for instrument in instruments:
            iid = instrument["id"]
            zh = instrument["nameKey"]
            name_en = en.get(zh, zh)
            if iid in by_id:
                item = by_id[iid]
                status = "专属图标"
                icon = f"[{item['file']}](tiles/{item['file']}.png)"
            elif iid in reuse:
                item = reuse[iid]
                status = "复用"
                icon = f"{item['file']}（{item['nameZh']}）"
            else:
                status = "未收录"
                icon = NOT_COVERED.get(iid, "-")
            lines.append(
                f"| {family['shortNameKey']} | `{iid}` | {zh} | {name_en} | {status} | {icon} |"
            )

    lines += [
        "",
        "## 风格与尺寸",
        "",
        "- 画布：640 x 1024（0.625 宽高比，贴近现有 18 x 29 图标槽位），透明背景。",
        "- 输出：1x 320 x 512、2x 640 x 1024、3x 960 x 1536，24 件乐器尺寸完全一致。",
        "- 附加：`tiles/` 为 1024 x 1024 圆角彩色底图标，按乐器族识别色生成，"
        "仅用于预览或对外展示，不参与 App 内显示。",
        "- 风格：扁平矢量，暖木色 + 米色面板 + 黄铜配件的统一配色；"
        "统一正面视角、统一线宽、无文字、无阴影。",
        "- 细节密度按 36 x 36 显示尺寸控制；18 x 29 时古筝、日本筝、伽倻琴、古琴等"
        "长条乐器会退化为竖向轮廓，属于该尺寸的物理限制。",
        "",
        "## 文件结构",
        "",
        "```",
        "design/instrument-icons/",
        "  svg/                    矢量源文件（24 个）",
        "  png/1x/  png/2x/  png/3x/",
        "  tiles/                  1024 x 1024 彩色圆角底图标",
        "  tools/generate_icons.py 生成 SVG",
        "  tools/build_assets.py   渲染 PNG 与 tile",
        "  tools/make_coverage.py  生成本文档",
        "  tools/preview_small.py  生成真实尺寸预览",
        "  manifest.json           乐器 ID、族色、文件与复用关系",
        "  contact-sheet.png       透明底总览",
        "  contact-sheet-tiles.png 彩色底总览",
        "  preview-actual-size-4x.png 18 x 29 与 36 x 36 实际尺寸预览（4 倍放大）",
        "```",
        "",
        "## 重新生成",
        "",
        "```bash",
        "/opt/miniconda3/bin/python tools/generate_icons.py",
        "/opt/miniconda3/bin/python tools/build_assets.py",
        "/opt/miniconda3/bin/python tools/preview_small.py",
        "/opt/miniconda3/bin/python tools/make_coverage.py",
        "```",
        "",
        "依赖：`rsvg-convert`、Pillow。",
        "",
        "## 版权",
        "",
        "全部图形由本目录下的生成脚本原创绘制，未使用第三方图标库、照片或生成式模型输出，"
        "不携带额外授权限制，可随 App 使用。",
        "",
        "## 后续接入（本轮未执行）",
        "",
        "1. 将 `png/1x`、`png/2x`、`png/3x` 做成 `Assets.xcassets` 的 imageset；"
        "`manifest.json` 中的 `suggestedAssetName` 已按 `instrument_<乐器 ID>` 生成，"
        "例如 `instrument_erhu`，可直接作为 imageset 名。",
        "2. 在 `Instruments.json` 中对目标乐器填写 `image` 字段，值使用 imageset 名称。",
        "3. 图片缺失时现有代码会自动回退到 `glyph`，因此可以逐件灰度接入。",
        "",
    ]
    (ROOT / "instrument-coverage.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {ROOT / 'instrument-coverage.md'}")


if __name__ == "__main__":
    main()

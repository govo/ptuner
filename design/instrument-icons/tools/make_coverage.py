#!/usr/bin/env python3
"""Write instrument-coverage.md from the app catalog and the icon manifest."""

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
CATALOG = REPO / "PTuner" / "PTuner" / "Resources" / "Instruments.json"
MANIFEST = ROOT / "manifest.json"

NOT_COVERED = {}


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
        "图标已接入 `Assets.xcassets`（imageset 名 `instrument_<乐器 ID>`），"
        "并在 `Instruments.json` 中填写了对应乐器的 `image` 字段。"
        "未修改任何 Swift 代码或 `Localizations.json`。",
        "",
        "## 收录的图标",
        "",
        "| 文件 | 乐器 | English | 族 | 1x / 2x / 3x | 可复用于 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for item in manifest:
        reused = "、".join(item.get("reuseFor", [])) or "-"
        lines.append(
            f"| [{item['file']}](raster/{item['file']}.png) | {item['nameZh']} | {item['nameEn']} | "
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
        f"- 输出：1x 320 x 512、2x 640 x 1024、3x 960 x 1536，{len(manifest)} 件乐器尺寸完全一致。",
        "- 附加：`tiles/` 为 1024 x 1024 圆角彩色底图标，按乐器族识别色生成，"
        "仅用于预览或对外展示，不参与 App 内显示。",
        "- 风格：暖木色写实插画，统一正面视角、统一光源；已去除背景与水印，无文字、无阴影。",
        "- 细节密度按 36 x 36 显示尺寸控制；18 x 29 时古筝、日本筝、伽倻琴、古琴等"
        "长条乐器会退化为竖向轮廓，属于该尺寸的物理限制。",
        "",
        "## 文件结构",
        "",
        "```",
        "design/instrument-icons/",
        "  raster/                 透明背景 640 x 1024 母版（App 实际使用）",
        f"  svg/                    早期脚本绘制的矢量备份（{len(manifest)} 个）",
        "  png/1x/  png/2x/  png/3x/",
        "  tiles/                  1024 x 1024 彩色圆角底图标",
        "  tools/import_raster_icons.py 去除水印与背景，生成 raster 母版",
        "  tools/build_assets.py   由 raster（或 SVG）生成 PNG 与 tile",
        "  tools/install_assets.py 写入 Assets.xcassets 与 Instruments.json",
        "  tools/make_coverage.py  生成本文档",
        "  tools/preview_small.py  生成真实尺寸预览",
        "  manifest.json           乐器 ID、族色、文件与复用关系",
        "  contact-sheet.png       透明底总览",
        "  contact-sheet-tiles.png 彩色底总览",
        "  preview-actual-size-4x.png 18 x 29 与 36 x 36 实际尺寸预览（4 倍放大）",
        "```",
        "",
        "## 重新生成与接入",
        "",
        "```bash",
        "/opt/miniconda3/bin/python tools/import_raster_icons.py --source /path/to/源图目录",
        "/opt/miniconda3/bin/python tools/build_assets.py",
        "/opt/miniconda3/bin/python tools/install_assets.py",
        "/opt/miniconda3/bin/python tools/preview_small.py",
        "/opt/miniconda3/bin/python tools/make_coverage.py",
        "```",
        "",
        "`build_assets.py` 优先读取 `raster/<文件名>.png`；该文件不存在时才回退到 "
        "`svg/<文件名>.svg` 并用 `rsvg-convert` 渲染。",
        "",
        "依赖：`Pillow`、`numpy`、`scipy`；SVG 回退方案另需 `rsvg-convert`。",
        "",
        "## 版权",
        "",
        "App 内当前使用的图标由用户提供的 AI 生成素材制作，已去除右下角水印并转为透明背景；"
        "素材来源与商用授权由提供方确认。`svg/` 为早期脚本绘制的备用版本，未再参与 App 构建。",
        "",
        "## 接入状态",
        "",
        f"1. `Assets.xcassets` 中已创建 {len(manifest)} 个 imageset，命名规则 `instrument_<乐器 ID>`，"
        "例如 `instrument_erhu`，每个包含 1x / 2x / 3x 三档 PNG。",
        f"2. `Instruments.json` 中已有 {len(by_id) + len(reuse)} 件乐器填写 `image` 字段并指向对应 imageset。",
        "3. 图片缺失时现有代码会自动回退到 `glyph`，后续新增乐器仍可逐件接入。",
        "",
    ]
    (ROOT / "instrument-coverage.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {ROOT / 'instrument-coverage.md'}")


if __name__ == "__main__":
    main()

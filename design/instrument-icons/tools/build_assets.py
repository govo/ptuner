#!/usr/bin/env python3
"""Render the PTuner instrument icons into app-ready PNG scales and tiles.

Inputs:  svg/*.svg
Outputs: png/1x, png/2x, png/3x, tiles/*.png, manifest.json

Requires: rsvg-convert, Pillow.
"""

from pathlib import Path
import json
import subprocess

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SVG_DIR = ROOT / "svg"
PNG_DIR = ROOT / "png"
TILE_DIR = ROOT / "tiles"
MANIFEST = ROOT / "manifest.json"

SCALES = {"1x": (320, 512), "2x": (640, 1024), "3x": (960, 1536)}
TILE_SIZE = 1024
TILE_RADIUS = 224


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def render_svg(svg_path, out_path, size):
    subprocess.run(
        ["rsvg-convert", "-w", str(size[0]), "-h", str(size[1]), str(svg_path), "-o", str(out_path)],
        check=True,
    )


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def tile_background(tint):
    base_top = hex_rgb("#1B2230")
    base_bottom = hex_rgb("#0B0E13")
    top = mix(base_top, tint, 0.42)
    bottom = mix(base_bottom, tint, 0.26)
    image = Image.new("RGB", (TILE_SIZE, TILE_SIZE))
    draw = ImageDraw.Draw(image)
    for y in range(TILE_SIZE):
        t = y / (TILE_SIZE - 1)
        draw.line((0, y, TILE_SIZE, y), fill=mix(top, bottom, t))
    # soft top highlight
    glow = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse((-220, -420, TILE_SIZE + 220, 520), fill=(*mix(tint, (255, 255, 255), 0.35), 90))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    image = Image.alpha_composite(image.convert("RGBA"), glow)
    # inner edge light
    edge = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    edraw = ImageDraw.Draw(edge)
    edraw.rounded_rectangle((3, 3, TILE_SIZE - 4, TILE_SIZE - 4), radius=TILE_RADIUS - 2,
                            outline=(255, 255, 255, 36), width=4)
    image = Image.alpha_composite(image, edge)
    image.putalpha(rounded_mask(TILE_SIZE, TILE_RADIUS))
    return image


def make_tile(icon_3x, tint, out_path):
    tile = tile_background(hex_rgb(tint))
    icon = Image.open(icon_3x).convert("RGBA")
    target_h = 840
    target_w = round(icon.width * target_h / icon.height)
    icon = icon.resize((target_w, target_h), Image.LANCZOS)
    x = (TILE_SIZE - target_w) // 2
    y = (TILE_SIZE - target_h) // 2
    tile.alpha_composite(icon, (x, y))
    tile.save(out_path)


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for scale, size in SCALES.items():
        (PNG_DIR / scale).mkdir(parents=True, exist_ok=True)
    TILE_DIR.mkdir(parents=True, exist_ok=True)

    updated = []
    for item in manifest:
        key = item["file"]
        svg = SVG_DIR / f"{key}.svg"
        for scale, size in SCALES.items():
            out = PNG_DIR / scale / f"{key}.png"
            render_svg(svg, out, size)
        icon_3x = PNG_DIR / "3x" / f"{key}.png"
        tile = TILE_DIR / f"{key}.png"
        make_tile(icon_3x, item["familyTint"], tile)
        item.update({
            "png1x": f"png/1x/{key}.png",
            "png2x": f"png/2x/{key}.png",
            "png3x": f"png/3x/{key}.png",
            "tile": f"tiles/{key}.png",
        })
        item.pop("png", None)
        updated.append(item)

    MANIFEST.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"rendered {len(updated)} icons at {', '.join(SCALES)} and {len(updated)} tiles")


if __name__ == "__main__":
    main()

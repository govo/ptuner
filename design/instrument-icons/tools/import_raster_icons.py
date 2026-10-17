#!/usr/bin/env python3
"""Import user-provided AI raster icons as transparent 640 x 1024 assets.

Source images are 1600 x 2560 PNGs with a near-white background and a
"豆包 AI 生成" watermark in the bottom-right corner. This script:

1. clears the watermark rectangle (verified empty of instrument pixels),
2. flood-fills the near-white background from the canvas border,
3. feathers the anti-aliased outline,
4. resizes with premultiplied alpha to avoid white fringes,
5. writes raster/<file key>.png at 640 x 1024 RGBA.

build_assets.py prefers raster/<key>.png over svg/<key>.svg when present.

Requires: Pillow, numpy, scipy.
"""

from pathlib import Path
import argparse
import json

import numpy as np
from PIL import Image
from scipy import ndimage

from image_ops import resize_premultiplied

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "manifest.json"
OUT_DIR = ROOT / "raster"
DEFAULT_SOURCE = Path("/Users/govo/Downloads/琴")
CANVAS = (640, 1024)

# The watermark sits at roughly x >= 80.5% and y >= 95.2% of the generated
# frame. Checked against all 31 source images: no instrument pixels in rect.
WATERMARK_X = 0.805
WATERMARK_Y = 0.952

BACKGROUND_MIN = 240
BACKGROUND_SATURATION = 8
FEATHER_DEPTH = 2
FEATHER_RANGE = 18


def clear_watermark(rgb):
    height, width, _ = rgb.shape
    x0 = round(width * WATERMARK_X)
    y0 = round(height * WATERMARK_Y)
    rgb[y0:, x0:] = 255
    return rgb


def background_mask(rgb):
    light = rgb.min(axis=2) >= BACKGROUND_MIN
    neutral = (rgb.max(axis=2) - rgb.min(axis=2)) <= BACKGROUND_SATURATION
    candidate = light & neutral
    labels, _ = ndimage.label(candidate, structure=np.ones((3, 3), dtype=int))
    border = np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])))
    border = border[border > 0]
    return np.isin(labels, border)


def build_alpha(rgb, background):
    """Opaque inside, transparent outside, soft over the anti-aliased rim."""
    saturation = rgb.max(axis=2) - rgb.min(axis=2)
    luminance = rgb.mean(axis=2)
    alpha = np.full(background.shape, 255.0, dtype=np.float32)

    rim = ndimage.binary_dilation(background, iterations=FEATHER_DEPTH) & ~background
    rim &= saturation <= BACKGROUND_SATURATION + 4
    rim_alpha = np.clip((255.0 - luminance[rim]) / FEATHER_RANGE * 255.0, 0, 255)
    alpha[rim] = rim_alpha
    alpha[background] = 0
    return alpha


def process(source, destination):
    rgb = np.asarray(Image.open(source).convert("RGB"), dtype=np.uint8).astype(np.int16)
    clear_watermark(rgb)
    background = background_mask(rgb)
    alpha = build_alpha(rgb, background)

    rgba = Image.fromarray(np.dstack((rgb.astype(np.uint8), alpha.astype(np.uint8))))
    resize_premultiplied(rgba, CANVAS).save(destination)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    missing = []
    for item in manifest:
        key = item["file"]
        source = args.source / f"{key}.png"
        if not source.is_file():
            missing.append(source.name)
            continue
        process(source, OUT_DIR / f"{key}.png")

    if missing:
        raise SystemExit(f"missing source images: {', '.join(missing)}")
    print(f"imported {len(manifest)} raster icons into {OUT_DIR}")


if __name__ == "__main__":
    main()

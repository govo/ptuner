#!/usr/bin/env python3
"""Build a nearest-neighbour preview of the icons at their real display sizes.

Each cell shows the 38 x 38 app tile with the icon at 38 x 38 and at 18 x 29
(the two sizes currently used by InstrumentRowViews / InstrumentSelectionView).
The whole sheet is enlarged 4x with nearest-neighbour so the pixel result is
visible without smoothing.
"""

from pathlib import Path
import json

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))

CELL_W, CELL_H = 200, 190
COLS = 5
ROWS = (len(MANIFEST) + COLS - 1) // COLS
SCALE = 4
BG = (11, 14, 19)
CARD = (28, 34, 43)
LABEL = (220, 229, 240)


def tint_rgba(hex_value, alpha):
    value = hex_value.lstrip("#")
    r, g, b = (int(value[i:i + 2], 16) for i in (0, 2, 4))
    return (r, g, b, alpha)


def rounded_card(size, fill):
    card = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle((0, 0, size - 1, size - 1), radius=10, fill=fill)
    return card


try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)
except OSError:
    font = ImageFont.load_default()


def main():
    sheet = Image.new("RGB", (CELL_W * COLS, CELL_H * ROWS), BG)
    draw = ImageDraw.Draw(sheet)
    for index, item in enumerate(MANIFEST):
        col = index % COLS
        row = index // COLS
        x0 = col * CELL_W
        y0 = row * CELL_H
        icon = Image.open(ROOT / item["png2x"]).convert("RGBA")
        tint = tint_rgba(item["familyTint"], 34)

        # 18 x 29 slot, matching InstrumentRowViews presetIcon
        card_a = rounded_card(38, (*CARD, 255))
        card_a = Image.alpha_composite(card_a, rounded_card(38, tint))
        small = icon.resize((18, 29), Image.LANCZOS)
        card_a.alpha_composite(small, ((38 - 18) // 2, (38 - 29) // 2))
        sheet.paste(card_a.convert("RGB"), (x0 + 24, y0 + 16), card_a)

        # 36 x 36 slot, matching InstrumentSelectionView
        card_b = rounded_card(38, (*CARD, 255))
        card_b = Image.alpha_composite(card_b, rounded_card(38, tint))
        big = icon.resize((36, 36), Image.LANCZOS)
        card_b.alpha_composite(big, (1, 1))
        sheet.paste(card_b.convert("RGB"), (x0 + 96, y0 + 16), card_b)

        draw.text((x0 + 24, y0 + 66), "18x29", font=font, fill=LABEL)
        draw.text((x0 + 96, y0 + 66), "36x36", font=font, fill=LABEL)
        draw.text((x0 + 24, y0 + 88), item["file"], font=font, fill=LABEL)

    sheet = sheet.resize((sheet.width * SCALE, sheet.height * SCALE), Image.NEAREST)
    sheet.save(ROOT / "preview-actual-size-4x.png")
    print(f"wrote {ROOT / 'preview-actual-size-4x.png'}")


if __name__ == "__main__":
    main()

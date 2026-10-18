#!/usr/bin/env python3
"""把原始截图合成为带主标题、副标题的 App Store 营销截图。

用法：
    python compose_screenshots.py --lang zh-Hans
    python compose_screenshots.py --lang zh-Hans --device iphone
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "doc" / "screenshots-raw"
OUT = ROOT / "doc" / "marketing" / "preview"

PINGFANG = ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/"
            "86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc")
HIRAGINO = "/System/Library/Fonts/Hiragino Sans GB.ttc"
GOTHIC = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
SFNS = "/System/Library/Fonts/SFNS.ttf"

# 每种语言：(字体文件, 标题索引或变体, 正文索引或变体)
FONTS = {
    "zh-Hans": (PINGFANG, 11, 3),
    "zh-Hant": (PINGFANG, 10, 2),
    "ja": (HIRAGINO, 2, 0),
    "ko": (GOTHIC, 6, 0),
    "en": (SFNS, "Semibold", "Regular"),
    "es": (SFNS, "Semibold", "Regular"),
    "de": (SFNS, "Semibold", "Regular"),
    "fr": (SFNS, "Semibold", "Regular"),
    "it": (SFNS, "Semibold", "Regular"),
}

SCENES = ["single", "multi", "library", "custom", "chord"]

COPY = {
    "zh-Hans": {
        "single": ("一拨即准", "高精度单音调音，音分偏差一眼看清"),
        "multi": ("六根弦，一次调好", "多音同步识别，整琴校验不必逐根拨弦"),
        "library": ("一支 App，调遍乐器", "54 种乐器 · 134 种调弦，开箱即用"),
        "custom": ("你的调弦，你来定", "逐弦微调音分，保存成专属调弦"),
        "chord": ("听见和弦的名字", "实时识别和弦与组成音，练习更高效"),
    },
    "zh-Hant": {
        "single": ("一撥即準", "高精度單音調音，音分偏差一眼看清"),
        "multi": ("六根弦，一次調好", "多音同步辨識，整琴校驗不必逐根撥弦"),
        "library": ("一支 App，調遍樂器", "54 種樂器 · 134 種調弦，開箱即用"),
        "custom": ("你的調弦，你來定", "逐弦微調音分，存成專屬調弦"),
        "chord": ("聽見和弦的名字", "即時辨識和弦與組成音，練習更有效率"),
    },
    "ja": {
        "single": ("一音で、正確に", "高精度の単音チューニング。セント単位のずれがひと目でわかる"),
        "multi": ("6本まとめて、一度に", "複数弦を同時検出。1本ずつ弾かなくても全体を確認"),
        "library": ("1つのアプリで、すべての楽器を", "54種の楽器・134種のチューニングをすぐに利用"),
        "custom": ("チューニングは、自由に", "弦ごとにセント調整して、自分だけの設定を保存"),
        "chord": ("コードの名前が、聴こえる", "コードと構成音をリアルタイム認識。練習がもっと効率的に"),
    },
    "ko": {
        "single": ("한 번 튕기면 정확하게", "정밀한 단음 튜닝, 센트 단위 오차를 한눈에"),
        "multi": ("여섯 줄을 한 번에", "다중 음 동시 인식으로 악기 전체를 한 번에 점검"),
        "library": ("하나의 앱으로 모든 악기를", "54가지 악기 · 134가지 튜닝 기본 제공"),
        "custom": ("나만의 조율을", "줄마다 센트를 미세 조정해 나만의 튜닝 저장"),
        "chord": ("코드의 이름이 들린다", "코드와 구성음을 실시간 인식해 연습이 더 효율적"),
    },
    "en": {
        "single": ("Spot on, every note", "High-precision single-note tuning with cent-level accuracy"),
        "multi": ("Six strings, one pass", "Polyphonic detection tunes the whole instrument at once"),
        "library": ("Every instrument, one app", "54 instruments · 134 tunings, ready to play"),
        "custom": ("Your tuning, your rules", "Fine-tune each string in cents and save your own preset"),
        "chord": ("Every chord has a name", "Real-time chord and note recognition for smarter practice"),
    },
    "es": {
        "single": ("Afinado a la primera", "Precisión de afinación con desviación en cents al instante"),
        "multi": ("Seis cuerdas, una pasada", "Detección polifónica para revisar todo el instrumento a la vez"),
        "library": ("Una app, todos los instrumentos", "54 instrumentos · 134 afinaciones listas para usar"),
        "custom": ("Tu afinación, tus reglas", "Ajusta cada cuerda en cents y guarda tu propia afinación"),
        "chord": ("Escucha cada acorde", "Reconocimiento de acordes y notas en tiempo real para practicar mejor"),
    },
    "de": {
        "single": ("Jeder Ton sitzt", "Präzise Einzelsaiten-Stimmung mit Cent-genauer Abweichung"),
        "multi": ("Sechs Saiten, ein Durchgang", "Polyphone Erkennung stimmt das ganze Instrument auf einmal"),
        "library": ("Eine App, alle Instrumente", "54 Instrumente · 134 Stimmungen sofort einsatzbereit"),
        "custom": ("Deine Stimmung, deine Regeln", "Jede Saite in Cents feinjustieren und als eigenes Preset speichern"),
        "chord": ("Jeder Akkord hat einen Namen", "Akkorde und Töne in Echtzeit erkennen für effizienteres Üben"),
    },
    "fr": {
        "single": ("Juste du premier coup", "Précision d'accordage avec écart en cents visible instantanément"),
        "multi": ("Six cordes, une seule passe", "Détection polyphonique pour accorder tout l'instrument d'un coup"),
        "library": ("Une app, tous les instruments", "54 instruments · 134 accordages prêts à l'emploi"),
        "custom": ("Votre accordage, vos règles", "Ajustez chaque corde en cents et enregistrez votre accordage"),
        "chord": ("Chaque accord a un nom", "Reconnaissance des accords et des notes en temps réel pour mieux pratiquer"),
    },
    "it": {
        "single": ("Intonato al primo colpo", "Precisione di accordatura con scostamento in cents sempre visibile"),
        "multi": ("Sei corde, una sola passata", "Rilevamento polifonico per accordare tutto lo strumento insieme"),
        "library": ("Un'app, tutti gli strumenti", "54 strumenti · 134 accordature pronte all'uso"),
        "custom": ("L'accordatura, come vuoi tu", "Regola ogni corda in cents e salva la tua accordatura"),
        "chord": ("Ogni accordo ha un nome", "Riconoscimento di accordi e note in tempo reale per esercitarti meglio"),
    },
}

DEVICES = {
    "iphone": {
        "size": (1320, 2868),
        "raw": "iphone",
        "brand_size": 30,
        "brand_y": 112,
        "head_size": 92,
        "head_y": 210,
        "sub_size": 38,
        "sub_gap": 46,
        "card_box": (140, 610, 1040, 2170),
        "radius": 54,
        "border": 3,
        "shadow": 60,
    },
    "ipad": {
        "size": (2752, 2064),
        "raw": "ipad",
        "brand_size": 36,
        "brand_y": 120,
        "head_size": 118,
        "head_y": 232,
        "sub_size": 46,
        "sub_gap": 52,
        "card_box": (296, 560, 2160, 1430),
        "radius": 46,
        "border": 3,
        "shadow": 60,
    },
    "mac": {
        "size": (2560, 1600),
        "raw": "mac",
        "brand_size": 30,
        "brand_y": 92,
        "head_size": 104,
        "head_y": 178,
        "sub_size": 40,
        "sub_gap": 44,
        "card_box": (350, 450, 1860, 1090),
        "radius": 30,
        "border": 3,
        "shadow": 48,
    },
}


def load_font(lang: str, size: int, headline: bool) -> ImageFont.FreeTypeFont:
    path, head_spec, body_spec = FONTS[lang]
    spec = head_spec if headline else body_spec
    if isinstance(spec, int):
        return ImageFont.truetype(path, size, index=spec)
    font = ImageFont.truetype(path, size)
    font.set_variation_by_name(spec)
    return font


def fit_font(lang: str, text: str, size: int, headline: bool,
             max_width: float) -> ImageFont.FreeTypeFont:
    while size > 24:
        font = load_font(lang, size, headline)
        if font.getlength(text) <= max_width:
            return font
        size -= 2
    return load_font(lang, size, headline)


def background(size: tuple[int, int]) -> Image.Image:
    w, h = size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    base = np.zeros((h, w, 3), dtype=np.float32)
    base[..., 0] = 5
    base[..., 1] = 7
    base[..., 2] = 12

    def glow(cx: float, cy: float, radius: float, color: tuple[int, int, int], strength: float):
        dx = (x - cx * w) / w
        dy = (y - cy * h) / h
        dist = np.sqrt(dx * dx + dy * dy * (h / w) ** 2)
        falloff = np.exp(-(dist * w / radius) ** 2)
        for channel in range(3):
            base[..., channel] += (color[channel] - base[..., channel]) * falloff * strength

    glow(0.20, 0.00, 1500, (36, 92, 220), 0.55)
    glow(0.86, 0.62, 1300, (24, 120, 96), 0.30)
    glow(0.55, 0.12, 900, (30, 70, 160), 0.18)

    # 轻微暗角，让中心更聚焦。
    dx = (x / w - 0.5) * 2
    dy = (y / h - 0.5) * 2
    vignette = np.clip(1.0 - 0.35 * (dx * dx + dy * dy) ** 0.7, 0.62, 1.0)
    base *= vignette[..., None]

    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")


def draw_tracked_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str,
                      font: ImageFont.FreeTypeFont, fill, tracking: int) -> int:
    x, y = xy
    for char in text:
        draw.text((x, y), char, font=font, fill=fill)
        x += font.getlength(char) + tracking
    return x


def rounded_card(raw: Image.Image, box: tuple[int, int, int, int],
                 radius: int, border: int, shadow: int) -> tuple[Image.Image, tuple[int, int]]:
    bx, by, bw, bh = box
    scale = min(bw / raw.width, bh / raw.height)
    tw, th = int(raw.width * scale), int(raw.height * scale)
    card = raw.resize((tw, th), Image.LANCZOS)

    mask = Image.new("L", (tw, th), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, tw - 1, th - 1), radius=radius, fill=255)

    x = bx + (bw - tw) // 2
    y = by
    return card, mask, (x, y), (tw, th)


def compose(device: str, lang: str, scene: str) -> Path:
    cfg = DEVICES[device]
    canvas = background(cfg["size"])
    draw = ImageDraw.Draw(canvas)

    head, sub = COPY[lang][scene]
    width = cfg["size"][0]

    brand_font = load_font(lang, cfg["brand_size"], headline=True)
    head_font = fit_font(lang, head, cfg["head_size"], True, width * 0.86)
    sub_font = fit_font(lang, sub, cfg["sub_size"], False, width * 0.86)

    brand = "PTUNER"
    tracking = max(6, cfg["brand_size"] // 3)
    brand_w = sum(brand_font.getlength(c) for c in brand) + tracking * (len(brand) - 1)
    draw_tracked_text(draw, (int((width - brand_w) / 2), cfg["brand_y"]),
                      brand, brand_font, (86, 140, 255), tracking)

    draw.text((width / 2, cfg["head_y"]), head, font=head_font,
              fill=(242, 246, 252), anchor="ma")

    line_y = cfg["head_y"] + head_font.size + 44
    line_w = int(head_font.size * 2.4)
    draw.rounded_rectangle((width / 2 - line_w / 2, line_y,
                            width / 2 + line_w / 2, line_y + 4),
                           radius=2, fill=(64, 138, 246))

    sub_y = line_y + cfg["sub_gap"]
    draw.text((width / 2, sub_y), sub, font=sub_font,
              fill=(148, 160, 178), anchor="ma")

    raw = Image.open(RAW / cfg["raw"] / lang / f"{scene}.png").convert("RGB")
    card, mask, pos, size = rounded_card(raw, cfg["card_box"], cfg["radius"],
                                         cfg["border"], cfg["shadow"])
    tw, th = size

    # 投影
    shadow_layer = Image.new("RGBA", cfg["size"], (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    sx, sy = pos
    sd.rounded_rectangle((sx, sy + 24, sx + tw, sy + th + 24),
                         radius=cfg["radius"], fill=(0, 0, 0, 150))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(cfg["shadow"]))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow_layer).convert("RGB")
    draw = ImageDraw.Draw(canvas)

    # 边框光晕
    draw.rounded_rectangle((sx - cfg["border"], sy - cfg["border"],
                            sx + tw + cfg["border"], sy + th + cfg["border"]),
                           radius=cfg["radius"] + cfg["border"],
                           fill=(30, 46, 70))
    canvas.paste(card, (sx, sy), mask)
    draw = ImageDraw.Draw(canvas)

    out = OUT / lang
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{device}-{scene}.png"
    canvas.save(path, quality=95)
    return path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", default="zh-Hans")
    parser.add_argument("--device", choices=list(DEVICES), default=None)
    args = parser.parse_args()

    devices = [args.device] if args.device else list(DEVICES)
    for device in devices:
        for scene in SCENES:
            print(compose(device, args.lang, scene))


if __name__ == "__main__":
    main()

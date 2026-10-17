#!/usr/bin/env python3
"""Generate the PTuner instrument icon set.

The output is intentionally kept outside the app target. Nothing in this
script touches Swift sources, Instruments.json or Assets.xcassets.

Canvas: 640 x 1024 (0.625 aspect, matching the existing glyph slot).
Style: flat vector, warm wood + cream + brass palette, no text, no outlines
heavier than 8 px, readable at 32 px.
"""

from pathlib import Path
import json

W, H = 640, 1024
ROOT = Path(__file__).resolve().parent.parent
SVG_DIR = ROOT / "svg"
PNG_DIR = ROOT / "png"
TILE_DIR = ROOT / "tiles"

INK = "#241A14"
CREAM = "#F3E4C6"
CREAM_DARK = "#D8BE92"
GOLD = "#D9B45E"
STEEL = "#C9D2DE"


def esc(value):
    return str(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def rrect(x, y, w, h, r, fill, stroke=None, sw=0, opacity=1.0, extra=""):
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" fill="{fill}"'
    if opacity != 1.0:
        s += f' opacity="{opacity}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    if extra:
        s += " " + extra
    return s + "/>"


def circle(cx, cy, r, fill, stroke=None, sw=0, opacity=1.0):
    s = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"'
    if opacity != 1.0:
        s += f' opacity="{opacity}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    return s + "/>"


def ellipse(cx, cy, rx, ry, fill, stroke=None, sw=0, opacity=1.0, rotate=None):
    s = f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"'
    if opacity != 1.0:
        s += f' opacity="{opacity}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    if rotate is not None:
        s += f' transform="rotate({rotate} {cx} {cy})"'
    return s + "/>"


def path(d, fill, stroke=None, sw=0, opacity=1.0, fill_rule=None, linecap="round", linejoin="round"):
    s = f'<path d="{d}" fill="{fill}" stroke-linecap="{linecap}" stroke-linejoin="{linejoin}"'
    if opacity != 1.0:
        s += f' opacity="{opacity}"'
    if fill_rule:
        s += f' fill-rule="{fill_rule}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    return s + "/>"


def line(x1, y1, x2, y2, stroke, width=4, opacity=1.0, dash=None):
    s = f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round"'
    if opacity != 1.0:
        s += f' opacity="{opacity}"'
    if dash:
        s += f' stroke-dasharray="{dash}"'
    return s + "/>"


def linear_grad(gid, c1, c2, x1=0, y1=0, x2=0, y2=1):
    return (
        f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
        f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/>'
        f"</linearGradient>"
    )


def radial_grad(gid, c1, c2, cx=0.5, cy=0.4, r=0.7):
    return (
        f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">'
        f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/>'
        f"</radialGradient>"
    )


def tuners(positions, color=GOLD, r=9):
    return "".join(circle(x, y, r, color, INK, 2) for x, y in positions)


def svg_doc(defs, body):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}">'
        f"<defs>{defs}</defs>{body}</svg>\n"
    )


def write(name, defs, body):
    (SVG_DIR / f"{name}.svg").write_text(svg_doc(defs, body), encoding="utf-8")


# ---------------------------------------------------------------------------
# Guitar family
# ---------------------------------------------------------------------------

def guitar():
    defs = (
        radial_grad("body", "#FBD39E", "#B65A20", cx=0.5, cy=0.46, r=0.72)
        + linear_grad("neck", "#B06A35", "#77401E")
        + linear_grad("head", "#5C3018", "#2E1508")
    )
    body_d = (
        "M320 470 C272 470 212 500 198 548 C188 600 238 636 253 662 "
        "C268 686 248 704 226 726 C178 768 140 844 186 906 "
        "C230 960 410 960 454 906 C500 844 462 768 414 726 "
        "C392 704 372 686 387 662 C402 636 452 600 442 548 "
        "C428 500 368 470 320 470 Z"
    )
    head_d = (
        "M282 60 C282 46 294 36 310 36 L330 36 C346 36 358 46 358 60 "
        "L352 146 C352 160 342 170 328 170 L312 170 C298 170 288 160 288 146 Z"
    )
    b = []
    # neck behind the body
    b.append(rrect(292, 158, 56, 370, 18, "url(#neck)", "#3E200F", 5))
    # body with binding
    b.append(path(body_d, "url(#body)", "#4A2410", 7))
    b.append(path(body_d, "none", "#F0D7A8", 4, 0.6))
    b.append(path("M232 828 C292 798 372 798 430 840", "none", "#7A3A18", 3, 0.16))
    b.append(path("M218 886 C290 856 388 856 444 898", "none", "#7A3A18", 3, 0.13))
    # fretboard over the body
    b.append(rrect(295, 158, 50, 426, 8, "#2A211C"))
    for y in range(190, 580, 30):
        b.append(line(297, y, 343, y, "#7B6B5E", 2, 0.7))
    for y in (260, 370, 480):
        b.append(circle(320, y, 4, CREAM, None, 0, 0.85))
    # headstock
    b.append(path(head_d, "url(#head)", "#2A1408", 5))
    b.append(rrect(292, 166, 56, 14, 4, CREAM, None, 0, 0.9))
    for y in (78, 108, 138):
        b.append(line(268, y, 290, y, GOLD, 4))
        b.append(line(372, y, 350, y, GOLD, 4))
        b.append(circle(261, y, 10, GOLD, INK, 2))
        b.append(circle(379, y, 10, GOLD, INK, 2))
    # soundhole and rosette
    b.append(circle(320, 644, 48, "#241B16", "#F0DDB4", 4))
    b.append(circle(320, 644, 58, "none", "#8D5227", 4, 0.9))
    b.append(circle(320, 644, 66, "none", GOLD, 2, 0.5))
    # bridge
    b.append(rrect(268, 830, 104, 24, 7, "#33241B"))
    b.append(rrect(276, 836, 88, 6, 3, CREAM, None, 0, 0.8))
    for i in range(6):
        b.append(circle(284 + i * 13.2, 864, 4, CREAM, "#5A3A1E", 1))
    # strings
    for i in range(6):
        x = 302 + i * 7.2
        b.append(line(x, 842, x, 176, "#F8EEDB", 2.2, 0.8))
    return defs, "".join(b)


def bass_guitar():
    defs = (
        radial_grad("body", "#8A76FF", "#2A1A72", cx=0.42, cy=0.35, r=0.8)
        + linear_grad("neck", "#C98B4E", "#8A5224")
        + linear_grad("head", "#2E2722", "#16120F")
    )
    body_d = (
        "M320 586 C300 586 282 592 268 602 "
        "C246 616 228 640 226 668 "
        "C224 690 234 708 248 722 "
        "C262 736 260 752 248 768 "
        "C220 800 208 848 228 886 "
        "C250 926 390 926 412 886 "
        "C432 848 420 800 392 768 "
        "C380 752 378 736 392 722 "
        "C406 708 416 690 414 668 "
        "C412 640 394 616 372 602 "
        "C358 592 340 586 320 586 Z"
    )
    head_d = (
        "M292 52 C292 38 304 28 320 28 L340 28 C356 28 368 38 368 52 "
        "L374 176 C374 190 364 200 348 200 L308 200 C292 200 282 190 282 176 Z"
    )
    b = []
    # neck behind the body
    b.append(rrect(296, 190, 48, 430, 14, "url(#neck)", "#2A1C12", 5))
    # body
    b.append(path(body_d, "url(#body)", "#1E1440", 7))
    b.append(path(body_d, "none", "#C9C0FF", 3, 0.3))
    # fretboard
    b.append(rrect(300, 206, 40, 414, 7, "#241D18"))
    for y in range(238, 606, 30):
        b.append(line(302, y, 338, y, "#7B6B5E", 2, 0.7))
    for y in (270, 390, 510):
        b.append(circle(320, y, 3, CREAM, None, 0, 0.8))
    # headstock
    b.append(path(head_d, "url(#head)", "#0F0C0A", 5))
    b.append(rrect(296, 192, 48, 12, 4, CREAM, None, 0, 0.85))
    for y in (72, 108, 144, 180):
        b.append(line(266, y, 290, y, GOLD, 4))
        b.append(circle(260, y, 10, GOLD, INK, 2))
    # pickups
    for y, w in ((728, 96), (796, 110)):
        b.append(rrect(320 - w / 2, y, w, 32, 6, "#18141C", CREAM, 3))
        for i in range(4):
            x = 320 - w / 2 + 16 + i * ((w - 32) / 3)
            b.append(line(x, y + 9, x, y + 23, CREAM, 3, 0.85))
    # bridge and saddles
    b.append(rrect(266, 862, 108, 26, 6, STEEL, "#5B6572", 3))
    for i in range(4):
        b.append(rrect(280 + i * 22, 866, 14, 18, 3, "#8E99A8"))
    # control knobs
    for cx, cy in ((414, 800), (442, 838), (410, 874)):
        b.append(circle(cx, cy, 13, GOLD, INK, 3))
        b.append(circle(cx, cy, 5, "#F4E7CC"))
    # strings
    for i in range(4):
        x = 304 + i * 10.5
        b.append(line(x, 880, x, 206, "#E8EDF5", 3, 0.85))
    return defs, "".join(b)


def ukulele():
    defs = (
        linear_grad("body", "#F9C06B", "#DE7F26")
        + linear_grad("neck", "#B06B33", "#76401D")
        + linear_grad("head", "#6B3A1C", "#3B1D0D")
    )
    d = (
        "M320 560 C275 560 250 590 248 630 C246 665 268 690 274 708 "
        "C280 726 266 740 252 756 C224 788 222 840 252 878 "
        "C285 918 355 918 388 878 C418 840 416 788 388 756 "
        "C374 740 360 726 366 708 C372 690 394 665 392 630 "
        "C390 590 365 560 320 560 Z"
    )
    b = [path(d, "url(#body)", "#7A3E14", 7)]
    b.append(path(d, "none", CREAM, 3, opacity=0.5))
    b.append(rrect(302, 268, 36, 330, 14, "url(#neck)", "#3E200F", 5))
    b.append(rrect(288, 168, 64, 128, 18, "url(#head)", "#2A1408", 5))
    b.append(tuners([(276, 200), (276, 236), (364, 200), (364, 236)], GOLD, 9))
    b.append(rrect(305, 290, 30, 400, 6, "#2C231D"))
    for y in range(318, 640, 32):
        b.append(line(306, y, 334, y, "#7B6A5C", 2, 0.7))
    b.append(circle(320, 690, 34, "#241B16", "#F0DDB4", 4))
    b.append(rrect(286, 812, 68, 18, 6, "#3A2618"))
    for i in range(4):
        x = 307 + i * 8.6
        b.append(line(x, 816, x, 180, "#F8EBD4", 3, 0.92))
    return defs, "".join(b)


def banjo():
    defs = (
        linear_grad("rim", "#96603A", "#5E341C")
        + linear_grad("head", "#F7EDD6", "#E4D1AB")
        + linear_grad("neck", "#7A4A28", "#4B2A15")
    )
    b = []
    # neck behind rim
    b.append(rrect(298, 226, 44, 520, 8, "url(#neck)", "#38200F", 5))
    b.append(rrect(303, 250, 34, 430, 4, "#2C1B10"))
    b.append(rrect(286, 108, 68, 142, 16, "#5A3218", "#2E180A", 5))
    b.append(tuners([(274, 142), (274, 182), (366, 142), (366, 182)], CREAM_DARK, 9))
    # pot
    b.append(circle(320, 782, 176, "url(#rim)", "#3A1E0D", 8))
    b.append(circle(320, 782, 158, STEEL, "#7A8797", 5))
    b.append(circle(320, 782, 146, "url(#head)", "#B79A6C", 4))
    # tension hooks
    import math
    for i in range(20):
        a = math.radians(i * 18)
        x = 320 + 167 * math.cos(a)
        y = 782 + 167 * math.sin(a)
        b.append(rrect(x - 4, y - 4, 8, 8, 2, STEEL, "#66707C", 2))
    # tailpiece + bridge
    b.append(path("M300 930 L340 930 L330 972 L310 972 Z", STEEL, "#5B6572", 3))
    b.append(rrect(282, 812, 76, 16, 4, "#3A2618"))
    # 5th peg
    b.append(circle(266, 352, 11, GOLD, INK, 3))
    # strings
    for i in range(5):
        x = 305 + i * 7.5
        b.append(line(x, 818, x, 226, "#F8EBD4", 3, 0.9))
    b.append(line(268, 356, 300, 560, "#F8EBD4", 3, 0.85))
    return defs, "".join(b)


def mandolin():
    defs = (
        linear_grad("body", "#E9A34C", "#B45A1E")
        + linear_grad("neck", "#8A4A22", "#552B12")
        + linear_grad("head", "#4C2711", "#2A1207")
    )
    body_d = (
        "M360 560 C330 560 300 572 276 596 "
        "C248 624 232 664 236 704 "
        "C240 750 268 792 304 822 "
        "C338 852 396 868 432 850 "
        "C470 832 484 788 470 748 "
        "C460 716 432 692 416 664 "
        "C402 640 400 606 390 584 "
        "C382 568 372 560 360 560 Z"
    )
    b = [path(body_d, "url(#body)", "#5C2A0E", 7)]
    b.append(path(body_d, "none", CREAM, 3, opacity=0.5))
    # scroll on the upper-left bout
    b.append(path("M244 612 C224 600 206 604 200 622 C194 642 208 658 228 656", "none", "#5C2A0E", 14))
    b.append(circle(214, 620, 38, "url(#body)", "#5C2A0E", 6))
    b.append(path("M214 620 C214 600 232 598 240 612 C247 626 236 640 224 634", "none", "#4A210A", 7))
    # points on the lower-right bout
    b.append(path("M462 744 L494 730 L474 776 Z", "url(#body)", "#5C2A0E", 5))
    b.append(path("M446 842 L476 856 L436 876 Z", "url(#body)", "#5C2A0E", 5))
    # neck + head
    b.append(rrect(342, 330, 34, 260, 9, "url(#neck)", "#3A1C0A", 5))
    b.append(rrect(326, 208, 68, 132, 16, "url(#head)", "#240E05", 5))
    b.append(tuners([(314, 238), (314, 272), (314, 306), (314, 340),
                     (406, 238), (406, 272), (406, 306), (406, 340)], CREAM_DARK, 8))
    # fretboard + frets
    b.append(rrect(344, 346, 30, 240, 5, "#2A1D14"))
    for y in range(374, 576, 26):
        b.append(line(345, y, 373, y, "#8A7868", 2, 0.75))
    # oval hole
    b.append(ellipse(344, 720, 32, 46, "#24180F", CREAM_DARK, 4))
    b.append(rrect(328, 800, 64, 14, 5, "#3A2414"))
    # 8 strings as 4 courses
    for i in range(4):
        x = 348 + i * 8
        b.append(line(x - 1.4, 804, x - 1.4, 240, "#F8EBD4", 2.0, 0.85))
        b.append(line(x + 1.4, 804, x + 1.4, 240, "#F8EBD4", 2.0, 0.85))
    return defs, "".join(b)


def resonator():
    defs = (
        linear_grad("body", "#B85A2A", "#6C2812")
        + linear_grad("plate", "#F0D488", "#A87526")
        + linear_grad("neck", "#7A4A28", "#472713")
    )
    d = (
        "M320 500 C260 500 224 545 221 610 C219 660 243 690 255 715 "
        "C267 740 251 762 231 786 C199 826 201 888 243 916 "
        "C287 946 353 946 397 916 C439 888 441 826 409 786 "
        "C389 762 373 740 385 715 C397 690 421 660 419 610 "
        "C416 545 380 500 320 500 Z"
    )
    b = [path(d, "url(#body)", "#3E1608", 7)]
    b.append(path(d, "none", "#E0A15C", 3, opacity=0.45))
    b.append(rrect(298, 120, 44, 440, 12, "url(#neck)", "#3E200F", 5))
    b.append(rrect(282, 44, 78, 126, 18, "#4A2510", "#281005", 5))
    b.append(tuners([(271, 80), (271, 118), (271, 156), (371, 80), (371, 118), (371, 156)], STEEL, 9))
    b.append(rrect(301, 150, 38, 430, 6, "#2A211D"))
    for y in range(184, 570, 32):
        b.append(line(302, y, 338, y, "#877667", 2, 0.7))
    # f-holes
    b.append(path("M262 654 C248 688 248 722 264 746 C270 728 270 678 268 660 Z", "#241610"))
    b.append(path("M378 654 C392 688 392 722 376 746 C370 728 370 678 372 660 Z", "#241610"))
    # coverplate
    b.append(circle(320, 790, 92, "url(#plate)", "#6E4911", 5))
    b.append(circle(320, 790, 78, "none", "#F7E7B8", 4, 0.7))
    b.append(circle(320, 790, 30, "#C9A24E", "#6E4911", 4))
    for i in range(6):
        import math
        a = math.radians(i * 60 + 30)
        b.append(circle(320 + 57 * math.cos(a), 790 + 57 * math.sin(a), 9, "#6E4911"))
    b.append(rrect(258, 744, 124, 12, 6, STEEL, "#59626E", 3))
    b.append(rrect(284, 878, 72, 16, 5, STEEL, "#59626E", 3))
    for i in range(6):
        x = 304 + i * 6.4
        b.append(line(x, 880, x, 158, "#F6E9D2", 3, 0.9))
    return defs, "".join(b)


# ---------------------------------------------------------------------------
# Bowed family
# ---------------------------------------------------------------------------

VIOLIN_BODY = (
    "M320 470 C284 470 256 492 246 528 "
    "C238 558 248 584 254 606 "
    "C260 628 262 644 256 660 "
    "C248 684 232 696 228 724 "
    "C222 762 234 802 250 830 "
    "C262 852 260 878 282 898 "
    "C302 918 338 918 358 898 "
    "C380 878 378 852 390 830 "
    "C406 802 418 762 412 724 "
    "C408 696 392 684 384 660 "
    "C378 644 380 628 386 606 "
    "C392 584 402 558 394 528 "
    "C384 492 356 470 320 470 Z"
)

DOUBLE_BASS_BODY = (
    "M320 448 C290 448 264 462 250 492 "
    "C239 517 240 543 247 566 "
    "C255 590 253 606 243 626 "
    "C226 656 212 696 216 740 "
    "C220 796 246 846 284 882 "
    "C308 905 346 905 370 882 "
    "C408 846 434 796 438 740 "
    "C442 696 428 656 411 626 "
    "C401 606 399 590 407 566 "
    "C414 543 415 517 404 492 "
    "C390 462 350 448 320 448 Z"
)


def bowed(name, *, body_color, body_edge, scale_x=1.0, body_top=470, body_bottom=918,
          neck_top=206, neck_width=28, endpin=False, dark_fingerboard=True,
          f_hole_color="#231812", chinrest=True):
    gid = f"{name}Body"
    defs = (
        linear_grad(gid, body_color[0], body_color[1])
        + linear_grad(f"{name}Neck", "#7A3D1E", "#3E1C0B")
    )
    b = [f'<g transform="translate(320 0) scale({scale_x} 1) translate(-320 0)">']
    # neck stops at the upper bout; the fingerboard runs a little further onto the body
    fingerboard_end = body_top + 138
    b.append(rrect(320 - neck_width / 2, neck_top, neck_width, fingerboard_end - neck_top,
                   10, f"url(#{name}Neck)", "#3A1B0A", 5))
    b.append(rrect(320 - neck_width / 2 + 2, neck_top + 16, neck_width - 4,
                   fingerboard_end - neck_top - 18, 5, "#241B17"))
    if name == "doubleBass":
        body_d = DOUBLE_BASS_BODY
    else:
        body_d = VIOLIN_BODY
    b.append(path(body_d, f"url(#{gid})", body_edge, 7))
    b.append(path(body_d, "none", "#F2D9B0", 3, opacity=0.42))
    # f holes: slim curved slots with round eyes
    for cx, mirror in ((290, 1), (350, -1)):
        b.append(path(
            f"M{cx} 700 C{cx - 11 * mirror} 728 {cx - 9 * mirror} 758 {cx - 1 * mirror} 786",
            "none", f_hole_color, 9))
        b.append(circle(cx, 700, 8, f_hole_color))
        b.append(circle(cx - 1 * mirror, 786, 10, f_hole_color))
    # bridge
    b.append(path("M294 782 L346 782 L340 808 L300 808 Z", "#E9D3A8", "#7A5A34", 3))
    # tailpiece
    b.append(path("M306 818 L334 818 L327 890 L313 890 Z", "#241B17", "#0E0A08", 3))
    if chinrest:
        b.append(ellipse(289, 892, 29, 20, "#1F1713", "#0D0907", 3, rotate=-18))
    # strings
    for i in range(4):
        x = 312 + i * 5.4
        b.append(line(x, 818, x, neck_top + 18, CREAM, 2.4, 0.92))
    # scroll
    b.append(rrect(320 - neck_width / 2 - 6, neck_top - 90, neck_width + 12, 100, 12, "#4A2511", "#2A1206", 5))
    b.append(circle(320, neck_top - 96, 26, f"url(#{name}Neck)", "#2A1206", 5))
    b.append(path(
        f"M320 {neck_top - 118} C338 {neck_top - 118} 344 {neck_top - 100} 334 {neck_top - 88} "
        f"C326 {neck_top - 78} 310 {neck_top - 82} 310 {neck_top - 94}",
        "none", "#2A1206", 6))
    b.append("</g>")
    if endpin:
        b.append(line(320, 908, 320, 996, STEEL, 8))
        b.append(circle(320, 998, 9, INK))
    return defs, "".join(b)


def violin():
    return bowed("violin", body_color=("#D06A35", "#923817"), body_edge="#5A210D",
                 scale_x=1.0, body_top=470, body_bottom=918, neck_top=206, neck_width=28)


def viola():
    return bowed("viola", body_color=("#B8552E", "#7D2A14"), body_edge="#4A1A0A",
                 scale_x=1.08, body_top=460, body_bottom=922, neck_top=198, neck_width=30)


def cello():
    defs, body = bowed("cello", body_color=("#D18B45", "#9A4E1F"), body_edge="#5A2A0E",
                       scale_x=1.18, body_top=450, body_bottom=908, neck_top=184,
                       neck_width=34, endpin=True)
    return defs, body


def double_bass():
    defs, body = bowed("doubleBass", body_color=("#A96635", "#5E2A12"), body_edge="#341306",
                       scale_x=1.28, body_top=448, body_bottom=900, neck_top=132,
                       neck_width=38, endpin=True, chinrest=False)
    return defs, body


# ---------------------------------------------------------------------------
# Chinese bowed
# ---------------------------------------------------------------------------

def erhu():
    defs = (
        linear_grad("wood", "#A85E30", "#6E3418")
        + linear_grad("skin", "#F6E6BF", "#DCC18C")
    )
    b = []
    b.append(rrect(306, 168, 28, 650, 10, "url(#wood)", "#3A1B0A", 5))
    # large pegs
    for y in (248, 320):
        b.append(rrect(250, y - 10, 140, 20, 9, "#4A2511", "#2A1206", 4))
        b.append(circle(244, y, 15, "#5E3017", INK, 3))
        b.append(circle(396, y, 15, "#5E3017", INK, 3))
    # soundbox
    hex_outer = "M320 742 L402 790 L402 890 L320 938 L238 890 L238 790 Z"
    hex_inner = "M320 764 L382 800 L382 880 L320 916 L258 880 L258 800 Z"
    b.append(path(hex_outer, "url(#wood)", "#3A1B0A", 7))
    b.append(path(hex_inner, "url(#skin)", "#8A5A33", 4))
    b.append(path("M320 794 L356 812 L356 868 L320 886 L284 868 L284 812 Z", "none", "#B98B52", 3, 0.7))
    # bridge + strings
    b.append(rrect(306, 866, 28, 10, 3, "#3A2618"))
    b.append(line(313, 330, 313, 918, CREAM, 3, 0.92))
    b.append(line(327, 330, 327, 918, CREAM, 3, 0.92))
    # bow
    b.append(path("M398 632 C510 716 512 884 398 968", "none", "#3A2A1E", 13))
    b.append(path("M402 648 C496 726 498 872 402 950", "none", CREAM, 5, 0.95))
    b.append(circle(398, 632, 8, "#2A1A10"))
    b.append(circle(398, 968, 8, "#2A1A10"))
    return defs, "".join(b)


def morin_khuur():
    defs = (
        linear_grad("wood", "#7A4A2A", "#45230F")
        + linear_grad("skin", "#F2E0B5", "#D5B87D")
        + linear_grad("gold", "#E8C87C", "#B4852F")
    )
    b = []
    b.append(rrect(304, 206, 32, 560, 10, "url(#wood)", "#2A1206", 5))
    # trapezoid body
    body_d = "M232 716 L408 716 L444 924 C444 942 430 952 410 952 L230 952 C210 952 196 942 196 924 Z"
    b.append(path(body_d, "url(#wood)", "#2A1206", 7))
    b.append(path("M250 738 L390 738 L418 906 C418 922 408 930 392 930 L248 930 C232 930 222 922 222 906 Z",
                  "url(#skin)", "#8A5A33", 4))
    b.append(circle(320, 838, 42, "none", "#B98B52", 4, 0.6))
    # horse head, side profile facing left
    head = (
        "M302 216 L302 174 C302 158 296 146 286 140 L250 132 "
        "C236 130 228 120 230 110 C232 100 242 96 252 100 L272 108 "
        "L276 84 L292 104 L304 80 L312 108 "
        "C322 116 326 130 324 144 L318 178 L318 216 Z"
    )
    b.append(path(head, "url(#gold)", "#4A2A0E", 5))
    b.append(circle(282, 122, 5, "#2A1206"))
    b.append(circle(240, 112, 3, "#2A1206"))
    b.append(path("M236 116 L266 122", "none", "#4A2A0E", 3, 0.8))
    b.append(path("M290 104 L288 118", "none", "#4A2A0E", 3, 0.7))
    for y in (150, 170, 190):
        b.append(path(f"M320 {y} C330 {y + 6} 332 {y + 14} 326 {y + 22}",
                      "none", "#4A2A0E", 4, 0.75))
    # pegs
    for y in (286, 350):
        b.append(rrect(252, y - 9, 136, 18, 8, "#5A3018", "#2A1206", 4))
        b.append(circle(246, y, 13, "#6E3A1C", INK, 3))
        b.append(circle(394, y, 13, "#6E3A1C", INK, 3))
    # strings + bow
    b.append(line(313, 360, 313, 924, CREAM, 3, 0.92))
    b.append(line(327, 360, 327, 924, CREAM, 3, 0.92))
    b.append(path("M400 640 C510 724 512 884 400 966", "none", "#2E1E12", 13))
    b.append(path("M404 656 C496 734 498 874 404 948", "none", CREAM, 5, 0.95))
    return defs, "".join(b)


# ---------------------------------------------------------------------------
# Chinese plucked
# ---------------------------------------------------------------------------

def zither_strings(b, left, right, y1, y2, count, width=2.4):
    for i in range(count):
        x = left + (right - left) * i / (count - 1)
        b.append(line(x, y1, x, y2, CREAM, width, 0.9))


def A_bridge(b, x, y, w=5.0, h=18.0, body="#F6EAD2", edge="#8A5A33"):
    b.append(path(
        f"M{x - w} {y + h * 0.4} L{x} {y - h * 0.6} L{x + w} {y + h * 0.4} Z",
        body, edge, 1.5))
    b.append(line(x - w, y + h * 0.4, x + w, y + h * 0.4, "#6E3A1E", 2, 0.65))


def guzheng():
    defs = (
        linear_grad("body", "#EFBE76", "#B5672A")
        + linear_grad("top", "#F7DCA6", "#DCA85E")
    )
    body_d = ("M254 98 C216 98 196 128 196 172 L196 860 C196 906 220 936 262 936 "
              "L378 936 C420 936 444 906 444 860 L444 172 C444 128 424 98 386 98 Z")
    b = [path(body_d, "url(#body)", "#5E2A0E", 7)]
    b.append(path("M216 130 C270 148 370 148 424 130 L424 98 L216 98 Z", "#7E3D16", None, 0, 0.95))
    b.append(path("M216 904 C270 886 370 886 424 904 L424 936 L216 936 Z", "#7E3D16", None, 0, 0.95))
    b.append(rrect(216, 130, 208, 774, 26, "url(#top)", "#9A5A26", 3))
    # carved end decoration
    for x in (244, 320, 396):
        b.append(circle(x, 114, 11, "none", GOLD, 3, 0.85))
        b.append(circle(x, 920, 11, "none", GOLD, 3, 0.85))
    b.append(path("M226 150 C270 166 370 166 414 150", "none", "#F2C984", 3, 0.65))
    b.append(path("M226 886 C270 870 370 870 414 886", "none", "#F2C984", 3, 0.65))
    zither_strings(b, 232, 408, 158, 878, 21)
    # 21 movable bridges on a clear diagonal
    for i in range(21):
        x = 232 + 176 * i / 20
        y = 704 - 8 * i
        A_bridge(b, x, y, w=4.2, h=16)
    return defs, "".join(b)


def guqin():
    gid = "guqinBody"
    defs = linear_grad(gid, "#3A3733", "#161514")
    body_d = (
        "M250 96 L390 96 C406 96 417 108 415 124 "
        "L404 900 C402 924 386 936 362 936 "
        "L278 936 C254 936 238 924 236 900 "
        "L225 124 C223 108 234 96 250 96 Z"
    )
    b = [path(body_d, f"url(#{gid})", "#0C0B0A", 7)]
    b.append(path(
        "M252 120 L386 120 C396 120 402 128 401 138 "
        "L391 894 C390 910 380 918 362 918 L278 918 "
        "C260 918 250 910 249 894 L239 138 C238 128 244 120 252 120 Z",
        "none", "#8A7A5E", 3, 0.5))
    # 7 strings
    for i in range(7):
        x = 268 + i * 14.8
        b.append(line(x, 142, x, 894, CREAM, 2.6, 0.9))
    # 13 hui studs
    for i in range(13):
        y = 152 + i * 60
        b.append(circle(386, y, 6, "#DCC18C", "#4A3A22", 2))
    # two ivory feet
    for x in (292, 348):
        b.append(circle(x, 918, 8, CREAM_DARK, "#4A3A22", 2))
    # red tassel cord
    b.append(line(320, 934, 320, 968, "#B23A2E", 4))
    b.append(circle(320, 976, 8, "#C4493A"))
    b.append(line(313, 984, 306, 1002, "#B23A2E", 4))
    b.append(line(327, 984, 334, 1002, "#B23A2E", 4))
    return defs, "".join(b)


def pipa():
    defs = (
        linear_grad("body", "#C86A3A", "#7E2E16")
        + linear_grad("face", "#F2D8A6", "#D8AE6C")
        + linear_grad("head", "#6E3418", "#38180A")
    )
    body_d = (
        "M320 552 C278 552 248 586 242 638 "
        "C236 696 222 756 210 808 "
        "C196 866 234 924 300 940 "
        "C366 956 430 922 446 866 "
        "C462 812 430 776 402 744 "
        "C378 716 372 660 372 612 "
        "C372 574 350 552 320 552 Z"
    )
    face_d = (
        "M320 574 C292 574 268 602 262 644 "
        "C256 698 244 754 234 800 "
        "C222 848 254 896 306 910 "
        "C362 924 412 896 424 856 "
        "C436 818 408 788 384 758 "
        "C362 730 354 668 354 624 "
        "C354 598 344 574 320 574 Z"
    )
    b = [path(body_d, "url(#body)", "#3A1708", 7)]
    b.append(path(face_d, "url(#face)", "#9A6A3A", 3, 0.97))
    # neck
    b.append(rrect(300, 300, 40, 286, 10, "url(#body)", "#3A1708", 5))
    # bent pegbox
    b.append(path("M300 306 L300 222 L278 178 L246 190 L272 248 L282 306 Z", "url(#head)", "#2A1006", 5))
    b.append(rrect(292, 216, 12, 108, 5, "#2A1006", None, 0, 0.7))
    for i in range(4):
        b.append(circle(262 if i % 2 == 0 else 354, 198 + i * 30, 13, "#5E3017", INK, 3))
    # frets
    for y in range(336, 570, 28):
        b.append(line(302, y, 338, y, "#6B4A2A", 3, 0.85))
    # bridge
    b.append(rrect(282, 846, 76, 16, 5, "#3A2414"))
    b.append(line(288, 850, 352, 850, CREAM, 2, 0.6))
    # strings
    for i in range(4):
        x = 306 + i * 9.4
        b.append(line(x, 882, x, 240, CREAM, 3, 0.92))
    return defs, "".join(b)


def yangqin():
    defs = (
        linear_grad("body", "#E7BB78", "#C08744")
        + linear_grad("top", "#F4DBA8", "#DDB673")
    )
    d = ("M164 286 L476 286 C508 286 524 308 518 340 L456 838 C451 866 430 880 402 880 "
         "L238 880 C210 880 189 866 184 838 L122 340 C116 308 132 286 164 286 Z")
    b = [path(d, "url(#body)", "#6E4418", 7)]
    b.append(path("M182 314 L458 314 C480 314 490 328 486 348 L430 812 C427 832 414 842 394 842 "
                  "L246 842 C226 842 213 832 210 812 L154 348 C150 328 160 314 182 314 Z",
                  "url(#top)", "#9A6A32", 3))
    # strings
    for i in range(22):
        t = i / 21
        top_x = 196 + t * 248
        bot_x = 230 + t * 148
        b.append(line(top_x, 330, bot_x, 828, CREAM, 2.0, 0.86))
    # bridges with metal pins
    for y, x1, x2 in ((500, 186, 442), (690, 206, 412)):
        b.append(line(x1, y, x2, y + 26, "#6B4A2A", 13))
        b.append(line(x1, y - 3, x2, y + 23, "#D9B45E", 4, 0.85))
        for i in range(16):
            t = i / 15
            px = x1 + (x2 - x1) * t
            py = y + 26 * t
            b.append(line(px, py - 9, px, py + 9, "#F4E7CC", 3, 0.9))
    # mallets
    b.append(line(180, 930, 420, 966, "#8A5A2B", 9))
    b.append(line(460, 930, 250, 980, "#8A5A2B", 9))
    b.append(circle(168, 926, 20, "#F0DDB4", "#8A5A2B", 4))
    b.append(circle(472, 926, 20, "#F0DDB4", "#8A5A2B", 4))
    return defs, "".join(b)


def ruan():
    defs = (
        linear_grad("body", "#B25A34", "#6E2C14")
        + linear_grad("face", "#EBC28A", "#CFA066")
    )
    b = [circle(320, 782, 158, "url(#body)", "#3A1708", 7)]
    b.append(circle(320, 782, 140, "url(#face)", "#8A5A2A", 4))
    b.append(circle(320, 782, 40, "#2A1A0E", "#8A5A2A", 4))
    b.append(circle(320, 782, 52, "none", "#B98B52", 3, 0.7))
    # neck
    b.append(rrect(302, 316, 36, 360, 10, "url(#body)", "#3A1708", 5))
    b.append(rrect(288, 206, 64, 134, 16, "#7E3418", "#3A1708", 5))
    b.append(tuners([(276, 238), (276, 274), (364, 238), (364, 274)], CREAM_DARK, 9))
    b.append(rrect(304, 336, 32, 330, 5, "#2A1D14"))
    for y in range(364, 650, 28):
        b.append(line(305, y, 335, y, "#8A7868", 2, 0.75))
    # strings + bridge
    b.append(rrect(286, 858, 68, 15, 5, "#3A2414"))
    for i in range(4):
        x = 308 + i * 8
        b.append(line(x, 862, x, 222, CREAM, 3, 0.92))
    return defs, "".join(b)


# ---------------------------------------------------------------------------
# Middle East / Europe
# ---------------------------------------------------------------------------

def oud():
    defs = (
        linear_grad("body", "#E0A65B", "#A85C27")
        + linear_grad("face", "#F2D49A", "#D3A45F")
        + linear_grad("head", "#5E3018", "#2A1206")
    )
    body_d = (
        "M320 618 C258 618 218 670 208 742 C198 824 236 902 302 938 "
        "C372 976 448 930 470 858 C492 784 458 714 416 676 "
        "C388 650 380 620 380 610 C380 602 350 618 320 618 Z"
    )
    b = [path(body_d, "url(#body)", "#3A1708", 7)]
    b.append(path("M320 640 C270 640 240 682 232 744 C224 812 254 878 306 908 "
                  "C364 940 424 902 442 846 C458 790 432 734 398 700 "
                  "C376 678 370 650 370 638 C370 632 348 640 320 640 Z",
                  "url(#face)", "#9A6A3A", 3, 0.9))
    # stripes
    for off in (-34, 0, 34):
        b.append(path(f"M250 {790 + off} C300 {760 + off} 380 {760 + off} 430 {790 + off}",
                      "none", "#B97A3B", 7, 0.28))
    # rosette
    b.append(circle(330, 786, 58, "none", "#8A4A26", 5))
    b.append(circle(330, 786, 44, "none", CREAM_DARK, 4, 0.8))
    b.append(circle(330, 786, 26, "#7E3A1A", CREAM_DARK, 3))
    for i in range(8):
        import math
        a = math.radians(i * 45)
        b.append(circle(330 + 51 * math.cos(a), 786 + 51 * math.sin(a), 5, "#F4E7CC", None, 0, 0.8))
    # neck
    b.append(rrect(302, 292, 36, 350, 10, "#8A4A26", "#3A1708", 5))
    # bent pegbox
    b.append(path("M302 292 L302 196 L272 142 L244 156 L266 214 L286 300 Z", "url(#head)", "#2A1206", 5))
    for i in range(6):
        b.append(circle(258 if i % 2 == 0 else 344, 170 + i * 20, 10, "#E8C87C", INK, 2))
    b.append(rrect(304, 312, 32, 320, 5, "#3A2414"))
    for y in range(340, 600, 34):
        b.append(line(305, y, 335, y, "#8A7868", 2, 0.7))
    # strings + bridge
    b.append(rrect(286, 866, 70, 15, 5, "#3A2414"))
    for i in range(6):
        x = 306 + i * 6
        b.append(line(x, 870, x, 210, CREAM, 2.6, 0.9))
    return defs, "".join(b)


def balalaika():
    defs = (
        linear_grad("body", "#E06A38", "#A83418")
        + linear_grad("neck", "#9A5A2E", "#5A2A12")
    )
    body_d = ("M320 636 C300 646 282 676 266 714 L206 894 C190 932 212 950 248 950 "
              "L392 950 C428 950 450 932 434 894 L374 714 C358 676 340 646 320 636 Z")
    b = [path(body_d, "url(#body)", "#4A1608", 7)]
    b.append(path(body_d, "none", "#F2B07A", 3, opacity=0.4))
    b.append(circle(320, 760, 30, "#2A160C", CREAM_DARK, 4))
    b.append(rrect(302, 300, 36, 380, 10, "url(#neck)", "#3A1608", 5))
    b.append(rrect(286, 190, 68, 134, 16, "#5A2A12", "#2A1006", 5))
    b.append(tuners([(274, 222), (274, 258), (274, 294)], CREAM_DARK, 9))
    b.append(rrect(304, 320, 32, 330, 5, "#2A1D14"))
    for y in range(348, 640, 30):
        b.append(line(305, y, 335, y, "#8A7868", 2, 0.75))
    b.append(rrect(288, 884, 64, 15, 5, "#3A2414"))
    for i in range(3):
        x = 310 + i * 10
        b.append(line(x, 888, x, 210, CREAM, 3, 0.92))
    return defs, "".join(b)


# ---------------------------------------------------------------------------
# South / East Asia, Africa
# ---------------------------------------------------------------------------

def sitar():
    defs = (
        linear_grad("gourd", "#D97A38", "#8E3A18")
        + radial_grad("body", "#E08A46", "#8A3616", cx=0.5, cy=0.35, r=0.8)
        + linear_grad("neck", "#4A3428", "#241812")
        + linear_grad("gold", "#E8C87C", "#B4852F")
    )
    body_d = (
        "M320 586 C286 586 260 608 256 642 "
        "C252 674 268 700 292 718 "
        "C246 742 216 786 220 836 "
        "C225 892 270 940 320 946 "
        "C370 940 415 892 420 836 "
        "C424 786 394 742 348 718 "
        "C372 700 388 674 384 642 "
        "C380 608 354 586 320 586 Z"
    )
    b = []
    # small gourd behind the pegbox
    b.append(circle(320, 62, 34, "url(#gourd)", "#3A1406", 5))
    # neck
    b.append(rrect(304, 140, 32, 600, 8, "url(#neck)", "#1A1008", 5))
    # gourd body
    b.append(path(body_d, "url(#body)", "#3A1406", 7))
    b.append(path(body_d, "none", "#F2B07A", 3, 0.3))
    # decorative inlay on the lower lobe
    for rx, ry in ((74, 66), (112, 100)):
        b.append(ellipse(320, 836, rx, ry, "none", "#7E2E10", 3, 0.35))
    b.append(ellipse(320, 836, 30, 26, "none", "#F2B07A", 3, 0.5))
    # pegbox
    b.append(rrect(290, 62, 60, 128, 15, "#3A2418", "#1A1008", 5))
    for i in range(6):
        b.append(circle(278 if i % 2 == 0 else 362, 88 + i * 18, 8, "url(#gold)", INK, 2))
    # sympathetic pegs along the neck
    for i in range(11):
        b.append(circle(294 if i % 2 == 0 else 346, 226 + i * 34, 6, "url(#gold)", INK, 2))
    # curved frets
    for i in range(10):
        y = 256 + i * 40
        b.append(path(f"M306 {y} C315 {y - 9} 325 {y - 9} 334 {y}", "none", "#C9D2DE", 6))
    # bridge
    b.append(rrect(276, 840, 88, 18, 6, "#3A2418", "#1A1008", 3))
    b.append(path("M285 840 C305 830 335 830 355 840", "none", CREAM, 4))
    # strings
    for i in range(7):
        x = 308 + i * 4
        b.append(line(x, 848, x, 150, CREAM, 2.2, 0.9))
    # sympathetic strings
    for i in range(3):
        x = 318 + i * 3
        b.append(line(x, 700, x, 190, CREAM, 1.2, 0.55))
    return defs, "".join(b)


def shamisen():
    defs = (
        linear_grad("skin", "#F7ECD5", "#DFCBA6")
        + linear_grad("wood", "#7A4A2A", "#3E1E0C")
    )
    b = []
    b.append(rrect(306, 178, 28, 540, 8, "url(#wood)", "#2A1206", 5))
    # body
    b.append(rrect(190, 686, 260, 250, 30, "#6E3A1C", "#2A1206", 7))
    b.append(rrect(204, 700, 232, 222, 22, "url(#skin)", "#8A5A33", 4))
    # corner guards
    for x, y, sx, sy in ((204, 700, 1, 1), (436, 700, -1, 1), (204, 922, 1, -1), (436, 922, -1, -1)):
        b.append(path(f"M{x} {y} L{x + 34 * sx} {y} L{x} {y + 34 * sy} Z", "#3A2418", None, 0, 0.9))
    # headstock + pegs
    b.append(rrect(292, 104, 56, 130, 14, "url(#wood)", "#2A1206", 5))
    for cx, cy in ((276, 142), (364, 142), (364, 194)):
        b.append(ellipse(cx, cy, 12, 19, "#5E3018", INK, 3, rotate=90))
    # skin seam and bottom rim
    b.append(line(212, 806, 428, 806, "#C9AE82", 3, 0.45))
    b.append(rrect(194, 928, 252, 12, 6, "#3A2418", None, 0, 0.9))
    # bridge + strings
    b.append(rrect(288, 852, 64, 14, 5, "#3A2414"))
    for i in range(3):
        x = 312 + i * 8
        b.append(line(x, 856, x, 130, CREAM, 3, 0.92))
    return defs, "".join(b)


def koto():
    defs = (
        linear_grad("body", "#E8C57D", "#C28A45")
        + linear_grad("top", "#F6E0AF", "#E0BC78")
    )
    body_d = ("M236 98 C220 98 212 112 212 132 L212 892 C212 920 228 938 252 938 "
              "L388 938 C412 938 428 920 428 892 L428 132 C428 112 420 98 404 98 Z")
    b = [path(body_d, "url(#body)", "#6E4418", 7)]
    # raised dark side rails
    b.append(rrect(212, 108, 17, 820, 9, "#7E4A1C", "#4A2A0E", 3))
    b.append(rrect(411, 108, 17, 820, 9, "#7E4A1C", "#4A2A0E", 3))
    b.append(rrect(231, 118, 178, 788, 24, "url(#top)", "#9A6A32", 3))
    # rounded end caps
    b.append(rrect(212, 98, 216, 44, 20, "#7E4A1C", "#4A2A0E", 4))
    b.append(rrect(212, 882, 216, 44, 20, "#7E4A1C", "#4A2A0E", 4))
    b.append(path("M240 120 L400 120", "none", GOLD, 3, 0.8))
    b.append(path("M240 904 L400 904", "none", GOLD, 3, 0.8))
    zither_strings(b, 246, 394, 142, 882, 13, 2.6)
    # 13 ivory ji bridges with dark caps, in a shallow arc
    for i in range(13):
        x = 246 + 148 * i / 12
        y = 692 + (i % 4) * 9
        b.append(path(
            f"M{x - 9} {y + 24} L{x - 6} {y - 12} L{x + 6} {y - 12} L{x + 9} {y + 24} Z",
            "#F9F1DE", "#5A3218", 2))
        b.append(line(x - 6, y - 8, x + 6, y - 8, "#2A1608", 4))
    return defs, "".join(b)


def gayageum():
    defs = (
        linear_grad("body", "#A25434", "#5E2412")
        + linear_grad("top", "#D9905E", "#A8562E")
    )
    body_d = ("M262 120 C222 120 206 158 206 210 L206 812 C206 874 230 906 272 918 "
              "L368 918 C410 906 434 874 434 812 L434 210 C434 158 418 120 378 120 Z")
    b = [path(body_d, "url(#body)", "#2A0E05", 7)]
    b.append(path("M278 144 C246 144 232 174 232 218 L232 802 C232 850 252 876 286 886 "
                  "L354 886 C388 876 408 850 408 802 L408 218 C408 174 394 144 362 144 Z",
                  "url(#top)", "#7E3A1E", 3, 0.92))
    # 12 strings
    zither_strings(b, 242, 398, 154, 876, 12, 2.6)
    # 12 anjok bridges on a clear diagonal
    for i in range(12):
        x = 242 + 156 * i / 11
        y = 730 - 12 * i
        A_bridge(b, x, y, w=6.4, h=20, body="#F4E2C0", edge="#6E2E18")
    # decorative cream bands
    b.append(path("M232 218 C280 236 360 236 408 218 L408 182 C360 200 280 200 232 182 Z",
                  "#EFC08A", None, 0, 0.7))
    b.append(path("M232 812 C280 830 360 830 408 812 L408 846 C360 864 280 864 232 846 Z",
                  "#EFC08A", None, 0, 0.6))
    b.append(path("M232 182 C280 200 360 200 408 182", "none", GOLD, 3, 0.7))
    b.append(path("M232 846 C280 864 360 864 408 846", "none", GOLD, 3, 0.7))
    return defs, "".join(b)


def kora():
    defs = (
        radial_grad("gourd", "#E8A455", "#A85A22")
        + linear_grad("neck", "#A86A34", "#5E3418")
    )
    b = []
    # gourd
    b.append(circle(320, 812, 176, "url(#gourd)", "#3A1406", 7))
    b.append(circle(320, 812, 156, "none", "#F2C184", 3, 0.45))
    # diamond pattern
    for row in range(3):
        for col in range(3):
            cx = 250 + col * 70
            cy = 742 + row * 70
            b.append(path(f"M{cx} {cy - 22} L{cx + 22} {cy} L{cx} {cy + 22} L{cx - 22} {cy} Z",
                          "none", "#7E3A14", 4, 0.35))
    # neck
    b.append(rrect(304, 112, 32, 620, 12, "url(#neck)", "#2A1206", 5))
    # strings fanning down the neck to the bridge
    for i in range(21):
        y = 168 + i * 24
        b.append(line(310 + (i % 3) * 6, y, 320, 800, CREAM, 1.6, 0.78))
    # bridge
    b.append(rrect(280, 772, 80, 62, 8, "#3A2210", "#1A0E05", 4))
    for i in range(5):
        b.append(line(288 + i * 15, 778, 288 + i * 15, 828, CREAM, 2, 0.55))
    # tuning pegs
    for i in range(10):
        b.append(circle(294 if i % 2 == 0 else 346, 150 + i * 48, 7, "#5E3018", INK, 2))
    return defs, "".join(b)


# ---------------------------------------------------------------------------
# Remaining catalog instruments
# ---------------------------------------------------------------------------

def nyckelharpa():
    defs = (
        linear_grad("body", "#D08A48", "#8A441C")
        + linear_grad("neck", "#5A3A24", "#2E1A0E")
        + linear_grad("key", "#E9D3A8", "#B99A66")
    )
    b = []
    # violin-like body
    b.append(path(VIOLIN_BODY, "url(#body)", "#4A2210", 7))
    b.append(path(VIOLIN_BODY, "none", "#F2D9B0", 3, 0.42))
    # neck
    b.append(rrect(304, 200, 32, 420, 10, "url(#neck)", "#2A1408", 5))
    # keybox with keys sticking out to the left
    b.append(rrect(268, 286, 46, 300, 8, "url(#neck)", "#2A1408", 5))
    for i in range(8):
        y = 300 + i * 35
        b.append(rrect(236, y, 40, 14, 5, "url(#key)", "#6E4A20", 2))
        b.append(circle(240, y + 7, 3, "#5A3A18"))
    # pegbox
    b.append(rrect(296, 96, 48, 118, 14, "url(#neck)", "#2A1408", 5))
    for y in (120, 152, 184):
        b.append(circle(286, y, 9, GOLD, INK, 2))
        b.append(circle(354, y, 9, GOLD, INK, 2))
    # bridge and tailpiece
    b.append(path("M292 780 L348 780 L342 806 L298 806 Z", "#E9D3A8", "#7A5A34", 3))
    b.append(path("M306 816 L334 816 L327 890 L313 890 Z", "#241B17", "#0E0A08", 3))
    # 4 melody strings and 3 sympathetic strings
    for i in range(4):
        x = 310 + i * 6.6
        b.append(line(x, 818, x, 110, CREAM, 2.2, 0.9))
    for i in range(3):
        x = 304 + i * 12
        b.append(line(x, 790, x, 130, CREAM, 1.2, 0.45))
    return defs, "".join(b)


def ektara():
    defs = (
        radial_grad("gourd", "#E8A455", "#98501E", cx=0.4, cy=0.35, r=0.8)
        + linear_grad("bamboo", "#E2C084", "#A8793C")
    )
    b = []
    # split bamboo neck
    b.append(path("M306 214 L300 128 L314 126 L323 202 L326 202 L335 126 L349 128 L334 214 Z",
                  "url(#bamboo)", "#6E4A1E", 5))
    b.append(rrect(304, 200, 32, 580, 10, "url(#bamboo)", "#6E4A1E", 5))
    # tuning bar
    b.append(line(286, 126, 356, 126, "#5A3A18", 7))
    b.append(circle(282, 126, 10, GOLD, INK, 2))
    b.append(circle(360, 126, 10, GOLD, INK, 2))
    # gourd resonator
    b.append(circle(320, 820, 118, "url(#gourd)", "#4A2208", 7))
    for rx in (30, 62, 94):
        b.append(ellipse(320, 820, rx, 114, "none", "#7E3A12", 3, 0.4))
    b.append(circle(320, 820, 112, "none", "#F2C184", 3, 0.35))
    # single string
    b.append(line(320, 134, 320, 820, CREAM, 3, 0.9))
    b.append(circle(320, 820, 8, "#3A2210"))
    # tassel
    b.append(line(320, 936, 320, 962, "#B23A2E", 4))
    b.append(circle(320, 970, 7, "#C4493A"))
    return defs, "".join(b)


def dotara():
    defs = (
        linear_grad("body", "#C8783A", "#7E3A14")
        + linear_grad("face", "#F0D6A2", "#CFA466")
        + linear_grad("neck", "#8A5224", "#4E2A10")
    )
    body_d = (
        "M320 616 C280 616 250 646 244 692 "
        "C238 744 226 798 226 838 "
        "C226 890 268 926 320 926 "
        "C372 926 414 890 414 838 "
        "C414 798 402 744 396 692 "
        "C390 646 360 616 320 616 Z"
    )
    face_d = (
        "M320 638 C290 638 268 662 263 700 "
        "C258 748 246 798 246 836 "
        "C246 878 278 906 320 906 "
        "C362 906 394 878 394 836 "
        "C394 798 382 748 377 700 "
        "C372 662 350 638 320 638 Z"
    )
    b = [path(body_d, "url(#body)", "#3A1708", 7)]
    b.append(path(face_d, "url(#face)", "#9A6A3A", 3, 0.97))
    # neck and pegbox
    b.append(rrect(302, 330, 36, 310, 9, "url(#neck)", "#2A1206", 5))
    b.append(rrect(290, 222, 60, 116, 14, "url(#neck)", "#2A1206", 5))
    b.append(tuners([(280, 252), (280, 294), (360, 252), (360, 294)], CREAM_DARK, 8))
    # frets
    for y in range(362, 606, 28):
        b.append(line(303, y, 337, y, "#8A7868", 2, 0.75))
    # rosette
    b.append(circle(320, 780, 30, "#2A1A0E", CREAM_DARK, 4))
    b.append(circle(320, 780, 38, "none", "#B98B52", 3, 0.7))
    # bridge
    b.append(rrect(288, 842, 64, 14, 5, "#3A2414"))
    # 4 strings
    for i in range(4):
        x = 308 + i * 8
        b.append(line(x, 846, x, 250, CREAM, 2.6, 0.9))
    return defs, "".join(b)


def sarangi():
    defs = (
        linear_grad("body", "#B8642E", "#6E2A10")
        + linear_grad("face", "#EBCB96", "#C79A5E")
        + linear_grad("neck", "#6E3A1C", "#341708")
    )
    body_d = (
        "M320 604 C284 604 258 626 252 662 "
        "C246 694 258 714 268 730 "
        "C278 746 272 762 262 778 "
        "C242 810 238 858 262 890 "
        "C288 926 352 926 378 890 "
        "C402 858 398 810 378 778 "
        "C368 762 362 746 372 730 "
        "C382 714 394 694 388 662 "
        "C382 626 356 604 320 604 Z"
    )
    face_d = (
        "M320 626 C292 626 272 644 267 672 "
        "C262 698 272 716 281 730 "
        "C290 744 286 756 278 770 "
        "C262 796 258 840 278 868 "
        "C298 896 342 896 362 868 "
        "C382 840 378 796 362 770 "
        "C354 756 350 744 359 730 "
        "C368 716 378 698 373 672 "
        "C368 644 348 626 320 626 Z"
    )
    b = [path(body_d, "url(#body)", "#3A1708", 7)]
    b.append(path(face_d, "url(#face)", "#9A6A3A", 3, 0.95))
    # wide neck and pegbox
    b.append(rrect(296, 300, 48, 350, 9, "url(#neck)", "#2A1206", 5))
    b.append(rrect(282, 176, 76, 140, 16, "url(#neck)", "#2A1206", 5))
    b.append(tuners([(270, 208), (270, 250), (270, 292), (370, 226), (370, 268)], CREAM_DARK, 9))
    # sympathetic pegs down the neck
    for i in range(10):
        y = 330 + i * 30
        b.append(circle(292, y, 5, GOLD, INK, 2))
        b.append(line(292, y, 300, y, GOLD, 2, 0.8))
    # wide bridge
    b.append(rrect(276, 846, 88, 14, 5, "#3A2414"))
    b.append(line(282, 850, 358, 850, CREAM, 2, 0.55))
    # 3 main strings and sympathetic strings
    for i in range(3):
        x = 310 + i * 10
        b.append(line(x, 852, x, 200, CREAM, 3, 0.9))
    for i in range(7):
        x = 302 + i * 6
        b.append(line(x, 848, x, 214, CREAM, 1.2, 0.45))
    return defs, "".join(b)


def kantele():
    defs = (
        linear_grad("body", "#E9C98C", "#B9823F")
        + linear_grad("top", "#F6E3B7", "#DDBA7C")
    )
    body_d = (
        "M266 146 C300 124 340 124 374 146 "
        "L420 872 C424 898 408 916 382 916 "
        "L258 916 C232 916 216 898 220 872 Z"
    )
    top_d = (
        "M282 168 C308 152 332 152 358 168 "
        "L398 866 C400 882 390 894 372 894 "
        "L268 894 C250 894 240 882 242 866 Z"
    )
    b = [path(body_d, "url(#body)", "#6E4418", 7)]
    b.append(path(top_d, "url(#top)", "#9A6A32", 3))
    # pin rail
    b.append(rrect(274, 146, 92, 26, 12, "#6E4418", "#3E2208", 4))
    # 11 strings fanning out
    for i in range(11):
        t = i / 10
        b.append(line(286 + t * 68, 172, 250 + t * 140, 870, CREAM, 2.2, 0.85))
    # bridge and soundhole
    b.append(rrect(236, 862, 168, 18, 8, "#6E4418", "#3E2208", 3))
    b.append(circle(320, 720, 22, "#3A2410", "#9A6A32", 3))
    return defs, "".join(b)


def gusli():
    defs = (
        linear_grad("body", "#C98F4E", "#7E4518")
        + linear_grad("top", "#E7C489", "#C09150")
    )
    body_d = (
        "M262 140 C242 140 230 156 234 176 "
        "L252 860 C254 890 274 912 304 912 "
        "L376 912 C410 912 430 886 418 856 "
        "C392 786 360 700 336 610 "
        "C316 536 306 450 302 360 "
        "C298 250 290 140 262 140 Z"
    )
    top_d = (
        "M268 164 C254 164 246 176 248 190 "
        "L264 854 C266 876 280 890 300 890 "
        "L370 890 C394 890 406 872 398 850 "
        "C374 784 344 700 322 614 "
        "C304 542 296 460 292 370 "
        "C288 274 282 164 268 164 Z"
    )
    b = [path(body_d, "url(#body)", "#4A2408", 7)]
    b.append(path(top_d, "url(#top)", "#8A5A26", 3, 0.95))
    # pin rail along the top wing
    b.append(path("M250 160 C270 148 292 148 310 160", "none", "#4A2408", 14))
    # 12 strings fanning across the wing
    for i in range(12):
        t = i / 11
        b.append(line(262 + t * 44, 166 + t * 20, 288 + t * 112, 848, CREAM, 2.0, 0.82))
    # bridge and soundhole
    b.append(rrect(282, 844, 118, 18, 8, "#4A2408", "#2A1206", 3))
    b.append(circle(340, 700, 24, "#3A2410", "#9A6A32", 3))
    return defs, "".join(b)


def bandura():
    defs = (
        linear_grad("body", "#D99A52", "#8A4A1C")
        + linear_grad("face", "#F1D9AC", "#D2A96C")
        + linear_grad("neck", "#7A3E1C", "#3A1A08")
    )
    body_d = (
        "M320 548 C260 548 214 592 206 656 "
        "C198 724 210 800 236 858 "
        "C258 906 290 936 320 936 "
        "C350 936 382 906 404 858 "
        "C430 800 442 724 434 656 "
        "C426 592 380 548 320 548 Z"
    )
    face_d = (
        "M320 570 C272 570 234 606 228 660 "
        "C222 722 232 792 254 846 "
        "C272 888 296 914 320 914 "
        "C344 914 368 888 386 846 "
        "C408 792 418 722 412 660 "
        "C406 606 368 570 320 570 Z"
    )
    b = [path(body_d, "url(#body)", "#3A1708", 7)]
    b.append(path(face_d, "url(#face)", "#9A6A3A", 3, 0.95))
    # short wide neck and pegbox
    b.append(rrect(292, 330, 56, 260, 12, "url(#neck)", "#2A1206", 5))
    b.append(rrect(272, 210, 96, 140, 18, "url(#neck)", "#2A1206", 5))
    for i in range(6):
        y = 232 + i * 20
        b.append(circle(260, y, 8, GOLD, INK, 2))
        b.append(circle(380, y, 8, GOLD, INK, 2))
    # rosette
    b.append(circle(320, 640, 30, "#2A1A0E", CREAM_DARK, 4))
    b.append(circle(320, 640, 38, "none", "#B98B52", 3, 0.7))
    # curved bridge
    b.append(rrect(240, 824, 160, 18, 9, "#3A2414"))
    # bass courses on the neck
    for i in range(12):
        x = 302 + i * 3.2
        b.append(line(x, 828, x, 226, CREAM, 1.8, 0.8))
    # treble strings fanning across the body
    for i in range(8):
        t = i / 7
        b.append(line(250 + t * 140, 830, 300 + t * 40, 360, CREAM, 1.4, 0.6))
    return defs, "".join(b)


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

ICONS = [
    # file key, instrument id, zh, en, family, family tint, drawer
    ("guitar", "guitar", "吉他", "Guitar", "guitars", "#FF9F5A", guitar),
    ("bass", "bass", "贝斯", "Bass", "basses", "#A78BFA", bass_guitar),
    ("ukulele", "ukulele", "尤克里里", "Ukulele", "ukuleles", "#34D399", ukulele),
    ("banjo", "banjo", "班卓琴", "Banjo", "banjos", "#F2C14E", banjo),
    ("mandolin", "mandolin", "曼陀林", "Mandolin", "mandolinFamily", "#5BA8FF", mandolin),
    ("resonator-guitar", "dobro", "多布罗琴", "Dobro", "guitars", "#FF9F5A", resonator),
    ("violin", "violin", "小提琴", "Violin", "westernBowed", "#2DD4BF", violin),
    ("viola", "viola", "中提琴", "Viola", "westernBowed", "#2DD4BF", viola),
    ("cello", "cello", "大提琴", "Cello", "westernBowed", "#2DD4BF", cello),
    ("double-bass", "doubleBass", "低音提琴", "Double Bass", "westernBowed", "#2DD4BF", double_bass),
    ("erhu", "erhu", "二胡", "Erhu", "chineseBowed", "#FF7A6B", erhu),
    ("morin-khuur", "morinKhuur", "马头琴", "Morin Khuur", "chineseBowed", "#FF7A6B", morin_khuur),
    ("guzheng", "guzheng", "古筝", "Guzheng", "chinesePlucked", "#F2C14E", guzheng),
    ("guqin", "guqin", "古琴", "Guqin", "chinesePlucked", "#F2C14E", guqin),
    ("pipa", "pipa", "琵琶", "Pipa", "chinesePlucked", "#F2C14E", pipa),
    ("yangqin", "yangqin", "扬琴", "Yangqin", "chinesePlucked", "#F2C14E", yangqin),
    ("ruan", "ruan", "阮", "Ruan", "chinesePlucked", "#F2C14E", ruan),
    ("oud", "oud", "乌德琴", "Oud", "westAsianEuropean", "#5BD98A", oud),
    ("balalaika", "balalaika", "巴拉莱卡琴", "Balalaika", "westAsianEuropean", "#5BD98A", balalaika),
    ("sitar", "sitar", "锡塔尔琴", "Sitar", "southAsian", "#E879CF", sitar),
    ("shamisen", "shamisen", "三味线", "Shamisen", "eastAsian", "#9AA6FF", shamisen),
    ("koto", "koto", "日本筝", "Koto", "eastAsian", "#9AA6FF", koto),
    ("gayageum", "gayageum", "伽倻琴", "Gayageum", "eastAsian", "#9AA6FF", gayageum),
    ("kora", "kora", "科拉琴", "Kora", "folkWorld", "#45D0E8", kora),
    ("nyckelharpa", "nyckelharpa", "尼克尔哈帕琴", "Nyckelharpa", "westAsianEuropean", "#5BD98A", nyckelharpa),
    ("ektara", "ektara", "埃克塔拉琴", "Ektara", "southAsian", "#E879CF", ektara),
    ("dotara", "dotara", "多塔拉琴", "Dotara", "southAsian", "#E879CF", dotara),
    ("sarangi", "sarangi", "萨兰吉琴", "Sarangi", "southAsian", "#E879CF", sarangi),
    ("kantele", "kantele", "坎特勒琴", "Kantele", "folkWorld", "#45D0E8", kantele),
    ("gusli", "gusli", "古斯里琴", "Gusli", "folkWorld", "#45D0E8", gusli),
    ("bandura", "bandura", "班杜拉琴", "Bandura", "folkWorld", "#45D0E8", bandura),
]


REUSE = {
    "guitar": ["twelveStringGuitar", "tenorGuitar"],
    "mandolin": ["mandola", "mandocello"],
    "erhu": ["gaohu", "zhonghu", "banhu", "jinghu"],
    "pipa": ["liuqin", "sanxian", "biwa"],
    "ruan": ["yueqin"],
    "oud": ["bouzouki", "domra"],
    "sitar": ["tanpura", "sarod", "veena"],
    "guzheng": ["qanun", "swarmandal"],
    "koto": ["zither"],
    "gayageum": ["geomungo"],
    "kora": ["ngoni"],
    "violin": ["hardangerFiddle"],
}


def main():
    SVG_DIR.mkdir(parents=True, exist_ok=True)
    manifest = []
    for key, instrument_id, zh, en, family, tint, drawer in ICONS:
        defs, body = drawer()
        write(key, defs, body)
        manifest.append({
            "file": key,
            "instrumentID": instrument_id,
            "nameZh": zh,
            "nameEn": en,
            "familyID": family,
            "familyTint": tint,
            "reuseFor": REUSE.get(key, []),
            "suggestedAssetName": f"instrument_{instrument_id}",
            "svg": f"svg/{key}.svg",
            "png": f"png/{key}.png",
            "tile": f"tiles/{key}.png",
        })
    (ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(manifest)} SVG files to {SVG_DIR}")


if __name__ == "__main__":
    main()

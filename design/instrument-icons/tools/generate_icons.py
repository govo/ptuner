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
        radial_grad("body", "#7C6BFF", "#2A1A78", cx=0.5, cy=0.42, r=0.75)
        + linear_grad("neck", "#C98B4E", "#8A5224")
        + linear_grad("head", "#2E2722", "#16120F")
    )
    body_d = (
        "M296 578 C252 592 206 626 192 670 C182 708 194 734 216 752 "
        "C234 768 230 786 214 804 C174 844 174 896 218 932 "
        "C264 970 396 970 442 932 C486 896 486 844 446 804 "
        "C430 786 426 768 444 752 C466 734 478 708 468 670 "
        "C454 626 408 592 364 604 L348 598 C332 586 314 582 296 578 Z"
    )
    head_d = (
        "M290 60 C290 46 302 36 318 36 L338 36 C354 36 366 46 366 60 "
        "L372 184 C372 200 362 212 346 212 L310 212 C294 212 284 200 284 184 Z"
    )
    guard_d = (
        "M300 604 C270 614 246 642 236 678 C228 708 236 734 254 750 "
        "C270 764 288 766 302 758 L318 720 C324 680 318 636 300 604 Z"
    )
    b = []
    # neck behind the body
    b.append(rrect(296, 200, 52, 470, 14, "url(#neck)", "#2A1C12", 5))
    # body
    b.append(path(body_d, "url(#body)", "#1E1440", 7))
    b.append(path(body_d, "none", "#C9C0FF", 3, 0.32))
    # fretboard
    b.append(rrect(300, 216, 44, 460, 7, "#241D18"))
    for y in range(248, 664, 32):
        b.append(line(302, y, 342, y, "#7B6B5E", 2, 0.7))
    for y in (280, 400, 520, 620):
        b.append(circle(322, y, 3, CREAM, None, 0, 0.8))
    # headstock
    b.append(path(head_d, "url(#head)", "#0F0C0A", 5))
    b.append(rrect(296, 202, 52, 12, 4, CREAM, None, 0, 0.85))
    for y in (78, 114, 150, 186):
        b.append(line(266, y, 290, y, GOLD, 4))
        b.append(circle(260, y, 10, GOLD, INK, 2))
    # pickguard
    b.append(path(guard_d, "#EFE5CF", "#A8936A", 3, 0.95))
    # pickups
    for y in (744, 810):
        b.append(rrect(278, y, 88, 34, 6, "#18141C", CREAM, 3))
        for i in range(4):
            b.append(line(294 + i * 19, y + 9, 294 + i * 19, y + 25, CREAM, 3, 0.85))
    # bridge and saddles
    b.append(rrect(272, 884, 96, 26, 6, STEEL, "#5B6572", 3))
    for i in range(4):
        b.append(rrect(284 + i * 20, 888, 13, 18, 3, "#8E99A8"))
    # control knobs
    for cx, cy in ((426, 846), (454, 880), (424, 914)):
        b.append(circle(cx, cy, 13, GOLD, INK, 3))
        b.append(circle(cx, cy, 5, "#F4E7CC"))
    # strings
    for i in range(4):
        x = 306 + i * 11
        b.append(line(x, 900, x, 216, "#E8EDF5", 3, 0.85))
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
    d = (
        "M320 578 C262 578 222 628 216 698 C210 778 246 858 306 898 "
        "C366 938 436 906 459 848 C481 793 463 723 429 690 "
        "C401 663 380 638 380 616 C380 594 352 578 320 578 Z"
    )
    b = [path(d, "url(#body)", "#5C2A0E", 7)]
    b.append(path(d, "none", CREAM, 3, opacity=0.55))
    # scroll
    b.append(circle(205, 624, 40, "url(#body)", "#5C2A0E", 6))
    b.append(path("M205 624 C205 606 220 604 228 616 C235 628 225 640 214 636", "none", "#4A210A", 7))
    # points on lower bout
    b.append(path("M452 758 L482 746 L462 788 Z", "url(#body)", "#5C2A0E", 5))
    b.append(path("M440 860 L468 872 L430 888 Z", "url(#body)", "#5C2A0E", 5))
    # neck + head
    b.append(rrect(302, 372, 36, 250, 10, "url(#neck)", "#3A1C0A", 5))
    b.append(rrect(288, 262, 64, 128, 16, "url(#head)", "#240E05", 5))
    b.append(tuners([(276, 292), (276, 326), (276, 360), (364, 292), (364, 326), (364, 360)], CREAM_DARK, 8))
    # fretboard + frets
    b.append(rrect(304, 388, 32, 230, 5, "#2A1D14"))
    for y in range(414, 610, 26):
        b.append(line(305, y, 335, y, "#8A7868", 2, 0.75))
    # oval hole
    b.append(ellipse(330, 772, 38, 54, "#24180F", CREAM_DARK, 4))
    b.append(rrect(286, 824, 68, 14, 5, "#3A2414"))
    # 8 strings as 4 courses
    for i in range(4):
        x = 307 + i * 8
        b.append(line(x, 828, x, 274, "#F8EBD4", 3, 0.9))
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
    "M320 516 C290 516 270 540 264 574 C259 602 278 622 288 640 "
    "C298 658 280 676 268 694 C255 714 268 732 280 750 "
    "C292 768 272 796 258 828 C240 870 270 918 320 918 "
    "C370 918 400 870 382 828 C368 796 348 768 360 750 "
    "C372 732 385 714 372 694 C360 676 342 658 352 640 "
    "C362 622 381 602 376 574 C370 540 350 516 320 516 Z"
)

DOUBLE_BASS_BODY = (
    "M320 470 C278 470 250 498 240 548 C232 590 246 620 258 650 "
    "C270 682 250 700 238 734 C222 780 228 842 258 884 "
    "C286 924 354 924 382 884 C412 842 418 780 402 734 "
    "C390 700 370 682 382 650 C394 620 408 590 400 548 "
    "C390 498 362 470 320 470 Z"
)


def bowed(name, *, body_color, body_edge, scale_x=1.0, body_top=516, body_bottom=918,
          neck_top=236, neck_width=26, endpin=False, dark_fingerboard=True,
          f_hole_color="#231812", chinrest=True):
    gid = f"{name}Body"
    defs = (
        linear_grad(gid, body_color[0], body_color[1])
        + linear_grad(f"{name}Neck", "#7A3D1E", "#3E1C0B")
    )
    b = [f'<g transform="translate(320 0) scale({scale_x} 1) translate(-320 0)">']
    # neck and fingerboard
    b.append(rrect(320 - neck_width / 2, neck_top, neck_width, body_bottom - neck_top - 120,
                   10, f"url(#{name}Neck)", "#3A1B0A", 5))
    b.append(rrect(320 - neck_width / 2 + 2, neck_top + 16, neck_width - 4,
                   body_bottom - neck_top - 150, 5, "#241B17"))
    if name == "doubleBass":
        body_d = DOUBLE_BASS_BODY
    else:
        body_d = VIOLIN_BODY
    b.append(path(body_d, f"url(#{gid})", body_edge, 7))
    b.append(path(body_d, "none", "#F2D9B0", 3, opacity=0.42))
    # f holes
    if name in ("violin", "viola"):
        b.append(path("M292 694 C280 724 282 762 296 788 C304 768 304 720 300 700 Z", f_hole_color))
        b.append(path("M348 694 C360 724 358 762 344 788 C336 768 336 720 340 700 Z", f_hole_color))
    else:
        b.append(path("M286 650 C272 690 274 748 292 786 C302 762 302 688 296 656 Z", f_hole_color))
        b.append(path("M354 650 C368 690 366 748 348 786 C338 762 338 688 344 656 Z", f_hole_color))
    # bridge
    b.append(path("M300 782 L340 782 L336 806 L304 806 Z", "#E9D3A8", "#7A5A34", 3))
    # tailpiece
    b.append(path("M306 812 L334 812 L328 892 L312 892 Z", "#241B17", "#0E0A08", 3))
    if chinrest:
        b.append(ellipse(287, 888, 30, 22, "#1F1713", "#0D0907", 3, rotate=-18))
    # strings
    for i in range(4):
        x = 312 + i * 5.4
        b.append(line(x, 812, x, neck_top + 18, CREAM, 2.4, 0.92))
    # scroll
    b.append(rrect(320 - neck_width / 2 - 6, neck_top - 90, neck_width + 12, 100, 12, "#4A2511", "#2A1206", 5))
    b.append(circle(320, neck_top - 96, 26, f"url(#{name}Neck)", "#2A1206", 5))
    b.append(path(
        f"M320 {neck_top - 118} C338 {neck_top - 118} 344 {neck_top - 100} 334 {neck_top - 88} "
        f"C326 {neck_top - 78} 310 {neck_top - 82} 310 {neck_top - 94}",
        "none", "#2A1206", 6))
    b.append("</g>")
    if endpin:
        b.append(line(320, 912, 320, 996, STEEL, 8))
        b.append(circle(320, 998, 9, INK))
    return defs, "".join(b)


def violin():
    return bowed("violin", body_color=("#D06A35", "#923817"), body_edge="#5A210D")


def viola():
    return bowed("viola", body_color=("#B8552E", "#7D2A14"), body_edge="#4A1A0A",
                 scale_x=1.14, body_top=490, body_bottom=930)


def cello():
    defs, body = bowed("cello", body_color=("#D18B45", "#9A4E1F"), body_edge="#5A2A0E",
                       scale_x=1.24, body_top=430, body_bottom=900, neck_top=206,
                       neck_width=30, endpin=True)
    return defs, body


def double_bass():
    defs, body = bowed("doubleBass", body_color=("#A96635", "#5E2A12"), body_edge="#341306",
                       scale_x=1.34, body_top=470, body_bottom=900, neck_top=150,
                       neck_width=32, endpin=True, chinrest=False)
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
    b = [rrect(238, 96, 164, 840, 46, f"url(#{gid})", "#0C0B0A", 7)]
    b.append(rrect(252, 118, 136, 796, 32, "none", "#8A7A5E", 3, 0.5))
    # 7 strings
    for i in range(7):
        x = 270 + i * 16.6
        b.append(line(x, 140, x, 892, CREAM, 2.6, 0.9))
    # 13 hui studs
    for i in range(13):
        y = 150 + i * 60
        b.append(circle(386, y, 6, "#DCC18C", "#4A3A22", 2))
    # tassel
    b.append(line(320, 936, 320, 980, "#B23A2E", 6))
    b.append(path("M306 980 L334 980 L328 1010 L312 1010 Z", "#C4493A", None, 0, 0.95))
    return defs, "".join(b)


def pipa():
    defs = (
        linear_grad("body", "#C86A3A", "#7E2E16")
        + linear_grad("face", "#F2D8A6", "#D8AE6C")
        + linear_grad("head", "#6E3418", "#38180A")
    )
    body_d = (
        "M320 592 C282 592 258 622 254 672 C250 730 236 790 222 840 "
        "C208 892 242 936 302 944 C370 954 432 920 448 868 "
        "C464 816 430 768 402 730 C380 700 380 650 380 612 "
        "C380 598 352 592 320 592 Z"
    )
    b = [path(body_d, "url(#body)", "#3A1708", 7)]
    b.append(path("M320 612 C292 612 274 638 270 680 C266 732 252 790 240 838 "
                  "C228 884 256 918 306 924 C364 932 414 902 426 862 "
                  "C438 818 408 776 386 740 C368 712 368 660 368 626 "
                  "C368 618 346 612 320 612 Z", "url(#face)", "#9A6A3A", 3, 0.95))
    # neck
    b.append(rrect(302, 330, 36, 300, 10, "url(#body)", "#3A1708", 5))
    # bent pegbox
    b.append(path("M302 330 L302 238 L282 188 L250 198 L274 252 L284 330 Z", "url(#head)", "#2A1006", 5))
    b.append(rrect(294, 220, 12, 120, 5, "#2A1006", None, 0, 0.7))
    for i in range(4):
        b.append(circle(266 if i % 2 == 0 else 352, 206 + i * 30, 13, "#5E3017", INK, 3))
    # frets
    for y in range(356, 600, 30):
        b.append(line(304, y, 336, y, "#6B4A2A", 3, 0.85))
    # strings
    for i in range(4):
        x = 308 + i * 8
        b.append(line(x, 910, x, 250, CREAM, 3, 0.92))
    # decorative ring
    b.append(circle(320, 860, 22, "none", "#8A4A26", 4, 0.5))
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
        + linear_grad("neck", "#4A3428", "#241812")
        + linear_grad("gold", "#E8C87C", "#B4852F")
    )
    b = []
    # neck
    b.append(rrect(306, 150, 30, 590, 8, "url(#neck)", "#1A1008", 5))
    # gourd body
    b.append(ellipse(320, 816, 158, 148, "url(#gourd)", "#3A1406", 7))
    b.append(ellipse(320, 664, 94, 82, "url(#gourd)", "#3A1406", 6))
    b.append(ellipse(320, 816, 142, 132, "none", "#F2B07A", 3, 0.35))
    # decorative gourd pattern
    for r in (52, 88, 120):
        b.append(circle(320, 816, r, "none", "#7E2E10", 3, 0.35))
    # pegbox
    b.append(rrect(288, 68, 64, 150, 16, "#3A2418", "#1A1008", 5))
    for i in range(7):
        b.append(circle(276 if i % 2 == 0 else 364, 92 + i * 18, 9, "url(#gold)", INK, 2))
    # sympathetic pegs
    for i in range(12):
        b.append(circle(294 if i % 2 == 0 else 346, 236 + i * 32, 7, "url(#gold)", INK, 2))
    # curved frets
    for i in range(10):
        y = 260 + i * 42
        b.append(path(f"M306 {y} C316 {y - 8} 324 {y - 8} 334 {y}", "none", "#C9D2DE", 5))
    # bridge
    b.append(rrect(270, 838, 100, 20, 6, "#3A2418", "#1A1008", 3))
    b.append(path("M280 838 C300 828 340 828 360 838", "none", CREAM, 4))
    # strings
    for i in range(7):
        x = 308 + i * 4
        b.append(line(x, 846, x, 160, CREAM, 2.2, 0.9))
    # sympathetic strings
    for i in range(3):
        x = 316 + i * 4
        b.append(line(x, 690, x, 200, CREAM, 1.2, 0.55))
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
    # bridge + strings
    b.append(rrect(288, 852, 64, 14, 5, "#3A2414"))
    for i in range(3):
        x = 312 + i * 8
        b.append(line(x, 856, x, 130, CREAM, 3, 0.92))
    b.append(rrect(196, 940, 248, 14, 6, "#B23A2E", None, 0, 0.9))
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

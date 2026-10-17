#!/usr/bin/env python3
"""Install generated icons into the app's Assets.xcassets and Instruments.json.

For every manifest entry this creates an imageset named
``instrument_<file>`` containing the 1x/2x/3x PNGs, then points the
instrument (and every instrument listed in ``reuseFor``) at that asset via
the ``image`` field. Instruments without an icon keep the ``glyph`` fallback.

Idempotent: re-running rewrites the imagesets and leaves already-correct
``image`` values untouched.
"""

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
ASSETS = REPO / "PTuner" / "PTuner" / "Assets.xcassets"
CATALOG = REPO / "PTuner" / "PTuner" / "Resources" / "Instruments.json"
MANIFEST = ROOT / "manifest.json"

SCALES = ("1x", "2x", "3x")


def asset_name(item):
    return item.get("suggestedAssetName") or f"instrument_{item['file']}"


def write_imageset(item):
    name = asset_name(item)
    imageset = ASSETS / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)

    images = []
    for scale in SCALES:
        src = ROOT / "png" / scale / f"{item['file']}.png"
        if not src.is_file():
            raise FileNotFoundError(f"missing {src}; run build_assets.py first")
        filename = f"{item['file']}-{scale}.png"
        (imageset / filename).write_bytes(src.read_bytes())
        images.append({
            "filename": filename,
            "idiom": "universal",
            "scale": scale,
        })

    contents = {
        "images": images,
        "info": {"author": "xcode", "version": 1},
    }
    (imageset / "Contents.json").write_text(
        json.dumps(contents, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return name


def with_image(definition, image):
    """Return the definition with ``image`` placed right after ``glyph``."""
    ordered = {}
    for key, value in definition.items():
        if key == "image":
            continue
        ordered[key] = value
        if key == "glyph":
            ordered["image"] = image
    if "image" not in ordered:
        ordered["image"] = image
    return ordered


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))

    mapping = {}
    for item in manifest:
        name = write_imageset(item)
        mapping[item["instrumentID"]] = name
        for reused in item.get("reuseFor", []):
            mapping[reused] = name

    known = {i["id"] for i in catalog["instruments"]}
    unknown = sorted(set(mapping) - known)
    if unknown:
        raise SystemExit(f"manifest references unknown instrument IDs: {unknown}")

    for index, definition in enumerate(catalog["instruments"]):
        image = mapping.get(definition["id"])
        if image:
            catalog["instruments"][index] = with_image(definition, image)

    CATALOG.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    covered = sum(1 for i in catalog["instruments"] if mapping.get(i["id"]))
    print(f"installed {len(manifest)} imagesets")
    print(f"linked {covered} / {len(catalog['instruments'])} instruments")


if __name__ == "__main__":
    main()

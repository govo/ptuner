"""Shared image helpers for the instrument icon pipeline."""

import numpy as np
from PIL import Image


def resize_premultiplied(image, size):
    """Resize an RGBA image without bleeding color from transparent pixels."""
    array = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = array[..., 3:4] / 255.0
    premultiplied = np.concatenate((array[..., :3] * alpha, array[..., 3:4]), axis=2)

    resized = []
    for channel in range(4):
        plane = Image.fromarray(premultiplied[..., channel])
        plane = plane.resize(size, Image.LANCZOS)
        resized.append(np.asarray(plane, dtype=np.float32))
    out = np.stack(resized, axis=2)

    out_alpha = np.clip(out[..., 3:4], 0, 255)
    scale = np.maximum(out_alpha / 255.0, 1e-6)
    out_rgb = np.clip(out[..., :3] / scale, 0, 255)
    return Image.fromarray(np.concatenate((out_rgb, out_alpha), axis=2).astype(np.uint8))

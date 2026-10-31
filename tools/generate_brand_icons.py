#!/usr/bin/env python3
"""Generate app launcher icons from the approved assets/brand/refilly_app_icon.png.

Requires: pip install pillow
Run after replacing the source PNG. Apple icons are flattened to opaque RGB.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/brand/refilly_app_icon.png"
BLUE = (9, 104, 238)


def render(size: int, *, background: bool = True) -> Image.Image:
    image = Image.open(SOURCE).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    if background:
        # iOS marketing icon must have no alpha; same opaque background on
        # every platform prevents white-corner artifacts after OS masking.
        base = Image.new("RGBA", (size, size), (*BLUE, 255))
        base.alpha_composite(image)
        return base.convert("RGB")
    return image


def save(path: str, size: int, *, maskable: bool = False) -> None:
    dest = ROOT / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    if maskable:
        # Keep the whole mark within the middle 80% safe area.
        image = Image.new("RGB", (size, size), BLUE)
        content = render(round(size * .80), background=False)
        image.paste(content, ((size - content.width) // 2, (size - content.height) // 2), content)
    else:
        image = render(size)
    image.save(dest, "PNG", optimize=True)
    print(f"{dest.relative_to(ROOT)} {size}x{size}")


for density, pixels in {
    "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}.items():
    save(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", pixels)

ios_root = "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
for points, scales in {
    "20x20": [1, 2, 3],
    "29x29": [1, 2, 3],
    "40x40": [1, 2, 3],
    "60x60": [2, 3],
    "76x76": [1, 2],
    "83.5x83.5": [2],
    "1024x1024": [1],
}.items():
    point_size = float(points.split("x")[0])
    for scale in scales:
        name = f"Icon-App-{points}@{scale}x.png"
        save(ios_root + name, round(point_size * scale))

save("web/icons/Icon-192.png", 192)
save("web/icons/Icon-512.png", 512)
save("web/icons/Icon-maskable-192.png", 192, maskable=True)
save("web/icons/Icon-maskable-512.png", 512, maskable=True)
save("web/favicon.png", 48)

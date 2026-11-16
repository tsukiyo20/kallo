#!/usr/bin/env python3
"""Turn the icon master into every platform's assets.

The master is `kallo-icon-1024.png`, a full-bleed square rendered from
`kallo-icon.svg`. This script owns the platform differences: macOS wants a
rounded square with a transparent margin, iOS wants the full square and no
alpha, Android wants adaptive layers, Windows wants one ICO.

Run from anywhere:

    python3 app/icon/generate.py

Pillow is the only dependency.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(__file__).resolve().parent
MASTER = SOURCE / "kallo-icon-1024.png"

MACOS = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
IOS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_LAUNCH = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
IOS_LAUNCH_BACKGROUND = ROOT / "ios/Runner/Assets.xcassets/LaunchBackground.colorset"
ANDROID = ROOT / "android/app/src/main/res"
WINDOWS = ROOT / "windows/runner/resources/app_icon.ico"
UI = ROOT / "assets/kallo-icon.png"

MAC_SIZES = {
    16: "app_icon_16.png",
    32: "app_icon_32.png",
    64: "app_icon_64.png",
    128: "app_icon_128.png",
    256: "app_icon_256.png",
    512: "app_icon_512.png",
    1024: "app_icon_1024.png",
}

# The launch screen's mark, in pixels: the same tile at each scale. It is the
# icon as iOS would mask it, on a transparent canvas, so it can be centred on
# the app's own ground in either appearance.
IOS_LAUNCH_SIZES = {
    "LaunchImage.png": 96,
    "LaunchImage@2x.png": 192,
    "LaunchImage@3x.png": 288,
}

# The app's ground colours, as `KalloColors.light.ground` and `.dark.ground`
# write them: the launch screen is the first frame's colour, so the hand-off
# from the storyboard to the app is a colour that does not move.
LAUNCH_BACKGROUND_LIGHT = (0.949, 0.949, 0.969, 1.0)
LAUNCH_BACKGROUND_DARK = (0.0, 0.0, 0.0, 1.0)

# Android's legacy mipmaps, in pixels.
ANDROID_LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive icon layers are 108 dp; the visible window is 72 dp and the safe
# zone is 66 dp. The artwork is scaled down so the frame sits inside it.
ANDROID_ADAPTIVE = {
    "drawable-mdpi": 108,
    "drawable-hdpi": 162,
    "drawable-xhdpi": 216,
    "drawable-xxhdpi": 324,
    "drawable-xxxhdpi": 432,
}


def squircle(master: Image.Image, margin: int = 100, radius: int = 185) -> Image.Image:
    """The macOS icon: a rounded square on transparent canvas, with its shadow."""
    size = master.width
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle(
        (margin, margin + 14, size - margin, size - margin + 14),
        radius=radius,
        fill=(0, 0, 0, 90),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24)))

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (margin, margin, size - margin, size - margin),
        radius=radius,
        fill=255,
    )
    shape = master.copy()
    shape.putalpha(mask)
    canvas.alpha_composite(shape)
    return canvas


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def ui(master: Image.Image) -> None:
    """The mark the About page draws, at the largest size it asks for."""
    save_png(master.resize((256, 256), Image.LANCZOS), UI)


def macos(master: Image.Image) -> None:
    icon = squircle(master)
    for size, name in MAC_SIZES.items():
        save_png(icon.resize((size, size), Image.LANCZOS), MACOS / name)


def ios(master: Image.Image) -> None:
    full = master.convert("RGB")
    contents = json.loads((IOS / "Contents.json").read_text())
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        size = round(points * scale)
        full.resize((size, size), Image.LANCZOS).save(
            IOS / filename,
            "PNG",
            optimize=True,
        )


def launch_screen(master: Image.Image) -> None:
    """The iOS launch screen: the mark, and the colour it sits on.

    iOS has no automatic icon splash the way Android 12 does, so the launch
    storyboard is the one that shows the app opening. The mark is the icon as
    the launcher masks it — rounded, with a transparent margin — and the
    background is the app's ground in that appearance, so the launch screen and
    the first frame of the app are the same colour.
    """
    for name, size in IOS_LAUNCH_SIZES.items():
        art = master.resize((size, size), Image.LANCZOS)
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, size - 1, size - 1),
            radius=round(size * 0.225),
            fill=255,
        )
        tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        tile.alpha_composite(art)
        tile.putalpha(mask)
        save_png(tile, IOS_LAUNCH / name)

    def colour(rgba: tuple[float, float, float, float]) -> dict[str, object]:
        red, green, blue, alpha = rgba
        return {
            "color-space": "srgb",
            "components": {
                "alpha": f"{alpha:.3f}",
                "blue": f"{blue:.3f}",
                "green": f"{green:.3f}",
                "red": f"{red:.3f}",
            },
        }

    IOS_LAUNCH_BACKGROUND.mkdir(parents=True, exist_ok=True)
    (IOS_LAUNCH_BACKGROUND / "Contents.json").write_text(
        json.dumps(
            {
                "colors": [
                    {"idiom": "universal", "color": colour(LAUNCH_BACKGROUND_LIGHT)},
                    {
                        "appearances": [
                            {"appearance": "luminosity", "value": "dark"}
                        ],
                        "idiom": "universal",
                        "color": colour(LAUNCH_BACKGROUND_DARK),
                    },
                ],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
        + "\n"
    )


def android(master: Image.Image) -> None:
    full = master.convert("RGB")
    for folder, size in ANDROID_LEGACY.items():
        (ANDROID / folder).mkdir(parents=True, exist_ok=True)
        full.resize((size, size), Image.LANCZOS).save(
            ANDROID / folder / "ic_launcher.png",
            "PNG",
            optimize=True,
        )

    # The launcher masks the background layer; keep the frame inside its 66 dp
    # safe zone by shrinking the whole square a little.
    for folder, size in ANDROID_ADAPTIVE.items():
        (ANDROID / folder).mkdir(parents=True, exist_ok=True)
        layer = Image.new("RGB", (size, size), (7, 7, 8))
        art = full.resize((round(size * 0.90),) * 2, Image.LANCZOS)
        layer.paste(art, ((size - art.width) // 2, (size - art.height) // 2))
        layer.save(
            ANDROID / folder / "ic_launcher_background.png",
            "PNG",
            optimize=True,
        )


def windows(master: Image.Image) -> None:
    icon = squircle(master, margin=72, radius=200)
    icon.save(
        WINDOWS,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def main() -> None:
    master = Image.open(MASTER).convert("RGBA")
    if master.size != (1024, 1024):
        raise SystemExit(f"{MASTER} is not 1024 x 1024")
    ui(master)
    macos(master)
    ios(master)
    launch_screen(master)
    android(master)
    windows(master)
    print("icons written from", MASTER)


if __name__ == "__main__":
    main()

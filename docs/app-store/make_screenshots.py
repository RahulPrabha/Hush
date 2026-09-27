#!/usr/bin/env python3
"""Build Mac App Store screenshots for Hush.

Cuts the Hush controls panel out of full-screen captures and places it on a
brown gradient with a headline. The raw captures are not committed: they show
whatever was behind the panel. Take new ones with the panel open (Shift-Cmd-3),
then set each capture's path and the panel's pixel box below.

Requires Pillow (pip install pillow) and macOS for the SF system font.
Output: 2880x1800 PNGs, one of Apple's accepted Mac sizes.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).parent
W, H = 2880, 1800
SCALE = 1.35          # panel enlargement
RADIUS = 20           # panel corner radius in capture pixels
FONT = "/System/Library/Fonts/SFNS.ttf"
TOP, BOTTOM = (38, 26, 19), (112, 66, 36)

# (capture path, panel box (left, top, right, bottom) in capture pixels,
#  headline, subline, output name)
SHOTS = [
    ("brown.png", (4502, 86, 5222, 1106), "Brown noise,\none click away.",
     "Lives in your menu bar.\nRight-click the icon to toggle.", "1-brown.png"),
    ("speech.png", (4502, 86, 5222, 910), "Tune out\nthe voices.",
     "Speech Blocker is shaped to mask\nnearby conversation.", "2-speech.png"),
    ("light.png", (4502, 86, 5222, 1106), "Offline.\nPrivate.",
     "Every sound is generated live\non your Mac. Nothing leaves it.", "3-light.png"),
]


def background():
    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        draw.line([(0, y), (W, y)], fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return img


def build(capture, box, head, sub, name, base, bold, regular):
    panel = Image.open(capture).convert("RGB").crop(box)
    panel = panel.resize((round(panel.width * SCALE), round(panel.height * SCALE)), Image.LANCZOS)
    w, h = panel.size
    r = round(RADIUS * SCALE)
    k = 4  # supersample the mask for smooth corners
    mask = Image.new("L", (w * k, h * k), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w * k - 1, h * k - 1], r * k, fill=255)
    mask = mask.resize((w, h), Image.LANCZOS)

    px, py = W - w - 260, (H - h) // 2
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([px, py + 30, px + w, py + h + 30], r, fill=150)
    img = Image.composite(Image.new("RGB", (W, H)), base, shadow.filter(ImageFilter.GaussianBlur(40)))
    img.paste(panel, (px, py), mask)

    draw = ImageDraw.Draw(img)
    hb = draw.multiline_textbbox((0, 0), head, font=bold, spacing=20)
    sb = draw.multiline_textbbox((0, 0), sub, font=regular, spacing=18)
    y0 = (H - ((hb[3] - hb[1]) + 70 + (sb[3] - sb[1]))) // 2 - hb[1]
    draw.multiline_text((240, y0), head, font=bold, fill=(250, 244, 236), spacing=20)
    draw.multiline_text((244, y0 + hb[3] + 70), sub, font=regular, fill=(226, 206, 186), spacing=18)
    img.save(OUT / name)


def main():
    bold = ImageFont.truetype(FONT, 150)
    bold.set_variation_by_name("Bold")
    regular = ImageFont.truetype(FONT, 64)
    base = background()
    for shot in SHOTS:
        build(*shot, base, bold, regular)


if __name__ == "__main__":
    main()

"""Build Mac App Store screenshots for Hush.

Puts the Hush controls panel on a brown gradient with a headline. The panel
images come from render_panels.sh, which draws the app's real SwiftUI view
offscreen, so nothing is ever captured from the screen.

Usage: render_panels.sh captures && python3 make_screenshots.py captures
(the directory defaults to ./captures).

Requires Pillow (pip install pillow) and macOS for the system fonts.
Output: 2880x1800 PNGs, one of Apple's accepted Mac sizes.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).parent
W, H = 2880, 1800
SCALE = 1.25          # panel enlargement
RADIUS = 20           # panel corner radius in capture pixels
FONT = "/System/Library/Fonts/SFNS.ttf"
TOP, BOTTOM = (38, 26, 19), (112, 66, 36)

# The app's languages (English plus the 8 in Localizable.xcstrings), each in
# its own script. SF has no CJK glyphs, so those names use a system CJK font.
CJK = {
    "日本語": "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
    "한국어": "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "简体中文": "/System/Library/Fonts/Hiragino Sans GB.ttc",
}
LANGUAGES = [
    ["English", "Deutsch", "Español"],
    ["Français", "Italiano", "Português"],
    ["日本語", "한국어", "简体中文"],
]

# (panel capture, headline, subline, output name, show the language list)
SHOTS = [
    ("brown.png", "Brown noise,\none click away.",
     "Lives in your menu bar.\nRight-click the icon to toggle.", "1-brown.png", False),
    ("speech.png", "Tune out\nthe voices.",
     "Speech Blocker is shaped to mask\nnearby conversation.", "2-speech.png", False),
    ("light.png", "Offline.\nPrivate.",
     "Every sound is generated live\non your Mac. Nothing leaves it.", "3-light.png", False),
    # The panel is shown in Japanese; the caption stays English.
    ("ja.png", "Speaks your\nlanguage.",
     "Hush is available in 9 languages:", "4-languages.png", True),
]


def background():
    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        draw.line([(0, y), (W, y)], fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return img


def draw_languages(draw, x, y, regular_small):
    """Draws LANGUAGES, one row per line, each name in a font that has its glyphs."""
    sep = "  \u00b7  "
    for row in LANGUAGES:
        cx = x
        for n, name in enumerate(row):
            font = ImageFont.truetype(CJK[name], 52) if name in CJK else regular_small
            draw.text((cx, y), name, font=font, fill=(250, 244, 236), anchor="ls")
            cx += draw.textlength(name, font=font)
            if n < len(row) - 1:
                draw.text((cx, y), sep, font=regular_small, fill=(170, 140, 114), anchor="ls")
                cx += draw.textlength(sep, font=regular_small)
        y += 96


def build(capture, head, sub, name, languages, base, bold, regular, small):
    panel = Image.open(capture).convert("RGB")
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
    langs = 60 + len(LANGUAGES) * 96 if languages else 0
    y0 = (H - ((hb[3] - hb[1]) + 70 + (sb[3] - sb[1]) + langs)) // 2 - hb[1]
    draw.multiline_text((240, y0), head, font=bold, fill=(250, 244, 236), spacing=20)
    draw.multiline_text((244, y0 + hb[3] + 70), sub, font=regular, fill=(226, 206, 186), spacing=18)
    if languages:
        draw_languages(draw, 244, y0 + hb[3] + 70 + sb[3] + 130, small)
    img.save(OUT / name)


def main():
    captures = Path(sys.argv[1] if len(sys.argv) > 1 else "captures")
    bold = ImageFont.truetype(FONT, 150)
    bold.set_variation_by_name("Bold")
    regular = ImageFont.truetype(FONT, 64)
    small = ImageFont.truetype(FONT, 52)
    base = background()
    for capture, *rest in SHOTS:
        build(captures / capture, *rest, base, bold, regular, small)


if __name__ == "__main__":
    main()

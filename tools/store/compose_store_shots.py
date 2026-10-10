#!/usr/bin/env python3
"""Turns the raw screenshots from tools/store_shots.gd into store-ready images.

    python3 tools/store/compose_store_shots.py

Reads  docs/store/raw/play/*.png      (1080x1920)
       docs/store/raw/appstore/*.png  (1080x2346)
       docs/store/canva/*.png         (transparent art)
Writes docs/store/play/NN_name.png          Google Play phone, 1080x1920
       docs/store/appstore/NN_name.png      Apple 6.9", 1320x2868
       docs/store/icon_512.png, icon_1024.png   draft app icons
       docs/store/feature_graphic.png           draft 1024x500 feature graphic

Captions live in CAPTIONS below. Needs Pillow (pip3 install pillow).
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
STORE = os.path.join(ROOT, "docs", "store")
FONT = os.path.join(ROOT, "assets", "fonts", "LilitaOne-Regular.ttf")

CAPTIONS = {
    "01_sort": "Sort sweet candies\ninto jars!",
    "02_renovate": "Renovate Hajurama's\nold pasal",
    "03_style": "Pick your\nfavourite style",
    "04_win": "Win stars and\ncoins every level",
    "05_twists": "Clever twists:\ncloth, locks & more",
    "06_before_after": "Bring the shop\nback to life",
    "07_daily": "Daily gifts\nand challenges",
    "08_themes": "Cosy Nepali themes\nto unlock",
}

TOP = (0x34, 0x28, 0xC4)
BOTTOM = (0xC2, 0x4F, 0xD8)
OUTLINE = (0x26, 0x16, 0x5E)


def gradient(size, top=TOP, bottom=BOTTOM):
    w, h = size
    img = Image.new("RGB", size, top)
    px = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        px.line([(0, y), (w, y)], fill=col)
    # Soft bokeh lights.
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    import random
    rnd = random.Random(7)
    for _ in range(26):
        r = rnd.randint(int(w * 0.03), int(w * 0.09))
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        g.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(14, 30)))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.006))
    img = img.convert("RGBA")
    img.alpha_composite(glow)
    return img


def caption(img, text, box, size):
    """Centred, white, thick dark outline and a drop shadow (game style)."""
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size)
    stroke = max(6, size // 9)
    bbox = d.multiline_textbbox((0, 0), text, font=font, stroke_width=stroke, spacing=size * 0.08, align="center")
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    # Shrink to fit the width if needed.
    while tw > box[2] * 0.92 and size > 40:
        size -= 4
        font = ImageFont.truetype(FONT, size)
        stroke = max(6, size // 9)
        bbox = d.multiline_textbbox((0, 0), text, font=font, stroke_width=stroke, spacing=size * 0.08, align="center")
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = box[0] + (box[2] - tw) / 2 - bbox[0]
    y = box[1] + (box[3] - th) / 2 - bbox[1]
    shadow = (0x26, 0x16, 0x5E, 170)
    d.multiline_text((x, y + size * 0.09), text, font=font, fill=shadow, stroke_width=stroke, stroke_fill=shadow, spacing=size * 0.08, align="center")
    d.multiline_text((x, y), text, font=font, fill=(255, 255, 255), stroke_width=stroke, stroke_fill=OUTLINE, spacing=size * 0.08, align="center")


def framed(screen, width, radius, border):
    """The screenshot scaled to `width`, rounded, with a white border and shadow."""
    h = round(screen.height * width / screen.width)
    shot = screen.convert("RGB").resize((width, h), Image.LANCZOS)
    W, H = width + border * 2, h + border * 2
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius + border, fill=255)
    frame.paste((255, 255, 255, 255), (0, 0), mask)
    inner = Image.new("L", (width, h), 0)
    ImageDraw.Draw(inner).rounded_rectangle([0, 0, width - 1, h - 1], radius, fill=255)
    frame.paste(shot, (border, border), inner)
    shadow = Image.new("RGBA", (W + 120, H + 120), (0, 0, 0, 0))
    sm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sm).rounded_rectangle([0, 0, W - 1, H - 1], radius + border, fill=140)
    shadow.paste((20, 6, 60, 255), (60, 80), sm)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    return frame, shadow


def compose(raw_dir, out_dir, size, cap_h, shot_w, font_size):
    os.makedirs(out_dir, exist_ok=True)
    for name in sorted(os.listdir(raw_dir)):
        if not name.endswith(".png"):
            continue
        key = name[:-4]
        img = gradient(size)
        caption(img, CAPTIONS.get(key, key), (0, int(size[1] * 0.02), size[0], cap_h), font_size)
        frame, shadow = framed(Image.open(os.path.join(raw_dir, name)), shot_w, int(shot_w * 0.07), int(shot_w * 0.016))
        x = (size[0] - frame.width) // 2
        y = cap_h + int(size[1] * 0.005)
        img.alpha_composite(shadow, (x - 60, y - 60))
        img.alpha_composite(frame, (x, y))
        img.convert("RGB").save(os.path.join(out_dir, name), optimize=True)
        print("  ", os.path.relpath(os.path.join(out_dir, name), ROOT), img.size)


def drafts():
    canva = os.path.join(STORE, "canva")
    # App icon: a full candy jar on the game gradient. No text (stores
    # discourage it, and it is unreadable at launcher size).
    icon = gradient((1024, 1024), (0x5A, 0x3A, 0xF0), (0xD0, 0x4F, 0xC8))
    glow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([170, 170, 854, 854], fill=(255, 230, 150, 70))
    icon.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
    jar = Image.open(os.path.join(canva, "jar_full.png")).convert("RGBA")
    jar = jar.crop(jar.getbbox())
    jar = jar.resize((int(jar.width * 760 / jar.height), 760), Image.LANCZOS)
    icon.alpha_composite(jar, ((1024 - jar.width) // 2, 140))
    for i, (fname, xy, s) in enumerate([("candy_08_neelo.png", (40, 600), 330), ("candy_12_chocolate_gold.png", (660, 620), 330)]):
        c = Image.open(os.path.join(canva, fname)).convert("RGBA")
        c = c.crop(c.getbbox()).resize((s, int(s * c.height / c.width)), Image.LANCZOS)
        icon.alpha_composite(c, xy)
    # Apple: 1024x1024, no alpha. Google Play: 512x512, 32-bit PNG (opaque).
    icon.convert("RGB").save(os.path.join(STORE, "icon_1024.png"))
    icon.resize((512, 512), Image.LANCZOS).convert("RGBA").save(os.path.join(STORE, "icon_512.png"))
    print("   docs/store/icon_1024.png, icon_512.png")

    # Feature graphic 1024x500: logo on the left half, candies and a jar right.
    fg = gradient((1024, 500))
    logo = Image.open(os.path.join(canva, "logo.png")).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    logo = logo.resize((560, int(logo.height * 560 / logo.width)), Image.LANCZOS)
    fg.alpha_composite(logo, (40, (500 - logo.height) // 2))
    jar = Image.open(os.path.join(canva, "jar_full.png")).convert("RGBA")
    jar = jar.crop(jar.getbbox())
    jar = jar.resize((int(jar.width * 400 / jar.height), 400), Image.LANCZOS)
    fg.alpha_composite(jar, (700, 60))
    for fname, xy, s in [("candy_07_khursani.png", (620, 300), 170), ("candy_09_kagati.png", (830, 330), 170), ("candy_05_jamun.png", (850, 40), 150)]:
        c = Image.open(os.path.join(canva, fname)).convert("RGBA")
        c = c.crop(c.getbbox()).resize((s, int(s * c.height / c.width)), Image.LANCZOS)
        fg.alpha_composite(c, xy)
    fg.convert("RGB").save(os.path.join(STORE, "feature_graphic.png"))
    print("   docs/store/feature_graphic.png (1024, 500)")


if __name__ == "__main__":
    print("Google Play (1080x1920):")
    compose(os.path.join(STORE, "raw", "play"), os.path.join(STORE, "play"), (1080, 1920), 430, 780, 104)
    print("App Store 6.9\" (1320x2868):")
    compose(os.path.join(STORE, "raw", "appstore"), os.path.join(STORE, "appstore"), (1320, 2868), 560, 1000, 128)
    print("Drafts:")
    drafts()

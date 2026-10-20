#!/usr/bin/env python3
"""Writes the art brief manifest for the Project-Makeover-style revamp.

    python3 tools/art_brief/make_manifest.py [OUT_ROOT]   (default ~/Downloads/pasal-sort-art)

OUT_ROOT/_brief/asset_manifest.csv lists every image the game needs, with the
exact path (relative to OUT_ROOT, mirroring res://assets/art/), pixel size,
transparency, 9-slice margins and a description, built from the game data so
nothing is missed. Area objects get the exact aspect ratio of their box in the
room (the game stretches each PNG to its box).
"""
import csv, json, glob, os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads/pasal-sort-art")
rows = []


def add(batch, path, w, h, alpha, desc, slice_=""):
    rows.append({"batch": batch, "file": path, "width": w, "height": h,
                 "transparent": "yes" if alpha else "no", "nine_slice_LTRB": slice_, "description": desc})


def fit2x(w, h, cap=2048):
    """2x the box for crispness, capped, keeping the box's exact aspect."""
    k = min(2.0, cap / max(w, h))
    return round(w * k), round(h * k)


def load(p):
    return json.load(open(os.path.join(ROOT, p)))


# ---- 1. UI kit ------------------------------------------------------------
B = "01_ui_kit"
add(B, "logo/logo.png", 1600, 700, True, "PASAL SORT game logo wordmark: chunky rounded 3D letters in warm candy colours (pink/orange/gold) with a soft darker outline and glossy top highlight, a small candy jar or wrapped sweet tucked into the design, a carved-wood sign plate behind it like the shop sign in the banner. Must read clearly at small size. Text exactly: PASAL SORT.")
add(B, "logo/logo_tagline.png", 1200, 160, True, "Small ribbon/plaque reading exactly: Sort & Renovate. Same style as the logo.")
kit = [
    ("ui/panel_popup.png", 512, 512, "64,96,64,64", "Popup sheet: warm cream paper card with a subtle carved-wood or soft gold rim, rounded corners (~56 px), gentle inner shading and a soft drop shadow baked in. Centre must be flat/plain so text sits on it. 9-slice."),
    ("ui/panel_card.png", 400, 400, "48,48,48,48", "Small item card (shop items, stats, achievements): lighter cream card, rounded 40 px corners, thin warm outline, soft bottom shadow. 9-slice."),
    ("ui/panel_card_highlight.png", 400, 400, "48,48,48,48", "Same card with a gold glowing rim (best offer / daily gift). 9-slice."),
    ("ui/panel_dark.png", 400, 400, "48,48,48,48", "Translucent deep plum/purple glass panel for overlays on top of the room (toasts, chips backgrounds). 9-slice."),
    ("ui/ribbon_title.png", 1200, 200, "160,0,160,0", "Popup title ribbon: glossy pink/magenta satin banner with folded tails on both ends, like the current game's ribbon but painterly 3D. Plain middle for text. Horizontal 9-slice (stretch middle only)."),
    ("ui/ribbon_small.png", 600, 110, "90,0,90,0", "Smaller section ribbon in warm orange for section headers (e.g. Boosters, Coins). Horizontal 9-slice."),
    ("ui/btn_close.png", 160, 160, "", "Round red close button with a white X, glossy, bevelled, thick dark rim."),
    ("ui/btn_back.png", 160, 160, "", "Round blue back button with a white left arrow, glossy."),
    ("ui/chip_pill.png", 420, 120, "60,0,60,0", "Top-bar currency pill: dark plum glass capsule with a light rim (holds the coin/star/lives count). Horizontal 9-slice."),
    ("ui/chip_plus.png", 96, 96, "", "Small round green + button that sits at the right end of a currency pill."),
    ("ui/progress_bg.png", 600, 64, "32,0,32,0", "Progress bar track: dark inset rounded capsule. Horizontal 9-slice."),
    ("ui/progress_fill.png", 600, 64, "32,0,32,0", "Progress bar fill: glossy gold-to-orange capsule with a highlight stripe. Horizontal 9-slice."),
    ("ui/badge_count.png", 96, 96, "", "Red round notification badge (number drawn by the game on top). Plain centre."),
    ("ui/badge_dot.png", 48, 48, "", "Small red notification dot with white rim."),
    ("ui/tag_pill.png", 220, 72, "36,0,36,0", "Small red tag pill for labels like FREE / NEW / ON (text drawn by the game). Horizontal 9-slice."),
    ("ui/speech_bubble.png", 600, 300, "80,60,80,90", "Dialogue speech bubble: white rounded bubble with a small tail at bottom-left, soft shadow. 9-slice."),
    ("ui/name_plate.png", 400, 90, "50,0,50,0", "Speaker name plate: warm wood/orange plaque for the dialogue speaker's name. Horizontal 9-slice."),
    ("ui/toast.png", 700, 120, "60,0,60,0", "Toast message capsule: translucent deep plum with soft glow. Horizontal 9-slice."),
    ("ui/tutorial_hand.png", 256, 256, "", "Cartoon pointing hand (white glove or warm skin) pointing up-left, with a soft shadow, for tutorials."),
    ("ui/star_full.png", 256, 256, "", "Big glossy gold star with a highlight (rewards, ratings)."),
    ("ui/star_empty.png", 256, 256, "", "Same star empty: dark inset grey-purple."),
    ("ui/heart.png", 256, 256, "", "Glossy red heart (lives)."),
    ("ui/heart_infinity.png", 256, 256, "", "Glossy red heart with a white infinity sign (unlimited lives)."),
    ("ui/coin.png", 256, 256, "", "Gold coin with a simple embossed candy or lotus mark, glossy."),
    ("ui/coin_pile.png", 384, 320, "", "Pile of gold coins (shop coin packs)."),
    ("ui/coin_sack.png", 384, 384, "", "Cloth sack overflowing with gold coins (largest coin pack)."),
    ("ui/coin_jar.png", 384, 384, "", "Glass jar full of gold coins (medium coin pack)."),
    ("ui/streak_flame_on.png", 256, 256, "", "Warm layered flame (red-orange outside, yellow core), friendly, for the win streak."),
    ("ui/streak_flame_off.png", 256, 256, "", "Same flame greyed out / unlit."),
    ("ui/level_badge.png", 360, 120, "60,0,60,0", "Difficulty badge capsule (game tints it: HARD red, SUPER HARD purple). White/neutral body. Horizontal 9-slice."),
    ("ui/light_rays.png", 1024, 1024, "", "Soft golden light rays radiating from the centre, transparent edges (behind rewards and chests)."),
    ("ui/sparkle.png", 128, 128, "", "Four-point white-gold sparkle."),
]
for path, w, h, sl, d in kit:
    add(B, path, w, h, True, d, sl)
for kind, col in [("green", "fresh green (PLAY / confirm)"), ("blue", "sky blue (secondary)"), ("gold", "gold-orange (buy with coins)"),
                  ("red", "red (danger / give up)"), ("purple", "purple (watch ad / special)"), ("cream", "cream-white (neutral)")]:
    for state, extra in [("", "normal state"), ("_pressed", "pressed state: same button pushed down, lip thinner, slightly darker")]:
        add(B, f"ui/btn_{kind}{state}.png", 420, 170, True, f"Big glossy rounded game button in {col}, thick darker bottom lip (3D), soft top shine, plain centre for a text label; {extra}. Casual-game style like Project Makeover / Royal Match. 9-slice.", "70,60,70,70")
add(B, "ui/nav_bar.png", 1080, 230, True, "Bottom navigation bar background: deep plum-purple wooden/glass bar with a warm gold top edge and rounded top corners; full width. Horizontal 9-slice.", "120,0,120,0")
add(B, "ui/nav_selected.png", 360, 250, True, "Selected-tab plate for the bottom bar: glossy gold-orange rounded tile that rises above the bar. 9-slice.", "60,60,60,60")
for n, d in [("shop", "a tiny sweet-shop stall with a striped red-white awning and candy jars"), ("home", "a cosy Newari-style house with a terracotta roof and a lit window"), ("profile", "a round portrait of Maya (girl, teal kurta, dark braid)")]:
    add(B, f"ui/nav_{n}.png", 256, 256, True, f"Bottom-nav icon: {d}. Full-colour, chunky, readable at 90 px.")
for n, d in [("areas", "a rolled map of the shop's rooms"), ("daily", "a calendar page with a gift ribbon"), ("missions", "a clipboard with ticks"),
             ("album", "a sticker album book"), ("tasks", "a paint roller and hammer (renovation tasks)"), ("challenge", "a flag on a candy jar"),
             ("star_chest", "a small wooden chest with a gold star"), ("settings", "a gear")]:
    add(B, f"ui/feature_{n}.png", 220, 220, True, f"Round home-screen feature button: glossy coloured disc with {d} on it, thick rim. Different disc colour per button.")

# ---- 2. Icons, boosters, chests ---------------------------------------------
B = "02_icons_boosters"
icon_src = open(os.path.join(ROOT, "scripts/ui/icon_view.gd")).read()
icons = re.findall(r'^\t\t"([a-z_]+)"', icon_src, re.M)
for n in icons:
    add(B, f"icons/{n}.png", 256, 256, True, f"Small full-colour UI icon meaning '{n.replace('_', ' ')}', chunky rounded shapes, soft shading, readable at 48 px, centred with even padding (the drawing's bounding box centred in the square).")
boosters = {"undo": "Undo: a curved arrow going back", "extra_jar": "Extra Jar: an empty glass jar with a +", "shuffle": "Shuffle: two crossing arrows",
            "helper": "Haat Helper: a woven market basket", "open_jar": "Open Jar (start with one more empty jar): a jar with its lid lifting off",
            "peek": "Peek (see wrapped candies): an eye", "lucky": "Lucky Start: a four-leaf clover"}
for k, d in boosters.items():
    add(B, f"boosters/{k}.png", 320, 320, True, f"Round booster button art, {d}, on a glossy coloured disc (each booster its own colour), thick rim, icon centred. The game adds the count badge and label.")
for st, d in [("wood", "wooden treasure chest with brass bands"), ("gold", "golden treasure chest"), ("trunk", "Hajurama's old painted red tin trunk with brass corners"), ("mission", "purple gift chest with a ribbon")]:
    add(B, f"chests/{st}_closed.png", 640, 520, True, f"{d}, closed, front 3/4 view, sitting on the ground.")
    add(B, f"chests/{st}_open.png", 640, 640, True, f"Same {d}, lid open, warm glow and coins/candies inside.")

# ---- 3. Gameplay ------------------------------------------------------------
B = "03_gameplay"
candies = load("data/candies.json")["candies"]
for c in candies:
    for wrap, wd in [("own", f"its own wrapper type '{c.get('wrap', 'twist')}' (twist = twisted cellophane ends, crimp = flat crimped zigzag ends, bow = ribbon bow each side, cup = pleated paper cup, stick = lollipop stick, bare = unwrapped sugar-coated)"),
                     ("striped", "a striped paper wrapper (cosmetic)"), ("foil", "a shiny silver foil wrapper (gold foil for chocolate_gold) (cosmetic)")]:
        add(B, f"candies/{c['id']}_{wrap}.png", 256, 256, True,
            f"Candy '{c['name']}': glossy hard sweet in colour #{c['color']} with a clear {c['shape']} shape (shape must stay recognisable for colour-blind players), in {wd}. Side view, fits a 256 square with ~8% padding, consistent size with the other candies.")
add(B, "candies/hidden.png", 256, 256, True, "A mystery candy fully wrapped in plain kraft paper with a printed '?' (its colour is unknown).")
jars = {"jar_classic": "clear glass", "jar_steel": "clear glass with a steel lid band", "jar_blue": "blue-tinted glass", "jar_festival": "glass with painted festival patterns",
        "jar_frost": "frosted icy glass", "jar_gold": "glass with a gold rim", "jar_clay": "terracotta clay-look jar", "jar_rainbow": "glass with a rainbow tint"}
for k, d in jars.items():
    add(B, f"jars/{k}/top.png", 320, 120, True, f"Top (neck and rim) of a tall candy jar in {d}; front view; joins seamlessly onto mid.png.")
    add(B, f"jars/{k}/mid.png", 320, 160, True, f"Middle body of the same jar ({d}); MUST tile vertically with no seams (the game stacks it for 4-6 candies). Mostly transparent glass with side highlights.")
    add(B, f"jars/{k}/bottom.png", 320, 120, True, f"Rounded base of the same jar ({d}) with a small paper label strip; joins onto mid.png.")
for n, d in [("lid", "A screw lid for a sealed jar, plain WHITE/light grey so the game can tint it to the candy colour."),
             ("cloth", "Dhaka cloth (Nepali woven pattern) draped over a jar to cover it, front view, 320 wide."),
             ("padlock", "A brass padlock hanging on a jar."), ("gift", "A small wrapped gift box sitting in the bottom slot of a jar."),
             ("biralo_on_jar", "Biralo the ginger cat sitting on top of a jar lid, curled tail, cute."), ("shelf", "A wooden shelf plank the jars stand on, 1080 wide, horizontal 9-slice."),
             ("jar_done_glow", "Soft gold glow + sparkles for a completed jar, transparent.")]:
    w = 1080 if n == "shelf" else 320
    add(B, f"jars/overlays/{n}.png", w, 140 if n == "shelf" else 320, True, d, "120,0,120,0" if n == "shelf" else "")
themes = {"theme_asan": "Asan Bazaar morning", "theme_thamel": "Thamel evening lights", "theme_hill": "hill-village shop", "theme_tihar": "Tihar festival night with diyo lamps",
          "theme_snow": "snowy mountain shop"}
for k, d in themes.items():
    add(B, f"backgrounds/puzzle_{k}.png", 1080, 2340, False, f"Puzzle-screen background, {d}: soft-focus painted scene (shop interior or street) in the same style as the banner, deliberately CALM and low-detail with a darker, blurred middle so the jars and candies stay easy to read. No characters, no text. Portrait.")
add(B, "backgrounds/loading.png", 1080, 2340, False, "Loading screen: the shop front from the banner at dusk (striped awning, carved wood, red brick, fairy lights, candy jars, potted plants), space at the top for the logo and at the bottom for a progress bar. No text.")
add(B, "backgrounds/hub_frame_top.png", 1080, 260, True, "Soft dark gradient strip that sits behind the top bar on the home screen so currency pills read over any room.")

# ---- 4. Characters -----------------------------------------------------------
B = "04_characters"
cast = {"maya": "Maya, a cheerful young Nepali woman (about 18), shopkeeper, teal kurta, long dark braid, earrings - exactly like the girl in the banner",
        "hajurama": "Hajurama, Maya's kind grandmother, white hair in a bun, round glasses, red-maroon sari and shawl",
        "bhai": "Bhai, Maya's little brother (about 8), spiky hair, blue T-shirt, playful",
        "kanchha": "Kanchha Dai, friendly handyman neighbour (30s), moustache, flat cap, dark-blue shirt",
        "sunita": "Sunita Didi, the tea-shop neighbour (30s), hair bun with a flower, pink kurta and apron",
        "biralo": "Biralo, the shop's chubby ginger cat"}
for k, d in cast.items():
    poses = ["idle", "wave", "cheer", "worried"] if k != "biralo" else ["sit", "sleep", "walk", "stretch"]
    for p in poses:
        add(B, f"characters/{k}/body_{p}.png", 768 if k != "biralo" else 640, 1280 if k != "biralo" else 512, True,
            f"{d}. Full body, standing on the ground (feet at the bottom edge), pose: {p}. Same proportions and outfit in every pose.")
    if k != "biralo":
        for m in ["neutral", "happy", "laugh", "surprised", "worried", "grumpy"]:
            add(B, f"characters/{k}/portrait_{m}.png", 512, 512, True, f"{d}. Head-and-shoulders portrait for dialogue, mood: {m}, facing slightly toward the viewer's right.")
for a in load("data/meta.json")["avatars"]:
    aid = a["id"] if isinstance(a, dict) else a
    add(B, f"avatars/{aid}.png", 512, 512, False, f"Player avatar portrait '{aid}' (a friendly Nepali character type matching the name), round-crop friendly composition on a soft coloured background.")
for f in ["frame_plain", "frame_marigold", "frame_dhaka", "frame_gold", "frame_mountain"]:
    add(B, f"avatars/frames/{f}.png", 512, 512, True, f"Round avatar frame '{f.replace('frame_', '')}': a decorative ring with a fully transparent circular centre (inner diameter ~400 px).")

# ---- 5+. Areas ------------------------------------------------------------------
for ai, f in enumerate(sorted(glob.glob(os.path.join(ROOT, "data/areas/area_*.json"))), start=1):
    d = json.load(open(f))
    aid = d["id"]
    B = "05_area_01_02" if ai <= 2 else "06_areas_03_10"
    task_of = {}
    for t in d["tasks"]:
        for o in t.get("objects", []):
            task_of[o] = t
    if d.get("backdrop") != "interior":
        add(B, f"areas/{aid}/backdrop.png", 2048, 1707, False,
            f"Area '{d['name']}' ({d.get('subtitle', '')}): far background only (sky, distant hills/buildings, ground) for a {d.get('backdrop')} scene, 1800x1500 world. No objects that are listed separately. See _brief/layouts/{aid}_layout.png.")
    for o in d["objects"]:
        r = o["rect"]
        w, h = fit2x(int(r[2]), int(r[3]))
        base = f"Area '{d['name']}' object '{o['id']}' (kind {o.get('kind')}), box {int(r[2])}x{int(r[3])} at ({int(r[0])},{int(r[1])}) in the 1800x1500 room - see _brief/layouts/{aid}_layout.png and {aid}_after.png. Fill the box exactly; transparent around the object."
        if o["id"] in ("wall", "floor"):
            base = f"Area '{d['name']}' {o['id']} plate, fills the whole box {int(r[2])}x{int(r[3])}, opaque, no furniture. See _brief/layouts/{aid}_layout.png."
        t = task_of.get(o["id"])
        if t:
            add(B, f"areas/{aid}/{o['id']}_broken.png", w, h, o["id"] not in ("wall", "floor"),
                base + f" Renovation task '{t['name']}': {t.get('desc', '')} BROKEN state: the same object old, dusty, faded, chipped or cracked, cobwebs - clearly needs fixing, same footprint.")
            for s in t.get("styles", []):
                cols = ", ".join(f"{k} #{s[k]}" for k in ("base", "accent", "trim") if k in s)
                add(B, f"areas/{aid}/{o['id']}_{s['id']}.png", w, h, o["id"] not in ("wall", "floor"),
                    base + f" Renovated style '{s.get('name', s['id'])}' ({cols}; pattern {s.get('pattern', '')}): clean, charming, freshly restored.")
        else:
            st = o.get("style", {})
            sid = st.get("id", "style")
            add(B, f"areas/{aid}/{o['id']}_{sid}.png", w, h, o["id"] not in ("wall", "floor"),
                base + f" Always-present decor, colours {', '.join('#' + str(v) for k, v in st.items() if k in ('base', 'accent'))}.")

# ---- 7. Album and misc -------------------------------------------------------------
B = "07_album"
album = load("data/album.json")
for s in album["sets"]:
    add(B, f"album/covers/{s['id']}.png", 600, 400, False, f"Album page header art for the sticker set '{s['name']}' (theme colour #{s.get('color', 'ff9f1c')}).")
    for st in s["stickers"]:
        add(B, f"album/stickers/{st['id']}.png", 384, 384, True, f"Die-cut sticker of '{st['name']}' (set: {s['name']}), thick white sticker border, glossy, cute, rarity {st.get('rarity', 1)} (rarer = a little more ornate).")
add(B, "album/pack.png", 420, 560, True, "Foil sticker pack (sealed), colourful, with a candy-jar motif.")
add(B, "album/sticker_slot.png", 384, 384, True, "Empty sticker slot: dashed rounded outline on a faint paper square.")

# ---- write ------------------------------------------------------------------------------
brief = os.path.join(OUT, "_brief")
os.makedirs(brief, exist_ok=True)
with open(os.path.join(brief, "asset_manifest.csv"), "w", newline="") as fh:
    wr = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    wr.writeheader()
    wr.writerows(rows)
refs = os.path.join(brief, "references")
os.makedirs(refs, exist_ok=True)
for src, dst in [(os.path.expanduser("~/Downloads/Nepali Pasal Banner.png"), "style_key_banner.png"),
                 (os.path.join(ROOT, "assets/app_icon/icon_1024.png"), "style_key_app_icon.png")]:
    if os.path.exists(src):
        shutil.copy(src, os.path.join(refs, dst))
for f in glob.glob(os.path.join(ROOT, "docs/store/raw/play/*.png")):
    shutil.copy(f, os.path.join(refs, "current_ui_" + os.path.basename(f)))
from collections import Counter
print(len(rows), "assets:", dict(Counter(r["batch"] for r in rows)))
print("wrote", os.path.join(brief, "asset_manifest.csv"))

# Store assets: icon, feature graphic and screenshots

Everything you need for the Google Play and App Store listings lives in
`docs/store/`. The screenshots are ready to upload as they are. The icon and
feature graphic come as drafts plus Canva prompts, so you can make nicer
final versions there.

## What to upload where

| Asset | Google Play | App Store | File |
|---|---|---|---|
| App icon | 512 x 512, 32-bit PNG, under 1 MB | 1024 x 1024, PNG, no transparency, no rounded corners | `docs/store/icon_512.png` / `icon_1024.png` (drafts) |
| Feature graphic | 1024 x 500, JPG or 24-bit PNG, no transparency | not used | `docs/store/feature_graphic.png` (draft) |
| Phone screenshots | 2 to 8, 1080 x 1920 | up to 10 at 6.9" (1320 x 2868) | `docs/store/play/*.png` / `docs/store/appstore/*.png` |

Upload the screenshots in file order (01 to 08). The first two or three are
the ones most people see, so the order puts the core puzzle, the renovation
and the pouring action first.

| # | Caption | Shows |
|---|---|---|
| 01 | Sort sweet candies into jars! | Level 60 (SUPER HARD) with a jar mid-pour |
| 02 | Renovate Hajurama's old pasal | Home: The Old Counter, partly renovated |
| 03 | Pick your favourite style | The style picker (hang new lights) |
| 04 | Win stars and coins every level | LEVEL COMPLETE with stars and coins |
| 05 | Clever twists: cloth, locks & more | Level 200 with a dhaka-cloth jar and a padlock |
| 06 | Bring the shop back to life | Area complete: before / after slider |
| 07 | Daily gifts and challenges | Daily rewards calendar |
| 08 | Cosy Nepali themes to unlock | Tihar Night theme with festival glass |

The raw screens without captions are in `docs/store/raw/play/` (1080 x 1920)
and `docs/store/raw/appstore/` (1080 x 2346). Google Play accepts those too
if you'd rather not use caption bands.

## Canva: app icon

**Setup:** in Canva, choose *Create a design*, then *Custom size* 1024 x 1024 px.
Open *Apps*, then *Magic Media* (or *Dream Lab*). Paste the prompt, pick a
style like *3D*, *Digital art* or *Playful*, and generate. Make several and
pick the one that still reads clearly when you zoom out to thumbnail size.

**Prompt 1 (main):**

> A glossy cartoon mobile game app icon. One clear glass candy jar with a bright pink screw lid sits in the centre, filled with colourful wrapped candies of different shapes: a pink heart, a blue star, a yellow oval, a red flame, a green leaf and a gold hexagon, each in shiny twisted cellophane wrappers. A vibrant purple-to-magenta background with soft glowing bokeh lights and a few white sparkles. Thick dark outlines, soft 3D shading, bold simple silhouette, polished casual puzzle game style like Candy Crush or Magic Sort. Centred composition with space around the jar, no text, no letters, no border, no frame, square.

**Prompt 2 (candy closeup):**

> A cute glossy app icon for a candy sorting puzzle game. A single big wrapped candy shaped like a pink heart in shiny cellophane with twisted ends, slightly tilted, in front of a glass jar silhouette. Vibrant purple gradient background with soft light rays and sparkles. Cartoon 3D style, thick outlines, bright saturated colours, high contrast, readable at small size. No text, no border, square.

**Prompt 3 (Nepali shop flavour):**

> A bright cartoon app icon: a tiny Nepali corner-shop counter with a row of three glass candy jars full of colourful wrapped sweets, a string of fairy lights above and a marigold flower on the side. Warm wooden counter, vibrant purple gradient sky behind, sparkles. Glossy 3D casual mobile game style, thick dark outlines, simple and bold, readable at small size. No text, no people, no religious symbols, square.

**Before you export:**
- No words on the icon (the store shows the name next to it).
- Keep the main shape inside the middle 80%. Google Play and iOS round the corners and may crop the edges.
- Export as PNG at 1024 x 1024 for the App Store (no transparency). Then resize to 512 x 512 for Google Play (under 1 MB).
- If you like, place `docs/store/canva/jar_full.png` or a candy PNG on top of a generated background instead of using a fully generated jar. The transparent pieces are in `docs/store/canva/`.

## Canva: feature graphic (Google Play, 1024 x 500)

**Setup:** *Custom size* 1024 x 500 px. Generate the background with Magic
Media, then add the real logo on top. Upload `docs/store/canva/logo.png`
(transparent) instead of letting the AI write the title, because AI text
usually comes out misspelled.

**Prompt 1 (main, wide scene):**

> A wide banner illustration for a cosy candy sorting mobile game. On the right side, a glossy wooden shelf holds four clear glass candy jars filled with colourful wrapped candies (pink hearts, blue stars, yellow ovals, red flames, green leaves, gold hexagons), one jar with a pink lid. Bright wrapped candies float and sparkle around the jars. The left half is a clean vibrant purple-to-magenta gradient with soft bokeh lights, left empty for a logo. In the far background, faint silhouettes of Kathmandu-style brick houses with sloped roofs and distant snowy Himalayan peaks. Glossy cartoon 3D casual game style, thick outlines, saturated colours, warm and cheerful. No text, no letters, no people, no temples, no religious symbols, landscape 1024x500.

**Prompt 2 (shop front):**

> A wide cheerful cartoon banner: the front of a small colourful Nepali corner shop (pasal) with red brick pillars, a carved wooden beam, a striped awning, fairy lights and a counter full of glass candy jars with bright wrapped sweets. A friendly young shopkeeper girl in a teal kurta waves from behind the counter on the right side. The left third is a soft purple gradient sky with sparkles, left empty for a logo. Glossy 3D casual mobile game art, thick outlines, vibrant colours, cosy and inviting. No text, no religious symbols, landscape 1024x500.

**Before you export:**
- Keep the logo and anything important away from the edges (about 15% margin). Google Play sometimes crops or covers parts of the graphic.
- No device frames, no "#1" or "Best game" claims, no prices or "free" badges.
- Export as PNG or JPG at exactly 1024 x 500, no transparency.

## Canva: helpful pieces

`docs/store/canva/` has transparent PNGs to drop into any Canva design:

- `logo.png`: the PASAL SORT logo (1500 x 620)
- `jar_full.png`: a lidded jar full of heart candies
- `candy_01_lapsi.png` to `candy_12_chocolate_gold.png`: every candy, large

## Cultural check (for any generated art)

Keep it friendly and respectful. Use no temples, stupas, deities, prayer flags,
mantras or other sacred imagery, no real brand logos, and no caricatures of
people. Shops, houses, mountains, marigolds, fairy lights and food are all fine.

## Regenerating the screenshots

When the game's look changes, rebuild everything in two steps:

```
# 1. Raw screens at store size, plus the transparent Canva art (needs a window).
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 540x960 --script res://tools/store_shots.gd -- --out=res://docs/store/raw

# 2. Caption bands, frames, Apple sizes, draft icon and feature graphic (needs Pillow).
python3 tools/store/compose_store_shots.py
```

- Captions are in `CAPTIONS` at the top of `tools/store/compose_store_shots.py`.
- The screens and the game state for each are set up in `_shots()` in `tools/store_shots.gd`.
- The tool renders off-screen at the full store size, so the window can stay small. It uses its own save file, never yours.

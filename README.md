# Pasal Sort: Sort & Renovate

A cosy Nepali sort puzzle for mobile (Godot 4, GDScript, 2D, portrait).
Maya comes home to her grandmother's dusty pasal in Chiya Tole. Tap a jar,
tap another, and sort the candies until every jar holds one kind. Every
win earns a star; stars renovate the shop, the family home above it and,
later, new branches across Nepal. Infinite levels, 10 areas.

See PROGRESS.md for the build status and how the pieces fit together.

## Run

- **Editor:** open `project.godot` in Godot 4.3+ (tested on 4.7.2) and press Play.
  The mouse works as touch (`emulate_touch_from_mouse`). Escape acts as the Android back button.
- **Command line:**
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --path .
  ```
  Useful flags after `--`: `--safe-debug` (fake notch insets), `--ad-fail` (every mock ad fails).

## Tests

```
# Every suite (smoke, meta, relaunch, generator); --quick skips the generator.
godot --headless --path . --script res://tests/run_all.gd

# Renovation rules, area/story data, save migration, debug clock, first
# renovation end to end and the area-complete flow.
godot --headless --path . --script res://tests/meta_test.gd

# Everything important: rules, solver, lives, tutorial, level 1 solved by taps,
# boosters, resume, save/load, ads, IAP, shop, achievements, back button, layout.
godot --headless --path . --script res://tests/smoke_test.gd

# Levels 31-400: all solvable and deterministic; SUPER HARD > normal > easy.
godot --headless --path . --script res://tests/generator_test.gd

# A real two-process relaunch: board, undo history, coins, cosmetics, lives.
godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=write
godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=verify

# Every script and scene compiles.
godot --headless --path . --script res://tools/parse_check.gd

# Screenshots for visual review (needs a window).
godot --path . --resolution 540x960 --script res://tests/capture.gd -- --out=/tmp/shots --set=hub|reno|play|twists|popups|themes|boot|extra

# Contact sheets of every renovation object, the cast and all 10 areas.
godot --path . --resolution 1080x1920 res://tools/art_sheet.tscn -- --out=/tmp/sheets
```
All tests use their own save files, never the player's `user://save.json`.

## Layout

```
data/            JSON tuning: candies, difficulty ramp, economy, achievements,
                 decorations/avatars/tips, authored levels 1-30
scripts/core/    autoloads (no class_name): Save, Game, Currency, Progression,
                 Lives, Booster, Achievement, Audio, Haptics, Pool, VFX,
                 Screen, Ad (mock), IAP (mock)
scripts/systems/ Board (rules), Solver (DFS + hashing), LevelGenerator, ToneSynth
scripts/gameplay/ Gameplay (level flow), BoardView (jars + animation),
                 TutorialDirector
scripts/ui/      hub, pages, popups, win panel, settings, buttons, chips
scripts/visuals/ code-drawn placeholder art (jar, candy, shopkeeper, pasal, ...)
scenes/components/ jar_visual.tscn, candy_visual.tscn, ... (swap for final art)
tools/           author_levels.gd (curates levels 11-30), parse_check.gd
tests/           smoke_test, generator_test, relaunch_check, capture
```

## Tuning

- Jar-count ramp, rhythm (HARD every 5th, SUPER HARD every 10th), twist
  introduction levels and generator budgets: `data/difficulty.json`.
- Rewards, booster prices, lives, shop items and cosmetics: `data/economy.json`.
- Levels 1-10 are hand-made in `data/levels_authored.json`; 11-30 were curated
  with `tools/author_levels.gd` and are frozen in the same file.

## Replacing placeholder art

All art is drawn in code. Each visual lives in its own scene
(`scenes/components/jar_visual.tscn`, `candy_visual.tscn`,
`character_visual.tscn`, ...). Renovation objects pick up a PNG
automatically: `res://assets/art/areas/<area id>/<object id>_<variant>.png`
where variant is `broken` or the style id from the area JSON. Gameplay talks to them
only through their public methods (`setup`, `slot_position`, `set_selected`,
`close_lid`, `set_cloth`, `set_lock`, `reveal`, ...), so sprites can replace
the `_draw()` code without touching gameplay.

## Ads and purchases

`AdManager` and `IAPManager` are mocks: a full-screen "TEST AD" overlay and a
"TEST PURCHASE" confirmation. A real SDK adapter replaces only
`AdManager.show_rewarded()` / `show_interstitial()` and `IAPManager.buy()`.
The game is fully playable without ads or purchases.

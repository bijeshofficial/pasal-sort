# PASAL SORT: SORT & RENOVATE — progress

Read this first at the start of every session. Godot 4.7.2 at
`/Applications/Godot.app/Contents/MacOS/Godot` (project targets 4.3+).

## Status by phase

| Phase | Scope | State |
|---|---|---|
| 1 Core puzzle | jars, candies, moves, completion, undo, stuck, win | done (baseline) |
| 2 Levels | authored 1-30, seeded generator + solver, ramp, sawtooth, twists 1-4, resume | done; level_report tool added |
| 3 Hub & core meta | loading shutter, nav, top bar, lives, in-level boosters, tutorial, settings | done |
| 4 Renovation | stars, areas 1-10 data, Home pan/zoom, tasks, style picker, dialogue | done |
| 5 Economy & shop | pre-level boosters, start card, Dami streak, iap_products, No Ads, starter pack | todo |
| 6 Daily loop | calendar, missions + chest, daily challenge, chests, achievements 30+ | todo |
| 7 Live features | album, weekly event, Bazaar Race, treasure streak, cat paw, gift box, orders, move limit, Haat Helper | todo |
| 8 Polish | i18n en/ne, accessibility, analytics, debug menu, QA screenshots | todo |

## Decisions

- The brief says "current repository", but sessions open in neuron-nest (a
  website). The game lives in its own repo, `~/Neuron Projects/pasal-sort`.
- UI keeps the glossy casual-game look (purple/blue backdrops, Lilita One,
  glossy buttons). The user picked it over a flat cream/brown UI. The warm
  Kathmandu palette (wood, brick, marigold, teal) is used for the renovation
  scenes and characters, not for UI chrome.
- The renovation meta replaces the old "decoration every 10 levels" system.
  Save v1 -> v2 migration grants 1 star per completed level and drops the
  old decoration fields.

## How it fits together (meta)

- Every win: 1 star + coins (`ProgressionManager.complete_level`).
- `RenovationManager` (autoload, scripts/meta/) keeps task state per area;
  areas are `data/areas/area_NN.json`, stories `data/story/area_NN.json`.
- Home (`scripts/ui/home_page.gd`) overlays the `HomeView` (pan/zoom) that
  the Hub draws full-screen behind its bars. `AreaScene` builds an area
  from data: `AreaBackdrop`, `RenoObject`s drawn by `RenoArt`, the cast
  (`CharacterVisual` / `CharacterArt`), ambient life and time-of-day light.
- Task flow: TaskPanel -> stars fly -> poof -> StylePicker -> dialogue ->
  coins; area complete -> BeforeAfter -> ChestPopup -> outro -> page turn.
- Art review: `godot --path . --resolution 1080x1920 res://tools/art_sheet.tscn -- --out=DIR`.
- Tests: `godot --headless --path . --script res://tests/run_all.gd [-- --quick]`.

## Next step

Phase 5: Level start card with pre-level boosters (Open Jar, Peek, Lucky
Start) + Dami streak, iap_products.json, No Ads + starter pack, shop
sections, jar skins Clay-look and Rainbow, interstitial "after level 20".

## Known issues

- None recorded yet.

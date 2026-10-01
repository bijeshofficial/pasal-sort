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
| 5 Economy & shop | pre-level boosters, start card, Dami streak, iap_products, No Ads, starter pack | done |
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
- Economy: `data/economy.json` (prices, starting inventory, streak rewards,
  fail offers, interstitial caps) and `data/iap_products.json` (mock store).
- Level start card (`scripts/ui/level_start_card.gd`) from level 12: goal,
  Dami streak meter, max 2 pre-level boosters, used only when the level starts.
- `StreakManager`: Dami streak (free pre-boosters) and the 7-win treasure
  streak (Hajurama's Trunk). Give up -> "So close!" second chance once.

## Next step

Phase 6: daily reward calendar (7-day), daily missions + mission chest,
daily challenge (date-seeded, calendar of completed days), level chest every
10 levels (replace the milestone gift) and star chest every 15 stars spent,
profile stats + 30+ tiered achievements, avatar frames on the profile.

## Known issues

- None recorded yet.

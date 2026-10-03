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
| 6 Daily loop | calendar, missions + chest, daily challenge, chests, achievements 30+ | done |
| 7 Live features | album, weekly event, Bazaar Race, treasure streak, cat paw, gift box, orders, move limit, Haat Helper | done |
| 8 Polish | i18n en/ne, accessibility, analytics, debug menu, QA screenshots | done |

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

- 2026-10-02 (user feedback): no interstitial ads, rewarded ads only (No Ads
  product removed); no real-money products on Android (no Play Store
  merchant account in Nepal), paid store kept for iOS (`store_platforms` in
  iap_products.json; `--store` shows it on desktop); weekly events and the
  Bazaar Race removed; Tasks moved to the right feature column with a full-
  width PLAY; new bottom nav; calm gameplay background.
- 2026-10-04 (user feedback round 2): only the top modal is visible
  (`ScreenManager._refresh_stack`; meta `modal_overlay` lets the one below
  show, used by the dialogue box), so stacked popups never show two
  ribbons; chest rewards wrap 4 per row and stickers merge into one tile;
  start card shows streak freebies as gold FREE slots with a plain hint and
  a new flame + 3-step streak meter; slow cloud drift on Home; auto-sort
  finishes the level once every unfinished jar holds one candy type and
  nothing is hidden/sealed/cat (`Gameplay.autosort_moves`, state BUSY while
  it plays, skipped in tutorials or when it would break a move limit).
  Stuck now means no reachable progress (`Board.is_stuck`: small search for a
  move that completes a jar, reveals a candy or lifts a seal), so endless
  back-and-forth swaps trigger the Stuck popup. New chest art (domed planked
  chest, bands, keyhole, loot); Hajurama's Trunk is red with brass.

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
- Daily: `DailyManager` (calendar, missions picked by date, date-seeded
  challenge played in Gameplay `mode = "daily"`), `ChestManager` (level chest
  every 10 levels, star chest per 15 stars spent), data in `data/daily.json`
  and `data/chests.json`. Game events go through `GameManager.emit_event`.
- Achievements: 32 families with tiers (`data/achievements.json`).
- i18n: `data/i18n/strings.csv` (keys, en, ne, _review). Regenerate after
  adding strings: `python3 tools/i18n_extract.py [--merge DIR_OF_JSON]`, then
  `godot --headless --path . --import`. Static code translates with
  `UIKit.t()`. Lilita One falls back to Baloo 2 for Devanagari.
- Settings: language, colour-blind pips on candies, text size (rebuilds the
  screen), credits, privacy, double-confirm reset. 5 taps on the version
  opens `DebugMenu` (debug builds): level jump, currencies, clock, area,
  tutorials, level report, solver solution, analytics summary.
- `AnalyticsManager`: JSON lines in user://analytics.log, no personal data.
- Theme: `assets/ui/game_theme.tres` (built by tools/build_theme.gd) is the
  project-wide fallback; UIKit styles everything in code.
- Live: `AlbumManager` (`data/album.json`).
- Popups opened from another popup close it with `Popups.close_id(id)`:
  lambdas capture locals by value, so a captured popup variable is null.
- Twists: the cat's route is planned from a known solution (solvable by
  construction) and stored with `solution_moves`; gift boxes are cosmetic for
  the rules; orders and move limits come from `LevelGenerator.decorate`.

## Next step

All 8 phases are built. Most valuable next steps:
1. Native-speaker review of the Nepali story lines (marked `_review` in
   data/i18n/strings.csv) and a pass over UI wording.
2. Real art: drop PNGs into assets/art/areas/<area>/<object>_<variant>.png
   and replace CharacterArt/RenoArt placeholders; record real audio.
3. Device testing on Android (performance of the full-screen Home scene,
   safe areas, back button), then real ad/IAP/notification adapters.
4. Polish areas 4-10 (they reuse generic drawers and have 1-line stories).

## Known issues

- Generation: levels 31-400 generate in ~17 s total on an idle M3 (worst
  case ~9k solver nodes per level).
- Nepali story lines are machine-drafted and need native review.
- Android export not built here (no SDK/keystore configured in this session);
  package id is com.neuronnest.pasalsort (chosen earlier instead of the
  brief's com.example placeholder).
- Another session added store-screenshot tooling (docs/store, tools/store_shots.gd,
  GameManager.capture_mode); it is left uncommitted for its owner.

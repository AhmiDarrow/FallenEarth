---
name: v091-audio-wiring
description: Audio bug fix — all 12 .ogg .import files now loop=true, MusicManager + AmbientAudio wired into MainMenu/HubWorld/SettlementInterior/RiftInstance/TacticalCombat/WorldMapScreen, biome name→key mapping added, OptionsMenu live volume wired.
---

## Current Focus: v0.9.1 — Audio Wiring Bug Fix (HOTFIX)

### Bug
"Sounds does not work." Two root causes:

1. **All 12 audio `.import` files had `loop=false`.** Ambient loops
   and music themes each played once and went silent. The `_loop`
   files (`wind_loop`, `crickets_loop`, `birds_loop`, `hot_wind_loop`,
   `water_drip_loop`, `eerie_drone`, `industrial_hum`) obviously need
   to loop, and so do music themes (3–5 min tracks need to repeat).

2. **MusicManager + AmbientAudio autoloads were never called.** The
   systems existed and were even registered in `project.godot`
   `[autoload]`, but no scene's `_ready` ever called `play_track()`
   or `play_biome()`. So even with `loop=true`, the audio bed
   literally never started.

A third smaller issue: `OptionsMenu.gd` saved the volume slider
values to `user://options.cfg` but never pushed them live to the
managers, so changes only took effect on the next launch.

### Files Changed

**`.import` flags (12 files) — set `loop=true`:**
- `audio/cave/water_drip_loop.ogg.import`
- `audio/combat/combat_theme.ogg.import`
- `audio/desert/hot_wind_loop.ogg.import`
- `audio/exploration/exploration_theme.ogg.import`
- `audio/forest/birds_loop.ogg.import`
- `audio/forest/crickets_loop.ogg.import`
- `audio/main_menu/main_menu_theme.ogg.import`
- `audio/rift/eerie_drone.ogg.import`
- `audio/rift/rift_theme.ogg.import`
- `audio/settlement/settlement_theme.ogg.import`
- `audio/urban/industrial_hum.ogg.import`
- `audio/wasteland/wind_loop.ogg.import`

Cache: `.godot/imported/*.oggvorbisstr` deleted and re-imported via
`godot --headless --import` so the binary cache matches the new
`loop=true` flag.

**Audio systems:**
- `scripts/AmbientAudio.gd` — added `_biome_aliases` dict + `map_biome(name)`
  helper. The world has 10 biomes (Ash Wastes, Rust Canyons, Neon
  Bogs, Scorched Plains, Ironwood Thicket, Glass Dunes, Corpse
  Fields, Stormspire Highlands, Toxin Marshes, Dead City Outskirts)
  but only 6 ambient bed keys — the helper maps each world name to
  the closest bed. Added a `settlement` bed key that reuses the
  urban hum for the inside-town soundscape.

**Scene wiring (6 scripts):**
- `scripts/MainMenu.gd` — starts `main_menu` music, stops ambient
- `scripts/HubWorld.gd` — starts `exploration` music, ambient bed
  follows the current hex biome. New helper `_start_audio_for_current_region()`
  is called from both `_ready` and `_try_cross_edge` so the bed
  changes when the player walks across a region border.
- `scripts/SettlementInterior.gd` — switches to `settlement` music
  + settlement ambient
- `scripts/RiftInstance.gd` — switches to `rift` music + rift drone
- `scripts/TacticalCombat.gd` — switches to `combat` music, mutes
  ambient bed
- `scripts/WorldMapScreen.gd` — `exploration` music, mutes ambient
  (the world map is a hex-sphere overview, not a tile)
- `scripts/ui/OptionsMenu.gd` — `_on_music_changed` and
  `_on_sfx_changed` now call `MusicManager.set_volume` /
  `AmbientAudio.set_volume` so changes are audible immediately.

### New Test
`tools/smoke_audio.gd` — 12 checks:
- All 12 `.import` files contain `loop=true`
- All 12 AudioStream resources load successfully
- `map_biome()` maps all 10 world biome names correctly (and
  empty → `""` for stop)
- `MusicManager.play_track("main_menu")` stores the track
- `AmbientAudio.play_biome / stop_all` round-trip works
- All 6 wired scenes reference both `MusicManager` and `AmbientAudio`

### Verification

```bash
& godot --headless --import                       # rebuild .oggvorbisstr
& godot --headless --path . -s tools/smoke_audio.gd    # 12/12 pass
& godot --headless --path . -s tools/smoke_polish.gd   # 7/7 pass
& godot --headless --path . -s tools/smoke_ambient.gd  # 5/5 pass
& godot --headless --path . -s tools/smoke_combat_feedback.gd  # 4/4 pass
& godot --headless --path . -s tools/smoke_qol.gd      # 4/4 pass
& godot --headless --path . -s validate_scripts.gd     # OK
```

### Notes for Next Milestone

- Ambient bed pool is still small (6 keys for 10 world biomes).
  Add a `Glass Dunes` bed, a `Stormspire Highlands` wind bed, and
  a dedicated `Settlement` interior bed (the urban hum is a
  placeholder) when new audio assets are sourced.
- HubWorld does not start audio before `_local_map` is loaded
  (it skips if the map is empty), so the first Hex you spawn in
  triggers the bed. That's correct behavior.
- MusicManager crossfade uses `set_parallel(true)` + `chain()` —
  on a fast scene change the old player can be `queue_free`d
  before the fade completes, which is fine (next play_track
  rebuilds it).
- The audio_bus_layout is the default (just `Master`). If we
  want per-bus SFX/music sliders, add a `default_bus_layout.tres`
  with Music and SFX busses and switch the players to the right
  bus.

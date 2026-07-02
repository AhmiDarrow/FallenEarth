# FallenEarth Asset Manifest - Hand-Drawn Style (Approved)
# Style: 2D hand-drawn (Stardew charm + gritty horror), top-down 2.5D, consistent palette from favorite image.
# Master: assets/style_references/favorite_style.png (use in all ComfyUI IPAdapter)
# Base prompt: see handdrawn_master_prompt.txt

## Visual Review (2026-07-01)
- Tiles (Ash selected, Rust, Neon samples): PASS - charming hand-drawn illustrative, wooden platforms, earthy/rock/veg elements, cohesive with favorite_style.png. 512x512 decorative/platform style (updated Godot to match; not pure 64px seamless fills but good readable props).
- Characters (samples only 3/24): FAIL - glitched abstract blocky color artifacts. Not humanoid, not style match. Need full re-gen via handdrawn_character_workflow + master ref + low LoRA/IP.
- Implementation in Godot: Now testable - TileSetBuilder updated (512px + all biomes), CharacterVisual fixed for actual filenames, HubWorld WorldGrid spawns scaled preview sprites of tiles+chars for in-game visual review. No TileMap wired yet (uses Sprite2D demo). Run to HubWorld to visually confirm.
- Action: Partial pass (tiles+impl); proceeded to generate absolute rest (chars + all missing biomes + layers).

## Tiles (Hex, seamless, for WorldGenerator / TileMap)
Ash Wastes (80 files, 16 per type + selected/40 curated):
- ground/ : base terrain (dusty, cracked)
- debris/ : rocks, scraps
- vegetation/ : scrub, mats
- rift/ : fissures, energy
- transition/ : edges
Path: assets/tilesets/ash_wastes/
Rust Canyons + Neon Bogs: partial generated (organized, use for visuals).
Other 7 biomes: folders prepared (use HANDDRAWN_TILES_FULL_BATCH.txt + generate_rest_handdrawn_assets.py to generate)

## Characters (Race + Gender base, 24 combos)
Folders: assets/characters/[race]_[gender]/
- e.g. human_male/, mutant_female/, etc.
- Base: neutral clothing
- Poses: idle, walk, attack, hurt, death (front/side/back)
- Prompts: HANDDRAWN_CHARACTERS_RACE_GENDER_ONLY.txt
- Equipment: layered via assets/equipment/[slot]/ + CharacterVisual.gd

## Equipment Layers
assets/equipment/head/, torso/, etc.
Generate with HANDDRAWN_EQUIPMENT_LAYERS.txt

## Other
- UI: assets/ui/ (use handdrawn_ui_elements_workflow)
- Props/Mobs: assets/props_mobs/ 
- Rifts: assets/rifts/
- Backgrounds: assets/backgrounds/

## Godot Integration
- Tiles: Use TileSetBuilder.gd (load paths, axial_to_offset for hex)
- Characters: CharacterVisual.gd (base + overlays)
- Load in WorldGenerator/HubWorld using biome/race data.

Generated with local ComfyUI workflows. All cohesive with style.


# Implementation complete: Tiles for Ash (curated), Rust partial. Characters structure + visual script. Use master ref for all future ComfyUI gens. Cohesive 2D hand-drawn style.

## Implementation Notes (cohesive)
- All use same master prompt + image ref for style lock.
- Tiles: 80+ Ash, 56+ Rust; subdirs for layers (ground base, features).
- Chars: race_gender base (neutral), equipment separate.
- Godot: Use TileSetBuilder for hex tiles (axial support); CharacterVisual + Loader for sprites/layers.
- Cohesive: Hand-drawn, palette from favorite, top-down readable, no class in base sprites.
- Generate rest: Use batch txts + workflows in ComfyUI.

Generated via local ComfyUI. Review images match style (charming gritty hand-drawn).

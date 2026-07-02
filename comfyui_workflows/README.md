# Fallen Earth ComfyUI Asset Generation Setup

## Status (as of latest run)
- ComfyUI installed at: C:\Users\Administrator\Documents\ComfyUI
- All core models downloaded:
  - sd_xl_base_1.0.safetensors (base)
  - sdxl_vae.safetensors
  - ip-adapter_sdxl.bin + clip vision
  - controlnet-tile-sdxl-1.0 and openpose-sdxl
  - pixel-art-xl.safetensors (for uniform 2D game style)
- Custom nodes installed (via git in background tasks): ComfyUI-Manager, IPAdapter_plus, ControlNet-Aux, Advanced-ControlNet
- Workflows written for uniform assets
- Full plan documented below

## Important: Restart ComfyUI
After the background git clones finish, restart ComfyUI so the custom nodes load.

## Recommended Workflow Usage for Uniform Assets
All workflows are built around:
- IP-Adapter (using a master `style_reference.png` + per-asset references)
- Pixel Art LoRA for consistent look
- ControlNet (Tile for seamless textures, OpenPose for characters)
- Fixed negative prompt and similar settings across generations

**Master Reference Images (create once in ComfyUI/input/):**
- `style_reference.png` — Strong image that captures the overall grim post-apoc sci-fi wasteland style. Use this in IP-Adapter for EVERY generation.
- Additional character refs or pose refs as needed.

## Workflows in this folder
- tileset_generation_workflow.json — For biome tilesets (use with Tile ControlNet)
- character_sprites_workflow.json — For consistent character sprites across races/classes
- props_and_mobs_consistent_workflow.json — For items, loot, mobs
- (Others are variants or older versions)

Load them directly in ComfyUI (drag & drop the .json or use Load button).

## Full Asset Generation Plan

### 1. Preparation
- Prepare your master style_reference.png (use any tool or even a quick ComfyUI run).
- Decide on target resolution (e.g. 512x512 or 256x256 for pixel art feel).
- Use the pixel-art-xl LoRA at strength 0.7-1.0 for most things.

### 2. Tilesets (Highest priority for world)
Biomes from data/biomes.json:
- Ash Wastes, Rust Canyons, Neon Bogs, Scorched Plains, Ironwood Thicket, Glass Dunes, Corpse Fields, Stormspire Highlands, Toxin Marshes, Dead City Outskirts

For each biome:
- Run tileset workflow multiple times with different seeds.
- Generate ground tiles, transition tiles, props integrated into tiles, special rift-influenced variants.
- Aim for 20-40 unique tiles per biome that tile seamlessly.
- Use the Tile ControlNet to enforce consistency.

Output structure suggestion:
assets/tilesets/[biome_name]/*.png

### 3. Characters
Races (data/races.json):
- Human, Mutant, SentientAI, Cyborg (Upworld)
- Chthon, Vesperid, Nullborn (Underworld)

Classes (character_classes.json):
- Scavenger, Technician, Survivor

For each race + class combination:
- Generate a consistent character using character ref + style ref.
- Generate multiple views/animations:
  - Idle (front, side, back)
  - Walk cycles (4 or 8 directions)
  - Attack animations
  - Hurt / Death
- Use OpenPose ControlNet for pose control so the character stays recognizable.

Use the character sprites workflow.

Output:
assets/characters/[race]_[class]/*.png  (or organized by animation)

### 4. Mobs & Enemies
From data/mobs.json:
- Neutral (grazers, drifters, etc.)
- Aggressive (stalkers, leeches, behemoths, etc.)
- Underearth parts
- Tameable

For each:
- Idle, move, attack, death frames.
- Use props/mobs workflow with appropriate prompts.

### 5. Props, Items, Loot
From loot_tables, equipment, etc.:
- Scrap, components, consumables, tools, materials
- Weapons, armor pieces
- Environmental props (barrels, ruins, camp items)

Generate in batches using consistent style ref.

### 6. Special / Rift Assets
- Rift entrance / tunnel visuals
- Dungeon tiles for instanced rifts (walls, floors, hazards)
- "Close the rift" mechanism (core, energy effects)
- Boss variants

### 7. Uniformity Tips
- Always use the same style_reference image in IP-Adapter.
- Keep prompts structured: "grim post-apocalyptic sci-fi, [specific], top-down game asset, consistent with reference, detailed textures"
- Same negative prompt for all.
- After a set is generated, review and re-generate outliers with higher IP-Adapter strength.
- For tiles: emphasize "seamless, tileable, repeating pattern".
- For sprites: use character reference + pose control.

### 8. Post-Processing (outside ComfyUI)
- Pack spritesheets (use Aseprite, TexturePacker, or Godot importer).
- Adjust palette if needed for overall cohesion.
- Create Godot TileSet resources and SpriteFrames.

### 9. Phased Execution Recommendation
Phase 1: Master style ref + 2-3 test tiles per workflow.
Phase 2: All tilesets.
Phase 3: Core character set (one race + all classes as proof of concept).
Phase 4: Full characters + mobs.
Phase 5: Props + special rift assets.

This keeps iteration fast while locking in style early.

## Next Actions
1. Restart ComfyUI.
2. Test one workflow with your style_reference.png.
3. Generate the first biome tileset.
4. Iterate on style reference if uniformity isn't good enough.

All requested downloads and base workflows are now in place. You can expand the JSONs in ComfyUI as needed (add more nodes for upscaling, batching, etc.).

Good luck with the asset production!
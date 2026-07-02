# Custom Hand-Drawn Workflows for Fallen Earth (2D Hand-Drawn Style)

**Approved Style:** 2D hand-drawn illustration blending Stardew Valley charm + gritty cosmic horror. Readable top-down 2.5D game assets.

## Master Style Reference (Do this first)
1. Load `style_reference_generator.json`
2. Use the prompt from `handdrawn_master_prompt.txt`
3. Generate several (batch 4+)
4. Pick the best one that captures the hand-drawn look.
5. Save as `master_style.png` or `style_reference.png` in ComfyUI/input/

Use this image in the **IPAdapter** node of all workflows below (strength 0.8–0.95) for strong style consistency.

## Workflows Overview

### Core Production
- **handdrawn_tileset_workflow.json**  
  Seamless top-down hex tiles for biomes.  
  **Batch size: 4**  
  Prompt: Replace `[BIOME]`  
  Output prefix: `FallenEarth_Tile_Handdrawn`

- **handdrawn_character_workflow.json**  
  Consistent character sprites (front/side/back, idle/walk/attack).  
  Use OpenPose ControlNet + character ref image for pose consistency.  
  **Batch size: 4**  
  Prompt: Replace `[RACE] [CLASS]`  
  Output prefix: `FallenEarth_Char_Handdrawn`

- **handdrawn_props_mobs_workflow.json**  
  Creatures, items, environmental props.  
  **Batch size: 4**  
  Output prefix: `FallenEarth_Prop_Handdrawn`

### Special Purpose
- **handdrawn_background_workflow.json**  
  Large atmospheric backgrounds, menu screens, parallax layers.  
  **Batch size: 4**  
  Good for wide compositions.  
  Output prefix: `FallenEarth_Background_Handdrawn`

- **handdrawn_ui_elements_workflow.json**  
  Icons, buttons, cursors, HUD elements, inventory items (UI).  
  **Batch size: 6** (higher for quick icon sets)  
  Clean square composition, high contrast.  
  Output prefix: `FallenEarth_UI_Handdrawn`

- **handdrawn_rift_workflow.json**  
  Rift interiors, close-the-rift mechanisms, special dungeon tiles.  
  **Batch size: 4**  
  Cosmic horror / unstable energy focus.  
  Output prefix: `FallenEarth_Rift_Handdrawn`

- **handdrawn_general_asset_workflow.json**  
  Flexible catch-all for bosses, large creatures, special effects, unique props.  
  **Batch size: 3** (better for bigger/more detailed pieces)  
  Output prefix: `FallenEarth_Asset_Handdrawn`

## Recommended Settings
- **Base Model:** sd_xl_base_1.0.safetensors
- **LoRA:** pixel-art-xl.safetensors at low strength (0.15–0.25) — we want hand-drawn, not pixel
- **IPAdapter:** Master style image at 0.8–0.95 strength
- **ControlNet:** 
  - Tile for tilesets & backgrounds
  - OpenPose for characters
- **Resolution:** 512x512 (standard) or 768x768 (more detail)
- **Steps:** 25–35
- **CFG:** 6–8
- **Sampler:** euler or dpmpp_2m
- **Negative:** Use the one baked into the workflows (or the standard one)

## Workflow Usage Tips
1. Always load your `master_style.png` into IPAdapter.
2. Generate in small sessions per category for consistency.
3. After generation, upscale keepers separately if needed (4x-UltraSharp or similar).
4. Organize output:
   - `assets/tilesets/[biome]/`
   - `assets/characters/[race_class]/`
   - `assets/ui/`
   - `assets/rifts/`
   - `assets/props_mobs/`

## Next Steps After Asset Generation
- Import into Godot (TileSet resources, SpriteFrames)
- Test in WorldGeneration, HubWorld, RiftInstance, CharacterSelection
- Create a style harmonization pass if any drift appears (low denoise img2img with master ref)

All workflows are designed for the approved hand-drawn style. Generate your master reference first, then dive into tilesets and characters.

Good luck building the Fallen Earth visual identity!

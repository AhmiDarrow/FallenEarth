# FallenEarth ComfyUI Asset Generation - Restart Notes (2026-07-01)

## Status at session end
- **ComfyUI**: Was running on localhost:8188 with working VIT-G IPAdapter pipeline (using master_style.png + pixel-art-xl LoRA + SDXL).
- **Generation method**: Direct /prompt API calls with explicit node graphs (batch_size 3-4). All generations use IPAdapter for style lock + lore-driven prompts.
- **Tilesets generated**: Strong coverage
  - All 10 biomes have at least base tiles.
  - 4 variants each for: Ironwood Thicket, Glass Dunes, Corpse Fields, Stormspire Highlands, Toxin Marshes, Dead City Outskirts, Scorched Plains (plus Ash Wastes, Rust Canyons, Neon Bogs from earlier).
  - Total ~33 tile PNGs in assets/tilesets/.
- **Characters**: Only the original 3 (human_scavenger, mutant_technician, cyborg_survivor). Full race/class set (8 races × 3 classes) was queued with the correct pipeline but likely still pending / not finished when session was interrupted.
- **Mobs/Props**: Limited (a few props existed pre-session; some mobs were queued).
- **Style reference**: master_style_reference.png + tests present in assets/style_references/.
- **Queue at end**: ~16 pending (killed during cleanup).

## Key files for next session
- `comfyui_workflows/`
  - `style_reference_generator.json`
  - `tileset_*` and `character_sprite_*` workflows (JSON)
  - `MASTER_STYLE_REFERENCE_PROMPT.txt`, `ASH_WASTES_TILES_READY_PROMPTS.txt`, `character_prompts.txt`, `tileset_prompts.txt`
  - Various STEP / EXECUTE / PLAN .txt and .md files with copy-paste instructions
- `data/biomes.json`, `races.json`, `character_classes.json`, `mobs.json`
- `assets/` (target for all outputs)
- `lore.md`

## Working recipe (use this)
1. Ensure ComfyUI running with:
   - sd_xl_base_1.0.safetensors
   - pixel-art-xl.safetensors (in loras)
   - ip-adapter_sdxl.bin (in ipadapter)
   - CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors (in clip_vision)
   - ComfyUI_IPAdapter_plus custom node
2. master_style.png must be in ComfyUI/input/
3. Use this node structure (proven):
   - 1: CheckpointLoaderSimple (sd_xl_base...)
   - 2: LoraLoader (pixel-art-xl 0.82-0.85)
   - 3: IPAdapterUnifiedLoader (model from 2, preset="VIT-G (medium strength)")
   - 4: LoadImage ("master_style.png")
   - 5/6: CLIPTextEncode (positive/negative with "consistent with master style reference")
   - 7: EmptyLatentImage (512x512, batch_size=3 or 4)
   - 8: IPAdapter (model=3[0], ipadapter=3[1], image=4, weight~0.78-0.82)
   - 9: KSampler (model=8[0], ...)
   - 10: VAEDecode
   - 11: SaveImage (prefix="FallenEarth_Tile_XXX" or "FallenEarth_Char_RaceClass")
4. Prefixes help auto-sorting during copy:
   - Tiles: FallenEarth_Tile_BiomeName
   - Characters: FallenEarth_Char_Race_Class
   - Mobs: FallenEarth_Mob_Name

## Next steps for new session
- Restart ComfyUI cleanly (`python main.py --listen` from the .venv).
- Clear queue if needed (`/queue` DELETE or /interrupt).
- Re-generate / finish the character sprites (the 8 races x classes) using the working payload above.
- Generate remaining mobs + more prop variations.
- Run the copy script from previous (or the one in comfyui_workflows).
- Organize final assets (perhaps rename or make sprite sheets).
- Then move to game side (WorldGenerator, etc.).

## Cleanup performed
- Background jobs stopped.
- Final sync of generated PNGs to assets/.
- Comfy processes checked (may need full restart in new session).

This session made excellent progress on **tilesets** (uniform style via IPAdapter + master ref). Characters and mobs are the main remaining items for the asset generation phase.

Good luck in the new session!

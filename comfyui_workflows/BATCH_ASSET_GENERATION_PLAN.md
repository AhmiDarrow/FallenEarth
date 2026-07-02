# Fallen Earth - Batch Asset Generation Plan (ComfyUI + New Workflows)

**Date:** 2026-07-01  
**Context:** Project review + asset generation phase. Using updated consistent workflows (style_reference_generator.json, tileset_workflow_v2.json, tileset_consistent_workflow.json, character_sprite_consistent_workflow.json, props_and_mobs_consistent_workflow.json) + IP-Adapter + Pixel LoRA + ControlNet for uniform grim post-apoc sci-fi + cosmic horror style.  
**Goal:** Produce all required 2D assets (tiles, chars, mobs, props) in batch via ComfyUI locally for Godot 4 integration. No external image gen credits.

## Current Asset State (Review Snapshot)

**Tilesets (assets/tilesets/):** ~33 PNGs
- 7 biomes have 4 variants each: Scorched Plains, Ironwood Thicket, Glass Dunes, Corpse Fields, Stormspire Highlands, Toxin Marshes, Dead City Outskirts (FallenEarth_Tile_* prefix).
- Ash Wastes, Rust Canyons, Neon Bogs: only 1 each.
- Many use mixed/old styles (TEST_Base, raw). Not complete variety or full uniformity across 10 biomes.
- No dedicated subfolders yet.

**Characters (assets/characters/):** 15 PNGs total
- Cyborg Survivor (4), Human Scavenger (4), Mutant Technician (4) + older singles.
- Missing: SentientAI, Chthon, Vesperid, Nullborn, Revenant + full classes.
- Races from data/races.json: 8 total (Human, Mutant, SentientAI, Cyborg, Chthon, Vesperid, Nullborn, Revenant).
- Classes: 3 (Scavenger, Technician, Survivor) → 24 base character sets required.

**Mobs (assets/mobs/):** Empty folder.
- Needed from data/mobs.json: 5 neutral + 5 aggressive overworld + underearth parts + 4 tameable fruits.

**Props (assets/props/):** 4 files (mostly biome ground tests).
- Needed: Loot items (per loot_tables.json + biome resources), environment props, rift elements, scrap, tools, consumables, etc.

**Style References (assets/style_references/):** Several test + master_style_reference_00001_.png (stylized industrial top-down feel).
- Canonical: master_style_reference.png must be locked and reused in **every** IP-Adapter for uniformity.

**Other:** assets/FallenEarth_* folders are legacy/empty. Misc test tiles present.

**Implication:** Use new workflows to (a) lock master style, (b) batch complete/fill all tiles with uniform style, (c) generate full character set, (d) fill mobs/props. Re-generate starter biomes or harmonize as needed. Prioritize tiles (world gen advancing per NEXT_TASKS) then characters then combat props.

## Prerequisites (Do Before Any Batch)

1. **ComfyUI ready:**
   - Running from C:\Users\Administrator\Documents\ComfyUI (python main.py --listen recommended).
   - Required models (models/checkpoints, loras, ipadapter, controlnet, clip_vision):
     - sd_xl_base_1.0.safetensors + sdxl_vae.safetensors
     - pixel-art-xl.safetensors (LoRA)
     - ip-adapter_sdxl.bin + CLIP-ViT-bigG-14... (for VIT-G)
     - controlnet-tile-sdxl-1.0.safetensors + controlnet-openpose-sdxl.safetensors
   - Custom nodes installed: ComfyUI_IPAdapter_plus (and Impact-Pack recommended for batching).
   - **Restart ComfyUI** after installs/changes.

2. **Master Style Reference (critical - do this first if not locked):**
   - Load: `style_reference_generator.json`
   - Use exact prompt from `MASTER_STYLE_REFERENCE_PROMPT.txt` (or master_style_prompt.txt).
   - LoRA pixel-art-xl @ 0.82-0.85. IPAdapter temporarily low (0.3) or bypassed for exploration.
   - Settings: 512x512 or 768x768, 25-35 steps, CFG 6-8, euler.
   - Generate 8-12, pick **best** that screams "grim post-apoc sci-fi wasteland, cyberpunk decay + eldritch horror, readable top-down 2.5D game asset".
   - Save as: `assets/style_references/master_style_reference.png`
   - **Copy to ComfyUI/input/master_style_reference.png**
   - Also save a clean copy as `master_style.png` if workflows expect it.

3. **References folder prep:**
   - ComfyUI/input/ should have: master_style_reference.png
   - Optional: Prepare 1-2 character front reference images per major race (use consistent workflow or initial gens).
   - Pose references (T-pose skeletons) for OpenPose ControlNet in character batches.

4. **Workflow load:** Drag the .json into ComfyUI or use Load button. Wire LoadImage nodes to your master ref.

## Universal Batch Settings (Apply to All New Workflows)

- **Checkpoint:** sd_xl_base_1.0.safetensors
- **LoRA:** pixel-art-xl.safetensors strength 0.82-0.85 (model + clip)
- **IPAdapter:** Load master_style_reference.png. Strength 0.78-0.85 (use "VIT-G (medium strength)" preset if available in unified loader). 
- **ControlNet (tiles):** Tile @ 0.65-0.75 strength for seamless.
- **ControlNet (chars):** OpenPose @ 0.6-0.8 with pose image.
- **Resolution:** 512x512 primary (square for tiles/sprites). 768x768 for detail if VRAM allows.
- **Latent batch_size:** 3-4 (in EmptyLatentImage)
- **Sampler / Steps / CFG:** euler or dpmpp_2m, 25-30 steps, CFG 7.
- **Positive prompt MUST include:** "grim post-apocalyptic sci-fi wasteland, consistent with master style reference, top-down 2.5D game asset, highly detailed textures, [biome/race specifics], no text, no watermark"
- **Negative (standard):** "blurry, lowres, bad anatomy, watermark, text, deformed, cartoon, oversaturated, inconsistent style, ugly, pixel artifacts, bright colors, clean modern"
- **Seed strategy:** Fix base seed per asset group (e.g. biome), increment +1 or +100 for variations. Small variations keep consistency.
- **Queue strategy:** Queue 4-8 at a time per prompt type. Review outputs in ComfyUI preview/output. Move good ones immediately. Interrupt/restart queue as needed.

**Pro tip:** Use ComfyUI's "Queue Prompt" repeatedly or install Impact-Pack nodes for "Iterate" / batch prompts. For full automation, use the /prompt REST API with prepared JSON payloads.

## Phase 1: Tilesets - Batch Complete Uniform Set for All 10 Biomes

**Priority:** Highest (world hex map + exploration).

**Workflows to use:** 
- `tileset_workflow_v2.json` (recommended new)
- `tileset_consistent_workflow.json`
- `tileset_generation_workflow.json` (fallback)

**Per biome target:** 8-16 curated tiles (base ground + rocks/debris/scrub + craters/rifts + transitions + special features). Make seamless + atmospheric.

**Process (repeat for each biome):**
1. Load workflow.
2. Connect `master_style_reference.png` to IPAdapter (strength 0.85).
3. Enable pixel LoRA 0.85.
4. Enable Tile ControlNet ~0.7.
5. Replace prompt placeholders. Use the ready batches below or tileset_prompts.txt.
6. Set batch_size=4. Queue 6-10 variations per sub-prompt.
7. Curate: Keep most tileable + on-style. Discard drift.
8. Optional upscale: Use 4x-UltraSharp or similar in separate workflow pass.
9. Naming convention for keepers: `FallenEarth_Tile_[BiomeCamel]_[type]_[NN].png` or `ash_wastes_ground_001.png`
10. Save to `assets/tilesets/`

**Ready Batch Prompts - Ash Wastes (starter biome - re-do for consistency):**
See `ASH_WASTES_TILES_READY_PROMPTS.txt` (copy exact). 5 core prompts (ground, rocky, scrub, crater, transition).

**Ready Batch Prompts - All Other Biomes (copy-paste ready):**

Use structure: "seamless top-down hex tile texture for post-apocalyptic wasteland, [BIOME] biome, [specific features from data/biomes.json], grim sci-fi horror, consistent with master style reference, detailed ground texture, tileable, high quality game asset"

- **Rust Canyons:** barren toxic dust plains with scattered rocks and debris, twisted irradiated scrub, constant wind-blown ash, cracked earth + rusted metal scraps and irradiated debris, unstable ground, grim sci-fi horror...
- **Neon Bogs:** polluted wetlands with glowing flora, bioluminescent plants, failing pre-Collapse power lines, toxic sludge, electrified water...
- **Scorched Plains:** cracked earth and constant oppressive heat, baked into glass-like surfaces, extreme heat, sparse vegetation, heat haze...
- **Ironwood Thicket:** dense metallic trees and vines, forest transmuted into living iron and chrome-like growths, impaling vines...
- **Glass Dunes:** shimmering sand made of melted glass, glass storms, crystal formations, prismatic reflections, singing dunes...
- **Corpse Fields:** old battlegrounds littered with bones and wreckage, mass graves, rusting tanks, bone fields...
- **Stormspire Highlands:** high plateaus with constant lightning and fierce winds, ancient communication towers and corporate spires, lightning glass, crackling spires...
- **Toxin Marshes:** heavily polluted swamps thick with chemical runoff and bio-contamination, neurotoxins, corrosive sludge, sinking islands...
- **Dead City Outskirts:** ruined megacity edges, collapsed skyscrapers and subways, massive rift zones, feral gangs, overgrown streets...

**For each biome, create 5 sub-variants:**
1. Base ground / primary texture
2. Debris / rocky / wreckage variant
3. Vegetation / feature / organic
4. Damaged / rift-influenced / crater
5. Transition / edge to adjacent biome

Generate 6-8 per sub-variant. Total ~50-80 tiles per full biome (curate down).

**Batch files reference:** ASH_WASTES_TILES_READY_PROMPTS.txt + tileset_prompts.txt. Create similar *_READY_PROMPTS.txt per biome as you go (copy pattern).

**Post batch:** 
- Test seamless tiling (manual or Python script).
- Organize: Consider `assets/tilesets/ash_wastes/`, etc. (update Godot paths later).
- Harmonization pass (if old tiles mixed in): img2img low denoise + master ref.

## Phase 2: Characters - Full 8 Races × 3 Classes Batch

**Workflows:** `character_sprite_consistent_workflow.json`, `character_sprites_workflow.json`

**Key:** Use **two** IPAdapters or combined refs where possible:
- master_style_reference.png (style lock)
- Per-character reference (front/side view of that specific race/class)

**Process per character combo (e.g. "Human_Scavenger", "Vesperid_Technician"):**
1. Load character workflow.
2. Load master + character-specific ref images.
3. Use OpenPose ControlNet + pose skeleton ref for consistent body/angle.
4. Prompt template (from character_prompts.txt):
   `grim post-apocalyptic sci-fi [RACE] [CLASS], top-down 2.5D game sprite, detailed wasteland clothing with cybernetic and mutated elements, consistent with master style and character reference, high quality pixel art style sprite sheet asset, [VIEW/POSE: front idle / side walk frame 2 / back attack]`
5. Generate in one session: same refs + seed base.
   - Directions/views: front, side (left/right), back (4+)
   - States per view: Idle (1-3 frames), Walk cycle (4-8 frames), Attack (melee/ranged), Hurt, Death.
6. Batch 4-6 per specific frame description. Vary clothing/gear slightly while locking identity.
7. Naming: `FallenEarth_Char_[Race]_[Class]_[view]_[action]_[NN].png`
8. Repeat for all 24.

**Race + Class Combos (from data):**
Upworld: Human, Mutant, SentientAI, Cyborg
Underworld: Chthon, Vesperid, Nullborn, Revenant
+ Scavenger / Technician / Survivor

**Tips for batch:**
- Start with 1 race (e.g. Human) + all 3 classes as proof.
- Prepare pose refs once (use ControlNet preprocessor on a base sprite or simple line art).
- Keep CFG lower, IP strength high for character fidelity.
- Generate full animation set before switching characters.

See `character_prompts.txt` for more examples and animation list.

## Phase 3: Mobs & Enemies Batch

**Workflow:** `props_and_mobs_consistent_workflow.json` (adapt or duplicate from tiles/character)

**From data/mobs.json + tameable_fruits:**
Neutral: Ashveil Grazer, Lumen Drifter, Rustcarapace Scuttler, Silkroot Tapper, Echo Chorister
Aggressive: Charnel Stalker, Voidspine Leech, Mycelial Behemoth, Glimmer Swarm, Ferroclaw Reaver
+ Underearth parts (modular: head/body/limb/tail combos for procedural)
+ Tameable: Ashfruit, Voidbloom, Ironroot, Stormgourd (visuals + mount forms)

**Per mob:**
- Generate 4-8 variants for idle + movement + attack + death.
- Use style ref + simple structure ControlNet if available.
- Prompt: "grim post-apocalyptic sci-fi [mob name] [type], [description features], top-down 2.5D enemy sprite, consistent with master style reference, detailed texture, game asset"

Save to assets/mobs/ with `FallenEarth_Mob_[Name]_[state]_[NN].png`

**Batch order:** Neutral first, then aggressive, then modular parts (generate bases then composite).

## Phase 4: Props, Items, Loot & Environment

**Data sources:** loot_tables.json (all biomes' items), biomes resources, equipment, quest items, common props.

**Categories for batch:**
- Scrap / materials (rusted scrap, metallic vine, glass shards, etc.)
- Consumables (irradiated rations, tactical medkit, etc.)
- Components / tools (geiger counter cell, pre-war can opener)
- Quest / special (pre-collapse data chip, ancient seed)
- Environmental storytelling: ruined vehicles, barrels, campfires, altars, rusted hulks, power lines, bone traps.

**Workflow:** props_and_mobs_consistent_workflow.json

Prompt base: "post-apocalyptic wasteland prop/item, [specific item], grim sci-fi horror style, detailed worn texture, consistent with master style reference, top-down or 3/4 view, high quality game asset, no text"

Batch 3-6 per item. Save to assets/props/ or assets/items/.

**Rift-specific:** Portal effects, close-mechanism core, energy fissures, dungeon floor/wall variants (use tile workflow variant).

## Phase 5: Polish, Variations & Special

- Biome color-tinted variants or night/weather (low denoise img2img on masters + prompt).
- Damaged / overgrown states.
- UI icons (adapt prompts for small 2D icon style, same ref).
- Bosses (larger scale from mob bases).
- Rift interior tiles (separate "dungeon" prompt set using same style lock).

## Batch Execution Tips & Best Practices

- **One session per category/group:** Lock refs/seeds. Complete Ash Wastes tiles fully before moving.
- **Review discipline:** After each batch of 4-8, pause. Delete bad. Keep  best matching style.
- **Drift fix:** Low-denoise (0.25-0.4) img2img pass using the master ref + same prompt on outliers.
- **VRAM / performance (RTX 3080 12GB):** Use --lowvram or --normalvram flag on ComfyUI start. Small batches. 512 res.
- **Versioning outputs:** Use ComfyUI output subfolders or prefixes. Move curated to assets/ immediately.
- **Post-processing outside ComfyUI:**
  - Aseprite / GIMP / Python (PIL + numpy) for sprite sheet packing, palette normalization, hex masking/cropping.
  - Validate tile seamlessness.
  - Godot: Import as Texture2D, create TileSet (hex layout), SpriteFrames + AnimationPlayer for chars/mobs.
- **Organization final:**
  ```
  assets/
    tilesets/
      ash_wastes/ (or flat with clear names)
      ...
    characters/
      human_scavenger/
      ...
    mobs/
    props/
    style_references/
    rifts/
  ```
- **Tracking:** Note seed + workflow + ref version used per group in a small log (e.g. assets/gen_log.md).

## Recommended Order (Actionable Today)

1. **Style lock** (Phase 0) — 15-30 min.
2. **Ash Wastes full batch** (re-do for new style) using ASH_WASTES_TILES_READY_PROMPTS.txt — 45-90 min.
3. **Complete other 9 biomes** (use 4-5 subprompts each) — spread over sessions.
4. **Characters** — start with Human + Mutant sets (proof), then full 24.
5. **Mobs** + **Props** in parallel or after.
6. **Rift special** + polish.
7. **Integration pass** (move/rename, Godot setup, test in WorldGeneration/HubWorld/RiftInstance).

## Supporting Files in This Folder (use them)

- style_reference_generator.json + MASTER_STYLE_REFERENCE_PROMPT.txt + master_style_prompt.txt
- tileset_workflow_v2.json + tileset_consistent_workflow.json + ASH_WASTES_TILES_READY_PROMPTS.txt + tileset_prompts.txt
- character_*_workflow.json + character_prompts.txt
- props_and_mobs_consistent_workflow.json
- EXECUTE_NOW.txt, NOW_DO_THIS.txt, RUN_THIS_FIRST.txt (historical step instructions)

Create similar READY_PROMPTS for other biomes/characters as you execute.

## After Generation

- Update scripts that may hardcode old asset paths (search for png loads).
- Sync with WorldGenerator / MobManager / RiftInstance.
- Run F5 + playtest visual cohesion.
- If uniformity still off: Train a small LoRA on the locked set (future).

This batch plan + new workflows + master ref lock gives full control and perfectly consistent Fallen Earth assets.

**Next immediate action:** Restart ComfyUI → load style_reference_generator.json → generate/lock master_style_reference.png → load tileset_workflow_v2.json → run Ash Wastes batch.

Reply with status (e.g. "Master style locked. Starting Ash Wastes tiles.") for next detailed batch commands or prompt files.

---

**Assets complete = foundation for RimWorld-style hex world + rift running loop ready for full playtest.**
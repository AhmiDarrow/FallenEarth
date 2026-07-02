# ComfyUI Workflows for Fallen Earth Assets

## Status
- ComfyUI confirmed at: C:\Users\Administrator\Documents\ComfyUI
- Key models download attempted (IP-Adapter SDXL, ControlNet Tile SDXL, OpenPose SDXL) via background processes.
- Additional: You may need a base checkpoint (e.g. sd_xl_base_1.0.safetensors or Flux FP8). Use ComfyUI Manager or manual download from HuggingFace/Civitai.
- Custom nodes required (install via ComfyUI-Manager):
  - ComfyUI_IPAdapter_plus
  - ComfyUI-ControlNet-Aux (for preprocessors)
  - (Optional) ComfyUI-Impact-Pack for batching

## Custom Workflows Created
All workflows are designed for **uniform, consistent assets** using:
- IP-Adapter (style/character reference lock)
- ControlNet (structure: Tile for seamless tilesets, OpenPose for sprite poses)
- Fixed prompts with placeholders like [BIOME_NAME], [RACE], [CLASS]
- Reference image input (use a master style reference image for all to maintain grim post-apoc sci-fi horror aesthetic)
- Low variation settings for uniformity across batches
- Output organized for Godot import (e.g. FallenEarth_Tilesets/, FallenEarth_Characters/)

### 1. tileset_consistent_workflow.json
- **Purpose**: Generate uniform hex tilesets for biomes (Ash Wastes, Rust Canyons, etc.).
- **Key Features**: Seamless edges via Tile ControlNet + IP-Adapter style lock. Batch variations per biome.
- **Usage**:
  1. Load in ComfyUI (Queue Prompt or drag JSON).
  2. Set "master_style_reference.png" (your consistent grim wasteland style image).
  3. Edit positive prompt: Replace [BIOME_NAME] e.g. "Ash Wastes, toxic dust plains, irradiated scrub".
  4. Generate batch (change seed slightly for variations).
  5. Output to comfy output or custom.
- **Post-process**: Use external tool (e.g. Aseprite or Python) to ensure tileability and pack into Godot tileset resources.
- **For each biome**: Run separately with tailored prompt.

### 2. character_sprite_consistent_workflow.json
- **Purpose**: Generate consistent character sprites for races (Human, Mutant, Cyborg, Chthon etc.) + classes (Scavenger, Technician, Survivor).
- **Key Features**: IP-Adapter for character identity + OpenPose ControlNet for consistent poses/angles (idle, walk, attack from multiple views).
- **Usage**:
  1. Load workflow.
  2. Load "character_reference.png" (front/side view of specific race/class as reference).
  3. Load "pose_reference.png" (T-pose or walk cycle skeleton for ControlNet).
  4. Customize prompt with [RACE] and [CLASS].
  5. Generate multiple (different seeds for variations in clothing/gear while keeping face/body consistent).
  6. Output sprite sheets (front, side, back, animations).
- **For uniformity**: Use the same reference images across all characters in a set. Generate full animation cycles.
- **Races/Classes combos**: Run per combo (e.g. Mutant_Scavenger).

### 3. props_and_mobs_consistent_workflow.json
- **Purpose**: Uniform props (loot, scrap, equipment), mobs/enemies, rift dungeon elements.
- **Key Features**: IP-Adapter style lock + basic structure control. Good for items and creatures.
- **Usage**:
  1. Use master style ref.
  2. Prompt with specific [ITEM: rusted scrap] or mob type from data/mobs.json.
  3. Generate batches.
  4. For rift "close mechanism" props, use dedicated prompts.
- **Sets**: Run for loot_tables items, mobs, UI icons (adapt prompt for 2D icons).

## How to Use for Uniform Assets
1. **Prepare References** (critical for uniformity):
   - Create 1-2 "master" style images (e.g. via initial Grok gen or hand): one for overall aesthetic (grim, decayed sci-fi, muted colors, high contrast).
   - Per character: Reference sheet with consistent face/body.
   - Place in ComfyUI/input/ or specify path.

2. **Run Batches**:
   - Use same seed base + small increments for controlled variation.
   - Low CFG (6-8), steps 20-30, denoise 0.6-0.8 when using refs.
   - Batch size 4-8, review in ComfyUI preview.

3. **Post-Processing** (for Godot):
   - Slice large outputs into spritesheets/tiles.
   - Normalize palette across all assets.
   - Test in Godot (tileset importer, AnimationPlayer for sprites).
   - Suggested folders:
     - assets/tilesets/[biome]/
     - assets/characters/[race]_[class]/
     - assets/props/
     - assets/mobs/
     - assets/rifts/

4. **Consistency Tips**:
   - Always use IP-Adapter strength 0.8-1.0 with reference.
   - ControlNet strength 0.7-1.0.
   - Include "consistent art style, project specific" in all prompts.
   - Generate all tiles/characters in one session if possible.
   - Use "Tile" ControlNet for seamless tilesets.
   - For hex tiles: Generate square then mask/crop to hex in post.

## Asset Generation Plan
1. **Setup** (done-ish):
   - ComfyUI installed.
   - Required nodes: Install via Manager (ComfyUI_IPAdapter_plus, etc.).
   - Downloaded: IP-Adapter SDXL, ControlNets (background; verify files in models/ipadapter and controlnet).
   - Add a base checkpoint if missing (e.g. download sd_xl_base_1.0 from HF).

2. **References**:
   - Generate or create 1 master style ref.
   - Per major set: 1-3 reference images (e.g. one per race).

3. **Generation Order** (prioritized for project):
   - Phase 1: Tilesets (core for overworld hex sphere). Run tileset workflow for 10 biomes. ~200-500 tiles total.
   - Phase 2: Characters. Run sprite workflow for all races + classes (~50-100 sheets).
   - Phase 3: Mobs/Props/Rifts. Use props workflow + adaptations.
   - Phase 4: UI elements (adapt prompts to icon style).

4. **QA and Uniformity Checks**:
   - Visual review side-by-side.
   - Test integration in Godot scenes (WorldGeneration, HubWorld, RiftInstance).
   - Adjust workflow (e.g. higher IP strength if drift).
   - Batch regenerate inconsistent ones.

5. **Optimization for Hardware (RTX 3080 12GB)**:
   - Use SDXL (not full Flux unless quantized).
   - Resolution 512x512 or 768x768.
   - Enable lowvram if needed in ComfyUI launch.
   - Generate small batches, upscale separately if needed.
   - Monitor VRAM.

6. **Integration**:
   - After gen, move to FallenEarth/assets/...
   - Use Godot tools or scripts for packing (e.g. tileset from images).
   - Update data if new biomes/props.

7. **Future**:
   - Train custom LoRA on generated consistent set for even better uniformity.
   - Animate sprites (use AnimateDiff in ComfyUI if needed).
   - Scale to more variations (e.g. damaged states).

## Notes
- Workflows are starting points. Load in ComfyUI, tweak nodes (e.g. add more ControlNets, change seeds).
- For best results, use a reference image that embodies the "grim decay + cosmic horror" from lore.
- If downloads incomplete, re-run or use ComfyUI Manager "Install Models".
- Test one workflow first (e.g. tileset) before full batch.
- Credit: Workflows inspired by standard IPAdapter + ControlNet patterns for game assets.

Workflow files are in FallenEarth/comfyui_workflows/. Load them directly in your ComfyUI.

This enables generating all needed uniform assets locally without Grok credits.

(Stopped as requested after writing workflows and model download initiation.)
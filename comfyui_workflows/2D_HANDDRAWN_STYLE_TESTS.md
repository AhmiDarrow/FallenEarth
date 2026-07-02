# Fallen Earth - 2D Hand-Drawn Art Style Retry

**User Directive:** Retry with **2D hand-drawn** art style (not pixel art). Remember the core inspiration is a cross between RimWorld and Stardew Valley, but rendered as traditional 2D hand-drawn illustration / illustrated game assets.

## Art Style Direction
- **Primary:** 2D hand-drawn (illustrated, line art + painted textures, not pixel).
- **Influences:**
  - **RimWorld:** Iconic, simple-yet-readable, stylized, modular designs that support storytelling. Clean silhouettes, functional.
  - **Stardew Valley:** Charming, detailed environments, personality in small details, environmental storytelling, warm but atmospheric.
- **Fallen Earth Twist:** Grim post-apocalyptic sci-fi + cosmic horror (rusted towers, glowing fissures, mutated growths, toxic fog, neon in ash). Top-down 2.5D perspective for Godot sprites and hex tiles.
- **Key Qualities for Assets:**
  - Hand-drawn look: visible brush/line work, ink + color or painted feel.
  - Readable for gameplay (clear shapes for tiles, characters, props).
  - Tileable and sprite-sheet friendly.
  - Consistent dramatic lighting.
  - Muted earth tones (rusty oranges, deep reds, toxic greens, void blues) with eerie accents.
  - Not pixel, not photoreal, not overly cute/cartoon.
  - Charming grit: beautiful in its decay, hopeful survival amid horror.

## Research Basis (Quick)
- RimWorld: Abstracted icons, "typeface for the story", modular top-down, identifiable.
- Stardew: Detailed hand-crafted feel (even in pixel form), dithering/color for depth, charming readable worlds.
- Hand-drawn games (e.g. Don't Starve, some RPGs): Expressive lines, painterly or inked textures, 2D top-down or angled for assets.
- Adaptation: Remove pixel LoRA reliance. Emphasize "2D hand-drawn illustration", "hand-drawn sprite style", "illustrated top-down game assets".

## New Test Workflows (5 Variations)

Load these directly in ComfyUI (they are based on your generator, with pixel LoRA strength lowered to ~0.1 to avoid pixel look).

1. **style_test_handdrawn_01_balanced.json** — Core blend of RimWorld + Stardew as hand-drawn.
2. **style_test_handdrawn_02_illustrative.json** — More painterly/illustrative detailed hand-drawn.
3. **style_test_handdrawn_03_rimworld_iconic.json** — Iconic, simpler, readable like RimWorld but hand-drawn.
4. **style_test_handdrawn_04_stardew_charming.json** — Charming, detailed environments like Stardew, hand-drawn.
5. **style_test_handdrawn_05_gritty_horror.json** — Gritty cosmic horror emphasis, still hand-drawn and readable.

**Settings Tips:**
- Disable or minimize pixel-art LoRA (already set low in these JSONs).
- Base: sd_xl_base_1.0.safetensors
- Resolution: 512x512 or 768x768
- Steps: 25-35, CFG 6-8, euler or dpmpp
- Generate several seeds per test.
- Use the positive prompt as-is (includes "2D hand-drawn illustration style...").

## Exact Prompts (for reference or pasting)

**Common Negative:**
blurry, lowres, bad anatomy, watermark, text, deformed, cartoon, oversaturated, inconsistent style, ugly, pixel art, 8bit, low quality, photoreal

**01 Balanced:**
2D hand-drawn illustration style for top-down 2.5D game assets, blending RimWorld iconic simplicity and Stardew Valley charm, grim post-apocalyptic sci-fi Earth IV wasteland with cosmic horror elements, detailed hand-drawn textures, rusted metal towers and wreckage, glowing blue and sickly green fissures, twisted mutated organic growths, neon signs in toxic fog and ash, brutal yet strangely beautiful, readable silhouettes for sprites and tiles, consistent dramatic lighting, muted earth tones with rusty oranges, deep reds, toxic greens and void blues, atmospheric dust, no characters, no text, high quality consistent 2D hand-drawn game art style, tileable and sprite-friendly

**02 Illustrative:**
highly detailed 2D hand-drawn illustrated top-down game art style, inspired by RimWorld and Stardew Valley but fully hand-drawn not pixel, charming yet gritty post-apoc sci-fi wasteland, intricate linework and painterly details, rusted corporate ruins with eldritch mutations, bioluminescent glows, toxic fog, strong readable forms for Godot sprites and hex tiles, warm yet ominous atmosphere, limited but rich color palette, no characters no text

**03 RimWorld Iconic:**
2D hand-drawn iconic style like RimWorld blended with Stardew charm, simple yet expressive hand-drawn top-down sprites and tiles, post-apocalyptic sci-fi Earth IV, abstract but identifiable designs, rusted wasteland with cosmic horror touches, clean lines, modular feel, muted colors with accents, perfect for survival game assets, tileable, no text

**04 Stardew Charming:**
2D hand-drawn charming style like Stardew Valley with RimWorld influence, detailed hand-drawn environments and characters for top-down view, cozy grim post-apoc sci-fi survival, hand-crafted illustrated look, detailed foliage and structures in wasteland, glowing elements, atmospheric, rich colors in muted tones, sprite and tile friendly for Godot, no characters no text

**05 Gritty Horror:**
gritty 2D hand-drawn horror style for top-down game, RimWorld Stardew inspired but darker cosmic horror sci-fi wasteland, detailed ink and wash illustration feel, decayed ruins, unnatural growths, energy fissures, harsh lighting, detailed textures, readable for gameplay assets, muted desaturated palette with eerie highlights, tileable hand-drawn tiles and sprites

## How to Proceed
1. Open ComfyUI.
2. Load one of the `style_test_handdrawn_*.json`.
3. Generate 4-8 images per test (different seeds).
4. Pick the best overall (or combination).
5. Reply here (e.g. "02 illustrative is closest" or "use 01 but more like 04").

Next: I'll lock the chosen prompt as master, create a canonical master prompt file, update main asset workflows (remove pixel bias), and start batch generation for tiles/characters.

All files are in `comfyui_workflows/`.

This should finally hit the 2D hand-drawn RimWorld/Stardew cross for your grim sci-fi world. Let's find the right one!
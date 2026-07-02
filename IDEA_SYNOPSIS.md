# Fallen Earth — Idea Synopsis (Mechanics & Gameplay Overview)

---

## 🌍 Concept & Vision

**Fallen Earth** is a **top-down 2.5D survival RPG** built in Godot with an apocalyptic sci-fi aesthetic inspired by the grim decay of Shadowrun mixed with cosmic horror (Cthulhu vibes). It's set on "Earth IV," where corporate wars broke open the ancient Underearth, releasing horrors that reshaped civilization. The surface is now a brutal wasteland; settlements cling to existence while rifts from below intrude and consume territory.

The core premise: You're released (or escaped) from an exploitative **workcamp** as a youth and arrive in Riftspire—or a small outpost—almost destitute. Survival, carving out your future, and eventually establishing your own settlement centered around rift-running operations define the experience.

---

## 🔄 Gameplay Loop (RimWorld + Stardew Valley Hybrid)

Inspired by RimWorld (procedural world map, colony management, events) + Stardew Valley (daily life, farming/gathering, relationships, relaxed exploration with progression).

The world is a **hexagonal sphere** (RimWorld globe of hex tiles). 

**Exact Flow:**
- New Game → Generate hex sphere world (biomes via lat/temp/elev/rain like RimWorld).
- Choose starting grid/tile (site selection with info: biome, threats, resources).
- Character creation.
- Enter overworld: Settle on your hex tile. Play like a hybrid:
  - Stardew: Gather resources, "farm"/forage in tiles, build/expand settlement, daily cycles, NPC/faction interactions.
  - RimWorld: Manage threats, research/tech scavenging, recruit, base defense.
- Rifts spawn randomly (5-30 min real-time windows) or via quests as "tunnels" on the hex map. Enter for instanced procedural dungeon (combat, loot). Close rift at end to return to overworld. Some have bosses.

**Layers:**
1. **Overworld Hex Map** — Navigate adjacent hex tiles from your start. Harvest, explore, trigger rifts or quests. Settlement building on your grid.
2. **Rift Tunnels/Dungeons** — Instanced procedural (dungeon-like, Stardew mines or RW incidents). Tactical elements.
3. **Close & Return** — Mechanism at dungeon end closes rift, back to overworld with rewards.

**Progression:** Character skills from actions (Stardew), settlement growth (RW), rift-running reputation.

---

## 🌐 World & Biomes

The overworld features **10 distinct biomes**, each with different danger levels, resources, and rift frequencies:

- Ash Wastes — barren toxic dust plains (starter)
- Rust Canyons — deep canyons filled with rusted wreckage (high rift chance)
- Neon Bogs — polluted wetlands with glowing flora
- Scorched Plains — cracked earth/heat (low rift chance)
- Ironwood Thicket — dense metallic trees/vines
- Glass Dunes — shimmering sand made of melted glass (high rift chance)
- Corpse Fields — old battlegrounds littered with bones/wreckage
- Stormspire Highlands — high plateaus with constant lightning (**very** high rift chance)
- Toxin Marshes — heavily polluted swamps
- Dead City Outskirts — ruined megacity edges (extremely dangerous)

Biomes influence resource types, movement, and rift likelihood. The world is procedurally generated using a **hexasphere** layout that supports edge transitions, nearby settlements/factions preview, etc.

---

## 👤 Character Creation System

### Origins & Races

Players pick an **origin** (Upworld or Underworld) and a specific **race**. Each race provides base D&D-style stats (STR/DEX/CON/INT/WIS/CHA) reflecting adaptation. Classes provide mods.

| Origin | Race | Flavor Notes |
|--------|------|---------------|
| Upworld | Human | Balanced stats, neutral faction standing — jack-of-all-trades |
| | Mutant | Radiation-scarred adaptors; +Health, +RAD resist, −Hunger cap (tough but always hungry) |
| | Sentient AI | Conscious machine minds in synthetic bodies; high stamina/energy, fragile frame |
| | Cyborg | Chrome grafted onto flesh; durable frame with power-hungry implants, tech synergy |
| Underworld | Chthon | Pale elongated humanoids adapted to darkness; +Hunger resist, −Energy (closest to surface humans but changed) |
| | Vesperid | Insectoid-human hybrids with chitin plating/compound eyes; extremely durable |
| | Nullborn | Beings touched by the void between realities; flickering forms, unnatural calm, rare and partially unmade |
| | Revenant | Biologically repurposed corpses kept alive by Underearth tech/parasites; hard to kill, costly to sustain |

### Classes (Archetypes)

- **Scavenger** — Survival-focused kit for the harsh wasteland.
- **Technician** — High-tech tinkering and gadget use.
- **Survivor** — Balanced all-purpose archetype.

### Appearance Customization

- Gender swatches, skin tones, hair color palettes
- Live animated preview panel during creation (real multi-frame idle animation from uniform grids)
- Legacy "Model" part variants still exist in data but visuals now use the new grid sheets system
- Save format persists `gender`, `head`, `body`, `arms`, `legs`, `skin_tone`, `hair_color`

---

## 🎨 Visual Style & Art Pipeline

All art follows a unified grim aesthetic under seed **UNDEREARTH_GRIM_HAND_2026_v1**. Assets are organized in `assets/`:

### Character Rendering

- 16 identical **uniform sprite sheets** (`sheets/{race}_{gender}.png`) — each is 704×384, containing 11 columns × 4 rows of 64×96 frames.
- Layout (identical for every character): down/left/right/up; idle(2 frames), walk(4), attack(3), hurt(2) per direction.
- Base model wears **simple underwear only**; clothing, armor, weapons come from runtime equipment overlays (`equipment/`).
- Overworld tiles: 256×256 PNGs in `biomes/`; on-screen size is 128×128 via camera scaling.

### Equipment Visuals

- Weapons and armor pieces are single-pose 64×96 overlays aligned to uniform frames.
- Procedural tier generation (`EquipmentVisuals.generate_procedural_item`) feeds loot/crafting.

### UI Assets

- Background images per scene (splash, menu, character, world, combat).
- Ninepatch procedural textures (`assets/ui/ninepatch/`) — rusted/stitched/bone theme generated via `generate_ui_assets.make_nine_patches()`.

---

## ⚔️ Combat (Tactical)

Combat is **grid-based, turn-based**: each unit gets a move+act per turn. The current build has placeholder flow; deeper mechanics like AP system, terrain interaction, and full stats integration are planned.

### Rift Creatures

- 10 fixed overworld mobs (5 neutral, 5 aggressive): Ashveil Grazer, Lumen Drifter, Rustcarapace Scuttler, Silkroot Tapper, Echo Chorister vs. Charnel Stalker, Voidspine Leech, Mycelial Behemoth, Glimmer Swarm, Ferroclaw Reaver.
- Procedural underearth mobs use a modular parts system enabling thousands of random visual/stats combinations; all are combat usable, many mountable.

### Taming & Companions

Rift Runners can tame cybernetic creatures using special **Elemental Fruits** after defeating them:

| Fruit | Element | Combat Bonus | Mount Bonus |
|-------|---------|---------------|-------------|
| Ashfruit | Fire | Increased damage | Faster movement |
| Voidbloom | Void | Chance to inflict fear | Short-phase teleport |
| Ironroot | Earth | Higher health/defense | Extra inventory weight |
| Stormgourd | Lightning | Chance to stun on hit | Faster attack speed while mounted |

Tames level up through combat and exploration. Some powerful tames can pull cargo containers or megasleds. Both Upworlders and Underworlders use these creatures.

---

## 🏰 Base Building & Settlement

Settlement construction is free-form placement (inspired by Rust/Valheim): walls, floors, workbenches, storage, defenses, etc., crafted/scavenged materials. NPC recruitment: faction NPCs can be recruited to your base once you have sufficient reputation and player level; they function as storefronts/vendors selling faction-specific goods/services.

---

## 🏢 Factions & Lore Context

### Major Powers

- **Iron Accord** — Old-world corporate coalition controlling heavy industry/mercenary forces, exploiting the Underearth (motto: "Order from the ashes").
- **Hollow Covenant** — Theocratic-technocratic alliance of Chthon/Vesperid/Nullborn leaders; believe humanity's future lies below (motto: "We are the children of what came before").

### Independent Factions

Ash Serpents, Veilwardens, Neon Choir, Dust Parliament, Bone Circuit.

### Neutral Options

Black Ledger, Last Caravans, Echo Wardens.

---

## 💾 Save/Load System

- Autosaved to `user://saves/slot_0.json`
- Persists appearance dict and equipment via `SaveManager`
- Load flow: Main Menu → World Creation → Character Creation → Hub World (or Load Game)

---

## 🖥️ UI & Menus

Fully modernized with animated backgrounds (falling ash, drifting spores, pulsing vignettes):

| Scene | Path |
|-------|------|
| Splash | `scenes/ui/Splash.tscn` |
| Main Menu | `scenes/ui/MainMenu.tscn` |
| Options | `scenes/ui/Options.tscn` |
| World Creation | `scenes/ui/WorldCreation.tscn` |
| World Preview | `scenes/ui/WorldPreview.tscn` |
| Character Creation | `scenes/ui/CharacterCreation.tscn` |
| Pause Menu | `scenes/ui/PauseMenu.tscn` |
| Multiplayer Join / Lobby | `MultiplayerJoin.tscn`, `Lobby.tscn` |

---

## 🕹️ Controls (Hub)

| Input | Action |
|-------|--------|
| Arrow keys | Move player |
| Space | Interact (resources, rift nodes, tameable drone) · toggle build mode |
| Tab | Inventory |
| Left click (build mode) | Place wall |

---

## 📦 Autoloads

Global singletons handle stats, appearance data model, character visuals compositing, equipment system, race/class managers, overworld rendering, game state, world generation, run lifecycle, combat queue, save/load, multiplayer sync, pause overlay.

Full list in `project.godot` autoload array (e.g., `DisplayManager`, `AppearanceManager`, `CharacterVisuals`, `EquipmentManager`, `RaceManager`, `ClassManager`, `WorldGenerator`, etc.).

---

## 🐞 Current State & Limitations

| Area | Notes |
|------|-------|
| Character sheets | Base underwear only; may need more detail for combat feel |
| Equipment visuals | Single-pose overlays; full per-frame weapon/armor sheets would improve attack animations |
| Combat | Placeholder flow in progress; AP system + stats integration pending |
| Naming | `breach` vs `rift` inconsistency throughout code |
| Godot quirks | blit format warnings, canvas z>MAX (non-blocking) |

---

## 🚀 Next Steps / Improvements

1. Create per-frame overlay sheets for weapons/armor to match attack poses.
2. Rename `breach` → `rift` across the codebase.
3. Deepen tactical combat: grid movement, AP, terrain interaction.
4. Expand resources/crafting procedural generation and item quality tiers.
5. Add more animation polish (hurt reactions, breathing idle cycles).

---

*This synopsis was compiled from the project's README.md, lore.md, IDEA.md, autoload documentation, and scene lists — providing a concise overview of Fallen Earth's mechanics and gameplay.*

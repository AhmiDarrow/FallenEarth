Procedural 3D Entities System Plan for FallenEarth
Godot 4.x – Non-Asset, Engine-Drawn Graphics for All Interactables
Coder + Designer Deliverable – Ready to drop into /plans/ or /docs/

1. Vision & Scope
Goal: Replace or augment all sprite/asset-based characters, mobs, NPCs, items, rifts, doors, props, etc. with runtime procedural 3D primitives + composed meshes rendered on top of the existing 2D (or isometric) terrain layer.
Key Benefits:

Infinite visual variety via data (JSON + seeds).
Zero external model/texture assets for entities.
Full 3D lighting, shadows, selection, physics, and animation.
Easy modding/extensibility.
Maintain tight 2D gameplay feel with hybrid rendering.

Out of Scope: Terrain (TileMap/GridMap stays 2D). Backgrounds, UI, pure environmental effects.
Target Entities:

Players & Player Variants
Mobs / Enemies (mobs.json, enemy_archetypes.json)
NPCs (npc_archetypes.json)
Items / Loot (on-ground + held)
Rifts / Breaches / Portals
Interactive Props (doors, containers, vehicles, structures)
Attachments / Equipment


2. Architecture Overview
textMain 2D Scene (TileMap + Canvas)
    ├── EntityManager (Singleton)
    ├── SubViewport (3D World for Entities)
    │     └── Root Node3D per Entity
    │           ├── MeshInstance3D (composed primitives)
    │           ├── Skeleton3D (optional simple rig)
    │           ├── CollisionShape3D
    │           └── AnimationPlayer / Tween system
    └── 2D Sprite2D / TextureRect (receives ViewportTexture) + Billboard logic

Data-Driven: All visuals defined in data/appearance.json, extended schemas.
Core Classes (new/extend in /scripts/):
ProceduralEntityGenerator.gd
EntityVisualComponent.gd (attach to any Node2D/CharacterBody2D)
PrimitiveMeshLibrary.gd (reusable parts catalog)
MaterialLibrary.gd (extend existing Material3D work)
EntityAnimator.gd (procedural + keyframed)



3. Implementation Phases
Phase 1: Foundation (1-2 days)

Create /scripts/procedural/ directory.
Implement PrimitiveMeshLibrary with factory methods for:
Body parts: Capsule, Box, Cylinder, Sphere, Prism, Cone, Torus.
Modular attachments: Horns, Wings, Tails, Armor plates, Weapons.

Extend Material3D system for:
Procedural colors/palettes (per race/archetype).
Simple noise-based textures (dirt, glow, metallic).
Shader variants (outline on hover, faction tint, damage flash).

Add SubViewport setup in main scene(s):
Orthographic camera, fixed angle (top-down or isometric).
Transparent background.
Update size to match game resolution or use dynamic scaling.


Phase 2: Entity Composition System (2-3 days)

ProceduralEntityGenerator.create_visual(data: Dictionary) -> Node3D
Reads from appearance/race/mob JSON.
Builds hierarchy:
Root → Torso → Head → Limbs → Attachments.

Applies random seed-based variations (scale, offset, color hue).

Support composition presets:
Humanoid, Beast, Mechanical, Rift Entity, Item (floating orb + base).

Integration:
Attach EntityVisualComponent to existing 2D nodes.
Sync position/rotation between 2D body and 3D visual every frame (or use physics sync).


Phase 3: Rendering & Hybrid Integration (1-2 days)

ViewportTexture pipeline to 2D sprites.
Billboard / facing logic for consistent 2D view.
Depth sorting & Y-sort equivalent for 3D entities.
Lighting setup: Shared 3D environment lights + per-entity point lights (glowing rifts, etc.).
Pixelation / Stylization shader on final ViewportTexture (match art direction).

Phase 4: Animation & Behavior (3-4 days)

Procedural Animation:
Idle: Breathing, idle sway, particle glow.
Movement: Limb swing, bob, turn rate.
Attack / Ability: Simple lerp-based strikes.

EntityAnimator with states (Idle, Walk, Combat, Dead).
Optional simple Skeleton3D for better limb control.
Rift-specific: Pulsing, energy tendrils (cylinder + sphere chains).

Phase 5: Items, Props & Special Cases (2 days)

Items: Small composed meshes (floating + gentle rotation).
Held items: Attach as child mesh to hand bone/position.
Rifts: Large procedural geometry + shader effects (distortion, portals).
Props: Reusable primitive compositions with interaction highlights.

Phase 6: Polish, Optimization & Data Integration (2-3 days)

LOD system (simpler meshes at distance).
Culling / pooling for performance.
Editor tools: Previewer scene for JSON entities.
Update all JSON schemas (appearance.json, etc.) with visual params.
Seed system integration for consistent looks across saves.
Testing: Spawn 50+ varied mobs, profile FPS.


4. Data Schema Extensions (JSON)
Example additions to appearance.json / archetypes:
JSON{
  "entity_id": "mob_mutant",
  "visual": {
    "base_type": "humanoid",
    "torso": { "mesh": "capsule", "height": 1.8, "radius": 0.45, "color": [0.2, 0.8, 0.3] },
    "head": { "mesh": "sphere", "scale": 0.7, "attachments": ["horns"] },
    "limbs": { "count": 4, "style": "thin_cylinder" },
    "material": { "type": "organic", "roughness": 0.8, "glow": 0.2 },
    "variation_seed": 12345,
    "scale_range": [0.9, 1.1]
  }
}

5. Technical Details & Best Practices

Use SurfaceTool + ArrayMesh for custom shapes.
Pre-compile common materials (as in recent commits).
Cache generated meshes where possible, regenerate on significant changes.
Use Godot’s MultiMesh for swarm mobs.
Collision: Generate matching CapsuleShape3D / BoxShape3D procedurally.
Editor Integration: Custom inspector plugins for visual preview.


6. Testing & Validation Plan

Unit tests for mesh generation.
Playtest scene with all entity types.
Performance targets: 60 FPS with 100+ active entities.
Visual consistency audit across biomes/factions.
Edge cases: Very small/large entities, death animations, equipment changes.


7. Milestones & Priorities

MVP: Player + one mob type fully procedural (1 week).
Core Entities: All mobs/NPCs (Week 2).
Items & Rifts (Week 3).
Polish & Optimization (Week 4).

Risks: Performance on low-end hardware → mitigate with aggressive LOD/culling.
Dependencies: Existing Material3D / MeshPrimitives work (already strong)
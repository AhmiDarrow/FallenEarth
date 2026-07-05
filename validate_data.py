#!/usr/bin/env python3
import json, os

base = r"C:\Users\Administrator\FallenEarth"

DATA_FILES = [
    "races.json",
    "biomes.json",
    "mobs.json",
    "character_classes.json",
    "items.json",
    "tools.json",
    "weapons.json",
    "armor.json",
    "accessories.json",
    "recipes.json",
    "loot_tables.json",
    "dialogue.json",
    "factions.json",
    "npc_archetypes.json",
    "npc_name_parts.json",
    "joinable_npc_templates.json",
    "riftspire_layout.json",
    "settlement_rooms.json",
    "towns.json",
    "base.json",
    "base_shops.json",
    "dynamic_threat.json",
    "enemy_archetypes.json",
    "mob_sprites.json",
    "appearance.json",
    "combat_config.json",
    "rift_config.json",
]

errors = []
for fname in DATA_FILES:
    path = os.path.join(base, "data", fname)
    if not os.path.exists(path):
        errors.append(f"MISSING: {fname}")
        continue
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            print(f"[{fname}] VALID JSON (dict, {len(data)} keys)")
        elif isinstance(data, list):
            print(f"[{fname}] VALID JSON (list, {len(data)} entries)")
        else:
            print(f"[{fname}] VALID JSON ({type(data).__name__})")
    except json.JSONDecodeError as e:
        errors.append(f"INVALID JSON: {fname} — {e}")
        print(f"[{fname}] INVALID JSON — {e}")

print()
if errors:
    print(f"=== {len(errors)} ERROR(S) ===")
    for e in errors:
        print(f"  {e}")
else:
    print("=== ALL DATA FILES VALID ===")

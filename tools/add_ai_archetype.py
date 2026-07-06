#!/usr/bin/env python3
"""Add ai_archetype to each mob in data/mobs.json based on its type."""
import json
import pathlib

ARCHETYPE_BY_TYPE = {
    "herd_beast": "aggressive",
    "float_jelly": "defensive",
    "scavenger_crab": "aggressive",
    "stationary_plant": "defensive",
    "colony_beast": "defensive",
    "amphibian": "aggressive",
    "swarm_insect": "ranged",
    "pack_predator": "aggressive",
    "energy_drainer": "ranged",
    "spore_hulk": "boss",
    "coordinated_insects": "aggressive",
    "magnetic_horror": "boss",
    "scavenger_beetle": "aggressive",
    "spore_thrower": "caster",
    "crystal_reptile": "ranged",
    "carrion_centipede": "aggressive",
    "flying_beast": "ranged",
    "rift_predator": "aggressive",
    "rift_spider": "caster",
    "rift_wraith": "aggressive",
    "rift_aberration": "boss",
    "rift_spore": "caster",
    "rift_machine": "caster",
    "rift_storm": "boss",
    "rift_gatekeeper": "boss",
}

# Bosses are also pinned to "boss" regardless of type
BOSS_IDS = {
    "storm_herald",
    "rift_maw",
    "mycelial_behemoth",
    "ferroclaw_reaver",
    "lifecycle_horror",
}

PATH = pathlib.Path("data/mobs.json")
data = json.loads(PATH.read_text(encoding="utf-8"))


def assign(mob):
    mid = mob.get("id", "")
    if mid in BOSS_IDS:
        mob["ai_archetype"] = "boss"
        return
    mtype = mob.get("type", "")
    mob["ai_archetype"] = ARCHETYPE_BY_TYPE.get(mtype, "aggressive")


count = 0
for section in ("overworld", "rift_only"):
    bucket = data.get(section, {})
    if isinstance(bucket, dict):
        for cat in ("neutral", "aggressive"):
            for m in bucket.get(cat, []):
                assign(m)
                count += 1
    elif isinstance(bucket, list):
        for m in bucket:
            assign(m)
            count += 1

PATH.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
print(f"Updated {count} mobs with ai_archetype")

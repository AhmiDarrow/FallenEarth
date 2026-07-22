#!/usr/bin/env python3
"""Asset verification — checks that all expected asset files exist for
the current phase.

Run as a CI-style check at the end of each phase. Exits non-zero if
anything is missing.

Usage:
    python tools/verify_assets.py
    python tools/verify_assets.py --phase 1
"""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCE_NODES_JSON = ROOT / "data" / "resource_nodes.json"
ITEMS_JSON = ROOT / "data" / "items.json"

EXPECTED_DIRS = {
    "tilesets": ROOT / "assets" / "tilesets",
    "resource_node_sprites": ROOT / "assets" / "sprites" / "resource_nodes",
    "floor_pickup_sprites": ROOT / "assets" / "sprites" / "floor_pickups",
    "mob_sprites": ROOT / "assets" / "mobs",
    "character_sprites": ROOT / "assets" / "characters",
}


def check_tilesets() -> list[str]:
    """Phase 0+: 10 biomes x ground_64.png (primary) + per-terrain files."""
    missing: list[str] = []
    base = EXPECTED_DIRS["tilesets"]
    if not base.exists():
        return [f"{base} does not exist"]
    for biome_dir in base.iterdir():
        if not biome_dir.is_dir():
            continue
        # Primary texture (PixelLab-sized)
        if not (biome_dir / "ground_64.png").exists():
            missing.append(f"{biome_dir.name}/ground_64.png")
        # Legacy per-terrain files
        for terrain in ("ground.png", "debris.png", "vegetation.png", "blocked.png"):
            if not (biome_dir / terrain).exists():
                missing.append(f"{biome_dir.name}/{terrain}")
    return missing


def check_resource_nodes() -> list[str]:
    """Phase 1: every sprite_id referenced in resource_nodes.json, plus
    a _generic.png fallback."""
    if not RESOURCE_NODES_JSON.exists():
        return ["data/resource_nodes.json missing"]
    base = EXPECTED_DIRS["resource_node_sprites"]
    if not base.exists():
        return [f"{base} does not exist"]
    data = json.loads(RESOURCE_NODES_JSON.read_text())
    referenced: set[str] = set()
    for biome in data.get("biomes", {}).values():
        for category in ("trees", "formations", "ore", "crystals", "fauna"):
            for entry in biome.get(category, []):
                sid = entry.get("sprite")
                if sid:
                    referenced.add(sid)
    missing = []
    for sid in sorted(referenced):
        if not (base / f"{sid}.png").exists():
            missing.append(f"resource_nodes/{sid}.png")
    if not (base / "_generic.png").exists():
        missing.append("resource_nodes/_generic.png")
    return missing


def check_floor_pickups() -> list[str]:
    """Phase 1: stick.png and stone.png."""
    base = EXPECTED_DIRS["floor_pickup_sprites"]
    if not base.exists():
        return [f"{base} does not exist"]
    missing = []
    for item in ("stick.png", "stone.png"):
        if not (base / item).exists():
            missing.append(f"floor_pickups/{item}")
    return missing


def check_mobs() -> list[str]:
    """Phase 1+: every sprite_id in data/mobs.json."""
    base = EXPECTED_DIRS["mob_sprites"]
    if not base.exists():
        return [f"{base} does not exist"]
    mobs_json = ROOT / "data" / "mobs.json"
    if not mobs_json.exists():
        return []
    data = json.loads(mobs_json.read_text())
    referenced: set[str] = set()
    if "overworld" in data:
        for cat in ("neutral", "aggressive"):
            for m in data["overworld"].get(cat, []):
                sid = m.get("sprite_id")
                if sid:
                    referenced.add(sid)
    for m in data.get("rift_only", []):
        sid = m.get("sprite_id")
        if sid:
            referenced.add(sid)
    return [f"mobs/{sid}.png" for sid in sorted(referenced) if not (base / f"{sid}.png").exists()]


CHECKS = {
    "tilesets": check_tilesets,
    "resource_nodes": check_resource_nodes,
    "floor_pickups": check_floor_pickups,
    "mobs": check_mobs,
}


PHASE_SCOPE = {
    0: ["tilesets"],
    1: ["tilesets", "resource_nodes", "floor_pickups"],
    "all": list(CHECKS.keys()),
}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--phase", default="1", help="phase number to check (default: 1)")
    p.add_argument("--strict", action="store_true", help="treat warnings as errors")
    args = p.parse_args()

    try:
        phase = int(args.phase)
    except ValueError:
        phase = args.phase
    scope = PHASE_SCOPE.get(phase, PHASE_SCOPE[1])

    print(f"verify_assets — phase {phase}, scope: {scope}")
    total_missing = 0
    for name in scope:
        if name not in CHECKS:
            print(f"  ?   {name}: no checker defined")
            continue
        missing = CHECKS[name]()
        if not missing:
            print(f"  ok  {name}: all present")
            continue
        total_missing += len(missing)
        for m in missing[:20]:
            print(f"  MISS {name}: {m}")
        if len(missing) > 20:
            print(f"  ... and {len(missing) - 20} more")
    print()
    if total_missing == 0:
        print("All checks passed.")
        return 0
    print(f"{total_missing} asset(s) missing.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

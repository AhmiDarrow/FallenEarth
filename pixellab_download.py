#!/usr/bin/env python3
"""Download completed PixelLab assets from results manifest and save to asset paths.

Usage: python pixellab_download.py [results_file]

Reads pixellab_results.json (or specified file), downloads all PNGs,
saves to assets/mobs/{id}.png, assets/characters/{race}_{gender}/{race}_{gender}_S.png,
assets/backgrounds/bg_{biome}.png
"""

import json
import os
import sys
import urllib.request
from pathlib import Path

ASSETS_DIR = Path("assets")
MOBS_DIR = ASSETS_DIR / "mobs"
CHAR_DIR = ASSETS_DIR / "characters"
BACKGROUNDS_DIR = ASSETS_DIR / "backgrounds"

def download_file(url: str, dest: Path) -> bool:
    if not url:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        urllib.request.urlretrieve(url, str(dest))
        size = dest.stat().st_size
        print(f"  Downloaded {dest.name} ({size} bytes)")
        return True
    except Exception as e:
        print(f"  FAILED {dest.name}: {e}")
        return False

def main():
    manifest_path = sys.argv[1] if len(sys.argv) > 1 else "pixellab_results.json"
    with open(manifest_path) as f:
        results = json.load(f)

    print("=" * 60)
    print(f"Downloading from {manifest_path}")
    print("=" * 60)

    # ── Download character sprites ──
    print(f"\n--- Characters ({len(results.get('characters', []))}) ---")
    for c in results.get("characters", []):
        cid = c["id"]
        team = c.get("team", "mob")
        url = c.get("download_url", "")
        if not url:
            print(f"  SKIP {cid}: no URL")
            continue
        if team == "player":
            # Player: assets/characters/{race}_{gender}/{race}_{gender}_S.png
            parts = cid.split("_", 1)
            if len(parts) == 2:
                race, gender = parts
                dest = CHAR_DIR / f"{race}_{gender}" / f"{race}_{gender}_S.png"
                download_file(url, dest)
            else:
                print(f"  SKIP {cid}: bad id format")
        else:
            # Mob: assets/mobs/{sprite_id}.png
            dest = MOBS_DIR / f"{cid}.png"
            download_file(url, dest)

    # ── Download backgrounds ──
    print(f"\n--- Backgrounds ({len(results.get('backgrounds', []))}) ---")
    for bg in results.get("backgrounds", []):
        bid = bg["id"]
        url = bg.get("download_url", "")
        if not url:
            print(f"  SKIP {bid}: no URL")
            continue
        dest = BACKGROUNDS_DIR / f"{bid}.png"
        download_file(url, dest)

    # ── Download animation spritesheets ──
    print(f"\n--- Animations ({len(results.get('animations', []))}) ---")
    for a in results.get("animations", []):
        cid = a["id"]
        anim = a["anim"]
        url = a.get("download_url", "")
        if not url:
            print(f"  SKIP {cid}_{anim}: no URL")
            continue
        # Save to assets/mobs/{cid}/{anim}.png or assets/characters/{race}_{gender}/{anim}.png
        parts = cid.split("_", 1)
        if len(parts) == 2 and cid in [c["id"] for c in results.get("characters", []) if c.get("team") == "player"]:
            race, gender = parts
            dest = CHAR_DIR / f"{race}_{gender}" / f"{anim}.png"
        else:
            dest = MOBS_DIR / cid / f"{anim}.png"
        download_file(url, dest)

    print("\nDone!")

if __name__ == "__main__":
    main()

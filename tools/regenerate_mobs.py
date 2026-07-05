#!/usr/bin/env python3
"""Regenerate mob sprites via PixelLab with a 2px dark outline + rim color.

v0.3.0 round 3 of mob art. The previous round 2 produced visible silhouettes
but they still blended into vegetation-heavy biomes. This pass emphasizes a
2px black outline so mobs read as solid figures against any background, and
applies a slightly brighter rim color hint so dark-toned mobs (blight_toad,
spore_phantom) don't disappear into a dark background.

Reads sprite_ids from data/mobs.json (overworld + rift_only lists), so the
list stays in sync with the data file. Idempotent: skips existing files.
Use --force to regenerate.
"""

import argparse
import base64
import io
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from PIL import Image

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
GENERATE_SIZE = 64
FINAL_SIZE = 64

ROOT = Path(__file__).resolve().parent.parent
MOB_DIR = ROOT / "assets" / "mobs"
DATA_MOBS = ROOT / "data" / "mobs.json"

PALETTE_ANCHOR = (
    "thick 2 pixel solid black outline around the entire silhouette, "
    "post-apocalyptic wasteland palette, rust, dust brown, subtle eldritch "
    "cyan undertone, consistent pixel art style, 2D top-down game sprite, "
    "single character on transparent background"
)

# Per-archetype shape hints so pixflux produces more variety than "generic blob".
SHAPE_HINTS = {
    "beast_quadruped":   "four-legged beast body, head, tail, low stance",
    "beast_floater":     "floating soft-bodied creature, no legs, tendrils hanging down",
    "beast_insectoid":   "chitinous insect body, many legs, antennae, segmented",
    "beast_behemoth":    "huge hulking beast, oversized shoulders, massive arms",
    "mechanical_default": "robotic body, angular plating, glowing eye/core, mechanical limbs",
    "rift_void":         "ethereal void creature, indistinct edges, glowing void eye, dark with cyan rim",
    "rift_life":         "fleshy pulsating mass, spores, organic growths, sickly green",
    "rift_energy":       "energy construct, crackling arcs, glowing core, geometric",
}

# Per-biome tint hints applied to the rim/secondary color so the mob reads
# against that biome's typical background.
BIOME_TINTS = {
    "Ash Wastes":         "warm sandy orange rim, ash-grey underbelly",
    "Rust Canyons":       "deep rust red rim, dark iron body",
    "Neon Bogs":          "bioluminescent teal rim, dark green body",
    "Scorched Plains":    "sun-bleached tan rim, scorched brown body",
    "Ironwood Thicket":   "chrome silver rim, dark metal body",
    "Glass Dunes":        "prismatic blue rim, pale crystalline body",
    "Corpse Fields":      "bone-white rim, desaturated grey body",
    "Stormspire Highlands": "lightning blue rim, dark slate body",
    "Toxin Marshes":      "toxic yellow-green rim, murky green body",
    "Dead City Outskirts": "neon orange rim, dark concrete body",
}


def load_mob_ids() -> list[dict]:
    """Return a list of {id, shape, biomes} from data/mobs.json."""
    with open(DATA_MOBS) as f:
        data = json.load(f)
    out: list[dict] = []
    for section in ("overworld", "rift_only"):
        bucket = data.get(section, {})
        if isinstance(bucket, dict):
            for cat in ("neutral", "aggressive"):
                for m in bucket.get(cat, []):
                    out.append({
                        "id": m.get("sprite_id") or m.get("id"),
                        "shape": m.get("visual_preset", "beast_quadruped"),
                        "biomes": m.get("preferred_biomes", []),
                    })
        elif isinstance(bucket, list):
            for m in bucket:
                out.append({
                    "id": m.get("sprite_id") or m.get("id"),
                    "shape": m.get("visual_preset", "rift_void"),
                    "biomes": m.get("preferred_biomes", []),
                })
    return out


def call_pixflux(description: str) -> Image.Image:
    payload = {
        "description": description,
        "image_size": {"width": GENERATE_SIZE, "height": GENERATE_SIZE},
        "no_background": True,
        "view": "high top-down",
        "direction": "south",
    }
    r = requests.post(
        f"{BASE_URL}/create-image-pixflux",
        json=payload,
        headers=HEADERS,
        timeout=120,
    )
    if r.status_code != 200:
        raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
    img_b64 = r.json()["image"]["base64"]
    return Image.open(io.BytesIO(base64.b64decode(img_b64))).convert("RGBA")


def render_one(mob: dict, force: bool) -> tuple[str, str]:
    """Returns (mob_id, status) where status is 'ok'|'skip'|'fail:...'."""
    mob_id = mob["id"]
    if not mob_id:
        return "", "skip:no id"
    out_path = MOB_DIR / f"{mob_id}.png"
    if out_path.exists() and not force:
        return mob_id, "skip"

    MOB_DIR.mkdir(parents=True, exist_ok=True)
    shape = SHAPE_HINTS.get(mob["shape"], mob["shape"])
    biomes = mob.get("biomes") or []
    if biomes:
        tint = BIOME_TINTS.get(biomes[0], "warm rust rim, dark body")
    else:
        tint = "warm rust rim, dark body"
    description = (
        f"top-down pixel art monster, {shape}, {tint}, {PALETTE_ANCHOR}"
    )

    for attempt in range(3):
        try:
            img = call_pixflux(description)
            img = img.resize((FINAL_SIZE, FINAL_SIZE), Image.NEAREST)
            img.save(out_path, "PNG")
            return mob_id, "ok"
        except Exception as e:
            if attempt == 2:
                return mob_id, f"fail:{e}"
            time.sleep(2 * (attempt + 1))
    return mob_id, "fail"


def write_gdignore():
    MOB_DIR.mkdir(parents=True, exist_ok=True)
    gd = MOB_DIR / ".gdignore"
    if not gd.exists():
        gd.write_text("# generated by tools/regenerate_mobs.py\n")


def remove_gdignore():
    gd = MOB_DIR / ".gdignore"
    if gd.exists():
        gd.unlink()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--force", action="store_true", help="regenerate even if file exists")
    p.add_argument("--workers", type=int, default=5)
    args = p.parse_args()

    mobs = load_mob_ids()
    print(f"Regenerating {len(mobs)} mob sprite(s) from data/mobs.json, {args.workers} workers")
    write_gdignore()
    try:
        ok = skip = fail = 0
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            futs = {ex.submit(render_one, m, args.force): m for m in mobs}
            for fut in as_completed(futs):
                m = futs[fut]
                mid, status = fut.result()
                if status == "ok":
                    ok += 1
                    print(f"  ok   {mid}.png")
                elif status == "skip":
                    skip += 1
                else:
                    fail += 1
                    print(f"  FAIL {mid}  -> {status}")
        print(f"Done. ok={ok} skip={skip} fail={fail} of {len(mobs)}")
        return 0 if fail == 0 else 2
    finally:
        remove_gdignore()


if __name__ == "__main__":
    sys.exit(main())

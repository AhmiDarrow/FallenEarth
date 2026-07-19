#!/usr/bin/env python3
"""Download mount PixelLab character zips and build per-mob SpriteFrames .tres folders.

Uses the /download endpoint which returns a zip with metadata.json + PNG frames.
Extracts south-direction frames only (game uses single-south with flips).
Maps: running/running-8-frames → walk, idle → idle, rotation south.png → idle (fallback).
"""

import hashlib
import json
import os
import sys
import tempfile
import time
import urllib.request
import uuid
import zipfile
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
ASSETS_MOBS = BASE_DIR / "assets" / "mobs"
TEMP_ROOT = Path(tempfile.gettempdir()) / "opencode" / "mounts"

MOUNT_CHARACTERS: dict[str, str] = {
    "ember_strider":      "fa833c75-471a-438f-9e34-6bfc736a60e0",
    "cinder_hound":       "82279138-61d3-48bf-b394-2c64afafd5aa",
    "glowfin_stalker":    "6d12ed5e-f699-4445-878e-337dd4f79bb6",
    "ironjaw_stag":       "92bcdc72-da61-4f03-8468-c58d65eeef97",
    "rustfang_wolf":      "fde28b95-f827-4d08-bd4b-08ffb0d8ef96",
    "sandglass_rattler":  "04a7743b-89d3-4a98-be90-ffe25ab7227a",
    "bonegrinder":        "5fe2a404-a5d7-464b-b86d-8ac949f54287",
    "toxic_salamander":   "cbdb38b9-70bc-4341-887b-2642bb605119",
    "stormmane_elk":      "2df2e87d-1b53-4542-905b-0f041c44bbc4",
    "city_crawler":       "5b70c062-22ef-41ce-85f9-acdfc0933086",
    "flameback_charger":  "75e136fa-8ef4-4624-9970-02a30f308e93",
    "dust_lurker":        "6a6c285a-6ee9-4382-b1c6-c34e59fb76ea",
    "bogmire_crawler":    "76983265-21a7-44bf-b929-ee39e87da2a1",
    "brambleback_beast":  "591bcb13-5f62-4d62-9536-c4a10a473fcc",
    "canyon_grinder":     "6c0bf684-4cd1-4184-8796-51622a4633e8",
    "dune_prowler":       "41454b23-610f-42e2-8969-fd421e718c3c",
    "carrion_stalker":    "ebef32c1-33d3-4f39-b95b-8c61e0ee5722",
    "miasma_toad":        "27f79b29-c7ae-4dff-9413-f544d807ca0c",
    "thunderclaw_raptor": "deb947bf-aaae-4c54-84e0-97850dacd9b2",
    "ruin_hound":         "ed088d39-2c4b-4b7d-9ad7-d13c743a2013",
}

ANIM_MAP = {
    "idle":   {"speed": 5.0,  "loop": True},
    "walk":   {"speed": 8.0,  "loop": True},
}

DOWNLOAD_URL = "https://api.pixellab.ai/mcp/characters/{char_id}/download"


def _fmt_id(n: int) -> str:
    return f'ExtResource("{n}")'


def _make_import(src_path: str, dst_file: Path) -> None:
    png_name = dst_file.name
    h = hashlib.md5(src_path.encode()).hexdigest()
    uid = uuid.uuid4().hex[:13]
    content = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{png_name}-{h}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{src_path}"
dest_files=["res://.godot/imported/{png_name}-{h}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    (dst_file.parent / (png_name + ".import")).write_text(content, encoding="utf-8")


def _find_south_source(meta: dict, anim_name: str) -> str | None:
    """Return the zip-relative folder name that holds south frames for an animation."""
    meta_anims = meta["frames"]["animations"]
    keys = [k for k in meta_anims if k == anim_name or k.startswith(anim_name + "-")]
    for key in keys:
        if "south" in meta_anims[key]:
            return key
    return None


def _copy_frames(
    extract_dir: Path, sprite_id: str, game_name: str,
    png_paths: list[str], ext_resources: list[str], anim_entries: list[str]
) -> int:
    """Copy PNG frames into mob_dir/game_name/, append ext_resource lines, and
    build the animation entry. Returns the next free res_id."""
    res_id = len(ext_resources) + 2  # starts at 2

    anim_dir = ASSETS_MOBS / sprite_id / game_name
    anim_dir.mkdir(parents=True, exist_ok=True)

    fps_line = []
    for fi, rel in enumerate(sorted(png_paths)):
        src_file = extract_dir / rel
        dst_name = f"frame_{fi:02d}.png"
        dst_file = anim_dir / dst_name

        if not src_file.exists():
            print(f"    WARN: missing {rel}")
            continue

        dst_file.write_bytes(src_file.read_bytes())
        res_path = f"res://assets/mobs/{sprite_id}/{game_name}/{dst_name}"
        ext_resources.append(f'[ext_resource type="Texture2D" path="{res_path}" id="{res_id}"]')
        _make_import(res_path, dst_file)
        fps_line.append(f'{{"duration": 1.0, "texture": {_fmt_id(res_id)}}}')
        res_id += 1

    if not fps_line:
        print(f"    WARN: no frames copied for {game_name}")
        return 0

    a_def = ANIM_MAP[game_name]
    anim_entry = (
        f'{{"name": "{game_name}", "speed": {a_def["speed"]}, '
        f'"loop": {str(a_def["loop"]).lower()}, "frames": [{", ".join(fps_line)}]}}'
    )
    anim_entries.append(anim_entry)
    return len(fps_line)


def _import_one(sprite_id: str, char_id: str) -> bool:
    """Download, extract, copy south frames, and write .tres + .import files."""
    mob_dir = ASSETS_MOBS / sprite_id
    tres_path = mob_dir / f"{sprite_id}.tres"

    if tres_path.exists():
        print(f"  [{sprite_id}] .tres exists, skipping")
        return True

    temp_zip = TEMP_ROOT / f"{char_id}.zip"
    temp_extract = TEMP_ROOT / char_id

    # Download
    if not temp_zip.exists():
        url = DOWNLOAD_URL.format(char_id=char_id)
        print(f"  [{sprite_id}] downloading...")
        try:
            urllib.request.urlretrieve(url, temp_zip)
        except Exception as e:
            print(f"  [{sprite_id}] DOWNLOAD FAILED: {e}")
            return False
        time.sleep(0.5)

    # Unzip (overwrite if exists)
    if temp_extract.exists():
        import shutil
        shutil.rmtree(temp_extract)
    try:
        with zipfile.ZipFile(temp_zip, "r") as zf:
            zf.extractall(temp_extract)
    except Exception as e:
        print(f"  [{sprite_id}] UNZIP FAILED: {e}")
        return False

    # Read metadata
    meta_file = temp_extract / "metadata.json"
    if not meta_file.exists():
        print(f"  [{sprite_id}] no metadata.json")
        return False
    meta = json.loads(meta_file.read_text(encoding="utf-8"))
    state = meta["states"][0]
    fname = state["folder"]  # e.g. "Cinder_Hound"
    meta_anims = state["frames"]["animations"]
    rotations = state["frames"].get("rotations", {})

    # --- detect which download→game animation names exist ---
    download_map: dict[str, str] = {}  # zip_anim_key → game_anim_name

    # idle
    src = _find_south_source(state, "idle")
    if src:
        download_map[src] = "idle"
    else:
        # fallback: use rotation south.png as a 1‑frame idle
        print(f"  [{sprite_id}] no idle anim — using rotation south.png fallback")

    # walk ← running / running-8-frames
    for run_candidate in ["running-8-frames", "running"]:
        src = _find_south_source(state, run_candidate)
        if src:
            download_map[src] = "walk"
            break

    if not download_map:
        print(f"  [{sprite_id}] no south animations found in zip!")
        return False

    # --- Build ---
    mob_dir.mkdir(parents=True, exist_ok=True)
    ext_resources: list[str] = []
    anim_entries: list[str] = []

    # Idle from animation
    for src_key, game_name in sorted(download_map.items(), key=lambda x: 0 if x[1] == "idle" else 1):
        south_fps = meta_anims[src_key].get("south", [])
        if south_fps:
            _copy_frames(temp_extract, sprite_id, game_name, south_fps, ext_resources, anim_entries)

    # Idle from rotation fallback
    if "idle" not in {e.split('"name": "')[1].split('"')[0] for e in anim_entries}:
        rot_south_rel = rotations.get("south", "")
        if rot_south_rel:
            _copy_frames(temp_extract, sprite_id, "idle", [rot_south_rel], ext_resources, anim_entries)

    if not anim_entries:
        print(f"  [{sprite_id}] no animation entries built!")
        return False

    # --- Write .tres ---
    load_steps = len(ext_resources) + 2  # self + [resource]
    lines = [
        f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]',
        "",
    ]
    lines.extend(ext_resources)
    lines.extend(["", "[resource]"])
    lines.append(f"animations = [{', '.join(anim_entries)}]")
    lines.append("")
    tres_path.write_text("\n".join(lines), encoding="utf-8")

    total_frames = len(ext_resources)
    print(f"  [{sprite_id}] OK — {len(anim_entries)} animations, {total_frames} frames")

    if temp_zip.exists():
        temp_zip.unlink()
    return True


def main():
    if len(sys.argv) > 1:
        subset = {k: MOUNT_CHARACTERS[k] for k in sys.argv[1:] if k in MOUNT_CHARACTERS}
        if not subset:
            print(f"Usage: python {sys.argv[0]} [sprite_id ...]")
            print(f"Available: {', '.join(sorted(MOUNT_CHARACTERS))}")
            sys.exit(1)
    else:
        subset = MOUNT_CHARACTERS

    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    ok = 0
    fail = 0
    for sprite_id, char_id in subset.items():
        if _import_one(sprite_id, char_id):
            ok += 1
        else:
            fail += 1

    print(f"\nDone: {ok} OK, {fail} FAILED")


if __name__ == "__main__":
    main()

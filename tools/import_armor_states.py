#!/usr/bin/env python3
"""Download PixelLab armor state zips, extract south direction frames,
and build .tres SpriteFrames per animation for use in the game.

Run with:  python tools/import_armor_states.py [race_gender ...]
Example:   python tools/import_armor_states.py human_male
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
CHAR_DIR = BASE_DIR / "assets" / "characters"
TEMP_ROOT = Path(tempfile.gettempdir()) / "opencode" / "armor_states"

DOWNLOAD_URL = "https://api.pixellab.ai/mcp/characters/{char_id}/download"

# Animation mapping: game anim name → possible PixelLab template names
# We look for the first match in the metadata.
ANIM_CANDIDATES: dict[str, list[str]] = {
    "idle":   ["idle", "breathing-idle"],
    "walk":   ["walk", "walking-8-frames", "walking", "walking-6-frames"],
    "attack": ["attack", "cross-punch", "fight-stance-idle-8-frames"],
    "death":  ["death", "falling-back-death"],
}

ANIM_META = {
    "idle":   {"speed": 5.0,  "loop": True},
    "walk":   {"speed": 8.0,  "loop": True},
    "attack": {"speed": 6.0,  "loop": False},
    "death":  {"speed": 6.0,  "loop": False},
}

# Armor state name → folder suffix
STATE_MAP = {
    "Wearing massive post": "armor_massive",
    "Wearing rugged post-": "armor_rugged",
    "Wearing heavy post-a": "armor_heavy",
}

# Completed armor state character IDs per race_gender.
# Format: {race_gender: {"state_name": char_id}}
# Add as states complete.
COMPLETED: dict[str, dict[str, str]] = {
    "human_male": {
        "Wearing massive post": "375cf174-96f3-44d5-8a91-22f98c8950f2",
        "Wearing rugged post-": "e9b387fd-af61-4506-8f81-96bb640c72b2",
        "Wearing heavy post-a": "c1b86102-f8a2-4c05-a1a1-03519da63d5b",
    },
}


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


def _find_source(meta: dict, anim_name: str) -> str | None:
    """Return the zip-relative folder name for an animation that has south frames."""
    meta_anims = meta["frames"]["animations"]
    candidates = ANIM_CANDIDATES.get(anim_name, [anim_name])
    for key in candidates:
        if key in meta_anims and "south" in meta_anims[key]:
            return key
        # Also match keys with hash suffix: "walk-b3603f3f" -> "walk"
        if key + "-" in {k.split("-")[0] + "-" for k in meta_anims if "-" in k}:
            matching = [k for k in meta_anims if k.startswith(key + "-") and "south" in meta_anims[k]]
            if matching:
                return matching[0]
    return None


def _find_rotation_source(meta: dict) -> str | None:
    """Return south rotation path if available."""
    rotations = meta["frames"].get("rotations", {})
    return rotations.get("south", None)


def _build_tres(char_dir: Path, tres_name: str,
                png_frames: dict[str, list[str]], ext_resources: list[str]) -> None:
    """Build the .tres SpriteFrames file from copied frame paths.

    ext_resources is the flat list of all [ext_resource ...] lines in order:
    idle frames, then walk frames, then attack frames, then death frames.
    We compute the correct resource ID for each frame by tracking offsets.
    """
    # Compute per-animation frame counts to derive resource IDs
    anim_order = ["idle", "walk", "attack", "death"]
    frame_counts: dict[str, int] = {}
    for a in anim_order:
        fps = png_frames.get(a, [])
        if fps:
            frame_counts[a] = len(fps)

    # Build prefix-sum offset so each animation's first frame knows its ID
    offsets: dict[str, int] = {}
    off = 1
    for a in anim_order:
        offsets[a] = off
        off += frame_counts.get(a, 0)

    anim_entries: list[str] = []
    for anim_name in anim_order:
        cnt = frame_counts.get(anim_name, 0)
        if cnt == 0:
            continue
        meta = ANIM_META[anim_name]
        start = offsets[anim_name]
        fps_parts: list[str] = []
        for fi in range(cnt):
            fps_parts.append(f'{{"duration": 1.0, "texture": {_fmt_id(start + fi)}}}')
        anim_entry = (
            f'{{"name": "{anim_name}", "speed": {meta["speed"]}, '
            f'"loop": {str(meta["loop"]).lower()}, "frames": [{", ".join(fps_parts)}]}}'
        )
        anim_entries.append(anim_entry)

    if not anim_entries:
        print(f"    WARN: no animations to write for {tres_name}")
        return

    load_steps = len(ext_resources) + 2
    lines = [
        f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]',
        "",
    ]
    lines.extend(ext_resources)
    lines.extend(["", "[resource]"])
    lines.append(f"animations = [{', '.join(anim_entries)}]")
    lines.append("")

    tres_path = char_dir / f"{tres_name}.tres"
    tres_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"    wrote {tres_path.name} — {len(anim_entries)} anims, {len(ext_resources)} frames")


def import_armor_state(race_gender: str, state_name: str, char_id: str) -> bool:
    """Download zip and build .tres for one armor state."""
    rg_dir = CHAR_DIR / race_gender
    state_suffix = STATE_MAP.get(state_name, state_name.lower().replace(" ", "_"))
    state_dir = rg_dir / state_suffix
    state_dir.mkdir(parents=True, exist_ok=True)

    temp_zip = TEMP_ROOT / f"{char_id}.zip"
    temp_extract = TEMP_ROOT / char_id

    print(f"  [{race_gender}/{state_suffix}] downloading...")
    try:
        urllib.request.urlretrieve(DOWNLOAD_URL.format(char_id=char_id), temp_zip)
    except Exception as e:
        print(f"  [{race_gender}/{state_suffix}] DOWNLOAD FAILED: {e}")
        return False
    time.sleep(0.5)

    if temp_extract.exists():
        import shutil
        shutil.rmtree(temp_extract)
    try:
        with zipfile.ZipFile(temp_zip, "r") as zf:
            zf.extractall(temp_extract)
    except Exception as e:
        print(f"  [{race_gender}/{state_suffix}] UNZIP FAILED: {e}")
        return False

    meta_file = temp_extract / "metadata.json"
    if not meta_file.exists():
        print(f"  [{race_gender}/{state_suffix}] no metadata.json")
        return False
    meta = json.loads(meta_file.read_text(encoding="utf-8"))
    state = meta["states"][0]
    meta_anims = state["frames"]["animations"]

    # Map each game animation → PNG frame paths
    png_frames: dict[str, list[str]] = {}  # game_anim → [rel_frame_paths]
    png_paths_all: list[str] = []  # all copied paths
    res_id = 1

    for game_anim in ["idle", "walk", "attack", "death"]:
        src_key = _find_source(state, game_anim)
        if src_key and "south" in meta_anims[src_key]:
            south_fps = meta_anims[src_key]["south"]
        else:
            continue

        # Copy frames
        anim_dir = state_dir / game_anim
        anim_dir.mkdir(parents=True, exist_ok=True)

        frame_list: list[str] = []
        for fi, rel in enumerate(sorted(south_fps)):
            src_file = temp_extract / rel
            dst_name = f"frame_{fi:02d}.png"
            dst_file = anim_dir / dst_name
            if not src_file.exists():
                print(f"    WARN: missing {rel}")
                continue
            dst_file.write_bytes(src_file.read_bytes())
            png_paths_all.append(str(dst_file))
            frame_list.append(f"res://assets/characters/{race_gender}/{state_suffix}/{game_anim}/{dst_name}")
        if frame_list:
            png_frames[game_anim] = frame_list
            print(f"    {game_anim}: {len(frame_list)} frames")

    # Also export the south rotation as a static _S.png fallback
    rot_south = _find_rotation_source(state)
    if rot_south:
        src_file = temp_extract / rot_south
        if src_file.exists():
            dst_file = state_dir / f"{race_gender}_{state_suffix}_S.png"
            dst_file.write_bytes(src_file.read_bytes())
            _make_import(f"res://assets/characters/{race_gender}/{state_suffix}/{dst_file.name}", dst_file)
            print(f"    rotation south.png saved")

    if not png_frames:
        print(f"  [{race_gender}/{state_suffix}] no south animations found!")
        return False

    # Write .tres
    ext_resources: list[str] = []
    for game_anim in ["idle", "walk", "attack", "death"]:
        fps_paths = png_frames.get(game_anim, [])
        for rp in fps_paths:
            ext_resources.append(f'[ext_resource type="Texture2D" path="{rp}" id="{res_id}"]')
            res_id += 1

    _build_tres(state_dir, f"{race_gender}_{state_suffix}", png_frames, ext_resources)

    # Cleanup zip
    if temp_zip.exists():
        temp_zip.unlink()
    return True


def main():
    args = sys.argv[1:] or list(COMPLETED.keys())
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)

    ok = 0
    fail = 0
    for rg in args:
        states = COMPLETED.get(rg, {})
        if not states:
            print(f"[{rg}] no completed states defined, skipping")
            continue
        print(f"\n=== {rg} ===")
        for state_name, char_id in states.items():
            if import_armor_state(rg, state_name, char_id):
                ok += 1
            else:
                fail += 1

    print(f"\nDone: {ok} OK, {fail} FAILED")


if __name__ == "__main__":
    main()

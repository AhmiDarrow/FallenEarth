#!/usr/bin/env python3
"""Download PixelLab armor state zips, extract south direction frames,
and build .tres SpriteFrames per animation.

Improved version that:
- Uses Bearer token auth
- Finds armor states in the group download automatically
- Supports human_male and human_female
"""
import hashlib
import io
import json
import sys
import uuid
import zipfile
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CHAR_DIR = BASE_DIR / "assets" / "characters"

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"

ANIM_CANDIDATES: dict[str, list[str]] = {
    "idle":   ["idle", "breathing-idle", "animating"],
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

STATE_MAP = {
    "wearing massive": "armor_massive",
    "wearing rugged":  "armor_rugged",
    "wearing heavy":   "armor_heavy",
}

BASE_IDS: dict[str, str] = {
    "human_male":   "f1d9e3d3-6a51-4bc3-8177-ef09802dc5ea",
    "human_female": "59659e0e-aba9-46a7-acc9-c22e7759dec7",
}


def _fmt_id(n: int) -> str:
    return f'ExtResource("{n}")'


def _make_import(png_name: str, rel_path_to_png: str, dst_file: Path) -> None:
    h = hashlib.md5(rel_path_to_png.encode()).hexdigest()
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

source_file="{rel_path_to_png}"
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
    imp_path = dst_file.parent / (png_name + ".import")
    imp_path.write_text(content, encoding="utf-8")


def _find_source(meta_anims: dict, anim_name: str) -> str | None:
    candidates = ANIM_CANDIDATES.get(anim_name, [anim_name])
    for key in candidates:
        if key in meta_anims and "south" in meta_anims[key]:
            return key
        matching = [k for k in meta_anims if k.startswith(key + "-") and "south" in meta_anims[k]]
        if matching:
            return matching[0]
    return None


def _build_tres(tres_dir: Path, tres_name: str,
                png_frames: dict[str, list[str]], ext_resources: list[str]) -> None:
    anim_order = ["idle", "walk", "attack", "death"]
    frame_counts: dict[str, int] = {}
    for a in anim_order:
        fps = png_frames.get(a, [])
        if fps:
            frame_counts[a] = len(fps)

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
        fps_parts = [f'{{"duration": 1.0, "texture": {_fmt_id(start + fi)}}}' for fi in range(cnt)]
        anim_entry = (
            f'{{"name": "{anim_name}", "speed": {meta["speed"]}, '
            f'"loop": {str(meta["loop"]).lower()}, "frames": [{", ".join(fps_parts)}]}}'
        )
        anim_entries.append(anim_entry)

    if not anim_entries:
        print(f"    WARN: no animations to write for {tres_name}")
        return

    load_steps = len(ext_resources) + 2
    lines = [f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]', ""]
    lines.extend(ext_resources)
    lines.extend(["", "[resource]"])
    lines.append(f"animations = [{', '.join(anim_entries)}]")
    lines.append("")
    
    tres_path = tres_dir / f"{tres_name}.tres"
    tres_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"    wrote {tres_path.name} — {len(anim_entries)} anims, {len(ext_resources)} frames")


def download_zip(char_id: str) -> bytes | None:
    import urllib.request
    url = f"https://api.pixellab.ai/mcp/characters/{char_id}/download"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {API_KEY}",
        "User-Agent": "Python/3.13"
    })
    try:
        resp = urllib.request.urlopen(req, timeout=120)
        return resp.read()
    except Exception as e:
        print(f"    DOWNLOAD FAILED: {e}")
        return None


def import_single_state(z, state, race_gender, state_name, armor_suffix):
    rg_dir = CHAR_DIR / race_gender
    state_dir = rg_dir / armor_suffix
    state_dir.mkdir(parents=True, exist_ok=True)

    meta_anims = state["frames"]["animations"]
    png_frames = {}
    ext_resources = []

    for game_anim in ["idle", "walk", "attack", "death"]:
        src_key = _find_source(meta_anims, game_anim)
        if src_key and "south" in meta_anims[src_key]:
            south_fps = meta_anims[src_key]["south"]
        else:
            print(f"    {game_anim}: no south frames found")
            continue

        anim_dir = state_dir / game_anim
        anim_dir.mkdir(parents=True, exist_ok=True)

        frame_list = []
        for fi, rel in enumerate(sorted(south_fps)):
            try:
                src_data = z.read(rel)
            except KeyError:
                print(f"    WARN: missing {rel}")
                continue
            
            png_name = f"frame_{fi:02d}.png"
            dst_file = anim_dir / png_name
            dst_file.write_bytes(src_data)
            
            rel_png = f"res://assets/characters/{race_gender}/{armor_suffix}/{game_anim}/{png_name}"
            frame_list.append(rel_png)
        
        if frame_list:
            png_frames[game_anim] = frame_list
            print(f"    {game_anim}: {len(frame_list)} frames")

    # Export south rotation
    rot_south = state["frames"]["rotations"].get("south")
    if rot_south:
        try:
            src_data = z.read(rot_south)
            dst_file = state_dir / f"{race_gender}_{armor_suffix}_S.png"
            dst_file.write_bytes(src_data)
            rel_png = f"res://assets/characters/{race_gender}/{armor_suffix}/{dst_file.name}"
            _make_import(dst_file.name, rel_png, dst_file)
            print(f"    rotation south.png saved ({len(src_data)} bytes)")
        except KeyError:
            print(f"    WARN: rotation not found")

    if not png_frames:
        print(f"    ERROR: no south animations extracted!")
        return False

    for game_anim in ["idle", "walk", "attack", "death"]:
        for rp in png_frames.get(game_anim, []):
            ext_resources.append(f'[ext_resource type="Texture2D" path="{rp}" id="{len(ext_resources)+1}"]')

    _build_tres(state_dir, f"{race_gender}_{armor_suffix}", png_frames, ext_resources)
    return True


def import_armor_states_for(race_gender: str) -> bool:
    base_id = BASE_IDS.get(race_gender)
    if not base_id:
        print(f"[{race_gender}] no base character ID defined")
        return False

    print(f"  downloading group zip (char_id={base_id})...")
    data = download_zip(base_id)
    if not data:
        return False

    z = zipfile.ZipFile(io.BytesIO(data))
    meta = json.loads(z.read("metadata.json"))
    states = meta["states"]
    
    armors_found = 0
    for si, state in enumerate(states):
        rots = state["frames"]["rotations"]
        first_rot = list(rots.values())[0]
        state_name = first_rot.split("/")[0]
        
        armor_suffix = None
        state_lower = state_name.lower().replace("_", " ")
        for desc, suffix in STATE_MAP.items():
            if desc in state_lower:
                armor_suffix = suffix
                break
        
        if armor_suffix is None:
            print(f"  [{si}] '{state_name}' — skip (base state or unknown)")
            continue
        
        print(f"  [{si}] '{state_name}' -> armor suffix '{armor_suffix}'")
        if import_single_state(z, state, race_gender, state_name, armor_suffix):
            armors_found += 1

    print(f"  Imported {armors_found}/{len(states)} states")
    return armors_found > 0


def main():
    targets = sys.argv[1:] or list(BASE_IDS.keys())
    ok = 0
    for rg in targets:
        print(f"\n{'='*50}")
        print(f"  {rg}")
        print(f"{'='*50}")
        if import_armor_states_for(rg):
            ok += 1
    print(f"\nDone: {ok} race/gender combos processed")


if __name__ == "__main__":
    main()

## Quick helper to generate Godot .import files for the new battle
## decor + UI PNGs. Each .import file uses the same texture settings as
## the existing battle_ui assets (no mipmaps, no sRGB conversion, lossy
## compression off, alpha border fix on). Hash is taken from the file
## path so the import is deterministic and matches what Godot would
## emit on first scan.
import os
import hashlib

ROOT = r"C:\Users\Administrator\FallenEarth\assets"

TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{basename}-{hash}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{rel_path}"
dest_files=["res://.godot/imported/{basename}-{hash}.ctex"]

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


def short_hash(rel_path: str) -> str:
    h = hashlib.md5(rel_path.encode("utf-8")).hexdigest()
    return h


def make_uid(rel_path: str) -> str:
    h = hashlib.md5(("uid:" + rel_path).encode("utf-8")).hexdigest()[:12]
    return f"b{h[0:6]}{h[6:12]}"


def process_dir(subdir: str) -> None:
    full = os.path.join(ROOT, subdir)
    for name in os.listdir(full):
        if not name.endswith(".png"):
            continue
        png_path = os.path.join(full, name)
        if os.path.exists(png_path + ".import"):
            continue
        rel_path = "assets/" + subdir.replace("\\", "/") + "/" + name
        basename = name
        h = short_hash(rel_path)
        uid = make_uid(rel_path)
        body = TEMPLATE.format(uid=uid, basename=basename, hash=h, rel_path=rel_path)
        with open(png_path + ".import", "w", encoding="utf-8") as f:
            f.write(body)
        print("wrote", png_path + ".import")


for sub in [
    "battle_decor/boulder",
    "battle_decor/skull",
    "battle_decor/cactus",
    "battle_decor/rubble",
    "battle_decor/thorns",
    "battle_decor/stump",
    "battle_decor/roots",
    "battle_ui",
]:
    process_dir(sub)

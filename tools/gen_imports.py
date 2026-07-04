#!/usr/bin/env python3
"""Generate .import files for all character sprites matching human_male template."""

import hashlib
import uuid
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "assets" / "characters"

TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{name}-{hash}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/characters/{folder}/{name}"
dest_files=["res://.godot/imported/{name}-{hash}.ctex"]

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


def main():
    count = 0
    for folder in sorted(BASE.iterdir()):
        if not folder.is_dir():
            continue
        name = f"{folder.name}_base.png"
        png = folder / name
        if not png.exists():
            continue
        imp = png.with_suffix(".png.import")
        if imp.exists():
            print(f"  [skip] {folder.name} — already exists")
            continue

        src_path = f"res://assets/characters/{folder.name}/{name}"
        h = hashlib.md5(src_path.encode()).hexdigest()
        uid = uuid.uuid4().hex[:13]

        content = TEMPLATE.format(folder=folder.name, name=name, hash=h, uid=uid)
        imp.write_text(content, encoding="utf-8")
        print(f"  [OK] {folder.name}/{imp.name}")
        count += 1

    print(f"\nGenerated {count} .import files")


if __name__ == "__main__":
    main()

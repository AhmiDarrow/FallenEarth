#!/usr/bin/env python3
"""Fix the .tres files to include the new frame_04 in idle animations."""
import os, re

BASE = r'C:\Users\Administrator\FallenEarth\assets\characters'

DIRS_WITH_ROTATION = [
    'human_male', 'human_female', 'mutant_male', 'mutant_female',
    'sentientai_male', 'sentientai_female', 'revenant_male', 'revenant_female',
    'nullborn_male', 'nullborn_female', 'cyborg_male', 'cyborg_female',
    'chthon_male', 'chthon_female', 'vesperid_female', 'vesperid_male',
]

def update_tres(tres_path, frame_res_path, frame_id):
    """Add a frame to the idle animation in the .tres file, handling spaces in JSON."""
    if not os.path.exists(tres_path):
        return False
    with open(tres_path, 'r') as f:
        content = f.read()
    
    # Find idle animation entry - handle both "name":"idle" and "name": "idle"
    idle_match = re.search(r'\{"name"\s*:\s*"idle"\s*,\s*"speed"\s*:\s*([\d.]+)\s*,\s*"loop"\s*:\s*(true|false)\s*,\s*"frames"\s*:\s*\[([^\]]+)\]\}', content)
    if not idle_match:
        print(f"  SKIP: idle not found in {os.path.basename(tres_path)}")
        return False
    
    # Add ext_resource
    res_line = f'\n[ext_resource type="Texture2D" path="{frame_res_path}" id="{frame_id}"]'
    last_res = content.rfind('\n[ext_resource')
    if last_res >= 0:
        next_line = content.find('\n', last_res + 1)
        content = content[:next_line] + res_line + content[next_line:]
    
    # Add frame
    old_idle = idle_match.group(0)
    new_frame = f'{{"duration":1.0,"texture":ExtResource("{frame_id}")}}'
    new_idle = old_idle.rstrip(']}') + ',' + new_frame + ']}'
    content = content.replace(old_idle, new_idle)
    
    with open(tres_path, 'w') as f:
        f.write(content)
    print(f"  Updated {os.path.basename(tres_path)}")
    return True

for name in DIRS_WITH_ROTATION:
    print(f"\n{name}:")
    char_dir = os.path.join(BASE, name)
    
    # Find the highest ext resource id across all tres files
    max_id = 0
    for fname in os.listdir(char_dir):
        if fname.endswith('.tres'):
            with open(os.path.join(char_dir, fname)) as f:
                for m in re.finditer(r'id="(\d+)"', f.read()):
                    max_id = max(max_id, int(m.group(1)))
    
    next_id = max_id + 1
    
    # Determine idle folders per character
    # Check which directories have frame_04.png
    has_idle = os.path.exists(os.path.join(char_dir, 'idle', 'frame_04.png'))
    has_idle_south = os.path.exists(os.path.join(char_dir, 'idle_south', 'frame_04.png'))
    has_idle_north = os.path.exists(os.path.join(char_dir, 'idle_north', 'frame_04.png'))
    has_idle_east = os.path.exists(os.path.join(char_dir, 'idle_east', 'frame_04.png'))
    
    # If idle_south exists but idle doesn't, copy frame_04 there
    if has_idle and not has_idle_south:
        import shutil
        src = os.path.join(char_dir, 'idle', 'frame_04.png')
        dst_dir = os.path.join(char_dir, 'idle_south')
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, 'frame_04.png')
        shutil.copy2(src, dst)
        print(f"  Copied idle/frame_04.png -> idle_south/frame_04.png")
        has_idle_south = True
    
    # Update south tres (try _south.tres then .tres)
    south_tres = os.path.join(char_dir, f'{name}_south.tres')
    if not os.path.exists(south_tres):
        south_tres = os.path.join(char_dir, f'{name}.tres')
    
    if has_idle_south:
        frame_path = f'res://assets/characters/{name}/idle_south/frame_04.png'
    elif has_idle:
        frame_path = f'res://assets/characters/{name}/idle/frame_04.png'
    else:
        frame_path = None
    
    if frame_path:
        update_tres(south_tres, frame_path, next_id)
        next_id += 1
    
    # Update north tres
    north_tres = os.path.join(char_dir, f'{name}_north.tres')
    if has_idle_north and os.path.exists(north_tres):
        fp = f'res://assets/characters/{name}/idle_north/frame_04.png'
        update_tres(north_tres, fp, next_id)
        next_id += 1
    
    # Update east tres
    east_tres = os.path.join(char_dir, f'{name}_east.tres')
    if has_idle_east and os.path.exists(east_tres):
        fp = f'res://assets/characters/{name}/idle_east/frame_04.png'
        update_tres(east_tres, fp, next_id)
        next_id += 1

print("\nDone!")

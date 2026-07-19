#!/usr/bin/env python3
"""Download character rotation sprites and add them as extra idle frames."""
import urllib.request
import zipfile
import io
import os
import re

BASE = r'C:\Users\Administrator\FallenEarth\assets\characters'
API = 'https://api.pixellab.ai/mcp/characters'

CHARACTERS = {
    'human_male':       'f1d9e3d3-6a51-4bc3-8177-ef09802dc5ea',
    'human_female':     '59659e0e-aba9-46a7-acc9-c22e7759dec7',
    'mutant_male':      '920cfc87-42cb-458a-95a5-7f7770a20b4b',
    'mutant_female':    'e94868f7-41f0-41ba-8b2e-163c74d95441',
    'sentientai_male':  '280add63-0199-40c4-aac1-725dfd809f5e',
    'sentientai_female':'d8260770-2d3b-4b79-b599-a133957fd85e',
    'revenant_male':    '808982dc-48e9-4e56-809d-94a8e2d28ef9',
    'revenant_female':  '45f8cee2-6f76-47d4-b606-57ff2f73fb04',
    'nullborn_male':    'cb86a338-179c-43c7-8d5c-df39c51f75b1',
    'nullborn_female':  'e664c570-405e-4e29-930d-83a9fb3f1a3f',
    'cyborg_male':      '8d28fd41-bca5-47ed-a46f-3973f0dea2d1',
    'cyborg_female':    '7b7062e9-a0a0-4149-ae80-5199039796c2',
    'chthon_male':      '8d00bae6-1905-43ba-b363-71d2b860351d',
    'chthon_female':    '9eb12b2d-4a12-40a6-af6b-d597a2a1113e',
    'vesperid_female':  '5a89dc26-2f8f-486f-baf8-25bb995ce55a',
    'vesperid_male':    '232d35ca-5da8-493a-9410-3266886a04fe',
}

DIR_MAP = {
    'south': 'idle',
    'north': 'idle_north',
    'east': 'idle_east',
}

def download_zip(char_id):
    url = f'{API}/{char_id}/download'
    resp = urllib.request.urlopen(url, timeout=120)
    return zipfile.ZipFile(io.BytesIO(resp.read()))

def update_tres(tres_path, new_frame_path):
    """Add a 5th frame to the idle animation in the .tres file."""
    if not os.path.exists(tres_path):
        print(f"  WARNING: {tres_path} not found")
        return False
    with open(tres_path, 'r') as f:
        content = f.read()
    
    # Count existing idle frames
    idle_match = re.search(r'\{"name":"idle","speed":([\d.]+),"loop":(true|false),"frames":\[([^\]]+)\]\}', content)
    if not idle_match:
        print(f"  WARNING: Could not find idle animation in {tres_path}")
        return False
    
    speed = idle_match.group(1)
    loop = idle_match.group(2)
    frames_str = idle_match.group(3)
    
    # Count existing frames
    existing_count = len(re.findall(r'\{"duration":[\d.]+,"texture":ExtResource\("(\d+)"\)\}', frames_str))
    
    # Find the next available ext_resource id
    res_ids = [int(m) for m in re.findall(r'id="(\d+)"', content)]
    next_id = max(res_ids) + 1 if res_ids else 2
    
    # Add the new ext_resource
    res_line = f'\n[ext_resource type="Texture2D" path="{new_frame_path}" id="{next_id}"]'
    # Insert before the last ext_resource or before [resource]
    last_res_idx = content.rfind('[ext_resource')
    if last_res_idx >= 0:
        next_line = content.find('\n', last_res_idx)
        content = content[:next_line] + res_line + content[next_line:]
    
    # Add the new frame to the idle animation
    new_frame = f'{{"duration":1.0,"texture":ExtResource("{next_id}")}}'
    old_idle = idle_match.group(0)
    new_idle = old_idle.replace(']}', ',' + new_frame + ']}')
    content = content.replace(old_idle, new_idle)
    
    with open(tres_path, 'w') as f:
        f.write(content)
    
    print(f"  Added frame {existing_count + 1} to idle animation in {os.path.basename(tres_path)}")
    return True

def process_character(char_name, char_id):
    print(f"\n{char_name} ({char_id}):")
    
    char_dir = os.path.join(BASE, char_name)
    if not os.path.exists(char_dir):
        print(f"  SKIP: {char_dir} not found")
        return
    
    # Download the ZIP
    print(f"  Downloading...")
    try:
        z = download_zip(char_id)
    except Exception as e:
        print(f"  ERROR downloading: {e}")
        return
    
    # For each direction, extract rotation sprite and save as frame_04
    for dir_key, folder_name in DIR_MAP.items():
        zip_path = f'{char_name}/rotations/{dir_key}.png'
        try:
            rot_data = z.read(zip_path)
        except KeyError:
            print(f"  WARNING: {zip_path} not in ZIP")
            continue
        
        target_dir = os.path.join(char_dir, folder_name)
        os.makedirs(target_dir, exist_ok=True)
        
        # Find the next frame number
        existing_frames = [f for f in os.listdir(target_dir) if f.startswith('frame_') and f.endswith('.png')]
        next_num = len(existing_frames)
        frame_name = f'frame_{next_num:02d}.png'
        frame_path = os.path.join(target_dir, frame_name)
        
        with open(frame_path, 'wb') as f:
            f.write(rot_data)
        print(f"  Saved {folder_name}/{frame_name} ({len(rot_data)} bytes)")
        
        # Delete any existing .import file so Godot reimports
        import_path = frame_path + '.import'
        if os.path.exists(import_path):
            os.remove(import_path)
    
    # Update south .tres file
    tres_path = os.path.join(char_dir, f'{char_name}_south.tres')
    if not os.path.exists(tres_path):
        tres_path = os.path.join(char_dir, f'{char_name}.tres')
    
    rel_frame = f'res://assets/characters/{char_name}/idle/frame_04.png'
    update_tres(tres_path, rel_frame)
    
    # Update north .tres file
    north_tres = os.path.join(char_dir, f'{char_name}_north.tres')
    if os.path.exists(north_tres):
        rel_frame_n = f'res://assets/characters/{char_name}/idle_north/frame_04.png'
        update_tres(north_tres, rel_frame_n)
    
    # Update east .tres file
    east_tres = os.path.join(char_dir, f'{char_name}_east.tres')
    if os.path.exists(east_tres):
        rel_frame_e = f'res://assets/characters/{char_name}/idle_east/frame_04.png'
        update_tres(east_tres, rel_frame_e)

# Process all characters
for name, cid in CHARACTERS.items():
    process_character(name, cid)

print("\nDone!")

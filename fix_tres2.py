#!/usr/bin/env python3
"""Cleanly fix .tres files - correct the idle animation frame insertion."""
import os, re

BASE = r'C:\Users\Administrator\FallenEarth\assets\characters'

DIRS = ['human_male', 'human_female', 'mutant_male', 'mutant_female',
        'sentientai_male', 'sentientai_female', 'revenant_male', 'revenant_female',
        'nullborn_male', 'nullborn_female', 'cyborg_male', 'cyborg_female',
        'chthon_male', 'chthon_female', 'vesperid_female', 'vesperid_male']

for name in DIRS:
    char_dir = os.path.join(BASE, name)
    for fname in sorted(os.listdir(char_dir)):
        if not fname.endswith('.tres'):
            continue
        fpath = os.path.join(char_dir, fname)
        with open(fpath, 'r') as f:
            content = f.read()
        
        # Fix load_steps
        res_count = len(re.findall(r'\[ext_resource', content))
        content = re.sub(r'load_steps=\d+', f'load_steps={res_count}', content)
        
        # Fix broken idle animation pattern
        # Current broken: ExtResource("5")},{"duration":1.0,"texture":ExtResource("27")]}}
        # Should be: ExtResource("5")},{"duration":1.0,"texture":ExtResource("27")}]}
        content = re.sub(
            r'\)\},\{"duration":[\d.]+,"texture":ExtResource\("\d+"\)\]\}\}',
            lambda m: m.group(0).replace(']}}', ']}\n'),
            content
        )
        
        with open(fpath, 'w') as f:
            f.write(content)
        
        # Verify
        with open(fpath, 'r') as f:
            fixed = f.read()
        
        # Check for bracket issues near frame_04 references
        anim_start = fixed.find('animations =')
        if anim_start >= 0:
            idle = re.search(r'\{"name"\s*:\s*"idle".*?\}\]', fixed[anim_start:])
            if idle:
                text = idle.group()
                opens = text.count('{')
                closes = text.count('}')
                if opens != closes:
                    print(f"STILL BROKEN {fname}: {opens} vs {closes}")
                    print(text)
                else:
                    print(f"OK {fname}")

print("\nDone!")

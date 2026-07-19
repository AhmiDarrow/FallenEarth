#!/usr/bin/env python3
"""Fix .tres files: correct frame insertion, update load_steps."""
import os, re

BASE = r'C:\Users\Administrator\FallenEarth\assets\characters'

DIRS = ['human_male', 'human_female', 'mutant_male', 'mutant_female',
        'sentientai_male', 'sentientai_female', 'revenant_male', 'revenant_female',
        'nullborn_male', 'nullborn_female', 'cyborg_male', 'cyborg_female',
        'chthon_male', 'chthon_female', 'vesperid_female', 'vesperid_male']

for name in DIRS:
    print(f"\n{name}:")
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
        
        # Find the idle animation's last frame entry - pattern: ExtResource("N")}]
        # Then add the new frame before the ]}
        # New frame is the one with the highest id that references frame_04
        frame_04_matches = [(m.group(1), m.start()) for m in re.finditer(r'frame_04\.png" id="(\d+)"', content)]
        if not frame_04_matches:
            continue
        
        frame_04_id = frame_04_matches[-1][0]
        
        # Fix: the idle animation currently has a broken trailing frame like:
        # ExtResource("5"),{"duration":1.0,"texture":ExtResource("27")}]
        # Need to find and fix this pattern
        
        # Replace the broken pattern: "),{"duration":...  with ")},{"duration":...
        content = re.sub(
            r'(ExtResource\("\d+"\))\s*,\s*\{("duration":[\d.]+,"texture":ExtResource\("(\d+)"\))\}\]',
            lambda m: m.group(1) + '},' + '{' + m.group(2) + ']}' if m.group(3) == frame_04_id else m.group(0),
            content
        )
        
        with open(fpath, 'w') as f:
            f.write(content)
        
        # Verify the file is valid
        with open(fpath, 'r') as f:
            fixed = f.read()
        
        # Count open/close braces in animations section
        anim_start = fixed.find('animations =')
        if anim_start >= 0:
            # Check that idle frames are properly formatted
            idle_section = re.search(r'\{"name"\s*:\s*"idle".*?\}\]', fixed[anim_start:])
            if idle_section:
                text = idle_section.group()
                opens = text.count('{')
                closes = text.count('}')
                if opens != closes:
                    print(f"  BRACKET MISMATCH in {fname}: {opens} vs {closes}")
                else:
                    print(f"  OK {fname} ({res_count} resources)")

print("\nDone!")

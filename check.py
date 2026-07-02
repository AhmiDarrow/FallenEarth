import py_compile
import sys

files = [
    ("character_archetypes.py", "scripts/character_archetypes.py"),
    ("appearance_system.py", "scripts/appearance_system.py")
]

for name, path in files:
    try:
        py_compile.compile(path)
        print(f"OK - {name}")
    except py_compile.PyCompileError as e:
        print(f"FAILED - {name}: {e.message}")
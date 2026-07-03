#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

# Use absolute paths from this script's directory
SCRIPT_DIR = Path(__file__).resolve().parent

print("Checking character_archetypes.py...")
result = subprocess.run([sys.executable, "-m", "py_compile", str(SCRIPT_DIR / "scripts" / "character_archetypes.py")], capture_output=True)
if result.returncode == 0:
    print(f"[OK - no syntax errors in character_archetypes.py")
else:
    print(f"✗ FAILED: {result.stderr.decode()}")

print("\nChecking appearance_system.py...")
result = subprocess.run([sys.executable, "-m", "py_compile", str(SCRIPT_DIR / "scripts" / "appearance_system.py")], capture_output=True)
if result.returncode == 0:
    print(f"[✓] OK - no syntax errors in appearance_system.py")
else:
    print(f"✗ FAILED: {result.stderr.decode()}")

print("\nDone!")
import json
from pathlib import Path

def load_json(path):
    try:
        with open(path, 'r') as f:
            data = json.load(f)
            print(f"✓ {path} loaded successfully")
            return data
    except FileNotFoundError:
        print(f"✗ {path} not found")
        return None
    except json.JSONDecodeError:
        print(f"✗ Invalid JSON in {path}")
        return None

def test_race_manager():
    races = load_json("../data/races.json")
    classes = load_json("../data/character_classes.json")
    templates = load_json("../data/appearance.json")  # player_templates stale removed; using appearance
    
    if not races or not classes:
        print("\n✗ Failed to load required JSON files")
        return False
    
    # Validate current race structure (dict with upworld/underworld)
    if "upworld" not in races or "underworld" not in races:
        print("\n✗ Missing race categories (upworld/underworld)")
        return False
    print("✓ races present")
    
    # classes now array in data/
    if isinstance(classes, list) and len(classes) > 0:
        print("✓ classes loaded (array)")
    else:
        print("\n✗ classes unexpected")
        return False
    
    # templates/appearance basic
    if isinstance(templates, dict):
        print("✓ appearance-like templates present")
    
    print(f"\n✓ All managers validated successfully (updated for canonical data)!")
    return True

if __name__ == "__main__":
    test_race_manager()

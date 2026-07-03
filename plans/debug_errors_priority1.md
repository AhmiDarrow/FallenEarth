# Debug Errors - Priority 1 Fix

## Context

The game is missing `data/enemy_archetypes.json` which is required by the EncounterBuilder for spawning mobs in the HubWorld. This is causing 8 warning messages during game startup.

## Investigation

1. Check if file exists at `data/enemy_archetypes.json`
2. Review EncounterBuilder.gd to understand expected data structure
3. Determine if file needs to be created or if fallback mechanism is needed

## Action Plan

### Step 1: Check File Existence

Check if `data/enemy_archetypes.json` exists:
```bash
Test-Path "C:\Users\Administrator\FallenEarth\data\enemy_archetypes.json"
```

### Step 2: Review EncounterBuilder

Read `scripts/EncounterBuilder.gd` to understand:
- Expected JSON structure
- Error handling for missing data
- Fallback mechanisms

### Step 3: Fix Missing Data

**Option A: Create Empty File**
If the file doesn't exist, create it with proper JSON structure:
```json
{
  "archetypes": []
}
```

**Option B: Add Fallback Mechanism**
If the file should exist but is missing, add error handling in EncounterBuilder:
```gdscript
if not enemy_archetypes:
    enemy_archetypes = create_default_archetypes()
```

### Step 4: Test and Verify

1. Build the game
2. Start the game
3. Verify no more "Missing data: enemy_archetypes.json" warnings
4. Confirm mobs spawn correctly in HubWorld

## Verification

- [ ] No more "Missing data: enemy_archetypes.json" warnings in logs
- [ ] Mobs spawn correctly in HubWorld
- [ ] Game starts without errors related to enemy archetypes

## Files to Modify

1. `data/enemy_archetypes.json` - Create or update
2. `scripts/EncounterBuilder.gd` - Add fallback mechanism if needed

## Notes

- This is a data file, not code - should not cause crashes
- Missing data is better than crashes
- Consider adding logging for missing data to help with debugging

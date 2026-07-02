# Character Selection UI — Phase 2 Spec

## What's Here

- **Race selector** (dropdown) showing all 8 races + their stats from `data/races.json`
- **Class selector** (dropdown or radio buttons) for Scavenger, Technician, Survivor
- **Save/load**: Serialize full player state to JSON in `user://save.json`, load on startup

## Race Display Format (cards below dropdown)
```
┌─────────────┐
│  Human      │
│  HP:100 EN:100    hunger:100 rad:0%   │
│ ────────────│
│ Jack-of-all- │
│ trades.      │
└─────────────┘
```

## Class Display Format (same style)
```
┌─────────────────────┐
│ Scavenger          │
│ HP:+5 Rng:+10       │
│ ─────────────────── │
│ • foraging_expert  │
│ • scrap_recycler   │
│ • waste_resistant  │
└─────────────────────┘
```

## Implementation

**autoload.gd** — singleton handling save path resolution (`user://save.json`), load-on-startup.

**ui_main.tscn** — main UI with:
- VBoxContainer → RaceSelectorVBox + ClassSelectorVBox
- OptionButton for race dropdown (populate from races.json)
- OptionButtons for class selection (radio-style, mutually exclusive)
- Label nodes displaying selected race stats and class bonuses
- Confirm button that finalizes selection

**ui_logic.gd** — script handling:
- Loading both JSON files on scene ready
- Dropdown populate with race names
- Class radio logic (only one can be selected at a time)
- Confirm handler builds PlayerState from dropdown + radio choice
- Save to user://save.json using `FileAccess.get_open_path()` for Windows path resolution
- Load check on confirm — if save exists, show "Loaded: [filename]"

## Minimal Approach

No animations. No 3D preview. Plain Godot UI with clear text. Works end-to-end: pick race → pick class → confirm → player state saved to JSON → reload clears screen and re-populates from that file.
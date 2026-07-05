---
name: hubworld-mob-combat-fix
description: Fixed scene parse error + flat mob sprites so HubWorld mobs are visible and combat triggers
---

## Current Focus: HubWorld Mob Visibility & Combat Fix (Round 2)

Round 1 fixed the scene parse error blocking the seeder. Round 2 fixed the
mob PNGs themselves — they were flat 1-color blobs because
`generate_mob_sprites.py` drew the outline, body, head, and legs in the
same color. Regenerated all 27 with a 2px dark outline + visible body parts
(eye, mandibles, leg separation, etc.) per archetype. Script also auto-fills
missing sprite entries from `data/mobs.json`.

### Immediate Next Step

F5 playthrough: New Game → World Gen → pick start hex → Character → HubWorld.
Mobs should now read as silhouettes with dark borders against the terrain.
Watch Godot Output for `[HubWorld] Mob seed: ...` and `[MobVisual] Loaded
sprite: ...` lines.

### Relevant Handoffs

- [[hubworld-mob-combat-fix]] — this handoff (current focus)
- [[stardew-sprite-pipeline-handoff]] — display options (still relevant)
- [[latter-handoff]] — procedural drawing milestone (mostly obsolete post-fix)

### Context Files

- `docs/NEXT_TASKS.md` — project task queue (P0 F5 playthrough is now the active test)
- `memory/PROJECT_MEMORY.md` — display conventions unchanged
- `memory/SESSION_NOTES/HANDOFF_2026-07-04_2034.md` — full 9-section details on both fix rounds

---

Proceed with F5 verification, then continue with `docs/NEXT_TASKS.md` P1 items.
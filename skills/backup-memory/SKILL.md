---
name: backup-memory
description: Create a dated full backup copy of the critical shared memory layer (memory/ + docs/) into a backups/ folder. Run before major switches or periodically. Pure filesystem copy — no git dependency.
---

# backup-memory Skill

## Purpose
Protect the shared external brain against accidental deletion or bad edits during long projects.

## Steps
1. Determine current date/time for the backup folder name: `backups/YYYY-MM-DD_HHMM_backup/`
2. Create the backups/ directory at project root if it does not exist.
3. Recursively copy:
   - The entire `memory/` folder
   - The entire `docs/` folder
   - (Optional) the `skills/` folder if you want full procedure history
4. Optionally write a small `backup-manifest.txt` inside the backup folder listing what was copied and when.
5. Report the location of the backup to the user.

## Invocation
"Run backup-memory before we switch to Claude Code."

## Notes
- This is deliberately simple and local.
- Later you can layer compression or offsite sync on top.
- Always safe to run multiple times.

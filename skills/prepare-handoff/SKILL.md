---
name: prepare-handoff
description: At the end of a focused session or before switching agents, generate a complete, high-quality 9-section handoff markdown file. Reads core project files (LATEST_HANDOFF, OVERVIEW, ARCHITECTURE, PROJECT_MEMORY, recent files), summarizes the work done in this session from context and file inspection, writes a timestamped HANDOFF_YYYY-MM-DD_HHMM.md into memory/SESSION_NOTES/, and updates memory/LATEST_HANDOFF.md. Supports explicit "git_free" mode — never rely solely on git; always inspect files + use conversation summary.
---

# prepare-handoff Skill

Use this skill whenever a session is ending, before handing off to another agent (Hermes ↔ Claude Code), or when context feels large.

## Mandatory Rules
- Always follow the exact 9 sections defined in `docs/HANDOFF_PROTOCOL.md`.
- Output must be self-contained. The receiving agent should be able to resume with only this handoff + the 3-4 core docs.
- Be concrete. Use file paths, bullet lists, short diffs only when critical.
- Update LATEST_HANDOFF.md immediately after writing the new handoff file.
- Be honest about what is incomplete or blocked.

## Step-by-Step Procedure (Git-Free Mode — Default)

1. **Load Core Context**
   - Read `memory/LATEST_HANDOFF.md` to know the previous state.
   - Read the previous handoff file named inside it.
   - Read `docs/PROJECT_OVERVIEW.md`
   - Read `docs/ARCHITECTURE.md`
   - Read `docs/HANDOFF_PROTOCOL.md` (for reference)
   - Read `memory/PROJECT_MEMORY.md`
   - Read `docs/NEXT_TASKS.md`

2. **Gather Work from This Session**
   - Review the current conversation / task instructions for what was requested.
   - Use available tools to inspect recently changed or relevant files (read_file, grep, list_dir, terminal ls, etc.).
   - Note any files you created, edited, or deleted.
   - Do **not** assume git is present. If git status works, you may use it as supplemental info only.

3. **Determine Recommended Next Provider**
   - Default to Hermes for continuation / memory work.
   - Recommend Claude Code when the remaining work involves deep reasoning, large refactors, architecture changes, or hard algorithms.
   - Justify briefly.

4. **Build the 9 Sections**
   1. Header (Date, Session type + model/provider used, Focus)
   2. What Was Accomplished (bullets, concrete)
   3. Key Decisions & Rationale (reference ARCHITECTURE.md)
   4. Modified Files (list paths + 1-line description)
   5. Current State / Blockers
   6. Next Steps (1-5 atomic items, prioritized)
   7. Context That Must Survive (gotchas, partial state, conventions)
   8. Recommended Next Model/Provider + why
   9. Relevant Memory/Skills (pointers)

5. **Write the File**
   - Filename: `memory/SESSION_NOTES/HANDOFF_YYYY-MM-DD_HHMM.md` (use current local time, zero-pad minutes if needed).
   - Use clean markdown.
   - After writing successfully, update `memory/LATEST_HANDOFF.md` to contain only the new filename (e.g. `HANDOFF_2026-06-29_1430.md`).

6. **Optional Post-Handoff**
   - Suggest running `compact-and-learn` if the session was long.
   - Suggest running backup_memory skill.

## Quality Bar (Remedy will judge)
- Sloppy = vague bullets, missing sections, no file list, "just trust me".
- Excellent = precise, scannable, links to files/memory, tells the next agent exactly where to pick up.

## Example Invocation
"Use prepare-handoff to end this session and prepare to switch to Claude Code for the refactoring."

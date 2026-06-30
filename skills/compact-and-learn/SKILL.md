---
name: compact-and-learn
description: When context is getting large (~70% limit) or "dumb zone" symptoms appear, or at natural break points, run compaction. Summarize recent work, extract durable facts into PROJECT_MEMORY.md, extract reusable procedures into new skills/ entries, update ARCHITECTURE.md if needed, and clear non-essential history for the next turn. This is how the system gets smarter over time.
---

# compact-and-learn Skill

Trigger proactively. Do not wait until the model is already degraded.

## When to Run
- Approaching practical context limit
- Repeatedly explaining the same thing
- Before a long break or agent switch
- After a complex multi-step piece of work
- When the user or previous handoff suggests it

## Step-by-Step Procedure

1. **Capture Current State**
   - Read recent conversation turns (or use the last N user/assistant messages).
   - Re-read the current task focus and what was just completed.
   - Read latest handoff if not already in context.

2. **Write Durable Facts to PROJECT_MEMORY.md**
   - Scan for:
     - New conventions or style decisions
     - Gotchas discovered
     - Environment details
     - User preferences observed
   - Append under the appropriate section (use clear ## headings).
   - Keep entries concise and scannable.
   - Never delete old valuable entries unless they are explicitly superseded.

3. **Extract Reusable Procedures as Skills**
   - If you performed a repeatable sequence (e.g. "how we generate a new handoff", "how we safely edit Godot scripts", "our backup process"), create or update a skill under `skills/<kebab-name>/SKILL.md`.
   - Write high-quality frontmatter + instructions so future agents (Hermes/Claude/Grok) can invoke it.
   - Mirror the new skill to `~/.hermes/skills/`, `~/.claude/skills/`, and `~/.grok/skills/` when appropriate.

4. **Update ARCHITECTURE.md if Decisions Changed**
   - Any significant shift in how we structure agents, memory, routing, or tech choices belongs here.
   - Add a dated note.

5. **Update NEXT_TASKS.md**
   - Mark completed items.
   - Reprioritize.

6. **Optionally Generate a Compaction Handoff**
   - If this is a major compaction before ending the session, use prepare-handoff afterwards.
   - Mention in the handoff that compaction was performed and which new facts/skills were created.

7. **Advise the Agent**
   - "Non-essential recent history has been externalized. Proceed with fresh context using only the loaded memory + skills + the task at hand."

## Output Expectations
A good compaction run produces:
- Updated PROJECT_MEMORY.md (visible changes)
- 0 or more new/updated skill directories
- Possibly updated ARCHITECTURE.md or NEXT_TASKS.md
- A short summary of what was learned/extracted

## Example
"Run compact-and-learn on the last 20 turns, then prepare-handoff."

## Long-term Effect
Every time this skill is used well, the overall system becomes more capable and requires less re-explanation. This is the self-improvement loop.

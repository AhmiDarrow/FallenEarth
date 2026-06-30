---
name: load-project-context
description: Before starting meaningful work, prepare a minimal, high-signal context package. Reads the latest handoff + PROJECT_OVERVIEW + ARCHITECTURE + relevant sections of PROJECT_MEMORY + any skill pointers. Optionally performs lightweight retrieval over memory/ and skills/ directories. Returns a condensed briefing the agent can use without context bloat. Always the first action when resuming from a handoff.
---

# load-project-context Skill

Use this at the very start of any new session or after loading a handoff from another agent.

## Goals
- Minimize tokens while maximizing relevant knowledge.
- Never dump entire history.
- Surface only what is required for the declared focus.

## Step-by-Step

1. **Read the Pointer and Latest Handoff**
   - Read `memory/LATEST_HANDOFF.md`
   - Read the handoff file it references in full.
   - Extract: previous accomplishments, open next steps, surviving context, recommended model.

2. **Read Immutable Project Truth**
   - Read `docs/PROJECT_OVERVIEW.md` (goal + success criteria + constraints)
   - Read `docs/ARCHITECTURE.md` (current decisions)
   - Read `docs/HANDOFF_PROTOCOL.md` (reminder of the rules)

3. **Load Durable Memory Selectively**
   - Read `memory/PROJECT_MEMORY.md`
   - Skim for sections relevant to the current task (Environment, Coding Conventions, Gotchas, User Preferences).
   - Do not re-read the whole thing if task is narrow.

4. **Retrieve From Skills (if applicable)**
   - List contents of `skills/`
   - Read any SKILL.md files mentioned in the handoff or obviously relevant (e.g. prepare-handoff if you need to end the session).
   - For larger skill libraries later, do a simple keyword grep or directory scan.

5. **Optional Lightweight RAG / Search (Future)**
   - If a local search tool or embedding index exists over memory/ and skills/, query it for the current focus.
   - Otherwise fall back to targeted file reads + grep.

6. **Synthesize a Condensed Package**
   In your response (or internal scratch), produce something like:

   ```markdown
   ## Resumed Context (condensed)
   - Goal: ...
   - Last Accomplished: ...
   - Current Focus for this session: ...
   - Must-remember facts: (bullet the critical ones from memory)
   - Open Next Steps from previous: ...
   - Relevant Skills: ...
   - Files I should look at first: ...
   ```

7. **Stop**
   - Do not continue to implementation until you have explicitly loaded + acknowledged this package.
   - If something is missing, read the specific files you need.

## Invocation Example
"First use load-project-context for the task 'add user auth to the API', then begin work."

## Anti-Patterns
- Starting work without loading latest handoff.
- Re-reading every previous handoff instead of using the summary + memory.
- Ignoring the "Context That Must Survive" section.

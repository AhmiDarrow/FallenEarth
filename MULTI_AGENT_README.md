# Fallen Earth — Multi-Agent Automatic Development (Remedy)

This project has the full automatic multi-agent coding setup installed (based on the 2026-06-29 handoff + later automatic orchestration layer).

## Quick Start
1. `cd C:\Users\Administrator\FallenEarth`
2. Log into **Hermes as Remedy** (your normal sarcastic/efficient persona).
3. Give a high-level goal, e.g.:
   - "Advance the next milestone on world generation"
   - "Get character data loading and basic race/class selection working"
   - "Review current state and create next atomic tasks"

Remedy will:
- Automatically load the latest handoff + all context.
- Maintain NEXT_TASKS, memory, dispatches.
- Do work locally or prepare + (optionally launch) a dispatch to Claude Code / sub-agents.
- Write clean handoffs and keep state updated.

## Key Files
- `AGENTS.md`, `REMEDY.md`, `CLAUDE.md` (auto-load roots for Hermes / Claude Code)
- `docs/` — OVERVIEW, ARCHITECTURE, HANDOFF_PROTOCOL, NEXT_TASKS (seeded from dev_plan)
- `memory/` — LATEST_HANDOFF, SESSION_NOTES (handoffs), PROJECT_MEMORY, CURRENT_STATE, dispatches/
- `skills/` — remedy (orchestrator), prepare-handoff, load-project-context, etc.
- Existing planning docs (dev_plan.md, IDEA_SYNOPSIS.md, lore.md) remain primary for game design.

## Hermes Integration
- `.hermes/config.yaml` points at the shared layer.
- Your previous `.hermes/plans/` usage continues for internal plans.
- Cross-agent work uses the memory/ handoff + dispatch system.

See the bootstrap handoff in `memory/SESSION_NOTES/HANDOFF_2026-06-29_2100.md` for details of the setup.

The system is designed so you give direction; Remedy drives the rest automatically.

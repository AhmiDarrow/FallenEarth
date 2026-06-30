# CLAUDE.md — Fallen Earth (Godot Survival RPG)

This is a long-form Godot 4 project using a strict external multi-agent handoff system.

## Mandatory Startup for Any Session Here
1. Read `memory/LATEST_HANDOFF.md`
2. Read the handoff it points to in `memory/SESSION_NOTES/`
3. Read `docs/PROJECT_OVERVIEW.md` and `docs/ARCHITECTURE.md`
4. Read relevant sections of `memory/PROJECT_MEMORY.md` and `docs/NEXT_TASKS.md`
5. Check for a dispatch in `memory/dispatches/claude/`

Then perform **only** the atomic task assigned. Do not expand scope.

## When Dispatched by Remedy
- You are the specialist worker for one focused atomic task (e.g., implement specific biome generation logic in WorldGenerator.gd, wire a manager, add a UI flow step).
- Follow Godot data-driven patterns (load JSON from data/, keep logic in managers).
- At end: produce a clean 9-section handoff in `memory/SESSION_NOTES/`, update `LATEST_HANDOFF.md`, stop.

## Key Conventions
- Data lives in `data/*.json`.
- Autoload managers in `scripts/`.
- Current focus areas: world generation, character systems, save/load, combat/rift loop (see dev_plan.md and NEXT_TASKS.md).

Root files `AGENTS.md` and `REMEDY.md` control the orchestrator (Hermes/Remedy). Use the handoff system for continuity across sessions and agents.

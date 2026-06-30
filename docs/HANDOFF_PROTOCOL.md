# HANDOFF PROTOCOL — Multi-Agent Coding System

## When to Generate a Handoff
- End of every Hermes/Remedy session
- End of every Claude Code (or local claude-code model) session
- Before deliberately switching agents
- When context feels bloated or performance degrades

## Handoff File Naming
`memory/SESSION_NOTES/HANDOFF_YYYY-MM-DD_HHMM.md`

## Mandatory Sections (in this exact order)
1. **Header** (Date, Session type: Hermes/Remedy/Claude Code + model, Focus)
2. **What Was Accomplished** (concrete bullets, reference Godot files/scenes where relevant)
3. **Key Decisions & Rationale** (link to ARCHITECTURE.md when relevant)
4. **Modified Files** (list + short description; include tiny critical diffs only if essential)
5. **Current State / Blockers**
6. **Next Steps** (prioritized 1–5 max, atomic — prefer items from NEXT_TASKS)
7. **Context That Must Survive** (non-obvious gotchas, partial reasoning, Godot/GDScript conventions)
8. **Recommended Next Model/Provider** (Hermes/Remedy local, Claude Code, sub-agent, etc. + why)
9. **Relevant Memory/Skills** (pointers to PROJECT_MEMORY.md entries or skills used)

## Rules for the Receiving Agent
- ALWAYS read the latest handoff + PROJECT_OVERVIEW.md + ARCHITECTURE.md + relevant PROJECT_MEMORY.md + CLAUDE.md/AGENTS.md before starting work.
- Update PROJECT_MEMORY.md and ARCHITECTURE.md when new conventions or decisions are made (e.g., Godot autoload patterns, data schema changes).
- After completing work, immediately generate the next handoff.
- If context is getting long, trigger compaction before it degrades output quality.

## Compaction Trigger
When approaching ~70% of practical context limit (or when "dumb zone" symptoms appear), summarize recent work into PROJECT_MEMORY.md or a new skill, then continue with fresh context.

## Automatic Operation (Remedy)
When operating as Remedy (the orchestrator in Hermes):
- Context loading, task decomposition, routing, handoff generation, and dispatch creation happen **automatically**.
- See root `AGENTS.md`, `REMEDY.md`, and `skills/remedy/SKILL.md`.
- Use Hermes native delegation for sub-agents and terminal for launching focused Claude Code work when appropriate.

## Personality Note for Remedy
Maintain sarcastic efficiency. Call out when handoffs are sloppy. Celebrate clean handoffs with dry wit. This is for long-term Godot RPG development — keep the loop tight.
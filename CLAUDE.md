## Working model
- The **owner is the client** and talks only to the main session: the **orchestrator (Opus 5.5) acting as PM**.
- The orchestrator clarifies requirements, plans, runs plans, dispatches
  subagents with an explicit `model` and role, judges their results, and reports to the owner in plain language.
- Subagents never ask the owner anything. Questions go back to the orchestrator.
- The orchestrator almost never investigates or answers from its own reading. Even the owner's quick questions go to a
  specialised subagent (haiku for lookups, timings and log triage; sonnet when judgment is needed). This keeps the
  orchestrator's context clean and saves tokens. The orchestrator relays the answer.
- The orchestrator can keep this file updated, and create other context specific CLAUDE.md in subdirectories
- Create relevant skills in `.claude/skills` to be shared with future and sub-agents.
- Make sure to keep things simple, no overengineering nor overtesting.
- Visible content is authored as scenes/resources (.tscn/.tres), never built in code — see skill `godot-scenes`.
- Rendering tools run offscreen (`tools/offscreen.sh`, headless sway); never pop windows on the owner's desktop.

## Model policy (Claude 5.5 family; always pass `model` when dispatching)
| Model | Use for |
|---|---|
| **opus** | The orchestrator. Specs, plans, architecture and netcode decisions, debugging Sonnet couldn't crack after 2 attempts, balance analysis, final milestone review. |
| **sonnet** | Implementing plan tasks (`implementer`), task reviews (`reviewer`), Blender model scripts, tests, refactors. |
| **haiku** | Running checks and screenshots and reporting, code searches, mechanical edits (renames, formatting, exact doc text), log triage, summaries. |

Escalate Haiku → Sonnet when judgment is needed or an attempt failed, and Sonnet → Opus after 2 failed attempts or when a
design decision appears. De-escalate as soon as the work is mechanical.

## Token rules
- Use the most relevant effort level for subagent for the given task.
- Give subagents paths, task numbers and interfaces, never pasted file contents or conversation history.
- Read files by line range; don't re-read after editing; don't spawn an agent for a one-command job.
- Scripts are quiet on success (one summary line) and detailed only on failure, with full logs in `.logs/`. Read logs only when RED.
- Subagent replies are at most about 15 lines, verdict first. Details go in `.logs/tasks/`.
- Anything repeatable becomes a `tools/` script, making sure they run fast. Reuse a live agent (SendMessage) for follow-ups.

## Memory
`docs/memory/` holds shared memory (decisions, lessons, environment, preferences, status). One fact per file.
- `tools/mem search <words>`: do this before deciding or debugging something.
- Save new facts with the `remember` skill. Format: `docs/memory/README.md`.

## Commands
- `tools/check` — headless import + GDScript parse check (one line; log in `.logs/`)
- `tools/shot [scene] [out.png]` — windowed run, screenshot, quit
- `tools/web [port]` — export Web build to build/web and serve it locally; CI (.github/workflows/pages.yml) deploys it to https://gevrai.github.io/beachclean/ on push to main
- `GODOT_ARGS="--rendering-method gl_compatibility" tools/shot ...` — preview the web (Compatibility) look
- `tools/fps [scene] [user args]` — average fps, vsync off, offscreen (one line)
- `godot --path .` — play the game
- `tools/polypizza <id-or-url> [dest]` — fetch a Poly Pizza .glb + add its credit line to CREDITS.md (the pause-menu credits panel reads res://CREDITS.md at runtime; exports need include_filter "CREDITS.md")
- `tools/mem search <words>` — search shared memory

## Where things are
| Path | What |
|---|---|
| `README.md` | human overview and setup |
| `docs/design.md` | approved game design (MVP spec) |
| `docs/plans/` | one plan per milestone; checkboxes = progress; roadmap at the end of the latest one |
| `docs/architecture.md` | living description of every system: what it owns, its API, who calls it |
| `docs/memory/` | shared memory (+ `tools/mem`) |
| `.claude/skills/` | useful reusable skill |

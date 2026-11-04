# M1 — tiny prototype

Goal: the loop in `docs/design.md` is playable end to end on one beach, and it looks pretty.
Each task ends with `tools/check` GREEN; visual tasks also end with a `tools/shot` screenshot the reviewer looks at.

- [x] **1. Scaffold.** Godot project (`project.godot`, Forward+), folder layout (`scenes/`, `scripts/`, `assets/`),
      `tools/check` (headless import + script parse errors; one summary line, log to `.logs/`),
      `tools/shot [scene] [out.png]` (runs a scene windowed, saves a screenshot after ~2 s, quits),
      `.gitignore`, `README.md` setup, skill `.claude/skills/godot-workflow/SKILL.md` (how to check/shoot/run).
- [x] **2. Beach & lighting.** `scenes/beach.tscn`: sand terrain with gentle dunes (stylized sand shader), animated
      stylized water shader with shore foam, procedural sky, sun (DirectionalLight, soft shadows), WorldEnvironment
      (SDFGI or VoxelGI, glow, light fog, ACES/filmic tonemap), a few palms/rocks (Blender script or primitives).
      Expose `set_health(t: float)` on the environment that lerps saturation and sun colour/warmth (0 → greyish, 1 → golden).
- [x] **3. Player.** First-person CharacterBody3D: WASD, mouse look, captured mouse, Esc releases mouse.
      Center crosshair; raycast that highlights the debris under it within reach.
- [x] **4. Debris & bag.** `Debris` scene + data for the 4 types (simple stylized meshes), spawner that scatters ~150
      on the sand, tide timer that washes in new pieces. Click to pick up (with a satisfying pop/tween), bag with capacity, HUD (bag x/y, coins, health %).
- [x] **5. Shack & upgrades.** Recycling shack model + interact zone: E sells the bag; upgrade panel with the 5 upgrades,
      costs, levels; effects applied to the player. Central `GameState` autoload owns coins, bag, upgrades, health.
- [x] **6. Restoration.** Health drives `set_health`; milestone animals (crabs, gulls, turtle, hatchlings) spawn with
      simple looping animations; small toast when a milestone is reached.
- [x] **7. Bottles & save.** 3–5 message bottles (notes readable in the pause menu); autosave/load `user://save.json`.
- [x] **8. Polish pass.** Feel check: pickup juice, ambient wave sound, tuning so 100% takes ~15–20 min. Final screenshots.

## Roadmap after M1
Prestige / follow the current to new shores · more tools (sifter cart, boat) · more animals · audio & music.

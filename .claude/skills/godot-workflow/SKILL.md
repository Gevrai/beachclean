---
name: godot-workflow
description: How to check, screenshot and run the Beachclean Godot project (tools/check, tools/shot) plus GDScript 4.x gotchas. Use before/after any Godot code or scene change.
---
# Godot workflow
- `tools/check` - headless import + `--check-only` on every .gd. Prints `check: GREEN (N scripts)` or RED (see `.logs/check.log`). Run after every change (~7 s).
- `tools/shot [scenes/x.tscn] [out.png]` - windowed run, screenshot after 2 s, quit. Then Read the PNG to look at it. Default scene = main, default out `.logs/shot.png`. Log: `.logs/shot.log`.
- `tools/polypizza <id-or-url> [dest]` - download a Poly Pizza model to `assets/models/<dest>/` (default props) and append its CC-BY credit line to CREDITS.md (also add it to CreditsText in `scenes/ui/pause_menu.tscn`).
- Run the game: `godot --path .`
- `--shot-delay=SECONDS` (default 2) changes when the shot is taken, e.g. to compare two frames for motion.
- Shot works via the `DevTools` autoload (`scripts/dev_tools.gd`), which reacts only to user arg `-- --shot=PATH`.

## Gotchas
- User args go after `--`; read with `OS.get_cmdline_user_args()` (not `get_cmdline_args`).
- Wait `await RenderingServer.frame_post_draw` before reading the viewport texture.
- `--check-only` needs `--script`; it parses one file at a time, so cross-file `class_name` issues show up only at run time.
- New `.tscn` need `[gd_scene format=3]`; new `class_name` scripts need a re-import (`tools/check` does it).
- Use static typing (`var x: float`); `:=` fails when the type can't be inferred.

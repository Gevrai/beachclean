# Beachclean

This game is made fully with Claude mainly to try capabilities with Godot.

First-person 3D beach-cleaning game (Godot 4.7, GDScript, Forward+). Pick up debris, recycle it, upgrade, and watch the beach come back to life. See `docs/design.md`.

## Run
`godot --path .` (or open in the editor and press F5). Requires Godot 4.7.x on PATH.

## Tools
- `tools/check` - headless import + parse check of all scripts; one line, log in `.logs/check.log`.
- `tools/shot [scene] [out.png]` - run a scene windowed, save a screenshot after ~2 s (default `.logs/shot.png`).
- `tools/mem search <words>` - search shared project memory.

## Gallery
Open `scenes/gallery.tscn` in the Godot editor and press F6 (Run Current Scene; A/D or drag to pan, wheel or W/S to zoom): all items, coins and the message bottle with names, sizes and values.

## Controls
WASD move, mouse look, click pick up (hold with Grabber), E at the bins = recycle bag, E at the shack counter = upgrades, Esc pause, F1 cheat panel (debug).

## Credits

Third-party assets are credited in [CREDITS.md](CREDITS.md) and in the pause menu (Credits).

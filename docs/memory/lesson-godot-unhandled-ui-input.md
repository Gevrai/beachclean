Interaction keys (E/U/Esc) that must beat the player's `_unhandled_input` (Esc releases mouse) go in `_input` + `get_viewport().set_input_as_handled()`; a full-rect Control with mouse_filter STOP stops clicks reaching the player's recapture-on-click.
Why: unhandled input order is reverse tree order and the player handles Esc/click itself.
How to apply: shack.gd owns E/U/Esc; upgrade_panel.gd root Control is STOP. Headless tests for gameplay: scene in tools/tests/, run `godot --headless --path . res://tools/tests/x.tscn` (autoloads work).

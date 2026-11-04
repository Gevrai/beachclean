In Godot a parent's `_ready` runs AFTER its children's, so scene-child nodes cannot use parent state (e.g. beach noise/height_at) in `_ready`.
How to apply: beach.gd creates Player/DebrisManager/HUD at the end of its own `_ready` with `set_script(preload(..))` and sets `beach` var before add_child. Avoid `class_name` for these (cross-file parse issues in check).

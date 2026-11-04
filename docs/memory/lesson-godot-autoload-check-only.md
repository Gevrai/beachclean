`godot --check-only --script` and `--script` runs cannot resolve autoload names (GameState etc.): "Identifier not found". Not a real error.
Why: autoloads are only registered when running the project/scene normally.
How to apply: tools/check filters that noise and boots the main scene headless instead. For ad-hoc tests, write a temp .tscn with a Node script and run `godot --headless --path . path/to/test.tscn` (absolute path ok).

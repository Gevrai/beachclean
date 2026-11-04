---
name: godot-scenes
description: Rules for authoring visible content as Godot scenes/resources (.tscn/.tres/.gdshader) instead of code-built nodes, so the owner can see and tweak everything in the editor. Use before creating or changing any model, material, prop, environment or UI.
---
# Visible things are scenes and resources, not code

**Rule.** Anything the owner could want to see or tweak in the editor lives in files:
- Models/props/prefabs → `scenes/<area>/<name>.tscn` (MeshInstance3D with primitive meshes as sub_resources, or CSG, or imported .glb). One prefab per thing.
- Materials → `assets/materials/<name>.tres` (StandardMaterial3D or ShaderMaterial referencing `assets/shaders/*.gdshader`). Shared, not duplicated per instance.
- Environment / lighting → nodes in `scenes/beach.tscn` (WorldEnvironment with `assets/env/*.tres`, DirectionalLight3D), editable in the inspector.
- Tunable looks/values → exported vars or custom Resource `.tres` files (e.g. the polluted vs restored look), never magic numbers buried in code.
- Code is for behaviour only: spawning/scattering instances, game logic, animation driving, procedural audio.
- Procedural geometry that must stay procedural (terrain) → `@tool` script so it shows in the editor; prefer baking with an editor/CLI tool to a `.res`/`.tres` mesh.

**Hand-writing .tscn/.tres.** Header `[gd_scene format=3 uid="uid://<unique>"]` (load_steps optional in 4.x). Declare `[ext_resource type=... path="res://..." id="1_abc"]` then `[sub_resource type=... id="Mat_1"]` before `[node]` sections; reference as `ExtResource("1_abc")` / `SubResource("Mat_1")`. IDs unique within the file. Uids: make up a unique `uid://` string or omit the uid attribute — Godot fixes them on import. After writing, run `tools/check` (imports + loads) and open-test with a shot.

**Variation.** Random colour/tilt per instance: keep the prefab, set `instance_shader_parameter` or swap from a small list of material .tres, or a script on the prefab that randomizes in `_ready()` (skip randomization when `Engine.is_editor_hint()`).

**Verify.** Screenshot before and after (`tools/shot`, renders offscreen) and compare; the look must not regress.

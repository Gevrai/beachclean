Godot 4.7 look recipe: perturb NORMAL in world space inside fragment (INV_VIEW_MATRIX -> add noise -> VIEW_MATRIX) instead of NORMAL_MAP, since procedural ArrayMeshes have no tangents. Water depth = world y of the water minus world y reconstructed from hint_depth_texture (INV_PROJECTION_MATRIX then INV_VIEW_MATRIX).
Why: avoids tangent issues and gives a correct shoreline foam band on a gentle slope.
How to apply: low SPECULAR (~0.12) on water stops sky reflection washing out turquoise; keep volumetric fog density tiny (<0.006) or the sun blows out; sun bloom needs glow_hdr_threshold >1.
Also: camera at +Z looking has +X on the LEFT (right = forward x up). tools/shot forwards extra args after the 2nd (e.g. --health=1).

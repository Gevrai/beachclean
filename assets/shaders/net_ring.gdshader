shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Landing circle of the casting net: dashed ring + faint fill, drawn flat on the water. `tint` per instance (white = ok, red = can't land here).
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(0.88, 0.92, r) * (1.0 - smoothstep(0.96, 1.0, r));
	float dash = 0.55 + 0.45 * step(0.0, sin(atan(p.y, p.x) * 24.0 + TIME * 1.5));
	float fill = (1.0 - smoothstep(0.85, 1.0, r)) * 0.13;
	ALBEDO = tint.rgb;
	ALPHA = max(ring * dash * 0.9, fill) * tint.a;
}

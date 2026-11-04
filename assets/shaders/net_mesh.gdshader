shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// Casting net: a round diamond mesh of rope on a flat quad (everything outside the lines is discarded).
uniform vec4 rope_color : source_color = vec4(0.82, 0.68, 0.42, 1.0);
uniform float cells = 12.0;
uniform float line = 0.07;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (length(p) > 1.0) discard;
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.5 * cells;
	vec2 d = abs(fract(q) - 0.5);
	if (max(d.x, d.y) < 0.5 - line) discard;
	ALBEDO = rope_color.rgb;
	ROUGHNESS = 1.0;
}

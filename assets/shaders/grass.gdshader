shader_type spatial;
render_mode cull_disabled;
// Swaying dune-grass blades; UV.y = 0 at the root, 1 at the tip.
uniform vec3 root_color : source_color = vec3(0.3, 0.4, 0.15);
uniform vec3 tip_color : source_color = vec3(0.7, 0.8, 0.3);

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.6 + w.x * 0.6 + w.z * 0.4) * 0.5 + sin(TIME * 2.7 + w.x * 1.3) * 0.2;
	VERTEX.x += sway * 0.14 * UV.y * UV.y;
	VERTEX.z += sway * 0.07 * UV.y * UV.y;
}

void fragment() {
	vec3 c = mix(root_color, tip_color, UV.y);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	BACKLIGHT = c * 0.6;
}

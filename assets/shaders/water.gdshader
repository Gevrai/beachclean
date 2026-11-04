shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
// Stylized water: depth colour, gentle waves, crisp cartoon shore foam.
uniform vec3 shallow_color : source_color = vec3(0.25, 0.95, 0.85);
uniform vec3 deep_color : source_color = vec3(0.02, 0.35, 0.65);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform float absorb = 0.9;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);  // world-space direction to the sun (set by Beach)
uniform float glitter = 0.0;
uniform float foam_width = 0.05;
uniform float swell_amp = 0.12;
uniform float chop_amp = 0.06;
uniform sampler2D normal_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 wpos;

float swell_at(vec3 w) {
	return sin(TIME * 0.55 + w.x * 0.05) * 0.6 + sin(TIME * 0.31 + w.x * 0.11 + 1.7) * 0.4;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float chop = sin(w.x * 0.3 + TIME * 0.8) * cos(w.z * 0.37 - TIME * 1.1)
		+ 0.5 * sin(w.x * 0.71 - w.z * 0.53 + TIME * 1.7);
	VERTEX.y += swell_amp * swell_at(w) + chop_amp * chop;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// vertical water depth under this pixel
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	sv.xyz /= sv.w;
	vec3 sworld = (INV_VIEW_MATRIX * vec4(sv.xyz, 1.0)).xyz;
	float depth = max(wpos.y - sworld.y, 0.0);

	vec2 uv = wpos.xz;
	vec2 na = texture(normal_a, uv * 0.045 + vec2(TIME * 0.012, TIME * 0.007)).rg * 2.0 - 1.0;
	vec2 nb = texture(normal_b, uv * 0.11 - vec2(TIME * 0.02, -TIME * 0.015)).rg * 2.0 - 1.0;
	vec2 pert = (na * 0.6 + nb * 0.4) * 0.5;
	vec3 wn = normalize(vec3(pert.x, 1.0, pert.y));
	NORMAL = (VIEW_MATRIX * vec4(wn, 0.0)).xyz;

	float k = 1.0 - exp(-depth * absorb);
	vec3 col = mix(shallow_color, deep_color, pow(k, 0.8));

	// shore foam: bright band at the contact line, noisy and crisp, pulsing with the swell
	float n = texture(normal_a, uv * 0.09 + vec2(TIME * 0.02, 0.0)).b;
	float n2 = texture(normal_b, uv * 0.2 - vec2(0.0, TIME * 0.03)).b;
	float pulse = 0.5 + 0.5 * sin(TIME * 0.55 + wpos.x * 0.05);
	float w = foam_width * (0.7 + 0.6 * pulse);
	float f = (w - depth) / w + (n - 0.5) * 0.9 + (n2 - 0.5) * 0.5;
	float foam = smoothstep(0.32, 0.42, f);
	// second trailing foam line
	float line = abs(depth - (w * 2.6 + 0.04)) ;
	float f2 = (0.03 - line) / 0.03 + (n2 - 0.5) * 1.3;
	foam = max(foam, smoothstep(0.55, 0.65, f2) * 0.75);

	col = mix(col, foam_color, foam);
	float alpha = mix(0.35, 0.96, smoothstep(0.0, 1.8, depth));
	alpha *= smoothstep(0.0, 0.04, depth);
	alpha = max(alpha, foam * 0.95);

	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = mix(0.12, 0.8, foam);
	SPECULAR = 0.12;
	METALLIC = 0.0;
	// sun glitter path: sparkles where the perturbed normal reflects the sun towards the camera
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float g = pow(max(dot(reflect(-vw, wn), sun_dir), 0.0), 220.0);
	float sparkle = smoothstep(0.35, 0.8, n2) ;
	vec3 glit = vec3(1.0, 0.8, 0.55) * g * glitter * (0.35 + sparkle) * (1.0 - foam);
	EMISSION = col * 0.3 + glit * 6.0;
}

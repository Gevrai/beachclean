shader_type spatial;
render_mode cull_disabled;
// Marram-grass blades (meshes baked by scripts/dune_grass.gd). Per vertex: UV.y = 0 at the root .. 1 at the tip,
// COLOR = (blade dryness, blade phase, blade stiffness, 1). Per instance (INSTANCE_CUSTOM.r = clump dryness, .g = phase).
// root_color / tip_color are the fresh-green pair driven by BeachLook; the straw pair is for dry blades.
uniform vec3 root_color : source_color = vec3(0.3, 0.4, 0.15);
uniform vec3 tip_color : source_color = vec3(0.7, 0.8, 0.3);
uniform vec3 dry_root_color : source_color = vec3(0.4, 0.34, 0.14);
uniform vec3 dry_tip_color : source_color = vec3(0.86, 0.76, 0.42);
uniform float dryness : hint_range(0.0, 1.0) = 0.5;  // overall share of straw-coloured blades
uniform float translucency : hint_range(0.0, 1.5) = 0.8;
// Wind: gusts travel across the dunes along wind_dir; wind_strength = bend (m at 1 m height) in a gust.
uniform vec2 wind_dir = vec2(0.85, 0.5);
uniform float wind_strength : hint_range(0.0, 1.5) = 0.55;
uniform float wind_calm : hint_range(0.0, 1.0) = 0.12;  // constant lean when there is no gust
uniform float gust_speed : hint_range(0.0, 4.0) = 1.1;   // phase speed of the gust waves
uniform float gust_scale : hint_range(0.01, 0.5) = 0.11; // 1 / wavelength (per metre)
uniform float flutter : hint_range(0.0, 0.2) = 0.03;

varying float v_dry;
varying float v_shade;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 wd = normalize(wind_dir);
	vec2 pd = vec2(-wd.y, wd.x);
	float along = dot(origin.xz, wd);
	float across = dot(origin.xz, pd);
	// travelling gust waves, bent and mixed so they roll in irregular bands with lulls between
	float p = along * gust_scale - TIME * gust_speed * gust_scale * 6.0 + sin(across * gust_scale * 0.8) * 1.4;
	float g = sin(p) * 0.6 + sin(p * 2.3 + 1.7 + across * 0.05) * 0.4;
	float gust = smoothstep(-0.5, 1.0, g);
	float h = clamp(VERTEX.y, 0.0, 1.6);
	float stiff = 0.75 + 0.5 * COLOR.b;
	float bend = (wind_calm + gust * wind_strength) * h * h * stiff;
	float ph = COLOR.g * 6.2832 + INSTANCE_CUSTOM.g * 6.2832;
	float fl = sin(TIME * 6.0 + ph + h * 3.0) * flutter * h * (0.35 + gust) * COLOR.b;
	float wob = sin(p * 1.3 + ph * 0.3) * 0.12 * h * h * gust;
	vec3 off = vec3(wd.x, 0.0, wd.y) * (bend + fl) + vec3(pd.x, 0.0, pd.y) * (wob + fl * 0.7);
	off.y -= (bend * bend) * 0.5;
	// world offset -> instance-local (instances are yaw + uniform scale)
	mat3 m = mat3(MODEL_MATRIX);
	VERTEX += (transpose(m) * off) / dot(m[0], m[0]);
	v_dry = clamp(dryness + (INSTANCE_CUSTOM.r - 0.5) * 1.0 + (COLOR.r - 0.5) * 0.9, 0.0, 1.0);
	v_shade = 0.8 + 0.4 * fract(COLOR.g * 7.31 + COLOR.r * 3.17);
}

void fragment() {
	float t = UV.y;
	vec3 green = mix(root_color, tip_color, pow(t, 0.8));
	vec3 straw = mix(dry_root_color, dry_tip_color, pow(t, 0.8));
	vec3 c = mix(green, straw, smoothstep(0.25, 0.75, v_dry)) * v_shade;
	ALBEDO = c;
	ROUGHNESS = 0.65;
	SPECULAR = 0.25;
	AO = mix(0.2, 1.0, smoothstep(0.0, 0.55, t));
	AO_LIGHT_AFFECT = 0.8;
	// soft up-facing shading so the tufts read as masses, not as separate flat ribbons
	vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up_v, 0.55));
	BACKLIGHT = c * translucency;
	EMISSION = c * 0.05 * t;
}

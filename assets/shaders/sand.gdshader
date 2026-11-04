shader_type spatial;
// Stylized sand: warm colour patches, wind ripples, wet band near the water, dry-grass tint on dunes.
uniform vec3 sand_dry : source_color = vec3(1.0, 0.82, 0.55);
uniform vec3 sand_light : source_color = vec3(1.0, 0.9, 0.68);
uniform vec3 sand_wet : source_color = vec3(0.62, 0.43, 0.27);
uniform vec3 grass_tint : source_color = vec3(0.6, 0.62, 0.3);
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
uniform sampler2D patches : repeat_enable, filter_linear_mipmap;
uniform float swell = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float big = texture(patches, p * 0.011).r;
	float mid = texture(patches, p * 0.045 + 3.7).r;
	vec3 base = mix(sand_dry, sand_light, smoothstep(0.35, 0.65, big));
	base *= 0.93 + 0.14 * mid;
	// near-camera detail: soft blotches (~0.5 m) and fine mottling (~12 cm), stronger up close
	float near = 1.0 - smoothstep(6.0, 40.0, length(wpos - CAMERA_POSITION_WORLD));
	float blot = texture(patches, p * 0.4 + 11.3).r - 0.5;
	float fine = texture(patches, p * 1.7 + 5.1).r - 0.5;
	base *= 1.0 + (blot * 0.5 + fine * 0.4) * (0.45 + 0.55 * near);

	// dunes get a dry-grass tint
	float dune = smoothstep(1.0, 2.0, wpos.y + (mid - 0.5) * 0.9);
	base = mix(base, mix(base, grass_tint, 0.5), dune * 0.3);  // only a faint olive cast: dunes stay pale sand between the clumps

	// wind ripples (domain-warped sine), fading on dunes and wet sand
	float warp = texture(patches, p * 0.035).r * 5.0;
	float arg = (p.x * 0.55 + p.y * 1.05) * 2.2 + warp * 3.0;
	float rip = sin(arg);
	float rip_amt = (1.0 - dune) * smoothstep(0.1, 0.5, wpos.y);
	vec2 rip_grad = cos(arg) * vec2(0.55, 1.05) * 2.2 * 0.045 * rip_amt;
	base *= 1.0 + rip * 0.07 * rip_amt;
	base = mix(base, base * vec3(0.88, 0.76, 0.66), smoothstep(0.55, 1.0, -rip) * 0.5 * rip_amt);

	// wetness: darker, glossier near the waterline, moving with the swell
	float wet = 1.0 - smoothstep(0.0, 0.2, wpos.y - swell * 0.6);
	wet = max(wet, 0.0);
	base = mix(base, sand_wet, wet * 0.85);

	vec2 g = texture(grain, p * 1.3).rg * 2.0 - 1.0;
	vec2 g2 = texture(grain, p * 0.21).rg * 2.0 - 1.0;
	vec2 pert = g * 0.28 + g2 * 0.25 + rip_grad;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	wn = normalize(wn + vec3(pert.x, 0.0, pert.y));
	NORMAL = (VIEW_MATRIX * vec4(wn, 0.0)).xyz;

	// keep the sand out of ACES' shoulder (golden sun is bright): darker + a touch more saturated
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	base = mix(vec3(lum), base, 1.2) * 0.78;
	ALBEDO = base;
	ROUGHNESS = mix(0.92, 0.22, wet);
	SPECULAR = mix(0.0, 0.6, wet);
	// tiny sparkle
	float sp = step(0.985, texture(grain, p * 7.0).b);
	EMISSION = vec3(sp * 0.18) * (1.0 - wet) * (1.0 - dune);
}

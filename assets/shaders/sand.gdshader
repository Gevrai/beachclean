shader_type spatial;
// Stylized sand: warm colour patches, wind ripples (flat beach) / contour ripples (dune slopes), fine grain that
// fades with distance, a darker smoother wet band at the waterline, dry-grass tint on the dunes.
uniform vec3 sand_dry : source_color = vec3(1.0, 0.82, 0.55);
uniform vec3 sand_light : source_color = vec3(1.0, 0.9, 0.68);
uniform vec3 sand_wet : source_color = vec3(0.62, 0.43, 0.27);
uniform vec3 grass_tint : source_color = vec3(0.6, 0.62, 0.3);
uniform sampler2D grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D patches : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float swell = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	vec3 gn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);  // geometry normal, world space
	float steep = smoothstep(0.05, 0.3, 1.0 - gn.y);  // 0 = flat beach, 1 = dune slope

	// colour patches: big warm/light areas, mid mottling, and subtle warm/cool drifts
	float big = texture(patches, p * 0.011).r;
	float mid = texture(patches, p * 0.045 + 3.7).r;
	vec3 base = mix(sand_dry, sand_light, smoothstep(0.35, 0.65, big));
	base *= 0.93 + 0.14 * mid;
	float drift = smoothstep(0.3, 0.7, texture(patches, p * 0.07 + 8.1).r);
	base *= mix(vec3(1.03, 1.0, 0.95), vec3(0.97, 1.0, 1.04), drift);
	// near-camera detail: soft blotches (~0.5 m) and fine mottling (~12 cm), stronger up close
	float near = 1.0 - smoothstep(6.0, 40.0, dist);
	float blot = texture(patches, p * 0.4 + 11.3).r - 0.5;
	float fine = texture(patches, p * 1.7 + 5.1).r - 0.5;
	base *= 1.0 + (blot * 0.5 + fine * 0.4) * (0.45 + 0.55 * near);

	// dunes: faint olive cast, a touch warmer/darker on the slopes, soft darker band where the grass starts
	float dune = smoothstep(1.0, 2.0, wpos.y + (mid - 0.5) * 0.9);
	base = mix(base, mix(base, grass_tint, 0.5), dune * 0.3);
	base *= mix(vec3(1.0), vec3(1.0, 0.95, 0.88) * 0.95, steep * 0.6);
	float grassline = smoothstep(1.4, 2.8, wpos.y + (mid - 0.5) * 1.2);
	base = mix(base, base * vec3(0.8, 0.77, 0.62), grassline * 0.3);

	// wetness: darker, smoother band near the waterline, wavy edge, moving with the swell
	float wl = wpos.y - swell * 0.6 + (texture(patches, p * 0.08).r - 0.5) * 0.05;
	float wet = clamp(1.0 - smoothstep(0.0, 0.22, wl), 0.0, 1.0);
	float damp = 1.0 - smoothstep(0.1, 0.6, wl);
	base *= 1.0 - damp * 0.1;
	base = mix(base, sand_wet * (0.93 + 0.1 * mid), wet * 0.85);
	float rim = smoothstep(0.22, 0.27, wl) * (1.0 - smoothstep(0.27, 0.36, wl));  // dried salt line above the wet edge
	base *= 1.0 + rim * 0.07;

	// ripples: wind ripples on the flat beach, contour-following ripples on slopes (period ~ 1/slope, fades with distance)
	float warp = texture(patches, p * 0.035).r * 5.0;
	float arg1 = (p.x * 0.55 + p.y * 1.05) * 2.2 + warp * 3.0;
	float arg2 = wpos.y * 14.0 + warp * 2.0 + mid * 2.0;
	float rip = mix(sin(arg1), sin(arg2), steep);
	float rip_fade = 1.0 - smoothstep(25.0, 80.0, dist);
	float rip_amt = mix(smoothstep(0.1, 0.5, wpos.y) * (1.0 - dune), 0.55, steep) * (1.0 - wet) * rip_fade;
	vec2 rip_grad = mix(cos(arg1) * vec2(0.55, 1.05) * 2.2 * 0.045,
		-cos(arg2) * gn.xz / max(gn.y, 0.3) * 14.0 * 0.03, steep) * rip_amt;
	base *= 1.0 + rip * 0.1 * rip_amt;
	base = mix(base, base * vec3(0.88, 0.76, 0.66), smoothstep(0.55, 1.0, -rip) * 0.5 * rip_amt);

	// grain normals: the fine layer fades with distance (no shimmer), smoother when wet
	float grain_fade = (1.0 - smoothstep(12.0, 55.0, dist)) * (1.0 - wet * 0.85);
	vec2 g = texture(grain, p * 1.3).rg * 2.0 - 1.0;
	vec2 g2 = texture(grain, p * 0.21).rg * 2.0 - 1.0;
	vec2 pert = g * 0.28 * grain_fade + g2 * 0.25 * (1.0 - wet * 0.5) + rip_grad;
	vec3 wn = normalize(gn + vec3(pert.x, 0.0, pert.y));
	NORMAL = (VIEW_MATRIX * vec4(wn, 0.0)).xyz;

	// keep the sand out of ACES' shoulder (golden sun is bright): darker + a touch more saturated
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	base = mix(vec3(lum), base, 1.2) * 0.78;
	ALBEDO = base;
	ROUGHNESS = mix(0.92, 0.18, wet);
	SPECULAR = mix(0.0, 0.6, wet);
	// tiny sparkle (close up only)
	float sp = step(0.985, texture(grain, p * 7.0).b) * (1.0 - smoothstep(5.0, 22.0, dist));
	EMISSION = vec3(sp * 0.18) * (1.0 - wet) * (1.0 - dune);
}

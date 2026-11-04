shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
// Stylized water: depth colour, gentle waves, crisp cartoon shore foam, refracted shallows with a soft shoreline,
// two-scale ripple normals, a cheap screen-space reflection (SSR) with the engine's sky reflection as fallback,
// Fresnel, and a sun glitter path.
// NOTE: the vertex wave (swell_at + chop below) is copied by the floating debris: keep it unchanged.
uniform vec3 shallow_color : source_color = vec3(0.25, 0.95, 0.85);
uniform vec3 deep_color : source_color = vec3(0.02, 0.35, 0.65);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform float absorb = 0.9;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);  // world-space direction to the sun (set by Beach)
uniform float glitter = 0.0;
uniform float foam_width = 0.05;
uniform float swell_amp = 0.12;
uniform float chop_amp = 0.06;
uniform float refract_strength = 0.04;  // screen-space shift of what is seen through shallow water
uniform float reflect_strength = 1.0;   // 0 turns the screen-space reflection off
uniform float fine_ripples = 0.17;      // amplitude of the small ripple layers (fade out with distance)
uniform sampler2D normal_a : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_b : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

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
	float dist = length(VERTEX);

	// ripple normals: broad swell layers + two fine layers that fade out with distance (no shimmer)
	vec2 uv = wpos.xz;
	vec2 na = texture(normal_a, uv * 0.045 + vec2(TIME * 0.012, TIME * 0.007)).rg * 2.0 - 1.0;
	vec2 nb = texture(normal_b, uv * 0.11 - vec2(TIME * 0.02, -TIME * 0.015)).rg * 2.0 - 1.0;
	float fine_fade = 1.0 - smoothstep(25.0, 110.0, dist);
	vec2 nc = texture(normal_a, uv * 0.37 + vec2(-TIME * 0.05, TIME * 0.035)).rg * 2.0 - 1.0;
	vec2 nd = texture(normal_b, uv * 0.83 + vec2(TIME * 0.07, TIME * 0.06)).rg * 2.0 - 1.0;
	vec2 pert = (na * 0.6 + nb * 0.4) * 0.5 + (nc * 0.6 + nd * 0.4) * fine_ripples * fine_fade;
	vec3 wn = normalize(vec3(pert.x, 1.0, pert.y));
	NORMAL = (VIEW_MATRIX * vec4(wn, 0.0)).xyz;

	float k = 1.0 - exp(-depth * absorb);
	vec3 body = mix(shallow_color, deep_color, pow(k, 0.8));

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

	// refraction: what is under the water, shifted by the ripples (only in shallows, never from objects in front)
	vec2 shift = (VIEW_MATRIX * vec4(pert.x, 0.0, pert.y, 0.0)).xy * refract_strength * clamp(depth * 1.5, 0.0, 1.0);
	vec2 ruv = clamp(SCREEN_UV + shift, vec2(0.002), vec2(0.998));
	float rd_ = texture(depth_tex, ruv).r;
	vec4 rv = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, rd_, 1.0);
	if (rv.z / rv.w > VERTEX.z + 0.05) {
		ruv = SCREEN_UV;
	}
	vec3 under = textureLod(screen_tex, ruv, 0.0).rgb;
	under *= mix(vec3(1.0), shallow_color * 1.1, 1.0 - exp(-depth * 1.6));  // depth tint of the sand seen through

	// opacity: clear shallows, solid deep water, fully soft at the waterline (no hard intersection edge)
	float opacity = mix(0.4, 0.96, smoothstep(0.0, 1.6, depth));
	opacity *= smoothstep(0.0, 0.12, depth);
	// foam breakup: slow drifting patches thin the foam out (lacy, never a flat strip), the crisp lines stay
	float fm3 = texture(normal_b, uv * 0.55 + vec2(TIME * 0.035, -TIME * 0.02)).r;
	float fn4 = texture(normal_a, uv * 1.3 - vec2(TIME * 0.02, TIME * 0.03)).g;
	float fpatch = smoothstep(0.1, 0.5, fm3 * 0.6 + fn4 * 0.4);
	float foam_a = foam * (0.6 + 0.4 * fpatch);
	opacity = max(opacity, foam_a * 0.9 * smoothstep(0.0, 0.012, depth));
	vec3 fcol = foam_color * (0.42 + 0.2 * n2 + 0.14 * fpatch);  // shaded, not clipped white
	fcol = mix(fcol, shallow_color * 0.9, 0.1);  // picks up a little of the water
	vec3 col = mix(body, fcol, foam_a);

	// Fresnel + screen-space reflection (view-space ray march against the depth buffer, 18 steps)
	vec3 vdir = normalize(VERTEX);
	float ndv = clamp(dot(NORMAL, -vdir), 0.0, 1.0);
	float fres = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);
	vec3 refl = vec3(0.0);
	float hit = 0.0;
	vec3 rdir = reflect(vdir, NORMAL);
	if (reflect_strength > 0.0 && rdir.z < -0.02 && fres > 0.04 && foam < 0.9) {
		float t = 0.7;
		float stp = 0.7;
		for (int i = 0; i < 18; i++) {
			vec3 p = VERTEX + rdir * t;
			vec4 c = PROJECTION_MATRIX * vec4(p, 1.0);
			vec2 huv = c.xy / c.w * 0.5 + 0.5;
			if (huv.x < 0.0 || huv.x > 1.0 || huv.y < 0.0 || huv.y > 1.0) {
				break;
			}
			float hd = texture(depth_tex, huv).r;
			if (hd > 0.0) {
				vec4 hv = INV_PROJECTION_MATRIX * vec4(huv * 2.0 - 1.0, hd, 1.0);
				float diff = hv.z / hv.w - p.z;  // > 0: the ray is behind the surface
				if (diff > 0.0 && diff < stp * 1.5 + 0.3) {
					// refine between the last two samples
					float lo = t - stp;
					float hi = t;
					for (int j = 0; j < 3; j++) {
						float mid = 0.5 * (lo + hi);
						vec3 pm = VERTEX + rdir * mid;
						vec4 cm = PROJECTION_MATRIX * vec4(pm, 1.0);
						vec2 muv = cm.xy / cm.w * 0.5 + 0.5;
						float md = texture(depth_tex, muv).r;
						vec4 mv = INV_PROJECTION_MATRIX * vec4(muv * 2.0 - 1.0, md, 1.0);
						if (mv.z / mv.w - pm.z > 0.0) {
							hi = mid;
						} else {
							lo = mid;
						}
					}
					vec3 ph = VERTEX + rdir * hi;
					vec4 ch = PROJECTION_MATRIX * vec4(ph, 1.0);
					vec2 fuv = ch.xy / ch.w * 0.5 + 0.5;
					float edge = smoothstep(0.0, 0.08, min(min(fuv.x, 1.0 - fuv.x), min(fuv.y, 1.0 - fuv.y)));
					hit = edge * (1.0 - smoothstep(50.0, 150.0, hi));
					refl = textureLod(screen_tex, clamp(fuv, vec2(0.001), vec2(0.999)), 1.0).rgb;
					break;
				}
			}
			t += stp;
			stp *= 1.25;
		}
	}

	ALBEDO = col * opacity;
	ALPHA = 1.0;
	ROUGHNESS = mix(0.1, 0.8, foam);
	SPECULAR = (0.16 - 0.1 * hit) * (1.0 - foam);  // engine sky reflection is the fallback where the ray found nothing
	METALLIC = 0.0;

	// sun glitter path: sparkles where the perturbed normal reflects the sun towards the camera
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float sd = max(dot(reflect(-vw, wn), sun_dir), 0.0);
	float g = pow(sd, 220.0);
	float n3 = texture(normal_b, uv * 0.9 + vec2(TIME * 0.05, -TIME * 0.04)).b;
	float sparkle = smoothstep(0.35, 0.8, mix(n2, n3, 0.4 * fine_fade));
	vec3 glit = vec3(1.0, 0.8, 0.55) * (g * (0.35 + sparkle) + pow(sd, 24.0) * 0.1) * glitter * (1.0 - foam);

	EMISSION = under * (1.0 - opacity) + col * mix(0.3, 0.12, foam_a) * opacity + glit * 6.0
		+ refl * fres * hit * reflect_strength * (1.0 - foam);
}

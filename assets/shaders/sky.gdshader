shader_type sky;
// Stylized sky: gradient, soft sun glow, chunky cartoon clouds with sun-lit edges.
uniform vec3 zenith : source_color = vec3(0.15, 0.4, 0.8);
uniform vec3 mid : source_color = vec3(0.45, 0.7, 0.95);
uniform vec3 horizon : source_color = vec3(1.0, 0.78, 0.6);
uniform vec3 ground : source_color = vec3(0.7, 0.6, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.75, 0.45);
uniform float sun_size = 0.035;
uniform float cloud_cover = 0.5;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.9, 0.8);
uniform vec3 cloud_shade : source_color = vec3(0.6, 0.55, 0.7);
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;

float cn(vec2 uv) {
	return texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.7).r * 0.35;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.3, h));
	col = mix(col, zenith, smoothstep(0.25, 0.9, h));
	col = mix(col, ground, smoothstep(0.0, -0.12, h));

	vec3 sd = LIGHT0_DIRECTION;
	float s = max(dot(d, sd), 0.0);
	col += sun_color * (pow(s, 8.0) * 0.15 + pow(s, 48.0) * 0.3);

	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.18) * 0.28 + vec2(TIME * 0.003, 0.0);
		float n = cn(uv);
		float c = smoothstep(1.0 - cloud_cover * 0.75 - 0.1, 1.0 - cloud_cover * 0.75 + 0.03, n);
		vec2 off = normalize(sd.xz + vec2(0.0001)) * 0.02;
		float n2 = cn(uv + off);
		float lit = smoothstep(-0.02, 0.05, n - n2 + 0.01);
		vec3 cc = mix(cloud_shade, cloud_lit, lit);
		cc += sun_color * pow(s, 5.0) * 0.4;
		c *= smoothstep(0.0, 0.12, h);
		col = mix(col, cc, c);
	}
	// sun disc (HDR so it blooms)
	float disc = smoothstep(cos(sun_size), cos(sun_size * 0.8), dot(d, sd));
	col += sun_color * 6.0 * disc;
	COLOR = col;
}

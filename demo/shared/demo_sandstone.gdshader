shader_type spatial;
render_mode diffuse_burley;
// Weathered sandstone for a statue (demo only), no texture: a fine grain and a slow mottle in
// object space (so it moves with the statue), streaks running down, and the vertex colour (set
// per part when the figure is merged) darkening the recesses - the visor slit, the joints
// between plates - so a carved figure reads at 640 px. From GLYPHLUX's demo_sandstone.gdshader.
// Generated from WS/shared/demo_kit/demo_sandstone.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).

uniform vec4 base_col: source_color = vec4(0.34, 0.31, 0.26, 1.0);

varying vec3 v_o;

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Colour spaces, measured 2026-10-22 (the stage kit preview): Forward+ and Mobile hand
// source_color uniforms over linear and take ALBEDO as linear; the Compatibility renderer (and so
// the web demo) hands them over as written (sRGB) and takes ALBEDO as sRGB. A flat colour comes
// out the same either way, but whatever is multiplied in here (a mottle, a block's tone, a vertex
// colour) came out about twice as strong in Compatibility. So the colours are taken to linear
// light (ss_uniform), worked there, and handed back the way the renderer reads them
// (ss_albedo). Vertex colours are written as they look (sRGB) and converted in every renderer.
vec3 ss_to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

vec3 ss_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}

vec3 ss_uniform(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return ss_to_linear(c);
#else
	return c;
#endif
}

vec3 ss_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return ss_to_srgb(c);
#else
	return c;
#endif
}

void vertex() {
	v_o = VERTEX;
}

void fragment() {
	float mottle = 0.86 + 0.26 * vnoise(v_o * 4.0);
	// The fine grain fades to its average once it is under a pixel (no shimmer on a far statue).
	float px = length(fwidth(v_o));
	float grain = 0.94 + 0.12 * mix(vnoise(v_o * 38.0), 0.5, smoothstep(0.006, 0.025, px));
	float streak = 0.92 + 0.08 * vnoise(vec3(v_o.x * 14.0, v_o.y * 1.5, v_o.z * 14.0));
	ALBEDO = ss_albedo(ss_uniform(base_col.rgb) * mottle * grain * streak * ss_to_linear(COLOR.rgb));
	ROUGHNESS = 0.86;
}

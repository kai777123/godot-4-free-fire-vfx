shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// An old flagstone floor, no texture (demo only): rows of slabs of varied length, each its own
// shade and a hair of tilt (so neighbouring slabs catch the sun differently), worn edges, dark
// sunk joints with grit in them and a slow grime over the whole yard so it does not repeat.
// Joints and grit fade to their average once they are smaller than a pixel: no shimmer when
// the camera moves (MSAA smooths edges, not what a shader draws).
// From GLYPHLUX's and UNDALUX's demo_flagstone.gdshader (the slab rows of the first, the
// uniform names of the second).
// Generated from WS/shared/demo_kit/demo_flagstone.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).

uniform vec4 stone_color : source_color = vec4(0.31, 0.3, 0.285, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.13, 0.125, 0.12, 1.0);
// Row depth in metres; slabs in a row are 0.85 to 1.6 times that long.
uniform float slab = 0.8;
// Joint width in metres.
uniform float joint = 0.018;
uniform float variation : hint_range(0.0, 0.5) = 0.18;
uniform float roughness_base = 0.92;
// Slow grime over the whole floor (0 = clean).
uniform float grime = 0.25;
// How far each slab is tilted out of level (the normal, not the mesh).
uniform float tilt = 0.05;

varying vec3 v_w;

float fs_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float fs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fs_hash(i), fs_hash(i + vec2(1.0, 0.0)), f.x),
		mix(fs_hash(i + vec2(0.0, 1.0)), fs_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Colour spaces, measured 2026-10-22 (the stage kit preview): Forward+ and Mobile hand
// source_color uniforms over linear and take ALBEDO as linear; the Compatibility renderer (and so
// the web demo) hands them over as written (sRGB) and takes ALBEDO as sRGB. A flat colour comes
// out the same either way, but whatever is multiplied in here (a mottle, a block's tone, a vertex
// colour) came out about twice as strong in Compatibility. So the colours are taken to linear
// light (fs_uniform), worked there, and handed back the way the renderer reads them
// (fs_albedo). Vertex colours are written as they look (sRGB) and converted in every renderer.
vec3 fs_to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

vec3 fs_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}

vec3 fs_uniform(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return fs_to_linear(c);
#else
	return c;
#endif
}

vec3 fs_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return fs_to_srgb(c);
#else
	return c;
#endif
}

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = v_w.xz / slab;
	float row = floor(q.y);
	float len = mix(0.85, 1.6, fs_hash(vec2(row, 3.0)));
	float x = q.x / len + fs_hash(vec2(row, 9.0)) * 3.0;
	vec2 cell = vec2(floor(x), row);
	vec2 f = vec2(fract(x), fract(q.y));
	// Distance to the slab's edge, in metres.
	vec2 d = min(f, 1.0 - f) * vec2(len, 1.0) * slab;
	float px = max(fwidth(v_w.x), fwidth(v_w.z));
	float distant = smoothstep(0.015, 0.06, px);
	float wob = (fs_noise(v_w.xz * 9.0) - 0.5) * joint * 0.8 * (1.0 - distant);
	float edge_d = min(d.x, d.y) + wob;
	float jw = max(joint, px * 0.75);
	float on_slab = smoothstep(jw * 0.5, jw * 1.5, edge_d);
	on_slab = mix(0.88, on_slab, 1.0 - smoothstep(joint * 1.2, joint * 5.0, px));
	float h = fs_hash(cell);
	float shade = 1.0 + (h - 0.5) * 2.0 * variation;
	float fine = mix(fs_noise(v_w.xz * 13.0 + 4.0), 0.5, distant);
	float wear = 0.88 + 0.24 * fs_noise(v_w.xz * 2.3) * fine;
	// Dirt gathers along the joints: a slab darkens a little towards its edge.
	float rim = mix(0.9, 1.0, smoothstep(jw * 1.5, jw * 5.0, edge_d));
	float dirt = 1.0 - grime * (fs_noise(v_w.xz * 0.35) * 0.6 + fs_noise(v_w.xz * 0.9 + 3.0) * 0.4);
	vec3 slab_col = fs_uniform(stone_color.rgb) * shade * wear * rim;
	ALBEDO = fs_albedo(mix(fs_uniform(mortar_color.rgb), slab_col, on_slab) * dirt);
	ROUGHNESS = roughness_base - (h - 0.5) * 0.08;
	SPECULAR = 0.25;
	// Each slab a hair out of level.
	vec3 tw = vec3(fs_hash(cell + 17.0) - 0.5, 0.0, fs_hash(cell + 31.0) - 0.5) * 2.0 * tilt * on_slab;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tw, 0.0)).xyz);
}

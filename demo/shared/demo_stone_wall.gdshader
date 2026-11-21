shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Coursed masonry for a demo stage's walls, no texture (demo only): courses of blocks in running
// bond, each block its own shade with a soft rounded edge and a lighter upper face (relief under
// a high sun), sunk mortar joints, the lowest courses darker and greener (damp), slow weathering
// streaks. Joints fade to their average once they are under a pixel: no shimmer while the
// camera moves.
// From UNDALUX's demo_stone_wall.gdshader (hero look round 4: "near-white water needs something
// darker AND busier behind it"). Kit 2 draws the vertical joints too (the original compared
// abs(f.x) * 0.55 with the course threshold, so a course was one long block) and can take its
// coordinates from the mesh's UV, so a wall may run in any direction.
//   space 0: world XY, a wall running along X (the UNDALUX original; a BoxMesh works).
//   space 1: the mesh's UV in metres, x along the wall and y up (the kit's walls and arches).
// Generated from WS/shared/demo_kit/demo_stone_wall.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).

uniform vec4 stone_color : source_color = vec4(0.15, 0.145, 0.14, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.07, 0.068, 0.066, 1.0);
uniform float course_height = 0.42;
uniform float block_length = 0.95;
// Joint width as a share of the course height.
uniform float seam_width = 0.045;
uniform float roughness_base = 0.93;
uniform int space : hint_range(0, 1) = 0;
// How dark and green the courses near the ground are (0 = off) and up to what height (m).
uniform float damp = 0.35;
uniform float damp_top = 0.9;

varying vec3 v_world;

float dsw_hash(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float dsw_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(dsw_hash(i), dsw_hash(i + vec2(1.0, 0.0)), f.x),
		mix(dsw_hash(i + vec2(0.0, 1.0)), dsw_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Colour spaces, measured 2026-10-22 (the stage kit preview): Forward+ and Mobile hand
// source_color uniforms over linear and take ALBEDO as linear; the Compatibility renderer (and so
// the web demo) hands them over as written (sRGB) and takes ALBEDO as sRGB. A flat colour comes
// out the same either way, but whatever is multiplied in here (a mottle, a block's tone, a vertex
// colour) came out about twice as strong in Compatibility. So the colours are taken to linear
// light (dsw_uniform), worked there, and handed back the way the renderer reads them
// (dsw_albedo). Vertex colours are written as they look (sRGB) and converted in every renderer.
vec3 dsw_to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

vec3 dsw_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}

vec3 dsw_uniform(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return dsw_to_linear(c);
#else
	return c;
#endif
}

vec3 dsw_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return dsw_to_srgb(c);
#else
	return c;
#endif
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metres on the wall: x along it, y up.
	vec2 pm = v_world.xy;
	if (space == 1) {
		pm = UV;
	}
	vec2 p = vec2(pm.x / block_length, pm.y / course_height);
	float row = floor(p.y);
	float offs = fract(row * 0.5) > 0.25 ? 0.5 : 0.0;
	vec2 cell = vec2(p.x + offs + (dsw_hash(vec2(row, 3.0)) - 0.5) * 0.25, p.y);
	vec2 id = floor(cell);
	vec2 f = fract(cell) - 0.5;
	// Distance to the block's edge in metres.
	float dx = (0.5 - abs(f.x)) * block_length;
	float dy = (0.5 - abs(f.y)) * course_height;
	float edge_d = min(dx, dy);
	float jm = seam_width * course_height;
	float px = max(fwidth(pm.x), fwidth(pm.y));
	float jw = max(jm, px * 0.75);
	float on_block = smoothstep(jw * 0.5, jw * 1.2, edge_d);
	on_block = mix(0.9, on_block, 1.0 - smoothstep(jm * 1.2, jm * 5.0, px));
	float tone = dsw_hash(id);
	// Blocks vary a lot in value: an even wall is as dead as a flat colour at 640 px.
	vec3 stone = dsw_uniform(stone_color.rgb);
	vec3 block = mix(stone * 0.68, stone * 1.38, tone);
	// A rounded edge and a lighter upper face: the block stands out of the joint.
	block *= mix(0.84, 1.0, smoothstep(jw, jw * 4.0, edge_d)) * (0.94 + 0.12 * (f.y + 0.5));
	float distant = smoothstep(0.01, 0.05, px);
	float grain = mix(dsw_noise(pm * 22.0), 0.5, distant);
	block *= 0.92 + 0.16 * grain;
	// Weathering: slow vertical streaks.
	block *= 0.9 + 0.12 * dsw_noise(vec2(pm.x * 5.0, pm.y * 0.5));
	vec3 c = mix(dsw_uniform(mortar_color.rgb), block, on_block);
	float low = (1.0 - smoothstep(0.0, damp_top, pm.y)) * damp;
	c = mix(c, c * vec3(0.74, 0.84, 0.7), low);
	ALBEDO = dsw_albedo(c * dsw_to_linear(COLOR.rgb));
	ROUGHNESS = roughness_base - tone * 0.12;
	SPECULAR = 0.3;
}

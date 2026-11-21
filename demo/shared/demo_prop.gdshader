shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// One lit material for every code-built prop and figure of a demo stage (demo only): walls,
// rafters, barrels, crates, shelves, trunks, leaves, rocks, torches, pots and the painted
// figures. UV2.y is the face kind the builders in demo_props.gd write (0 top, 1 side,
// 2 underside), so a rock has a dusty top and a dark base; `planks` draws board seams from UV,
// so a crate is a crate and not a box. Kit 2: the vertex colour tints each part of a merged
// mesh (a figure's cloth, leather and steel in one surface), UV2.x = 1 marks a metal part, and
// `damp_height` darkens what stands in water or on wet ground.
// Self-contained (no #include of the addon), so it works in any pack and in its Lite demo.
// Generated from WS/shared/demo_kit/demo_prop.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).

uniform vec4 side_color : source_color = vec4(0.3, 0.22, 0.14, 1.0);
uniform vec4 top_color : source_color = vec4(0.36, 0.27, 0.18, 1.0);
uniform vec4 under_color : source_color = vec4(0.1, 0.08, 0.06, 1.0);
uniform float mottle = 0.12;
uniform float mottle_scale = 0.5;
// 0 = none, otherwise planks per unit of UV.
uniform float planks = 0.0;
uniform float roughness = 0.9;
// The whole material's metalness (the demo stage's mat(color, rough, metal)).
uniform float metallic = 0.0;
// Kit 4.1: a specular level of its own when >= 0 (the default follows `metallic`), and a pale
// fresnel rim (porcelain, a glazed figure): `rim_amount` 0 = none.
uniform float specular = -1.0;
uniform vec4 rim_color : source_color = vec4(0.6, 0.7, 0.85, 1.0);
uniform float rim_amount = 0.0;
// The parts marked metal (UV2.x = 1): iron hoops, a helmet, a sword.
uniform float metal_amount = 0.75;
uniform float metal_roughness = 0.38;
// World height under which the surface is wet (0 = off) and the colour it takes there.
uniform float damp_height = 0.0;
uniform vec4 damp_tint : source_color = vec4(0.52, 0.58, 0.46, 1.0);
// Kit 13: the studio sweep (LOOK_STUDIO) is this shader too, so the stage has one lit shader on
// the web (two lit shaders cost one more compile of every light version; godot-vfx-pack 2b-1b,
// pyro_rebuild 10/31). `sweep` 1 draws the v12 demo_studio.gdshader look: the floor curving into
// the back wall in a dark satin grey, a soft pool round `sweep_pool_centre`, the wall darkening
// upward, glossy only on the floor (and a little more where there is no SSR). Uniform branch,
// so a prop pays nothing for it.
uniform float sweep = 0.0;
uniform vec4 sweep_far : source_color = vec4(0.02, 0.02, 0.024, 1.0);
uniform vec3 sweep_pool_centre = vec3(0.0, 0.0, 0.0);
uniform float sweep_pool_radius = 3.2;
// Kit 14 (v13.1): 0 = no floor pool (the user, 11/01: the patch of light on the floor looked coarse
// and lopsided); a product can still set it.
uniform float sweep_pool_gain = 0.0;
uniform float sweep_wall_fade = 6.0;
uniform float sweep_floor_fade = 9.0;
uniform float sweep_gloss_no_ssr = 0.08;

varying vec3 v_world;
varying float v_kind;
varying float v_metal;

float dk_hash12(vec2 q) {
	vec3 q3 = fract(vec3(q.xyx) * 0.1031);
	q3 += dot(q3, q3.yzx + 33.33);
	return fract((q3.x + q3.y) * q3.z);
}

float dk_hash13(vec3 q) {
	q = fract(q * 0.1031);
	q += dot(q, q.zyx + 31.32);
	return fract((q.x + q.y) * q.z);
}

float dk_vnoise2(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	float a = dk_hash12(i);
	float b = dk_hash12(i + vec2(1.0, 0.0));
	float c = dk_hash12(i + vec2(0.0, 1.0));
	float d = dk_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float dk_vnoise3(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	float x00 = mix(dk_hash13(i), dk_hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float x10 = mix(dk_hash13(i + vec3(0.0, 1.0, 0.0)), dk_hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float x01 = mix(dk_hash13(i + vec3(0.0, 0.0, 1.0)), dk_hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float x11 = mix(dk_hash13(i + vec3(0.0, 1.0, 1.0)), dk_hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float dk_fbm3(vec3 q) {
	return 0.5 * dk_vnoise3(q) + 0.25 * dk_vnoise3(q * 2.03);
}

// Colour spaces, measured 2026-10-22 (the stage kit preview): Forward+ and Mobile hand
// source_color uniforms over linear and take ALBEDO as linear; the Compatibility renderer (and so
// the web demo) hands them over as written (sRGB) and takes ALBEDO as sRGB. A flat colour comes
// out the same either way, but whatever is multiplied in here (a mottle, a block's tone, a vertex
// colour) came out about twice as strong in Compatibility. So the colours are taken to linear
// light (dk_uniform), worked there, and handed back the way the renderer reads them
// (dk_albedo). Vertex colours are written as they look (sRGB) and converted in every renderer.
vec3 dk_to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

vec3 dk_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}

vec3 dk_uniform(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return dk_to_linear(c);
#else
	return c;
#endif
}

vec3 dk_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return dk_to_srgb(c);
#else
	return c;
#endif
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_kind = UV2.y;
	v_metal = clamp(UV2.x, 0.0, 1.0);
}

void fragment() {
	if (sweep > 0.5) {
		vec3 base = dk_uniform(side_color.rgb);
		vec3 far = dk_uniform(sweep_far.rgb);
		float r = length(v_world.xz - sweep_pool_centre.xz);
		float extra = 0.0;
		float rough = roughness;
#if CURRENT_RENDERER != RENDERER_FORWARD_PLUS
		extra = sweep_pool_gain > 0.0 ? 0.12 : 0.0;
		rough = max(roughness - sweep_gloss_no_ssr, 0.05);
#endif
		// A smooth (Gaussian) pool: no visible edge anywhere.
		float pool = exp(-(r * r) / (sweep_pool_radius * sweep_pool_radius)) * (sweep_pool_gain + extra);
		float sink = max(smoothstep(0.0, sweep_wall_fade, v_world.y), smoothstep(sweep_pool_radius, sweep_floor_fade, r) * 0.7);
		ALBEDO = dk_albedo(mix(base, far, sink) * (1.0 + pool));
		// Only the floor is glossy: the cove is a concave mirror, and its upside-down reflections
		// of a rising plume showed as streaks hanging from the top of the frame.
		ROUGHNESS = mix(rough, 1.0, smoothstep(0.02, 0.5, v_world.y));
		METALLIC = 0.0;
		SPECULAR = max(specular, 0.0);
	} else {
		vec3 c = dk_uniform(side_color.rgb);
		if (v_kind < 0.5) {
			c = dk_uniform(top_color.rgb);
		} else if (v_kind > 1.5) {
			c = dk_uniform(under_color.rgb);
		}
		float n = dk_fbm3(v_world / max(mottle_scale, 0.01));
		float k = 1.0 - mottle * 0.5 + mottle * n;
		if (planks > 0.5) {
			float p = UV.y * planks;
			// Kit 2: a dark groove at each board edge (kit 1 darkened the middle of every board and
			// left a bright line at the edge), each board its own shade, and the groove fades out
			// once it is thinner than a pixel so far crates do not shimmer.
			float px = fwidth(p);
			float edge = abs(fract(p) - 0.5) * 2.0;
			float seam = smoothstep(0.86 - px, 0.96, edge) * (1.0 - smoothstep(0.1, 0.35, px));
			float grain = dk_vnoise2(vec2(UV.x * 9.0, floor(p) * 5.3)) * 0.1;
			float board = 0.93 + 0.14 * dk_hash12(vec2(floor(p), 7.0));
			k *= (1.0 - 0.55 * seam) * (0.95 + grain) * board;
		}
		c *= k * dk_to_linear(COLOR.rgb);
		if (damp_height > 0.0) {
			float wet = 1.0 - smoothstep(damp_height - 0.12, damp_height + 0.02, v_world.y);
			c = mix(c, c * dk_uniform(damp_tint.rgb), wet);
		}
		ALBEDO = dk_albedo(c);
		ROUGHNESS = mix(roughness, metal_roughness, v_metal);
		METALLIC = mix(metallic, metal_amount, v_metal);
		SPECULAR = mix(0.12 + 0.38 * metallic, 0.5, v_metal);
		if (specular >= 0.0) {
			SPECULAR = specular;
		}
		if (rim_amount > 0.0) {
			float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
			EMISSION = dk_uniform(rim_color.rgb) * (fr * rim_amount);
		}
	}
}

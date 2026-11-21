shader_type spatial;
render_mode unshaded, cull_back;

// The stage's one unshaded shader (demo only). Two jobs:
// 1. Web first visit (the demo stage's lite_start): every stage mesh draws with it while the effects
//    compile (godot-vfx-pack 2b-1b: one shared unshaded shader, no shadow, no
//    StandardMaterial3D), lit by a fixed key in the shader so the courtyard still reads as
//    solid stone; lite_finish() puts the real materials back.
// 2. Things that glow on their own and need no light: a caster's gem, embers, a lit card.
//    `glow` = 1 draws the colour flat.
// The vertex colour multiplies in, so a merged figure keeps its parts.
// Generated from WS/shared/demo_kit/demo_quick.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).

uniform vec4 col : source_color = vec4(0.5, 0.5, 0.5, 1.0);
// The direction the key light comes from, in world space (the look's sun).
uniform vec3 sun_dir = vec3(0.45, 0.64, 0.62);
uniform float key = 0.9;
uniform float ambient = 0.45;
uniform float gain = 1.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
// Kit 13: the studio sweep's stand-in (`sweep` 1): the same pool and fall-off as the real sweep
// (demo_prop.gdshader sweep mode, same defaults), lit by `sweep_light` instead of the studio's
// lights, so the first scene can show before the real stage is back.
uniform float sweep = 0.0;
uniform vec4 sweep_far : source_color = vec4(0.02, 0.02, 0.024, 1.0);
uniform vec3 sweep_pool_centre = vec3(0.0, 0.0, 0.0);
uniform float sweep_pool_radius = 3.2;
uniform float sweep_pool_gain = 0.0;
uniform float sweep_wall_fade = 6.0;
uniform float sweep_floor_fade = 9.0;
uniform float sweep_light = 2.2;

varying vec3 q_world;

// Colour spaces, measured 2026-10-22 (the stage kit preview): Forward+ and Mobile hand
// source_color uniforms over linear and take ALBEDO as linear; the Compatibility renderer (and so
// the web demo) hands them over as written (sRGB) and takes ALBEDO as sRGB. A flat colour comes
// out the same either way, but whatever is multiplied in here (a mottle, a block's tone, a vertex
// colour) came out about twice as strong in Compatibility. So the colours are taken to linear
// light (q_uniform), worked there, and handed back the way the renderer reads them
// (q_albedo). Vertex colours are written as they look (sRGB) and converted in every renderer.
vec3 q_to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

vec3 q_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}

vec3 q_uniform(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return q_to_linear(c);
#else
	return c;
#endif
}

vec3 q_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return q_to_srgb(c);
#else
	return c;
#endif
}

void vertex() {
	q_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (sweep > 0.5) {
		vec3 sb = q_uniform(col.rgb);
		vec3 sf = q_uniform(sweep_far.rgb);
		float r = length(q_world.xz - sweep_pool_centre.xz);
		float pool = exp(-(r * r) / (sweep_pool_radius * sweep_pool_radius)) * (sweep_pool_gain > 0.0 ? sweep_pool_gain + 0.12 : 0.0);
		float sink = max(smoothstep(0.0, sweep_wall_fade, q_world.y), smoothstep(sweep_pool_radius, sweep_floor_fade, r) * 0.7);
		ALBEDO = q_albedo(mix(sb, sf, sink) * (1.0 + pool) * sweep_light);
	} else {
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float lit = max(dot(nw, normalize(sun_dir)), 0.0);
		vec3 base = q_uniform(col.rgb);
		vec3 shaded = base * (ambient + lit * key) * gain;
		ALBEDO = q_albedo(mix(shaded, base, glow) * q_to_linear(COLOR.rgb));
	}
}

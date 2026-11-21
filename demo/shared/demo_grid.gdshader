shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// A dark, low-contrast reference floor for promotional captures (LOOK_GRID): a faint checker of
// 1 m tiles with thin lighter seams, sinking into the background with distance so the frame
// darkens toward its edges (no post-process vignette, so the three renderers agree). The look
// says "effect pack" at a glance in a feed; the castle stages stay for the demos themselves.
// Values after the market check of 2026-10-25: base about 0.05, light tile and seam 0.10-0.12,
// never a high-contrast engineering grid. Seams fade to their average once thinner than a
// pixel (no shimmer when the camera moves). Lit a little (roughness 0.6) so an effect's light
// lands on the floor.
// Colour spaces as demo_flagstone.gdshader: worked in linear light, handed back as the renderer
// reads it.
// Generated from WS/shared/demo_kit/demo_grid.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).

uniform vec4 base_color : source_color = vec4(0.05, 0.052, 0.06, 1.0);
uniform vec4 tile_color : source_color = vec4(0.066, 0.069, 0.08, 1.0);
uniform vec4 seam_color : source_color = vec4(0.105, 0.11, 0.128, 1.0);
// What the floor sinks into far from the camera (match the sky's ground colour).
uniform vec4 fade_color : source_color = vec4(0.012, 0.014, 0.022, 1.0);
// Tile size in metres and the seam's half width in metres.
uniform float cell = 1.0;
uniform float seam = 0.012;
// The checker's strength (0 = plain tiles with seams only).
uniform float checker : hint_range(0.0, 1.0) = 0.55;
// Distance from the camera (metres) where the fade starts and where it is complete.
uniform float fade_start = 5.0;
uniform float fade_end = 15.0;
uniform float roughness_base = 0.6;
uniform float specular_base = 0.45;

varying vec3 v_w;

vec3 dg_to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

vec3 dg_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}

vec3 dg_uniform(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return dg_to_linear(c);
#else
	return c;
#endif
}

vec3 dg_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return dg_to_srgb(c);
#else
	return c;
#endif
}

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_w.xz / cell;
	vec2 cf = floor(p);
	float ck = mod(cf.x + cf.y, 2.0);
	// Distance to the nearest seam, in metres, and how wide a pixel is there.
	vec2 q = (0.5 - abs(fract(p) - 0.5)) * cell;
	float d = min(q.x, q.y);
	float fw = max(fwidth(d), 1e-4);
	float line = 1.0 - smoothstep(seam, seam + fw * 1.5, d);
	// Thinner than a pixel: fade the seam toward its share of the area (no shimmer).
	line *= clamp(seam * 2.0 / fw, 0.0, 1.0);
	vec3 base = dg_uniform(base_color.rgb);
	vec3 tile = dg_uniform(tile_color.rgb);
	vec3 sm = dg_uniform(seam_color.rgb);
	vec3 c = mix(base, tile, ck * checker);
	c = mix(c, sm, line);
	float dist = length(v_w - CAMERA_POSITION_WORLD);
	float fade = smoothstep(fade_start, fade_end, dist);
	c = mix(c, dg_uniform(fade_color.rgb), fade);
	ALBEDO = dg_albedo(c);
	ROUGHNESS = mix(roughness_base, 1.0, fade);
	SPECULAR = specular_base * (1.0 - fade);
}

shader_type spatial;
// A torch or brazier flame, no texture and no fire pack needed (demo only, not part of any
// addon). One upright quad that turns to face the camera around Y: a flickering tongue of fire,
// white-yellow at the root, orange, then dark red at the ragged tip, added over the scene.
// `level` shrinks and dims it while it goes out (DemoProps.TorchFlame: water puts it
// out, relight() lights it again). From UNDALUX's demo_torch_flame.gdshader, unchanged.
// Generated from WS/shared/demo_kit/demo_torch_flame.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float level : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.6 + vnoise(p * 2.13 + 7.1) * 0.3 + vnoise(p * 4.37 + 3.3) * 0.1;
}

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(side, 0.0),
		vec4(up, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, up)), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// y = 0 at the root, 1 at the top of the quad; x centred.
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * 1.0 + seed;
	float h = mix(0.35, 1.0, level);
	float yy = y / h;
	// The flame sways more towards the tip and rises through the noise.
	float sway = (vnoise(vec2(t * 1.7, 2.0)) - 0.5) * 0.5 * yy * yy;
	float n = fbm(vec2(x * 2.2, yy * 3.0 - t * 3.4));
	float xs = x - sway + (n - 0.5) * 0.85 * yy;
	// Teardrop: widest a little above the root, pinched to a point at the top.
	float width = 0.7 * pow(max(1.0 - yy, 0.0), 0.65) * smoothstep(-0.08, 0.2, yy);
	float d = abs(xs) / max(width, 0.001);
	float body = 1.0 - smoothstep(0.35, 1.0, d);
	// Ragged top: the noise eats the upper part away.
	float top = smoothstep(0.0, 0.3, (1.0 - yy) * 0.9 + (n - 0.55) * 1.2);
	float a = clamp(body * top, 0.0, 1.0);
	float core = (1.0 - smoothstep(0.0, 0.4, d)) * (1.0 - smoothstep(0.05, 0.4, yy));
	float flick = 0.88 + 0.12 * vnoise(vec2(t * 9.0, 5.0));
	vec3 deep = vec3(0.55, 0.06, 0.01);
	vec3 orange = vec3(1.0, 0.36, 0.04);
	vec3 yellow = vec3(1.0, 0.72, 0.28);
	vec3 col = mix(deep, orange, smoothstep(0.0, 0.5, a));
	col = mix(col, yellow, smoothstep(0.6, 1.0, a) * (1.0 - yy));
	col = mix(col, vec3(1.0, 0.93, 0.75), core * 0.6);
	ALBEDO = col * a * flick * 1.15 * level;
	ALPHA = 1.0;
}

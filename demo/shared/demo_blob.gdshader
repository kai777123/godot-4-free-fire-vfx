shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Kit 15: the stand-in for a shadow. The demo kit casts no real shadows (they cost 9-11 s of
// shader compiles on the web, _dev/webprobe/floor/RESULT.md), so each figure and prop carries a
// soft dark ellipse flat on the floor under it (DemoProps.blob_shadow). One unshaded shader shared
// by all of them: no lit versions, no per-light compiles. UV of the plane is 0..1; the dark is
// `strength` (0.75) at the centre and falls to 0 at the rim (squared smoothstep).
// Generated from WS/shared/demo_kit/demo_blob.gdshader by tools/vfxpack/demo_kit_sync.py
// (DEMO_KIT_VERSION 15).

uniform float strength = 0.75;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = clamp(length(p), 0.0, 1.0);
	float k = 1.0 - smoothstep(0.0, 1.0, r);
	ALBEDO = vec3(0.0);
	ALPHA = strength * k * k;
}

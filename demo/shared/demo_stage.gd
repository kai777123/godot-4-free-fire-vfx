class_name PyroluxDemoStage
extends Node3D
## Demo only: a stage for an effect, built in code (no imported mesh, no texture) - a castle
## courtyard of coursed stone: a flagstone floor, a back wall with an arcade of five arches and a
## dark gallery behind them, a string course and crenellations, four round corner towers with
## slate roofs, side walls and a front wall with a closed gate behind the camera (so a view from
## the side or the back never runs out of set), banners, torches on the piers and props against
## the walls (crates, barrels, a broken column, braziers, rubble, a tree, an urn on a pedestal).
## The middle, about 3 m round the origin, stays clear for the effect and the product's own props.
## The three renderers show it alike: the kit's shaders work in linear light everywhere and the
## sun is corrected for Compatibility (shadow_light_gain); use set_shadows() and set_look() rather
## than the sun's own properties. Glow is off unless `glow` is set.
##
## Four looks of light and sky (set_look):
##   LOOK_COURTYARD_DAY  noon on sandstone: the sun 1.2 at 40 degrees from the camera's
##                       left-front, ambient 0.45 (GLYPHLUX's hero look-gate, PASS.md)
##   LOOK_DARK_ARENA     the same daylight on dark stone (UNDALUX's dark stage, t5b: bright water
##                       against something darker than the water)
##   LOOK_DUNGEON_NIGHT  night: a black sky, a faint moon from behind the walls, the torches and
##                       braziers burning
##   LOOK_GRID           for promotional captures (2026-10-25): no walls, no props, a dark
##                       low-contrast 1 m checker floor sinking into a near-black sky with
##                       distance (demo_grid.gdshader), a weak white light from above with a
##                       shadow. Says "effect pack" at a glance in a feed; not for the demos.
##   LOOK_STUDIO         kit v12 (2026-10-31, look_1031 A): a photo studio. No walls, no props: one
##                       seamless dark satin sweep (the floor curving up into the back wall,
##                       demo_studio.gdshader), a soft key light from the front left, a cool rim
##                       from behind right, a faint halo on the sweep behind the subject. AgX
##                       tonemapping (no clipped whites), SSR on the floor and SSAO in Forward+,
##                       MSAA 8x and debanding on the desktop (--ss2: 2x supersampling for
##                       captures). Simple and smooth, so the effect is
##                       the only thing with detail in the frame.
##                       Kit 13: the sweep draws with the shared prop shader (`sweep` 1), so the
##                       studio adds no lit shader of its own; a stage that starts in the studio
##                       builds no courtyard, dressing or fires (they are built the first time
##                       another look is set); the web first visit hides the key, rim and halo and
##                       turns SSR and SSAO off, and the warm-up compiles the real materials in
##                       front of a small rig of the same light kinds (warm_rig) before
##                       lite_shadow_on() / lite_finish() / lite_post() bring them back.
##
## The camera: eye height 1.5 m and fov 50 by default (aim_camera, eye_camera, aim_hero_camera).
##
## Web first visit (set lite_start before add_child): every mesh draws with one shared unshaded
## shader (demo_quick.gdshader), the sun casts no shadow, the flames and their lights wait. The
## warm-up calls lite_shadow_on(), draws warm_materials() one per frame and lite_finish() puts
## the real materials back while the light comes up and the fires catch (godot-vfx-pack 2b-1b).
## These are the calls GLYPHLUX's and UNDALUX's demo runners make: lite_start, is_lite(),
## warm_materials(), lite_shadow_on(), lite_finish(), adopt(), add_mesh(), mat(), set_look(),
## aim_camera(), aim_hero_camera(), ensure_camera(), knight(), caster(), column(), brazier().
##
##   var stage := PyroluxDemoStage.new()
##   stage.lite_start = OS.has_feature("web")
##   add_child(stage)
##   stage.set_look(PyroluxDemoStage.LOOK_DUNGEON_NIGHT)
##   stage.eye_camera(Vector3(0.0, 1.0, 0.0), 4.5, 12.0)
##   var target: MeshInstance3D = stage.knight(Vector3.ZERO, root)       # root: the slot's node
##   stage.adopt(PyroluxDemoProps.barrel(root, Vector3(1.6, 0.0, -0.8)))
##
## From GLYPHLUX's demo_stage.gd (the courtyard, the knight, the looks, the light mode) and
## UNDALUX's (the dark stage, the renderer exposure gain, the ramp, the props).
## Generated from WS/shared/demo_kit/demo_stage.gd by tools/vfxpack/demo_kit_sync.py.

const DEMO_KIT_VERSION: int = 15

const LOOK_COURTYARD_DAY: int = 0
const LOOK_DARK_ARENA: int = 1
const LOOK_DUNGEON_NIGHT: int = 2
const LOOK_GRID: int = 3
const LOOK_STUDIO: int = 4

const CAM_FOV: float = 50.0
const CAM_EYE_Y: float = 1.5
## aim_hero_camera(): where the subject's vertical centre lands (share of the frame height), the
## camera's turn round it and how much of the frame height the subject fills (GLYPHLUX PASS.md).
const SUBJECT_CENTRE_V: float = 0.48
const CAM_YAW_DEG: float = 14.0
const FRAME_FILL: float = 0.56
const STATUE_H: float = 2.0

## The courtyard: the inner face of the back wall, its thickness and height, the inner faces of
## the side walls and of the front wall behind the camera (closed, so a view from the side or
## the back never runs out of set), the arcade's bays, the gate in the front wall.
const BACK_Z: float = -4.4
const WALL_T: float = 0.7
const WALL_H: float = 4.2
const SIDE_X: float = 7.4
const FRONT_Z: float = 12.0
const BAY: float = 2.8
const ARCH_W: float = 1.8
const SPRING: float = 2.05
const GALLERY: float = 1.7
const GATE_R: float = 1.5
const GATE_SPRING: float = 2.2
const GATE_HW: float = 2.5

const FLAG_SHADER: Shader = preload("res://demo/shared/demo_flagstone.gdshader")
const GRID_SHADER: Shader = preload("res://demo/shared/demo_grid.gdshader")
const QUICK_SHADER: Shader = preload("res://demo/shared/demo_quick.gdshader")
## The studio sweep: x half width, the floor from STUDIO_FRONT to the cove at STUDIO_BACK, the
## cove's radius and the wall's height (wide enough that a 50 degree view from 7 m stays on it).
const STUDIO_HW: float = 18.0
const STUDIO_FRONT: float = 14.0
const STUDIO_BACK: float = -5.5
const STUDIO_COVE: float = 3.4
const STUDIO_H: float = 10.0
## While the real stage comes back: the share of the light at the first frame, how long the light
## takes to come up, and how bright the unshaded stand-in is against the real light.
const RAMP_FROM: float = 0.55
const RAMP_SECONDS: float = 0.9
const QUICK_GAIN: float = 0.72

## Set before add_child(): start in the web first-visit mode (see the class comment).
var lite_start: bool = false
## Set before add_child(): the first look, whether to build the courtyard walls, and the props
## against them.
var look: int = LOOK_COURTYARD_DAY
var courtyard: bool = true
var dressing: bool = true
## The glow (WorldEnvironment), off unless set: in Forward+ the stage's looks gain next to
## nothing from it (the night 33.1 against 33.0 without), and the Compatibility renderer draws the
## whole frame about 10 % darker with it on (measured 2026-10-22), so the renderers drift apart.
var glow: bool = false

var environment: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
## The product's props (clear_props() empties it); the stage's own dressing is elsewhere.
var props: Node3D
var camera: Camera3D
var ground: MeshInstance3D

var _ground_mat: ShaderMaterial
var _grid_mat: ShaderMaterial
var _yard_root: Node3D
var _wall_mat: ShaderMaterial
var _trim_mat: ShaderMaterial
var _slate_mat: ShaderMaterial
var _cloth_mat: ShaderMaterial
var _dressing_root: Node3D
var _studio_root: Node3D
var _studio_mat: ShaderMaterial
var _yard_built: bool = false
## The studio's key light (LOOK_STUDIO), null before the look is first set.
var studio_key: SpotLight3D
var _mats: Dictionary = {}
## The stage's own fires (lit at night only).
var _fires: Array[PyroluxDemoProps.TorchFlame] = []
## false: the torches and braziers give a steady light (see TorchFlame.flicker). Applied to the
## fires already built and to every fire adopted later.
var flame_flicker: bool = true:
	set(value):
		flame_flicker = value
		for f: PyroluxDemoProps.TorchFlame in _fires:
			if is_instance_valid(f):
				f.flicker = value
var _lite: bool = false
var _real: Array[MeshInstance3D] = []
var _real_mats: Array[Material] = []
var _quick: Dictionary = {}
var _quick_list: Array[ShaderMaterial] = []
## Indices into _real whose material an effect held when lite_finish() ran (v8): each gets its
## real material when the effect gives the stand-in back (see _give_back).
var _late: Array[int] = []
## Flames and lights hidden while the stage is in its first-visit mode.
var _waiting: Array[Node3D] = []
## The dressing braziers' coals (glowing while they burn, black otherwise).
var _coals: Array[MeshInstance3D] = []
## The look's sun and ambient energies before the renderer's correction and the ramp.
var _sun_base: float = 1.2
var _amb_base: float = 0.45
var _ramp_t: float = 1.0
var _ramp_k: float = 1.0


func _ready() -> void:
	_lite = lite_start
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	_dressing_root = Node3D.new()
	_dressing_root.name = "Dressing"
	add_child(_dressing_root)
	_build_materials()
	_build_environment()
	_build_ground()
	# Kit 13: a stage that opens in the studio leaves the courtyard and its dressing unbuilt (no
	# meshes to make, no materials or fires to warm on the web); _ensure_yard() builds them the
	# first time a look that shows them is set.
	if look != LOOK_STUDIO:
		_ensure_yard()
	if _lite:
		sun.shadow_enabled = false
	set_look(look)


func _ensure_yard() -> void:
	if _yard_built:
		return
	_yard_built = true
	if courtyard:
		_build_courtyard()
	if dressing:
		_build_dressing()


# ------------------------------------------------------------------ renderer differences

## The sun's energy is multiplied by this per renderer, so the three renderers show the stage at
## the same brightness. Measured on the kit's own stage (2026-10-22, 4.4.1 and 4.7.2, the wall,
## floor, knight and a shaded arch of the day look): Mobile matches Forward+ to one level of 255,
## so 1.0 everywhere; Compatibility's one difference is the shadow (shadow_light_gain). UNDALUX's
## Mobile gain of 2.2 was for its wet shell's darkening ratio, not for the stage.
static func renderer_exposure_gain() -> float:
	match RenderingServer.get_current_rendering_method():
		"mobile":
			return 1.0
		"gl_compatibility":
			return 1.0
		_:
			return 1.0


## The sun's energy is multiplied by this while it casts shadows. The Compatibility renderer
## lights the scene far more strongly once a shadowed sun and an ambient light are both on (4.4.1
## and 4.7.2 alike: a sunlit wall at 151 against Forward+'s 116; a shadowed sun alone, or the
## ambient alone, matches). How much depends on the balance of the two, so each look has its own
## factor, found by measuring the eight preview views against Forward+ (2026-10-22): day 0.45
## (mean -0.3 %, worst -2.2 %), dark arena 0.7 (-0.6 %, -3.9 %), night 1.0 (-2.1 %, -7.0 %).
## Forward+ and Mobile: 1.0.
static func shadow_light_gain(look_id: int = LOOK_COURTYARD_DAY) -> float:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return 1.0
	match look_id:
		LOOK_DARK_ARENA:
			return 0.7
		LOOK_DUNGEON_NIGHT:
			return 1.0
		LOOK_GRID:
			return 0.7
		LOOK_STUDIO:
			return 1.0
		_:
			return 0.45


## The tonemap exposure per renderer (Compatibility's lever in UNDALUX); 1.0 for the stage.
static func renderer_tonemap_gain() -> float:
	match RenderingServer.get_current_rendering_method():
		"gl_compatibility":
			return 1.0
		_:
			return 1.0


## The sun's shadow on or off, keeping the sunlit side as bright in every renderer (use this, not
## sun.shadow_enabled, so shadow_light_gain() follows).
func set_shadows(_on: bool) -> void:
	# Kit 15: the demo casts no shadows (blob_shadow() stands in); kept so a product that calls it still runs.
	sun.shadow_enabled = false
	_apply_light()


## The sun and the ambient as the look asks, times the renderer's correction and the switch-on
## ramp. Every change of them goes through here.
func _apply_light() -> void:
	var g: float = renderer_exposure_gain()
	if sun.shadow_enabled:
		g *= shadow_light_gain(look)
	sun.light_energy = _sun_base * g * _ramp_k
	environment.ambient_light_energy = _amb_base * _ramp_k


# ------------------------------------------------------------------ building

func _build_materials() -> void:
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = FLAG_SHADER
	_grid_mat = ShaderMaterial.new()
	_grid_mat.shader = GRID_SHADER
	_wall_mat = PyroluxDemoProps.wall_material(Color(0.43, 0.405, 0.37), Color(0.2, 0.19, 0.17), 0.34, 0.66)
	_trim_mat = PyroluxDemoProps.material(Color(0.5, 0.47, 0.42), 1.08, 0.14, 0.0)
	_slate_mat = PyroluxDemoProps.material(Color(0.17, 0.18, 0.21), 1.12, 0.1, 6.0)
	_cloth_mat = PyroluxDemoProps.flat_material(Color(1.0, 1.0, 1.0), 0.95, 0.0, 0.05)


func _build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# A flat ambient colour and no sky reflection: Compatibility does not filter the procedural
	# sky the way the other two renderers do, so a sky-sourced ambient came out far brighter
	# there (UNDALUX PASS.md C6). One colour is the same light everywhere.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_intensity = 0.55
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 0.95
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.shadow_blur = 1.0
	sun.directional_shadow_max_distance = 32.0
	add_child(sun)


func _build_ground() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	ground = add_mesh(plane, Vector3.ZERO, _ground_mat, Vector3.ZERO, self)
	ground.name = "Ground"
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_courtyard() -> void:
	var yard: Node3D = Node3D.new()
	yard.name = "Courtyard"
	add_child(yard)
	_yard_root = yard
	var wb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	var tb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	var gb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	var zf: float = BACK_Z
	var zb: float = BACK_Z - WALL_T
	var r: float = ARCH_W * 0.5
	var bays: Array[float] = [-2.0 * BAY, -BAY, 0.0, BAY, 2.0 * BAY]
	# The arcade: piers up to the spring line, the wall over each arch, the ends.
	var edges: Array[float] = [-SIDE_X]
	for xc: float in bays:
		edges.append(xc - r)
		edges.append(xc + r)
	edges.append(SIDE_X)
	for k: int in range(0, edges.size(), 2):
		wb.box_m(Vector3(edges[k], 0.0, zb), Vector3(edges[k + 1], SPRING, zf))
	for xc: float in bays:
		_spandrel(wb, xc, r, zf, zb, BAY * 0.5, SPRING)
	wb.box_m(Vector3(-SIDE_X, SPRING, zb), Vector3(bays[0] - BAY * 0.5, WALL_H, zf))
	wb.box_m(Vector3(bays[4] + BAY * 0.5, SPRING, zb), Vector3(SIDE_X, WALL_H, zf))
	# Side walls, and the front wall with the gate behind the camera.
	var zf2: float = FRONT_Z
	var zb2: float = FRONT_Z + WALL_T
	for sx: float in [-1.0, 1.0]:
		var x0: float = SIDE_X if sx > 0.0 else -SIDE_X - WALL_T
		wb.box_m(Vector3(x0, 0.0, zb), Vector3(x0 + WALL_T, WALL_H, zb2))
		var xi: float = sx * GATE_R
		var xo: float = sx * SIDE_X
		wb.box_m(Vector3(minf(xi, xo), 0.0, zf2), Vector3(maxf(xi, xo), GATE_SPRING, zb2))
		var xh: float = sx * GATE_HW
		wb.box_m(Vector3(minf(xh, xo), GATE_SPRING, zf2), Vector3(maxf(xh, xo), WALL_H, zb2))
	_spandrel(wb, 0.0, GATE_R, zf2, zb2, GATE_HW, GATE_SPRING)
	_voussoirs(tb, 0.0, GATE_R, zf2, GATE_SPRING, -1.0)
	# Dressed stone: voussoirs round each arch with a keystone, imposts, pier bases.
	for xc: float in bays:
		_voussoirs(tb, xc, r, zf, SPRING, 1.0)
		for side: float in [-1.0, 1.0]:
			var xe: float = xc + side * r
			tb.tint = Color(0.95, 0.95, 0.95)
			tb.cbox(Vector3(minf(xe, xe - side * 0.2) - 0.02, SPRING - 0.17, zf - 0.04),
				Vector3(maxf(xe, xe - side * 0.2) + 0.02, SPRING, zf + 0.07), 0.015)
	for k: int in range(0, edges.size(), 2):
		tb.tint = Color(0.9, 0.9, 0.9)
		tb.cbox(Vector3(edges[k] - 0.05, 0.0, zf - 0.05), Vector3(edges[k + 1] + 0.05, 0.26, zf + 0.06), 0.02)
	# String course along the top of the four walls, merlons on their outer edge.
	_course_x(tb, -SIDE_X - WALL_T, SIDE_X + WALL_T, WALL_H - 0.2, zf, 0.1, 1.0)
	_course_x(tb, -SIDE_X - WALL_T, SIDE_X + WALL_T, WALL_H - 0.2, zf2, 0.1, -1.0)
	for sx: float in [-1.0, 1.0]:
		_course_z(tb, sx * SIDE_X, -sx, zf + 0.1, zf2 - 0.1, WALL_H - 0.2, 0.1)
	_merlons_x(tb, -SIDE_X - WALL_T, SIDE_X + WALL_T, zb, zb + 0.45)
	_merlons_x(tb, -SIDE_X - WALL_T, SIDE_X + WALL_T, zb2 - 0.45, zb2)
	for sx: float in [-1.0, 1.0]:
		var xo2: float = SIDE_X + WALL_T if sx > 0.0 else -SIDE_X - WALL_T
		_merlons_z(tb, xo2 - sx * 0.45, xo2, zb, zb2)
	# The gallery behind the arches: dark (no light reaches its back wall and ceiling), its floor
	# a darker paving over the yard's.
	# (The vertex colour stands in for the light a covered gallery never gets: the flat ambient
	# reaches into it as fully as into the yard.)
	var zg: float = zb - GALLERY
	gb.tint = Color(0.34, 0.34, 0.34)
	gb.box_m(Vector3(-SIDE_X, 0.0, zg - 0.4), Vector3(SIDE_X, WALL_H, zg))
	gb.tint = Color(0.26, 0.26, 0.26)
	gb.box_m(Vector3(-SIDE_X, SPRING + r + 0.25, zg), Vector3(SIDE_X, SPRING + r + 0.45, zb))
	gb.tint = Color(0.46, 0.46, 0.46)
	gb.box_m(Vector3(-SIDE_X, 0.0, zg), Vector3(SIDE_X, 0.014, zb))
	for sx: float in [-1.0, 1.0]:
		gb.tint = Color(0.34, 0.34, 0.34)
		var xg: float = SIDE_X if sx > 0.0 else -SIDE_X - 0.4
		gb.box_m(Vector3(xg, 0.0, zg - 0.4), Vector3(xg + 0.4, WALL_H, zb))
	var walls: MeshInstance3D = add_mesh(wb.mesh(), Vector3.ZERO, _wall_mat, Vector3.ZERO, yard)
	walls.name = "Walls"
	add_mesh(tb.mesh(), Vector3.ZERO, _trim_mat, Vector3.ZERO, yard).name = "Trim"
	add_mesh(gb.mesh(), Vector3.ZERO, _wall_mat, Vector3.ZERO, yard).name = "Gallery"
	for sx: float in [-1.0, 1.0]:
		_tower(yard, Vector3(sx * (SIDE_X + WALL_T * 0.5), 0.0, zb + WALL_T * 0.5))
		_tower(yard, Vector3(sx * (SIDE_X + WALL_T * 0.5), 0.0, zb2 - WALL_T * 0.5))
	_gate(yard, zf2 + 0.3)


## The wall over one arch: [xc - hw, xc + hw] x [spring, WALL_H] less the half disc of radius r,
## its face at zf (and at zb behind), and the arch's soffit between them. Cut into wedges along
## rays from the arch's centre so every piece is a flat convex quad.
func _spandrel(b: PyroluxDemoProps.Builder, xc: float, r: float, zf: float, zb: float, hw: float,
		spring: float) -> void:
	var top: float = WALL_H - spring
	var into: float = signf(zb - zf) * 0.1
	var corner: float = atan2(top, hw)
	var angles: Array[float] = []
	var n: int = 16
	for k: int in n + 1:
		angles.append(PI * float(k) / float(n))
	angles.append(corner)
	angles.append(PI - corner)
	angles.sort()
	var c: Vector2 = Vector2(xc, spring)
	var inner: Array[Vector2] = []
	var outer: Array[Vector2] = []
	for a: float in angles:
		var d: Vector2 = Vector2(cos(a), sin(a))
		inner.append(c + d * r)
		var tx: float = hw / maxf(absf(d.x), 0.00001)
		var ty: float = top / maxf(d.y, 0.00001)
		outer.append(c + d * minf(tx, ty))
	var arc: float = 0.0
	for i: int in angles.size() - 1:
		var a0: Vector2 = inner[i]
		var a1: Vector2 = inner[i + 1]
		var o0: Vector2 = outer[i]
		var o1: Vector2 = outer[i + 1]
		if (a1 - a0).length() < 0.0001 and (o1 - o0).length() < 0.0001:
			continue
		for face: int in 2:
			var z: float = zf if face == 0 else zb
			var dz: float = into if face == 0 else -into
			b.quad_o(Vector3(a0.x, a0.y, z), Vector3(a1.x, a1.y, z), Vector3(o1.x, o1.y, z), Vector3(o0.x, o0.y, z),
				Vector3((a0.x + o1.x) * 0.5, (a0.y + o1.y) * 0.5, z + dz),
				a0, a1, o1, o0)
		var l: float = (a1 - a0).length()
		var mid: Vector2 = (a0 + a1) * 0.5
		var solid: Vector2 = c + (mid - c).normalized() * (r + 0.1)
		b.quad_o(Vector3(a0.x, a0.y, zf), Vector3(a1.x, a1.y, zf), Vector3(a1.x, a1.y, zb), Vector3(a0.x, a0.y, zb),
			Vector3(solid.x, solid.y, (zf + zb) * 0.5),
			Vector2(arc, zf), Vector2(arc + l, zf), Vector2(arc + l, zb), Vector2(arc, zb))
		arc += l


## Wedge stones round an arch of radius r centred at (xc, spring), standing proud of the wall
## face at zf toward `facing` (+1 = +Z), the keystone bigger, thin joints between them.
func _voussoirs(b: PyroluxDemoProps.Builder, xc: float, r: float, zf: float, spring: float,
		facing: float) -> void:
	var n: int = 11 if r < 1.2 else 15
	var c: Vector3 = Vector3(xc, spring, 0.0)
	var r0: float = r - 0.015
	for k: int in n:
		var a0: float = PI * float(k) / float(n) + 0.006
		var a1: float = PI * float(k + 1) / float(n) - 0.006
		var key: bool = k == floori(float(n) * 0.5)
		var r1: float = r + (0.44 if key else 0.34)
		var zo: float = zf + facing * (0.075 if key else 0.055)
		var zi: float = zf - facing * 0.03
		b.tint = Color(1.0, 1.0, 1.0) if k % 2 == 0 else Color(0.92, 0.92, 0.92)
		var d0: Vector3 = Vector3(cos(a0), sin(a0), 0.0)
		var d1: Vector3 = Vector3(cos(a1), sin(a1), 0.0)
		var p: Array[Vector3] = [c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1]
		var inside: Vector3 = c + (d0 + d1).normalized() * (r0 + r1) * 0.5 + Vector3(0.0, 0.0, (zo + zi) * 0.5)
		var f: Array[Vector3] = []
		var bk: Array[Vector3] = []
		for q: Vector3 in p:
			f.append(Vector3(q.x, q.y, zo))
			bk.append(Vector3(q.x, q.y, zi))
		b.quad_o(f[0], f[1], f[2], f[3], inside)
		for e: int in 4:
			var e1: int = (e + 1) % 4
			b.quad_o(f[e], f[e1], bk[e1], bk[e], inside)


## A projecting band of dressed stone along X at height y (0.16 tall), on the face at zf that
## looks toward `facing` (+1 = +Z).
func _course_x(b: PyroluxDemoProps.Builder, x0: float, x1: float, y: float, zf: float, proud: float,
		facing: float) -> void:
	var x: float = x0
	var i: int = 0
	var za: float = zf - facing * 0.04
	var zz: float = zf + facing * proud
	while x < x1 - 0.01:
		var piece: float = minf(1.1 + 0.3 * PyroluxDemoProps._rand01(i * 3 + 1), x1 - x)
		b.tint = Color(0.97, 0.97, 0.97) if i % 2 == 0 else Color(0.9, 0.9, 0.9)
		b.cbox(Vector3(x + 0.003, y, minf(za, zz)), Vector3(x + piece - 0.003, y + 0.16, maxf(za, zz)), 0.018)
		x += piece
		i += 1


## The same band along Z on a side wall's inner face at x (facing `facing` = +1 / -1 in X).
func _course_z(b: PyroluxDemoProps.Builder, x: float, facing: float, z0: float, z1: float, y: float, proud: float) -> void:
	var z: float = z0
	var i: int = 0
	while z < z1 - 0.01:
		var piece: float = minf(1.1 + 0.3 * PyroluxDemoProps._rand01(i * 5 + 2), z1 - z)
		b.tint = Color(0.97, 0.97, 0.97) if i % 2 == 0 else Color(0.9, 0.9, 0.9)
		var xa: float = x - facing * 0.04
		var xb: float = x + facing * proud
		b.cbox(Vector3(minf(xa, xb), y, z + 0.003), Vector3(maxf(xa, xb), y + 0.16, z + piece - 0.003), 0.018)
		z += piece
		i += 1


## Merlons along X on the wall top (WALL_H), between z0 and z1, two knocked off.
func _merlons_x(b: PyroluxDemoProps.Builder, x0: float, x1: float, z0: float, z1: float) -> void:
	var w: float = 0.72
	var gap: float = 0.46
	var x: float = x0 + 0.05
	var i: int = 0
	while x + w <= x1:
		if i != 4 and i != 9:
			b.tint = Color(1.0, 1.0, 1.0) if i % 2 == 0 else Color(0.93, 0.93, 0.93)
			b.cbox(Vector3(x, WALL_H, z0), Vector3(x + w, WALL_H + 0.62, z1), 0.02)
		x += w + gap
		i += 1


func _merlons_z(b: PyroluxDemoProps.Builder, x0: float, x1: float, z0: float, z1: float) -> void:
	var w: float = 0.72
	var gap: float = 0.46
	var z: float = z0 + 0.6
	var i: int = 0
	while z + w <= z1:
		b.tint = Color(1.0, 1.0, 1.0) if i % 2 == 0 else Color(0.93, 0.93, 0.93)
		b.cbox(Vector3(minf(x0, x1), WALL_H, z), Vector3(maxf(x0, x1), WALL_H + 0.62, z + w), 0.02)
		z += w + gap
		i += 1


## A round corner tower: coursed masonry, a corbelled parapet with merlons and a slate cone.
func _tower(parent: Node3D, at: Vector3) -> void:
	var rt: float = 1.25
	var ht: float = 6.3
	var segs: int = 28
	var bw: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	bw.lathe(PackedVector2Array([Vector2(rt, 0.0), Vector2(rt, ht)]), segs, Vector3.ZERO, 40.0,
		PackedFloat32Array(), TAU * rt)
	var tb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	tb.lathe(PackedVector2Array([Vector2(rt - 0.05, ht - 0.05), Vector2(rt + 0.22, ht + 0.22),
		Vector2(rt + 0.22, ht + 0.5), Vector2(rt - 0.1, ht + 0.5), Vector2(rt - 0.1, ht + 0.3), Vector2(0.0, ht + 0.3)]),
		segs, Vector3.ZERO, 40.0)
	var merlons: int = 10
	for k: int in merlons:
		var a: float = TAU * (float(k) + 0.5) / float(merlons)
		var mk: int = tb.mark()
		tb.tint = Color(1.0, 1.0, 1.0) if k % 2 == 0 else Color(0.93, 0.93, 0.93)
		tb.cbox(Vector3(-0.28, 0.0, -0.17), Vector3(0.28, 0.55, 0.17), 0.02)
		tb.xform_from(mk, Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a), 0.0, sin(a)) * (rt + 0.05) + Vector3(0.0, ht + 0.5, 0.0)))
	var rb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	# The cone rises from inside the parapet's walkway.
	rb.lathe(PackedVector2Array([Vector2(0.0, ht + 0.3), Vector2(rt - 0.15, ht + 0.3), Vector2(rt - 0.12, ht + 0.45),
		Vector2(0.18, ht + 2.85), Vector2(0.0, ht + 3.05)]), segs, Vector3.ZERO, 30.0, PackedFloat32Array(), 6.0)
	var root: Node3D = Node3D.new()
	root.name = "Tower"
	root.position = at
	parent.add_child(root)
	add_mesh(bw.mesh(), Vector3.ZERO, _wall_mat, Vector3.ZERO, root)
	add_mesh(tb.mesh(), Vector3.ZERO, _trim_mat, Vector3.ZERO, root)
	add_mesh(rb.mesh(), Vector3.ZERO, _slate_mat, Vector3.ZERO, root)


## The courtyard's gate in the front wall: two leaves of vertical planks filling the arch at `z`
## (seen from the yard), three iron bands, ring handles.
func _gate(parent: Node3D, z: float) -> void:
	var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	var r: float = GATE_R - 0.01
	var sp: float = GATE_SPRING
	var behind: Vector3 = Vector3(0.0, 1.0, z + 0.2)
	b.quad_o(Vector3(-r, 0.0, z), Vector3(r, 0.0, z), Vector3(r, sp, z), Vector3(-r, sp, z), behind,
		Vector2(0.0, 0.0), Vector2(0.0, 2.0 * r * 0.9), Vector2(sp, 2.0 * r * 0.9), Vector2(sp, 0.0))
	var n: int = 18
	for k: int in n:
		var a0: float = PI * float(k) / float(n)
		var a1: float = PI * float(k + 1) / float(n)
		var p0: Vector3 = Vector3(cos(a0) * r, sp + sin(a0) * r, z)
		var p1: Vector3 = Vector3(cos(a1) * r, sp + sin(a1) * r, z)
		var cc: Vector3 = Vector3(0.0, sp, z)
		var nrm: Vector3 = (p0 - cc).cross(p1 - cc)
		var uvc: Vector2 = Vector2(sp, r * 0.9)
		var uv0: Vector2 = Vector2(p0.y, (p0.x + r) * 0.9)
		var uv1: Vector2 = Vector2(p1.y, (p1.x + r) * 0.9)
		if nrm.dot(Vector3(0.0, 0.0, -1.0)) >= 0.0:
			b.tri(cc, p0, p1, uvc, uv0, uv1)
		else:
			b.tri(cc, p1, p0, uvc, uv1, uv0)
	add_mesh(b.mesh(), Vector3.ZERO, PyroluxDemoProps.kit_material(&"wood_planks"), Vector3.ZERO, parent).name = "Gate"
	var ib: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	ib.metal = 1.0
	for y: float in [0.45, 1.3, 2.15]:
		ib.cbox(Vector3(-r + 0.02, y, z - 0.025), Vector3(r - 0.02, y + 0.09, z + 0.004), 0.008)
	ib.cbox(Vector3(-0.03, 0.0, z - 0.02), Vector3(0.03, sp + r - 0.05, z + 0.004), 0.006)
	for sx: float in [-1.0, 1.0]:
		var hc: Vector3 = Vector3(sx * 0.22, 1.05, z - 0.04)
		for k: int in 10:
			var a0: float = TAU * float(k) / 10.0
			var a1: float = TAU * float(k + 1) / 10.0
			ib.tube(hc + Vector3(cos(a0) * 0.07, sin(a0) * 0.07, 0.0), hc + Vector3(cos(a1) * 0.07, sin(a1) * 0.07, 0.0), 0.012, 0.012, 5)
	add_mesh(ib.mesh(), Vector3.ZERO, PyroluxDemoProps.kit_material(&"iron"), Vector3.ZERO, parent).name = "GateIron"


func _build_dressing() -> void:
	var d: Node3D = _dressing_root
	var zf: float = BACK_Z
	# Torches on the inner piers and on the side walls; banners on the outer piers.
	for x: float in [-BAY * 0.5, BAY * 0.5]:
		_fire_of(adopt(PyroluxDemoProps.wall_torch(d, Vector3(x, 2.25, zf + 0.002), 0.0)))
	for sx: float in [-1.0, 1.0]:
		_fire_of(adopt(PyroluxDemoProps.wall_torch(d, Vector3(-sx * SIDE_X + sx * 0.002, 2.25, -1.3), sx * PI * 0.5)))
	for x: float in [-BAY * 1.5, BAY * 1.5]:
		_banner(d, Vector3(x, 3.86, zf + 0.06))
	# Braziers near the back wall, burning at night.
	for sx: float in [-1.0, 1.0]:
		_fire_of(adopt(PyroluxDemoProps.brazier(d, Vector3(sx * 3.7, 0.0, -3.15), true, sx * 0.4)))
	# Stores in the back corners.
	adopt(PyroluxDemoProps.crate(d, Vector3(-6.45, 0.0, -3.55), 0.82, null, null, 0.12))
	adopt(PyroluxDemoProps.crate(d, Vector3(-6.42, 0.82, -3.6), 0.62, null, null, -0.35))
	adopt(PyroluxDemoProps.crate(d, Vector3(-5.5, 0.0, -3.75), 0.7, null, null, 0.5))
	adopt(PyroluxDemoProps.barrel(d, Vector3(-6.6, 0.0, -2.45), 0.32, 0.9, null, null, 0.3))
	adopt(PyroluxDemoProps.barrel(d, Vector3(-5.85, 0.0, -2.75), 0.3, 0.86, null, null, 1.7))
	adopt(PyroluxDemoProps.barrel(d, Vector3(6.55, 0.0, -3.5), 0.32, 0.9, null, null, 0.8))
	adopt(PyroluxDemoProps.barrel(d, Vector3(5.85, 0.0, -3.75), 0.3, 0.86, null, null, 2.2))
	adopt(PyroluxDemoProps.barrel(d, Vector3(6.2, 0.9, -3.62), 0.29, 0.8, null, null, 1.1))
	adopt(PyroluxDemoProps.crate(d, Vector3(6.5, 0.0, -2.6), 0.7, null, null, -0.25))
	# A broken column with its fallen drum, an urn on a pedestal, rubble at the walls' feet.
	adopt(PyroluxDemoProps.column(d, Vector3(5.7, 0.0, -1.1), 1.7, null, 0.3))
	adopt(PyroluxDemoProps.pedestal(d, Vector3(6.1, 0.0, 1.7), 0.66, 0.95))
	adopt(PyroluxDemoProps.urn(d, Vector3(6.1, 0.95, 1.7), null, 0.4))
	var rubble: ShaderMaterial = PyroluxDemoProps.kit_material(&"rock")
	for spot: Vector3 in [Vector3(-4.7, 0.0, -4.0), Vector3(3.25, 0.0, -4.05), Vector3(6.85, 0.0, 0.3), Vector3(-6.9, 0.0, 1.9)]:
		adopt(PyroluxDemoProps.rock_cluster(d, spot, 0.3, 5, int(spot.x * 10.0 + spot.z * 3.0) + 50, rubble))
	# A tree in a stone planter by the left wall.
	_planter(d, Vector3(-6.0, 0.0, 0.7))
	adopt(PyroluxDemoProps.tree(d, Vector3(-6.0, 0.42, 0.7), 3.9, 4))


func _fire_of(node: Node) -> void:
	var root: Node3D = node as Node3D
	if root == null or not root.has_meta(&"flame"):
		return
	var v: Variant = root.get_meta(&"flame")
	if v is PyroluxDemoProps.TorchFlame:
		var f: PyroluxDemoProps.TorchFlame = v
		f.flicker = flame_flicker
		_fires.append(f)
	if root.has_meta(&"coals"):
		var c: Variant = root.get_meta(&"coals")
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			_coals.append(mi)


## A banner hung from a pole under the string course: a field, a gold band and a lozenge, a
## swallowtail, a little sway in the cloth.
func _banner(parent: Node3D, top: Vector3) -> void:
	var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	b.kind = 1.0
	var w: float = 0.78
	var l: float = 1.95
	var rows: int = 10
	var cols: int = 7
	var grid: Array[PackedVector3Array] = []
	for i: int in rows + 1:
		var t: float = float(i) / float(rows)
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in cols + 1:
			var u: float = float(j) / float(cols) - 0.5
			var tail: float = 0.0
			if t > 0.82:
				tail = (t - 0.82) / 0.18 * 0.28 * (1.0 - absf(u) * 2.0)
			var yy: float = -t * l + tail
			var zz: float = 0.02 * sin(u * 5.0 + t * 2.0) * t
			row.append(Vector3(u * w, yy, zz))
		grid.append(row)
	b.tint = Color(0.5, 0.09, 0.075)
	b.sheet(grid, Vector3(0.0, 0.0, 1.0), 0.7)
	b.tint = Color(0.78, 0.6, 0.26)
	var band: Array[PackedVector3Array] = []
	for yy: float in [-0.16, -0.24]:
		band.append(PackedVector3Array([Vector3(-w * 0.5, yy, 0.006), Vector3(w * 0.5, yy, 0.006)]))
	b.sheet(band, Vector3(0.0, 0.0, 1.0), 1.0)
	var lz: Array[PackedVector3Array] = []
	var cy: float = -0.86
	lz.append(PackedVector3Array([Vector3(0.0, cy + 0.26, 0.016), Vector3(0.0, cy + 0.26, 0.016)]))
	lz.append(PackedVector3Array([Vector3(-0.17, cy, 0.016), Vector3(0.17, cy, 0.016)]))
	lz.append(PackedVector3Array([Vector3(0.0, cy - 0.26, 0.016), Vector3(0.0, cy - 0.26, 0.016)]))
	b.sheet(lz, Vector3(0.0, 0.0, 1.0), 1.0)
	b.tint = Color(0.42, 0.29, 0.17)
	b.tube(Vector3(-w * 0.62, 0.035, 0.0), Vector3(w * 0.62, 0.035, 0.0), 0.022, 0.022, 8, true, true)
	b.ellipsoid(Vector3(-w * 0.64, 0.035, 0.0), Vector3.ONE * 0.034, 8, 5)
	b.ellipsoid(Vector3(w * 0.64, 0.035, 0.0), Vector3.ONE * 0.034, 8, 5)
	b.tint = Color(0.35, 0.34, 0.33)
	b.metal = 1.0
	for sx: float in [-1.0, 1.0]:
		b.tube(Vector3(sx * w * 0.45, 0.035, 0.0), Vector3(sx * w * 0.45, 0.035, -0.06), 0.012, 0.012, 6)
	var mi: MeshInstance3D = add_mesh(b.mesh(), top, _cloth_mat, Vector3.ZERO, parent)
	mi.name = "Banner"


## A round stone planter with earth in it.
func _planter(parent: Node3D, at: Vector3) -> void:
	var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.92, 0.0), Vector2(0.95, 0.06), Vector2(0.92, 0.36),
		Vector2(0.96, 0.4), Vector2(0.96, 0.46), Vector2(0.8, 0.46), Vector2(0.78, 0.38), Vector2(0.0, 0.38)]),
		26, Vector3.ZERO, 40.0, PackedFloat32Array([1, 1, 1, 1, 1, 1, 1, 0.8, 0.8]))
	add_mesh(b.mesh(), at, _trim_mat, Vector3.ZERO, parent).name = "Planter"
	var e: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	e.lathe(PackedVector2Array([Vector2(0.79, 0.4), Vector2(0.0, 0.4)]), 26, Vector3.ZERO)
	add_mesh(e.mesh(), at, mat(Color(0.16, 0.12, 0.09), 0.98), Vector3.ZERO, parent).name = "Earth"


# ------------------------------------------------------------------ studio (LOOK_STUDIO)

## The sweep and the studio's lights, built the first time the look is set.
func _build_studio() -> void:
	_studio_root = Node3D.new()
	_studio_root.name = "Studio"
	add_child(_studio_root)
	# Kit 13: the shared prop shader in its sweep mode (v12 had demo_studio.gdshader, the same
	# look in a second lit shader).
	# Kit 14 (v13.1): a darker sweep (0.11 -> 0.035) under a wider, softer key, so the floor is one
	# even dark sheen with the shadows on it and no lopsided patch of light (the user, 11/01).
	_studio_mat = PyroluxDemoProps.flat_material(Color(0.035, 0.035, 0.038), 0.32, 0.0, 0.0)
	_studio_mat.set_shader_parameter("sweep", 1.0)
	_studio_mat.set_shader_parameter("specular", 0.5)
	var sweep: MeshInstance3D = add_mesh(_sweep_mesh(), Vector3.ZERO, _studio_mat, Vector3.ZERO, _studio_root)
	sweep.name = "Sweep"
	sweep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The key from the front left (soft: a large light size), the rim from behind right, a wide
	# faint halo on the cove behind the subject.
	studio_key = _studio_spot(Vector3(-3.0, 4.6, 3.9), Vector3(0.0, 0.9, 0.0), Color(1.0, 0.95, 0.88), 40.0, 55.0, 0.8, false)
	studio_key.name = "Key"
	# Kit 14: wide and soft (v13: 36 degrees, attenuation 3): its edge no longer falls inside a
	# normal frame as an ellipse on the floor.
	studio_key.spot_angle_attenuation = 1.5
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# Shadow acne (dark stripes on the figures and props) in Compatibility and on the web
		# with the default bias (AURELUX, 11/01).
		studio_key.shadow_bias = 0.12
		studio_key.shadow_normal_bias = 2.5
	# The rim and the halo light the subject and the sweep, not the floor's sheen: their glints on
	# the glossy floor read as stray blobs in front of the subject.
	var rim: SpotLight3D = _studio_spot(Vector3(2.8, 3.0, -2.8), Vector3(0.0, 1.1, 0.0), Color(0.62, 0.74, 1.0), 13.0, 30.0, 0.4, false)
	rim.name = "Rim"
	rim.light_specular = 0.0
	var halo: OmniLight3D = OmniLight3D.new()
	halo.name = "Halo"
	halo.position = Vector3(0.3, 2.2, STUDIO_BACK + 1.9)
	halo.light_color = Color(0.5, 0.56, 0.7)
	halo.light_energy = 5.0
	halo.omni_range = 7.5
	halo.omni_attenuation = 1.4
	halo.shadow_enabled = false
	halo.light_specular = 0.0
	_studio_root.add_child(halo)
	if _lite:
		studio_key.shadow_enabled = false
	adopt(_studio_root)


func _studio_spot(pos: Vector3, target: Vector3, c: Color, energy: float, angle: float, size: float,
		shadow: bool) -> SpotLight3D:
	var l: SpotLight3D = SpotLight3D.new()
	_studio_root.add_child(l)
	l.transform = Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)
	l.light_color = c
	l.light_energy = energy
	l.spot_angle = angle
	l.spot_angle_attenuation = 3.0
	l.spot_range = 20.0
	l.light_size = size
	l.shadow_enabled = shadow
	l.shadow_blur = 1.5
	return l


## The floor (y = 0) from STUDIO_FRONT back to the cove, a quarter circle of STUDIO_COVE, then the
## wall up to STUDIO_H at STUDIO_BACK: one sheet across x with smooth normals along the profile.
func _sweep_mesh() -> ArrayMesh:
	var prof: Array[Vector2] = []  # (y, z)
	var zc: float = STUDIO_BACK + STUDIO_COVE
	for i: int in 25:
		prof.append(Vector2(0.0, lerpf(STUDIO_FRONT, zc, float(i) / 24.0)))
	for i: int in range(1, 33):
		var a: float = float(i) / 32.0 * PI * 0.5
		prof.append(Vector2(STUDIO_COVE - STUDIO_COVE * cos(a), zc - STUDIO_COVE * sin(a)))
	for i: int in range(1, 13):
		prof.append(Vector2(STUDIO_COVE + (STUDIO_H - STUDIO_COVE) * float(i) / 12.0, STUDIO_BACK))
	var n: int = prof.size()
	var nrm: Array[Vector3] = []
	for i: int in n:
		var t: Vector2 = (prof[mini(i + 1, n - 1)] - prof[maxi(i - 1, 0)]).normalized()
		# The profile runs toward -z and then up: its normal faces up on the floor, +z on the wall.
		nrm.append(Vector3(0.0, -t.y, t.x).normalized())
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: int = 24
	for i: int in n - 1:
		for k: int in xs:
			var xa: float = lerpf(-STUDIO_HW, STUDIO_HW, float(k) / xs)
			var xb: float = lerpf(-STUDIO_HW, STUDIO_HW, float(k + 1) / xs)
			var p00: Vector3 = Vector3(xa, prof[i].x, prof[i].y)
			var p10: Vector3 = Vector3(xb, prof[i].x, prof[i].y)
			var p01: Vector3 = Vector3(xa, prof[i + 1].x, prof[i + 1].y)
			var p11: Vector3 = Vector3(xb, prof[i + 1].x, prof[i + 1].y)
			var na: Vector3 = nrm[i]
			var nb: Vector3 = nrm[i + 1]
			st.set_normal(na)
			st.add_vertex(p00)
			st.set_normal(nb)
			st.add_vertex(p01)
			st.set_normal(na)
			st.add_vertex(p10)
			st.set_normal(na)
			st.add_vertex(p10)
			st.set_normal(nb)
			st.add_vertex(p01)
			st.set_normal(nb)
			st.add_vertex(p11)
	return st.commit()


## The environment and the viewport as the studio asks (or as every other look had them).
func _studio_environment(studio: bool) -> void:
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX if studio else Environment.TONE_MAPPER_FILMIC
	environment.background_mode = Environment.BG_COLOR if studio else Environment.BG_SKY
	environment.background_color = Color(0.004, 0.004, 0.005)
	# SSR and SSAO are Forward+ only (4.7 also has SSAO in Compatibility, 4.4 does not); switching
	# either on elsewhere logs a warning (Mobile captures and the 4.4.1 table, 10/31).
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		# Kit 13: off while the stage is in its first-visit mode (lite_post() turns them on).
		var fx: bool = studio and not _lite
		environment.ssr_enabled = fx
		environment.ssr_max_steps = 96
		environment.ssr_fade_in = 0.15
		environment.ssr_fade_out = 2.0
		environment.ssao_enabled = false  # kit 15: off (a cost on every renderer that has it, no look worth it)
		environment.ssao_radius = 0.6
		environment.ssao_intensity = 1.2
	if studio and not OS.has_feature("web") and is_inside_tree():
		var vp: Viewport = get_viewport()
		vp.msaa_3d = Viewport.MSAA_8X
		vp.use_debanding = true
		# Captures for the store (--ss2 after --): the 3D at twice the window's size, filtered down
		# (2x supersampling), so a 960x540 GIF frame is drawn from 1920x1080.
		if OS.get_cmdline_user_args().has("--ss2"):
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 2.0


## Moves the studio's soft floor pool to `centre` (world xz), e.g. under a subject off the origin.
func studio_centre(centre: Vector3) -> void:
	if _studio_mat != null:
		_studio_mat.set_shader_parameter("sweep_pool_centre", centre)
		var q: Variant = _quick.get(_studio_mat.get_instance_id())
		if q is ShaderMaterial:
			var qm: ShaderMaterial = q
			qm.set_shader_parameter("sweep_pool_centre", centre)


# ------------------------------------------------------------------ looks

## Swaps the mood of the stage: sky, sun, ambient, the stone's colours, the fires. The camera
## stays the demo's own job; this only decides how bright and what colour the world is.
func set_look(value: int) -> void:
	look = value
	if sun == null:
		return
	environment.tonemap_exposure = renderer_tonemap_gain()
	match value:
		LOOK_DARK_ARENA:
			# UNDALUX COURTYARD after t5b (STATE.md decision 6): the dark flagstones and the dark
			# wall, a cooler, lower ambient, the same daylight.
			_sky(Color(0.32, 0.5, 0.78), Color(0.72, 0.74, 0.72), Color(0.5, 0.46, 0.4), Color(0.34, 0.3, 0.26), 12.0)
			_sun(Color(1.0, 0.96, 0.88), 1.3, Vector3(-40.0, -35.0, 0.0))
			_ambient(Color(0.42, 0.47, 0.56), 0.62)
			_stone(Color(0.19, 0.185, 0.18), Color(0.09, 0.088, 0.085), Color(0.155, 0.148, 0.142), Color(0.07, 0.068, 0.066),
				Color(0.2, 0.19, 0.18))
		LOOK_GRID:
			# A near-black sky with a hint of blue at the horizon; a weak white light from high
			# up and a little in front (a soft contact shadow under the figure), a cool low
			# ambient. The floor's own fade takes the far ground into the sky's colour.
			_sky(Color(0.008, 0.01, 0.02), Color(0.03, 0.036, 0.058), Color(0.012, 0.014, 0.022), Color(0.008, 0.009, 0.014), 2.0)
			_sun(Color(0.86, 0.9, 1.0), 0.8, Vector3(-72.0, 24.0, 0.0))
			_ambient(Color(0.3, 0.34, 0.46), 0.32)
			_stone(Color(0.3, 0.29, 0.275), Color(0.12, 0.115, 0.11), Color(0.36, 0.34, 0.32), Color(0.16, 0.15, 0.14),
				Color(0.42, 0.4, 0.37))
		LOOK_STUDIO:
			# The sun is hidden (the studio's own lights take over); its direction and energy
			# stay the key's, for the web first-visit stand-ins that light by them.
			_sky(Color(0.004, 0.004, 0.005), Color(0.008, 0.008, 0.01), Color(0.006, 0.006, 0.007), Color(0.004, 0.004, 0.005), 1.0)
			_sun(Color(1.0, 0.95, 0.88), 0.9, Vector3(-38.0, -36.0, 0.0))
			_ambient(Color(0.6, 0.63, 0.7), 0.3)
		LOOK_DUNGEON_NIGHT:
			_sky(Color(0.004, 0.006, 0.016), Color(0.018, 0.022, 0.04), Color(0.01, 0.01, 0.014), Color(0.004, 0.004, 0.006), 3.0)
			# The moon, faint, from behind the back wall and the right.
			_sun(Color(0.55, 0.64, 0.92), 0.14, Vector3(-53.0, 138.0, 0.0))
			_ambient(Color(0.24, 0.28, 0.4), 0.17)
			_stone(Color(0.3, 0.29, 0.275), Color(0.12, 0.115, 0.11), Color(0.36, 0.34, 0.32), Color(0.16, 0.15, 0.14),
				Color(0.42, 0.4, 0.37))
		_:
			# GLYPHLUX PASS.md: sun 1.2 at 40 degrees from the camera's left-front, ambient 0.45.
			_sky(Color(0.27, 0.46, 0.78), Color(0.68, 0.74, 0.82), Color(0.46, 0.43, 0.39), Color(0.24, 0.22, 0.2), 12.0)
			_sun(Color(1.0, 0.95, 0.86), 1.2, Vector3(-40.0, -38.0, 0.0))
			_ambient(Color(0.64, 0.7, 0.84), 0.45)
			_stone(Color(0.33, 0.315, 0.29), Color(0.15, 0.14, 0.13), Color(0.43, 0.405, 0.37), Color(0.2, 0.19, 0.17),
				Color(0.5, 0.47, 0.42))
	# The grid look hides the courtyard and its dressing and lays the reference floor; the studio
	# hides them and the ground and shows its sweep.
	var grid: bool = value == LOOK_GRID
	var studio: bool = value == LOOK_STUDIO
	if studio and _studio_root == null:
		_build_studio()
	if not studio and not grid:
		_ensure_yard()
	if _yard_root != null:
		_yard_root.visible = not grid and not studio
	if _dressing_root != null:
		_dressing_root.visible = not grid and not studio
	if ground != null:
		ground.visible = not studio
		_swap_material(ground, _grid_mat if grid else _ground_mat)
	if _studio_root != null:
		_studio_root.visible = studio
	sun.visible = not studio
	_studio_environment(studio)
	var burn: bool = value == LOOK_DUNGEON_NIGHT
	for f: PyroluxDemoProps.TorchFlame in _fires:
		if is_instance_valid(f):
			f.set_burning(burn, true)
	var coal: Material = PyroluxDemoProps.kit_material(&"ember" if burn else &"char")
	for mi: MeshInstance3D in _coals:
		if is_instance_valid(mi):
			_swap_material(mi, coal)
	environment.glow_enabled = glow
	_apply_light()
	for q: ShaderMaterial in _quick_list:
		_light_quick(q)


func _sky(top: Color, horizon: Color, ground_h: Color, ground_b: Color, sun_size: float) -> void:
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = ground_h
	sky_mat.ground_bottom_color = ground_b
	sky_mat.sun_angle_max = sun_size


func _sun(c: Color, energy: float, rot_deg: Vector3) -> void:
	sun.light_color = c
	_sun_base = energy
	sun.rotation_degrees = rot_deg


func _ambient(c: Color, energy: float) -> void:
	environment.ambient_light_color = c
	_amb_base = energy


func _stone(floor_c: Color, floor_mortar: Color, wall_c: Color, wall_mortar: Color, trim_c: Color) -> void:
	_ground_mat.set_shader_parameter("stone_color", floor_c)
	_ground_mat.set_shader_parameter("mortar_color", floor_mortar)
	_wall_mat.set_shader_parameter("stone_color", wall_c)
	_wall_mat.set_shader_parameter("mortar_color", wall_mortar)
	_trim_mat.set_shader_parameter("side_color", trim_c)
	_trim_mat.set_shader_parameter("top_color", trim_c * 1.08)
	_trim_mat.set_shader_parameter("under_color", trim_c * 0.35)
	for m: Material in [_ground_mat, _wall_mat, _trim_mat]:
		var key: int = m.get_instance_id()
		if _quick.has(key):
			var q: ShaderMaterial = _quick[key]
			q.set_shader_parameter("col", _colour_of(m))


# ------------------------------------------------------------------ meshes, props, figures

## A mesh of the stage, remembered for the first-visit swap. `parent` defaults to props.
func add_mesh(mesh: Mesh, at: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO,
		parent: Node = null) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation_degrees = rot_deg
	mi.material_override = material
	(parent if parent != null else props).add_child(mi)
	_remember(mi)
	return mi


## Registers everything under `node` (made elsewhere: the kit's props and figures, a product's
## own meshes) for the first-visit swap: meshes get the unshaded stand-in while the stage is
## light, flames and lights wait. Returns `node`.
func adopt(node: Node) -> Node:
	if node == null:
		return node
	var f: PyroluxDemoProps.TorchFlame = node as PyroluxDemoProps.TorchFlame
	if f != null:
		_wait(f)
		return node
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null and mi.material_override != null:
		_remember(mi)
	var light: Light3D = node as Light3D
	if light != null and light != sun:
		_wait(light)
	for c: Node in node.get_children():
		adopt(c)
	return node


func _remember(mi: MeshInstance3D) -> void:
	if mi.material_override == null:
		return
	_real.append(mi)
	_real_mats.append(mi.material_override)
	if _lite:
		mi.material_override = _quick_of(mi.material_override)


## Gives a registered mesh another real material (the stand-in while the stage is light).
func _swap_material(mi: MeshInstance3D, m: Material) -> void:
	var i: int = _real.find(mi)
	if i >= 0:
		_real_mats[i] = m
	mi.material_override = _quick_of(m) if _lite else m


func _wait(n: Node3D) -> void:
	if _lite:
		n.visible = false
		_waiting.append(n)


## Removes the product's props (the stage's own walls and dressing stay).
func clear_props() -> void:
	for c: Node in props.get_children():
		props.remove_child(c)
		c.queue_free()


## A plain lit material in the stage's shared prop shader (no StandardMaterial3D, so no shader of
## its own to compile on the web). Cached by its values.
func mat(color: Color, rough: float = 0.85, metal: float = 0.0) -> ShaderMaterial:
	var key: String = "%s_%.2f_%.2f" % [color.to_html(), rough, metal]
	if _mats.has(key):
		var hit: ShaderMaterial = _mats[key]
		return hit
	var m: ShaderMaterial = PyroluxDemoProps.flat_material(color, rough, metal, 0.05)
	_mats[key] = m
	return m


## The knight statue (DemoFigure.knight) at `at` under `parent` (default props), registered.
func knight(at: Vector3 = Vector3.ZERO, parent: Node = null, pedestal: bool = true, yaw: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = PyroluxDemoFigure.knight(parent if parent != null else props, at, pedestal, null, yaw)
	adopt(mi)
	return mi


## A statue to soak or burn: the knight on his plinth (UNDALUX's statue() call).
func statue(at: Vector3, parent: Node = null) -> MeshInstance3D:
	return knight(at, parent, true)


func mannequin(at: Vector3, parent: Node = null, yaw: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = PyroluxDemoFigure.mannequin(parent if parent != null else props, at, yaw)
	adopt(mi)
	return mi


## The hooded caster facing `aim` (DemoFigure.caster): metas "tip", "gem" as GLYPHLUX's.
func caster(at: Vector3, aim: Vector3, parent: Node = null, gem: Color = Color(0.75, 0.6, 1.0),
		pose: int = 0) -> Node3D:
	var who: Node3D = PyroluxDemoFigure.caster(parent if parent != null else props, at, aim, gem, null, pose)
	adopt(who)
	return who


func soldier(at: Vector3, aim: Vector3, parent: Node = null) -> MeshInstance3D:
	var mi: MeshInstance3D = PyroluxDemoFigure.soldier(parent if parent != null else props, at, aim)
	adopt(mi)
	return mi


func column(at: Vector3, height: float, parent: Node = null) -> Node3D:
	return adopt(PyroluxDemoProps.column(_parent3d(parent), at, height)) as Node3D


func brazier(at: Vector3, parent: Node = null, lit: bool = true) -> Node3D:
	var n: Node3D = adopt(PyroluxDemoProps.brazier(_parent3d(parent), at, lit)) as Node3D
	# Registers its flame like the built-in torches (flame_flicker, the look's burn switch).
	_fire_of(n)
	return n


func _parent3d(parent: Node) -> Node3D:
	var p: Node3D = parent as Node3D
	return p if p != null else props


# ------------------------------------------------------------------ camera

## The stage's camera at `pos` looking at `target` (made once, then moved), made current.
func aim_camera(pos: Vector3, target: Vector3, fov: float = CAM_FOV) -> Camera3D:
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera"
		add_child(camera)
	camera.fov = fov
	var dir: Vector3 = target - pos
	if dir.length_squared() < 0.000001:
		dir = Vector3.FORWARD
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.999 else Vector3.BACK
	camera.transform = Transform3D(Basis.looking_at(dir, up), pos)
	camera.make_current()
	return camera


## The eye-level camera: `dist` metres from `target` at eye height, `yaw_deg` round it (0 = from
## +Z, the open side of the courtyard), looking at `target`.
func eye_camera(target: Vector3, dist: float, yaw_deg: float = 0.0, fov: float = CAM_FOV,
		eye_y: float = CAM_EYE_Y) -> Camera3D:
	var yaw: float = deg_to_rad(yaw_deg)
	var horiz: float = sqrt(maxf(dist * dist - (eye_y - target.y) * (eye_y - target.y), 0.01))
	var pos: Vector3 = Vector3(target.x + sin(yaw) * horiz, eye_y, target.z + cos(yaw) * horiz)
	return aim_camera(pos, target, fov)


## GLYPHLUX's hero camera, aimed at a `target_h` tall subject standing at `at`.
func aim_hero_camera(at: Vector3, target_h: float = STATUE_H) -> Camera3D:
	var half_v: float = deg_to_rad(CAM_FOV * 0.5)
	var dist: float = target_h / (FRAME_FILL * 2.0 * tan(half_v))
	var yaw: float = deg_to_rad(CAM_YAW_DEG)
	var pos: Vector3 = at + Vector3(sin(yaw) * dist, CAM_EYE_Y, cos(yaw) * dist)
	var visible_h: float = 2.0 * dist * tan(half_v)
	var look_y: float = target_h * 0.5 - (0.5 - SUBJECT_CENTRE_V) * visible_h
	return aim_camera(pos, at + Vector3(0.0, look_y, 0.0), CAM_FOV)


## A camera for the demos that frame each slot themselves.
func ensure_camera() -> Camera3D:
	if camera == null:
		aim_hero_camera(Vector3.ZERO)
	return camera


# ------------------------------------------------------------------ web first visit

func is_lite() -> bool:
	return _lite


## One stand-in per real material, all on the one unshaded shader (so it compiles once). A
## material already on that shader (a gem, embers) stays as it is.
func _quick_of(m: Material) -> Material:
	var sm: ShaderMaterial = m as ShaderMaterial
	if sm != null and sm.shader == QUICK_SHADER:
		return m
	var key: int = m.get_instance_id()
	if _quick.has(key):
		var hit: ShaderMaterial = _quick[key]
		return hit
	var q: ShaderMaterial = ShaderMaterial.new()
	q.shader = QUICK_SHADER
	q.set_shader_parameter("col", _colour_of(m))
	var sw: Variant = sm.get_shader_parameter("sweep") if sm != null else null
	var swf: float = sw if sw is float else 0.0
	if swf > 0.5:
		# Kit 13: the studio sweep's stand-in keeps its pool and its fall-off (the visitor can see
		# it now: the first scene shows before the stage is back).
		q.set_shader_parameter("sweep", 1.0)
		for k: String in ["sweep_far", "sweep_pool_centre", "sweep_pool_radius", "sweep_pool_gain", "sweep_wall_fade", "sweep_floor_fade"]:
			q.set_shader_parameter(k, sm.get_shader_parameter(k))
	_light_quick(q)
	_quick[key] = q
	_quick_list.append(q)
	return q


func _colour_of(m: Material) -> Color:
	var sm: ShaderMaterial = m as ShaderMaterial
	if sm != null:
		for p: StringName in [&"side_color", &"stone_color", &"base_col", &"col", &"base_color"]:
			var v: Variant = sm.get_shader_parameter(p)
			if v is Color:
				var c: Color = v
				return c
	var st: BaseMaterial3D = m as BaseMaterial3D
	if st != null:
		return st.albedo_color
	return Color(0.5, 0.5, 0.5)


## The stand-in's fixed light follows the look: the sun's direction and strength, the ambient.
func _light_quick(q: ShaderMaterial) -> void:
	q.set_shader_parameter("sun_dir", sun.global_transform.basis.z if sun.is_inside_tree() else sun.transform.basis.z)
	var sc: Color = sun.light_color
	var ac: Color = environment.ambient_light_color
	q.set_shader_parameter("key", _sun_base * (sc.r + sc.g + sc.b) / 3.0 * 0.9)
	q.set_shader_parameter("ambient", maxf(_amb_base * (ac.r + ac.g + ac.b) / 3.0, 0.12))
	q.set_shader_parameter("gain", QUICK_GAIN)


## The real materials, for the warm-up to draw once each before lite_finish(): one per shader
## (materials that differ only in their values share a compiled shader), and the flame.
func warm_materials() -> Array[Material]:
	var out: Array[Material] = []
	var seen: Dictionary = {}
	for i: int in _real_mats.size():
		var m: Material = _real_mats[i]
		# Kit 13: not what the look hides (the ground and the yard in the studio).
		if _hidden_by_look(_real[i]):
			continue
		var sm: ShaderMaterial = m as ShaderMaterial
		var k: int = sm.shader.get_instance_id() if sm != null and sm.shader != null else m.get_instance_id()
		if not seen.has(k):
			seen[k] = true
			out.append(m)
	if look != LOOK_STUDIO or not _fires.is_empty():
		out.append(PyroluxDemoProps.flame_material())
	return out


func _hidden_by_look(mi: MeshInstance3D) -> bool:
	if not is_instance_valid(mi):
		return true
	if mi == ground:
		return not ground.visible
	for r: Node3D in [_yard_root, _dressing_root]:
		if r != null and not r.visible and r.is_ancestor_of(mi):
			return true
	return false


## Kit 13: the first-visit swap undone on the stage's own meshes, one shader per step (the
## warm-up runs one step per frame): the first step lets the studio's lights in (the key's shadow
## stays off until lite_shadow_on(); the stand-ins are unshaded, so nothing changes on screen yet), each later step
## gives the real material back to every mesh drawn with one shader. So each shader compiles the
## versions the stage really draws (its meshes, its lights) one frame at a time, where tiny quads
## in front of a warm light compiled versions of their own and lite_finish() still paid for the
## real ones in one long frame (GLYPHLUX step 10). lite_shadow_on(), lite_finish() and lite_post()
## follow as before.
func lite_restore_steps() -> Array[Callable]:
	var out: Array[Callable] = [_lights_in]
	var groups: Dictionary = {}
	var order: Array = []
	for i: int in _real.size():
		if _hidden_by_look(_real[i]):
			continue
		var m: Material = _real_mats[i]
		var sm: ShaderMaterial = m as ShaderMaterial
		var k: int = sm.shader.get_instance_id() if sm != null and sm.shader != null else m.get_instance_id()
		if not groups.has(k):
			groups[k] = []
			order.append(k)
		var g: Array = groups[k]
		g.append(i)
	for k: Variant in order:
		var g: Array = groups[k]
		out.append(_restore_group.bind(g))
	return out


## Kit 13: the kit warm-up's first step back (after slot 0 is on screen): the lights in, with
## their shadows (the stand-ins are unshaded, so the stage does not change yet).
func lite_lights_in() -> void:
	_lights_in()


## Kit 13: one [mesh, real material] per real shader still to come back (what the look hides
## left out), for the warm-up to draw a hidden copy of where the mesh stands.
func lite_ghosts() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for i: int in _real.size():
		if _hidden_by_look(_real[i]):
			continue
		var m: Material = _real_mats[i]
		var sm: ShaderMaterial = m as ShaderMaterial
		var k: int = sm.shader.get_instance_id() if sm != null and sm.shader != null else m.get_instance_id()
		if seen.has(k):
			continue
		seen[k] = true
		out.append([_real[i], m])
	return out


func _lights_in() -> void:
	if not _lite:
		return
	for k: int in range(_waiting.size() - 1, -1, -1):
		var n: Node3D = _waiting[k]
		if is_instance_valid(n) and n is Light3D:
			n.visible = true
			_waiting.remove_at(k)


func _restore_group(indices: Array) -> void:
	if not _lite:
		return
	for v: Variant in indices:
		var i: int = v
		if i < _real.size():
			_give_back(i)


## Kit 13: lights for the warm-up's material pieces, of the kinds the look lights with, so each
## real material compiles the light versions the stage will ask for (one per frame) and not all
## at once in lite_finish(). They see only `mask` and are nearly black. The warm-up parents them
## next to its pieces (0.6 m in front of the camera) and frees them afterwards. Empty: the
## warm-up uses its own small shadowed directional light (the courtyard looks).
func warm_rig(mask: int) -> Array[Light3D]:
	var out: Array[Light3D] = []
	if look != LOOK_STUDIO:
		return out
	for kind: int in 3:
		var l: Light3D
		if kind == 2:
			var o: OmniLight3D = OmniLight3D.new()
			o.omni_range = 1.0
			l = o
		else:
			var sp: SpotLight3D = SpotLight3D.new()
			sp.spot_range = 1.0
			sp.spot_angle = 40.0
			l = sp
		l.name = "WarmRig%d" % kind
		l.shadow_enabled = false
		l.light_energy = 0.01
		l.light_cull_mask = mask
		l.position = Vector3(0.0, 0.0, 0.3)
		out.append(l)
	return out


func lite_shadow_on() -> void:
	# Kit 15: nothing to bring back; the demo has no shadows.
	pass


## Puts every real material back, lets the waiting flames and lights in, and brings the light up
## from RAMP_FROM over RAMP_SECONDS (a switch-on, not a pop); the burning fires catch.
func lite_finish() -> void:
	if not _lite:
		return
	_lite = false
	for i: int in _real.size():
		if not _give_back(i):
			_late.append(i)
	for n: Node3D in _waiting:
		if is_instance_valid(n):
			n.visible = true
			var f: PyroluxDemoProps.TorchFlame = n as PyroluxDemoProps.TorchFlame
			if f != null and f.is_burning():
				f.catch_fire()
	_waiting.clear()
	_ramp_t = 0.0
	_apply_ramp()


## Kit 13: the last step back from the first-visit mode, called a frame after lite_finish(): the
## studio's SSR and SSAO (Forward+ only; nothing in the other renderers or the other looks).
func lite_post() -> void:
	if look == LOOK_STUDIO and environment != null:
		_studio_environment(true)


## Puts mesh `i`'s real material back when it still draws with its stand-in. False while
## something else holds its material: an effect that took the material over (a slice that moved it
## to the surface overrides, a status that swapped it) and will hand the stand-in back when it is
## done; the mesh is then retried every frame (kit v8). Writing the real material over the effect
## hid what the effect drew, the effect later "restored" the stand-in, and a mesh freed with both
## an override and the effect's surface materials logged `Parameter "material" is null` x4 in
## the Compatibility renderer (JANULUX web, step 8).
func _give_back(i: int) -> bool:
	var mi: MeshInstance3D = _real[i]
	if not is_instance_valid(mi):
		return true
	var real: Material = _real_mats[i]
	var cur: Material = mi.material_override
	if cur == real:
		return true
	if cur != null and cur == _stand_in(real):
		mi.material_override = real
		return true
	return false


## The stand-in made for `m` in lite mode, or null.
func _stand_in(m: Material) -> Material:
	if m == null:
		return null
	var sm: ShaderMaterial = m as ShaderMaterial
	if sm != null and sm.shader == QUICK_SHADER:
		return m
	var hit: Variant = _quick.get(m.get_instance_id())
	if hit is Material:
		return hit
	return null


func _process(delta: float) -> void:
	if not _late.is_empty():
		for k: int in range(_late.size() - 1, -1, -1):
			if _give_back(_late[k]):
				_late.remove_at(k)
	if _ramp_t >= 1.0:
		return
	_ramp_t = minf(1.0, _ramp_t + delta / RAMP_SECONDS)
	_apply_ramp()


func _apply_ramp() -> void:
	_ramp_k = lerpf(RAMP_FROM, 1.0, smoothstep(0.0, 1.0, _ramp_t))
	_apply_light()

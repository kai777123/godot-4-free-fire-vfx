class_name PyroluxDemoWarmup
extends Node
## Draws every PYROLUX shader once, tiny, right in front of the camera, and throws each piece
## away a few frames later. Demo only.
##
## Without this, the first effect in a browser build stalls for a second or two while the
## driver compiles the shader it has just been asked for. In a browser the first visit compiles
## a WebGL program per shader version (about a second each), and doing it all in one frame froze
## the page for 25 to 40 seconds (measured 2026-10-26: 41 s headless on NOXALUX). So (kit v5):
##
##  - In a browser it is ONE JOB PER FRAME (START_DELAY frames after the start, so the start card
##    is drawn first), with `progress(done, total)` for the card ("Loading effects N / M") and
##    `finished`. When the card is closed the runner sets `gap_frames = 8` so the demo the
##    visitor is watching does not stutter. Anywhere else (the desktop, captures, tests) it is
##    the old single batch in the first frame, so nothing about a capture changes.
##  - The jobs the FIRST slot needs come first (`lead_*`), and the runner builds slot 0 as soon as
##    they are done (not in _ready), so the first effect is on screen within seconds.
##  - With a `stage` (the kit's DemoStage in lite_start mode: unshaded, no shadows, one light) the
##    warm-up then brings the stage back in steps, one thing per frame: a small shadow-casting
##    light, each real material drawn once in front of it (their shadow and lit versions), the
##    sun's shadow, and lite_finish() (the light ramps up, the fires catch). godot-vfx-pack 2b-1b.
##    Kit 13: a stage with `warm_rig(mask)` (the studio) hands over lights of its own kinds (a
##    shadowed spot, a spot, an omni) for the pieces instead of the small directional light, and
##    `lite_post()` (SSR and SSAO) runs one frame after lite_finish(). In a browser the moment
##    slot 0's jobs are drawn is written to `window.__fxLead` (for measure scripts).
##    Kit 13 (11/01, dissolve's first visit frame by frame): one job per frame draws its pieces on
##    HIDE_LAYER, which the demo's camera does not see: a small SubViewport in the same world, its
##    camera kept on the demo camera, draws them. A shader that fills the screen (a fog, a flash)
##    or a preset that ignored the 1/400 scale had flashed over the demo once the clip was gone
##    (a beige frame, a green ball). With `stage.lite_ghosts()` the stage comes back after slot 0
##    is up: its lights first (unshaded stand-ins do not change), then a hidden copy of one mesh
##    per real shader drawn where the mesh stands (under the real lights and shadow, so exactly
##    the versions the stage will draw), then lite_finish() swaps every real material at once.
##
##   var w := PyroluxDemoWarmup.new()
##   w.camera = stage.camera          # leave null for a 2D-only scene
##   w.stage = stage                  # optional, see above
##   w.lead_calls = [func(holder: Node3D) -> void: ...]   # what slot 0 will build first
##   add_child(w)
##
## Two passes, because they catch different things: every shader file of the addon gets one
## quad (so a shader added later can never be missed), and one preset per node script is
## built for real (so the meshes, the layer counts and the uniform sets are the ones the demo
## will use). Both lists are read from the addon folder, never written down: the Lite pack
## ships fewer shaders and presets, and this same file then warms exactly those.
##
## The presets are built at 1/400 of their size: a full-size effect 0.6 m in front of the
## lens filled the first frames with a close-up (TERRALUX step 17: rock slabs in the store
## GIFs and the QA clips). A draw is a draw however few pixels it covers.
##
## Generated from WS/shared/demo_kit/demo_warmup.gd by tools/vfxpack/demo_kit_sync.py.

signal progress(done: int, total: int)
signal finished
## The jobs of `lead_*` are done AND drawn (their pieces are gone): what slot 0 uses is compiled.
signal lead_ready

const DEMO_KIT_VERSION: int = 15
const SHADER_DIR: String = "res://addons/pyrolux_fx/shaders/"
const P3: String = "res://addons/pyrolux_fx/presets/3d/"
const P2: String = "res://addons/pyrolux_fx/presets/2d/"
## Frames each throwaway piece stays on screen. Four is enough for one draw of it.
const FRAMES: int = 5
## Frames to wait before the first job, so the start card is drawn before anything compiles.
const START_DELAY: int = 2
## How small the 3D presets are drawn (TERRALUX step 17).
const PRESET_SCALE: float = 0.0025
## The render layer of the stage's material pieces and the small shadow light that only sees them.
const WARM_LAYER: int = 1 << 19
## Kit 13: the layer of the one-job-per-frame pieces; only the warm view sees it.
const HIDE_LAYER: int = 1 << 18
## Kit 13: no job for this long after the lead jobs (real time): the page switches, and slot 0
## plays once without a compile in the middle (dissolve: the next job froze it for 10 s right
## after the switch; each later job is a few seconds of compile, nothing to hide it behind).
const LEAD_PAUSE_MS: int = 6000

var camera: Camera3D
## The kit's DemoStage in lite_start mode (any node with is_lite / warm_materials /
## lite_shadow_on / lite_finish). Leave null for a scene without one.
var stage: Node
## Leave off for a scene without 2D nodes (a Lite pack that ships none).
var do_2d: bool = true
## Preset names (no folder, no .tscn) to build in addition to the automatic one-per-script
## pick: a preset whose look takes a shader branch no other preset of its script does.
var extra_3d: Array[String] = []
var extra_2d: Array[String] = []
## What the first slot uses, built before everything else. Preset names, shader file names
## (relative to the addon's shaders/), and calls `func(holder: Node3D)` for what a preset
## alone does not draw (a status applied to a mesh, a bolt that flies).
var lead_presets_3d: Array[String] = []
var lead_presets_2d: Array[String] = []
var lead_shaders: Array[String] = []
var lead_calls: Array[Callable] = []
## True: one job per frame (a browser). False: everything in the first frame (old behaviour).
## `--webwarm` turns it on for a desktop test, `--nowarm` skips the warm-up.
var incremental: bool = OS.has_feature("web") or OS.get_cmdline_user_args().has("--webwarm")
## Frames to skip between jobs. 0 while the start card is up (nothing to watch, so go fast);
## the runner raises it once the card closes, so the effect being watched is not choppy.
var gap_frames: int = 0

## Each entry: [Callable, wait] - `wait` jobs run only when every piece before them is gone.
var _jobs: Array = []
var _lead: int = 0
var _done: int = 0
var _frame: int = 0
var _last_job: int = -1000
var _lead_sent: bool = false
## [node, frame it was made]
var _live: Array = []
var _holder3: Node3D
var _small: Node3D
var _layer: CanvasLayer
var _root2: Node2D
var _warm_sun: DirectionalLight3D
var _warm_rig: Array[Light3D] = []
## Kit 13: the hidden view (one job per frame only) and the ghosts' parent.
var _view: SubViewport
var _view_cam: Camera3D
var _ghosts: Node3D
## Kit 13: in a browser, frames over 0.25 s go to window.__fxSlow with the job before them.
var _web_log: bool = OS.has_feature("web")
var _last_label: String = ""
var _last_ms: int = 0
var _pause_until_ms: int = 0
## Kit 13: bring the stage back by giving the real materials back on its own meshes
## (stage.lite_restore_steps), not by drawing quads in front of a warm light. False: the v12 way
## (with the stage's warm_rig when it has one).
var stage_swap_real: bool = true
var _stage_mats: Array[Material] = []


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--nowarm"):
		if stage != null and stage.has_method(&"lite_finish"):
			stage.call(&"lite_finish")
		finished.emit()
		queue_free()
		return
	if camera != null:
		_holder3 = Node3D.new()
		_holder3.name = "Warmup3D"
		# Parented to the camera, so it stays in view however the camera moves.
		_holder3.position = Vector3(0.0, 0.0, -0.6)
		camera.add_child(_holder3)
		if incremental:
			_make_view()
		_small = Node3D.new()
		_small.name = "Presets"
		_small.scale = Vector3.ONE * PRESET_SCALE
		_holder3.add_child(_small)
	if do_2d:
		_layer = CanvasLayer.new()
		_layer.name = "Warmup2D"
		_layer.layer = -20
		add_child(_layer)
		_root2 = Node2D.new()
		_root2.position = Vector2(2.0, 2.0)
		_root2.scale = Vector2(0.01, 0.01)
		_layer.add_child(_root2)
	_queue()


## Jobs the first slot needs; the runner builds slot 0 once this many are done.
func lead_total() -> int:
	return _lead


func total() -> int:
	return _jobs.size()


func is_done() -> bool:
	return _done >= _jobs.size()


func _process(_delta: float) -> void:
	_frame += 1
	if _web_log:
		# A frame that took long (a shader compiled in it): which job came before it. The real
		# clock, not the delta (the engine caps the process delta).
		var now_ms: int = Time.get_ticks_msec()
		if _last_ms > 0 and now_ms - _last_ms > 250:
			JavaScriptBridge.eval("(window.__fxSlow = window.__fxSlow || []).push([performance.now() | 0, %d, %s])" % [now_ms - _last_ms, JSON.stringify(_last_label)])
		_last_ms = now_ms
	if _view != null:
		_follow()
		for e: Array in _live:
			var pn: Node = e[0]
			if is_instance_valid(pn) and pn is Node3D:
				_hide(pn)
	while not _live.is_empty():
		var entry: Array = _live[0]
		var born: int = entry[1]
		if _frame - born < FRAMES:
			break
		var old_node: Node = entry[0]
		if is_instance_valid(old_node):
			old_node.queue_free()
		_live.pop_front()
	if incremental and _frame <= START_DELAY:
		return
	if not _lead_sent and _done >= _lead and _live.is_empty():
		_lead_sent = true
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.__fxLead = performance.now() | 0")
		# Kit 13: no job for LEAD_PAUSE_MS (see there); only in a browser-style warm-up.
		if incremental:
			_pause_until_ms = Time.get_ticks_msec() + LEAD_PAUSE_MS
		lead_ready.emit()
	if _done >= _lead and not _lead_sent:
		# Nothing after the lead jobs starts before slot 0 has been built on what they compiled.
		return
	if _done < _jobs.size():
		if incremental and _frame - _last_job <= gap_frames:
			return
		if incremental and Time.get_ticks_msec() < _pause_until_ms:
			return
		_last_job = _frame
		while _done < _jobs.size():
			var job: Array = _jobs[_done]
			var wait: bool = job[1]
			if wait and not _live.is_empty():
				return
			var fn: Callable = job[0]
			if _web_log:
				_last_label = "%d %s %s" % [_done, fn.get_method(), str(fn.get_bound_arguments()).right(60)]
			fn.call()
			if _view != null and not _live.is_empty():
				var last: Node = _live[_live.size() - 1][0]
				if is_instance_valid(last):
					_hide(last)
			_done += 1
			progress.emit(_done, _jobs.size())
			if incremental:
				return
		return
	if _live.is_empty():
		if _holder3 != null:
			_holder3.queue_free()
		if _view != null:
			_view.queue_free()
			camera.cull_mask |= HIDE_LAYER
		if _ghosts != null:
			_ghosts.queue_free()
		if _layer != null:
			_layer.queue_free()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.__fxDone = performance.now() | 0")
		finished.emit()
		queue_free()


func _keep(n: Node) -> void:
	_live.append([n, _frame])


## Kit 13: the hidden view. Same world, a camera on the demo camera that sees only HIDE_LAYER
## (and the demo camera stops seeing it), drawn every frame into a small target nobody shows.
func _make_view() -> void:
	camera.cull_mask &= ~HIDE_LAYER
	_view = SubViewport.new()
	_view.name = "WarmView"
	_view.size = Vector2i(160, 90)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.transparent_bg = true
	add_child(_view)
	_view_cam = Camera3D.new()
	_view_cam.cull_mask = HIDE_LAYER
	_view.add_child(_view_cam)
	_view_cam.current = true
	_ghosts = Node3D.new()
	_ghosts.name = "WarmGhosts"
	camera.get_parent().add_child(_ghosts)
	_follow()


func _follow() -> void:
	if _view_cam == null or not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	_view_cam.global_transform = camera.global_transform
	_view_cam.fov = camera.fov
	_view_cam.near = camera.near
	_view_cam.far = camera.far
	_view_cam.environment = camera.environment


## Puts `n` and everything under it on HIDE_LAYER (re-run each frame for what effects add later).
func _hide(n: Node) -> void:
	var vi: VisualInstance3D = n as VisualInstance3D
	if vi != null:
		vi.layers = HIDE_LAYER
	# Internal children too: effects keep their layers there (CINELUX make_layer, INTERNAL_MODE_BACK).
	for c: Node in n.get_children(true):
		_hide(c)


func _piece3() -> Node3D:
	var h: Node3D = Node3D.new()
	_small.add_child(h)
	_keep(h)
	return h


func _piece2() -> Node2D:
	var h: Node2D = Node2D.new()
	_root2.add_child(h)
	_keep(h)
	return h


func _add(fn: Callable, wait: bool = false) -> void:
	_jobs.append([fn, wait])


# ------------------------------------------------------------------ the job list

func _queue() -> void:
	# Kit 13: with a kit 13 stage the lights come in first (the stand-ins are unshaded, so nothing
	# changes on screen), so slot 0's lit effects compile once, with the lights they will have
	# (dissolve: 8.9 s of compile when the lights came in after the switch).
	var ghosts: bool = _view != null and stage != null and camera != null and stage.has_method(&"lite_ghosts") 		and stage.has_method(&"is_lite") and stage.call(&"is_lite")
	if ghosts:
		_add(_stage_lights_in)
	# 1. what the first slot uses
	if camera != null:
		for f: String in lead_shaders:
			_add(_shader_3d.bind(SHADER_DIR + f))
		for n: String in lead_presets_3d:
			_add(_preset_3d.bind(n))
		for c: Callable in lead_calls:
			_add(_call_3d.bind(c))
	if do_2d:
		for n: String in lead_presets_2d:
			_add(_preset_2d.bind(n))
	if ghosts:
		# Kit 13: the stage comes back before slot 0 is shown (a hidden copy per real shader, then
		# the swap): about 5 s on dissolve, where the v12 way took 30 s; so the page's switch shows
		# the real stage and slot 0 is not frozen by the stage's compiles right after it.
		_queue_stage()
	_lead = _jobs.size()
	# 2. the stage, back to its real look (nothing for a stage that is not in lite mode)
	if not ghosts and stage != null and camera != null and stage.has_method(&"is_lite") and stage.call(&"is_lite"):
		_queue_stage()
	# 3. everything else
	if camera != null:
		for sh: Shader in shaders(Shader.MODE_SPATIAL):
			_add(_shader_3d_of.bind(sh))
		for n: String in pick_presets(P3, extra_3d):
			_add(_preset_3d.bind(n))
	if do_2d:
		for sh: Shader in shaders(Shader.MODE_CANVAS_ITEM):
			_add(_shader_2d_of.bind(sh))
		for n: String in pick_presets(P2, extra_2d):
			_add(_preset_2d.bind(n))


func _queue_stage() -> void:
	if _view != null and stage.has_method(&"lite_ghosts"):
		# Kit 13: (the lights came in first, see _queue) one hidden copy per real shader where its
		# mesh stands, then the swap of every real material at once.
		var gs: Array = stage.call(&"lite_ghosts")
		for g: Variant in gs:
			if g is Array:
				var pair: Array = g
				if pair.size() == 2 and pair[0] is MeshInstance3D and pair[1] is Material:
					var gm: MeshInstance3D = pair[0]
					var gmat: Material = pair[1]
					_add(_ghost.bind(gm, gmat))
		_add(_stage_finish, true)
		if stage.has_method(&"lite_post"):
			_add(_stage_post)
		return
	if stage_swap_real and stage.has_method(&"lite_restore_steps"):
		# Kit 13: the real materials back on the stage's own meshes, one shader per frame.
		var steps: Array = stage.call(&"lite_restore_steps")
		for c: Variant in steps:
			if c is Callable:
				var step: Callable = c
				_add(step)
		_add(_stage_shadow)
		_add(_stage_finish, true)
		if stage.has_method(&"lite_post"):
			_add(_stage_post)
		return
	_stage_mats = stage.call(&"warm_materials")
	_add(_warm_sun_on)
	for m: Material in _stage_mats:
		_add(_stage_piece.bind(m))
	_add(_warm_sun_off, true)
	_add(_stage_shadow)
	_add(_stage_finish, true)
	if stage.has_method(&"lite_post"):
		_add(_stage_post)


## A small light that casts a shadow and sees only the pieces below, so the shadow versions of
## the real materials compile one at a time here instead of all at once when the sun's shadow
## goes on.
func _warm_sun_on() -> void:
	if stage.has_method(&"warm_rig"):
		var rig: Array = stage.call(&"warm_rig", WARM_LAYER)
		if not rig.is_empty():
			for l: Variant in rig:
				if not (l is Light3D) or _holder3 == null:
					continue
				var light: Light3D = l
				if light != null:
					_holder3.add_child(light)
					_warm_rig.append(light)
			return
	_warm_sun = DirectionalLight3D.new()
	_warm_sun.name = "WarmSun"
	_warm_sun.shadow_enabled = false
	_warm_sun.light_energy = 0.01
	_warm_sun.light_cull_mask = WARM_LAYER
	_warm_sun.rotation_degrees = Vector3(-50.0, 20.0, 0.0)
	add_child(_warm_sun)


func _warm_sun_off() -> void:
	if is_instance_valid(_warm_sun):
		_warm_sun.queue_free()
	for l: Light3D in _warm_rig:
		if is_instance_valid(l):
			l.queue_free()
	_warm_rig.clear()


func _stage_piece(m: Material) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.004, 0.004)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = m
	mi.layers = WARM_LAYER
	_piece3().add_child(mi)


func _stage_shadow() -> void:
	stage.call(&"lite_shadow_on")


func _stage_finish() -> void:
	stage.call(&"lite_finish")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__fxStage = performance.now() | 0")


func _stage_post() -> void:
	stage.call(&"lite_post")


func _stage_lights_in() -> void:
	stage.call(&"lite_lights_in")


## A hidden copy of `real` with its real material, where it stands (the warm view only).
func _ghost(real: MeshInstance3D, m: Material) -> void:
	if not is_instance_valid(real) or not real.is_inside_tree():
		return
	var g: MeshInstance3D = MeshInstance3D.new()
	g.mesh = real.mesh
	g.material_override = m
	g.cast_shadow = real.cast_shadow
	_ghosts.add_child(g)
	g.global_transform = real.global_transform
	g.layers = HIDE_LAYER
	_keep(g)


# ------------------------------------------------------------------ 3D

func _shader_3d(path: String) -> void:
	var sh: Shader = load(path) as Shader
	if sh != null:
		_shader_3d_of(sh)


func _shader_3d_of(sh: Shader) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.004, 0.004)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = quad
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_piece3().add_child(mi)


func _preset_3d(preset_name: String) -> void:
	_build_preset(_piece3(), P3 + preset_name + ".tscn")


func _call_3d(c: Callable) -> void:
	c.call(_piece3())


# ------------------------------------------------------------------ 2D

func _shader_2d_of(sh: Shader) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mi: MeshInstance2D = MeshInstance2D.new()
	mi.mesh = quad
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	mi.material = m
	_piece2().add_child(mi)


func _preset_2d(preset_name: String) -> void:
	_build_preset(_piece2(), P2 + preset_name + ".tscn")


## Every .gdshader of the addon (sub-folders too) whose mode is `mode`: spatial ones go on
## a 3D quad, canvas_item ones on a 2D quad. By mode, not by file name: a "_2d" in the
## name was the rule in one pack and not in the next.
static func shaders(mode: Shader.Mode) -> Array[Shader]:
	var out: Array[Shader] = []
	for path: String in _files(SHADER_DIR, ".gdshader", true):
		var sh: Shader = load(path) as Shader
		if sh != null and sh.get_mode() == mode:
			out.append(sh)
	return out


## One preset per node script (the first by name), and a second one for a script when a
## preset turns pixel_mode on (its own shader branch), plus `extra`. Read from the scene
## state, so nothing is instanced to choose.
static func pick_presets(dir: String, extra: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for path: String in _files(dir, ".tscn", false):
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			continue
		var key: String = _script_key(scene)
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		out.append(path.get_file().get_basename())
	for n: String in extra:
		if not out.has(n):
			out.append(n)
	return out


static func _script_key(scene: PackedScene) -> String:
	var st: SceneState = scene.get_state()
	if st.get_node_count() == 0:
		return ""
	var script_path: String = ""
	var pixel: bool = false
	for i: int in st.get_node_property_count(0):
		var pname: StringName = st.get_node_property_name(0, i)
		if pname == &"script":
			var v: Variant = st.get_node_property_value(0, i)
			if v is Script:
				var s: Script = v
				script_path = s.resource_path
		elif pname == &"pixel_mode":
			pixel = st.get_node_property_value(0, i) == true
	if script_path == "":
		return ""
	return script_path + ("|pixel" if pixel else "")


## Sorted res:// paths under `dir` ending in `ext`. ResourceLoader.list_directory (4.4+)
## sees the files of an exported build, where a scene is stored as "x.tscn.remap"; the
## DirAccess fallback strips that suffix itself.
static func _files(dir: String, ext: String, recurse: bool) -> Array[String]:
	var out: Array[String] = []
	var names: PackedStringArray = PackedStringArray()
	if ResourceLoader.has_method(&"list_directory"):
		names = ResourceLoader.call(&"list_directory", dir)
	else:
		for f: String in DirAccess.get_files_at(dir):
			names.append(f.trim_suffix(".remap"))
		for d: String in DirAccess.get_directories_at(dir):
			names.append(d + "/")
	for f: String in names:
		if f.ends_with("/"):
			if recurse:
				out.append_array(_files(dir + f, ext, true))
			continue
		if f.ends_with(ext):
			out.append(dir + f)
	out.sort()
	return out


## Builds one preset at once (fade_time 0) and fires it. The copy is freed with its piece, so
## nothing a warm-up started is still running when the first slot begins.
func _build_preset(parent: Node, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return
	var node: Node = scene.instantiate()
	if &"fade_time" in node:
		node.set(&"fade_time", 0.0)
	parent.add_child(node)
	if node.has_method(&"trigger"):
		node.call(&"trigger")

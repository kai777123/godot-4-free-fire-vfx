extends RefCounted
## PYROLUX's own things for the studio stage (shared demo kit 13, LOOK_STUDIO): the props a fire
## pack needs that the kit does not have (a campfire's logs and stones, a table with candles, a
## chimney, a rocket ...), built with the kit's Builder and drawn with the kit's one prop shader,
## and the kit's crate and barrel merged into ONE MeshInstance3D each, so a PyroluxBurn3D can sit
## on them (Burn3D burns one mesh: the kit's crate is two, the planks and the frame).
## Every mesh is registered with the stage (adopt), so the web first visit draws it with the
## stage's unshaded stand-in until the real look is back.
## Only used by the demo scenes; nothing here depends on the addon's classes (the Lite demo uses it).

const PROPS := preload("res://demo/shared/demo_props.gd")

static var _merged: Dictionary = {}
static var _meshes: Dictionary = {}


## The kit's crate (planks inside a frame of battens) as one mesh standing on `at`.
static func crate(stage: PyroluxDemoStage, at: Vector3, size: float = 0.8, parent: Node3D = null,
		yaw: float = 0.0) -> MeshInstance3D:
	var key: String = "crate_%.3f" % size
	var m: ArrayMesh = _merged.get(key)
	if m == null:
		var tmp: Node3D = Node3D.new()
		PROPS.crate(tmp, Vector3.ZERO, size)
		m = _merge(tmp)
		_merged[key] = m
	return _place(stage, m, at, yaw, parent, "Crate")


## The kit's barrel (staves and iron hoops) as one mesh standing on `at`.
static func barrel(stage: PyroluxDemoStage, at: Vector3, parent: Node3D = null, radius: float = 0.34,
		height: float = 0.95, yaw: float = 0.0) -> MeshInstance3D:
	var key: String = "barrel_%.3f_%.3f" % [radius, height]
	var m: ArrayMesh = _merged.get(key)
	if m == null:
		var tmp: Node3D = Node3D.new()
		PROPS.barrel(tmp, Vector3.ZERO, radius, height)
		m = _merge(tmp)
		_merged[key] = m
	return _place(stage, m, at, yaw, parent, "Barrel")


## One ArrayMesh with a surface (and that surface's material) per mesh anywhere under `root`, in
## `root`'s space (the kit's props hang their meshes under a root node); frees `root`.
static func _merge(root: Node3D) -> ArrayMesh:
	var out: ArrayMesh = ArrayMesh.new()
	_merge_into(out, root, Transform3D.IDENTITY)
	root.free()
	return out


static func _merge_into(out: ArrayMesh, node: Node, xf: Transform3D) -> void:
	for c: Node in node.get_children():
		var n3: Node3D = c as Node3D
		if n3 == null:
			continue
		var cxf: Transform3D = xf * n3.transform
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null and mi.mesh != null:
			for s: int in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				for i: int in v.size():
					v[i] = cxf * v[i]
				arr[Mesh.ARRAY_VERTEX] = v
				if arr[Mesh.ARRAY_NORMAL] != null:
					var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
					for i: int in nr.size():
						nr[i] = (cxf.basis * nr[i]).normalized()
					arr[Mesh.ARRAY_NORMAL] = nr
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				out.surface_set_material(out.get_surface_count() - 1, mi.material_override)
		_merge_into(out, c, cxf)


static func _place(stage: PyroluxDemoStage, m: Mesh, at: Vector3, yaw: float, parent: Node3D,
		label: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = label
	mi.mesh = m
	mi.position = at
	mi.rotation.y = yaw
	(parent if parent != null else stage.props).add_child(mi)
	stage.adopt(mi)
	return mi


## A mesh of the kit's prop shader under `parent` (default the stage's props), registered.
static func _put(stage: PyroluxDemoStage, m: Mesh, mat: Material, at: Vector3, parent: Node3D = null,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return stage.add_mesh(m, at, mat, rot_deg, parent)


static func _cached(key: String, build: Callable) -> ArrayMesh:
	var hit: ArrayMesh = _meshes.get(key)
	if hit == null:
		var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
		build.call(b)
		hit = b.mesh()
		_meshes[key] = hit
	return hit


static var _stone: ShaderMaterial


## The kit's rock colour with half its mottle: Compatibility (the web demo) takes the mottle's
## colours as sRGB and draws it about twice as strong (memory compat-color-space-findings), and the
## kit's 0.22 turned the campfire stones blotchy there.
static func _stone_mat() -> ShaderMaterial:
	if _stone == null:
		_stone = PROPS.material(Color(0.35, 0.33, 0.3), 1.12, 0.1, 0.0)
	return _stone


## A smooth river stone (the kit's blob rock) of about `s` metres.
static func stone(stage: PyroluxDemoStage, at: Vector3, s: float, seed_value: int, parent: Node3D = null) -> MeshInstance3D:
	var mi: MeshInstance3D = PROPS.rock(parent if parent != null else stage.props, at,
		Vector3(s, s * 0.62, s * 0.86), float(seed_value) * 1.7, seed_value, _stone_mat(), true)
	# No shadow of their own: the desktop Compatibility renderer drew dark stripes (shadow acne from
	# the studio key) over the small faceted stones.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.adopt(mi)
	return mi


## A campfire's bed: five split logs leaning in to the middle and a ring of nine stones.
static func campfire_base(stage: PyroluxDemoStage, at: Vector3, parent: Node3D = null) -> void:
	var logs: ArrayMesh = _cached("logs", func(b: PyroluxDemoProps.Builder) -> void:
		for i: int in 5:
			var a: float = TAU * float(i) / 5.0 + 0.3
			var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
			b.tube(d * 0.52 + Vector3(0, 0.07, 0), d * 0.06 + Vector3(0, 0.3, 0), 0.075, 0.06, 12, true, true))
	_put(stage, logs, PROPS.kit_material(&"bark"), at, parent)
	var char_core: ArrayMesh = _cached("logs_char", func(b: PyroluxDemoProps.Builder) -> void:
		b.ellipsoid(Vector3(0, 0.04, 0), Vector3(0.3, 0.06, 0.3), 14, 6))
	_put(stage, char_core, PROPS.kit_material(&"char"), at, parent)
	for i: int in 9:
		var a: float = TAU * float(i) / 9.0
		stone(stage, at + Vector3(cos(a) * 0.68, 0.0, sin(a) * 0.68), 0.3 + 0.05 * float(i % 3), 11 + i, parent)


## A small wooden table (top and four legs), `w` x `d`, `h` high, centred on `at`.
static func table(stage: PyroluxDemoStage, at: Vector3, w: float = 1.6, d: float = 0.7, h: float = 0.8,
		parent: Node3D = null) -> MeshInstance3D:
	var m: ArrayMesh = _cached("table_%.2f_%.2f_%.2f" % [w, d, h], func(b: PyroluxDemoProps.Builder) -> void:
		b.cbox(Vector3(-w * 0.5, h - 0.06, -d * 0.5), Vector3(w * 0.5, h, d * 0.5), 0.015)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var c: Vector3 = Vector3(sx * (w * 0.5 - 0.09), 0.0, sz * (d * 0.5 - 0.08))
				b.cbox(c - Vector3(0.035, 0.0, 0.035), c + Vector3(0.035, h - 0.06, 0.035), 0.008))
	return _put(stage, m, PROPS.kit_material(&"wood"), at, parent)


## A wax candle `h` tall standing on `at`; returns the wick's top (where the flame goes).
static func candle(stage: PyroluxDemoStage, at: Vector3, h: float, parent: Node3D = null) -> Vector3:
	var m: ArrayMesh = _cached("candle_%.2f" % h, func(b: PyroluxDemoProps.Builder) -> void:
		var prof: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.036, 0.0),
			Vector2(0.036, h - 0.012), Vector2(0.03, h), Vector2(0.0, h - 0.006)])
		b.lathe(prof, 16))
	_put(stage, m, stage.mat(Color(0.86, 0.8, 0.68), 0.6), at, parent)
	return at + Vector3(0.0, h + 0.01, 0.0)


## A brick-grey chimney stack `h` tall on `at` with a cap; returns its top.
static func chimney(stage: PyroluxDemoStage, at: Vector3, h: float = 3.2, parent: Node3D = null) -> Vector3:
	var m: ArrayMesh = _cached("chimney_%.2f" % h, func(b: PyroluxDemoProps.Builder) -> void:
		b.cbox(Vector3(-0.32, 0.0, -0.32), Vector3(0.32, h - 0.14, 0.32), 0.02)
		b.cbox(Vector3(-0.38, h - 0.14, -0.38), Vector3(0.38, h, 0.38), 0.02))
	_put(stage, m, PROPS.kit_material(&"terracotta"), at, parent)
	return at + Vector3(0.0, h, 0.0)


## An iron stand: a round foot, a post `h` tall and a small cup at its top; returns the top.
static func stand(stage: PyroluxDemoStage, at: Vector3, h: float, cup: float = 0.12, parent: Node3D = null) -> Vector3:
	var m: ArrayMesh = _cached("stand_%.2f_%.2f" % [h, cup], func(b: PyroluxDemoProps.Builder) -> void:
		b.metal = 1.0
		b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.22, 0.05),
			Vector2(0.06, 0.08), Vector2(0.045, 0.1), Vector2(0.045, h - 0.06), Vector2(cup, h - 0.02),
			Vector2(cup, h), Vector2(0.0, h)]), 20))
	_put(stage, m, PROPS.metal_material(Color(0.3, 0.3, 0.32)), at, parent)
	return at + Vector3(0.0, h, 0.0)


## A steel plate standing upright (a workshop wall) from `a` to `b` on the floor, `h` tall.
static func plate(stage: PyroluxDemoStage, centre: Vector3, w: float, h: float, parent: Node3D = null) -> MeshInstance3D:
	var m: ArrayMesh = _cached("plate_%.2f_%.2f" % [w, h], func(b: PyroluxDemoProps.Builder) -> void:
		b.metal = 1.0
		b.cbox(Vector3(-w * 0.5, 0.0, -0.06), Vector3(w * 0.5, h, 0.06), 0.02)
		for x: float in [-w * 0.25, w * 0.25]:
			b.cbox(Vector3(x - 0.05, 0.0, 0.06), Vector3(x + 0.05, h, 0.1), 0.01))
	# Dark and matt: a bright steel sheet under the studio key read as a lit billboard.
	return _put(stage, m, stage.mat(Color(0.1, 0.1, 0.11), 0.7, 0.3), centre, parent)


## A round steel bar from `a` to `b` (a workpiece, a pipe).
static func bar(stage: PyroluxDemoStage, a: Vector3, b: Vector3, r: float, parent: Node3D = null) -> MeshInstance3D:
	var len: float = (b - a).length()
	var m: ArrayMesh = _cached("bar_%.3f_%.3f" % [len, r], func(bl: PyroluxDemoProps.Builder) -> void:
		bl.metal = 1.0
		bl.tube(Vector3.ZERO, Vector3(0, 0, len), r, r, 16, true, true))
	var mi: MeshInstance3D = _put(stage, m, stage.mat(Color(0.2, 0.2, 0.21), 0.5, 0.6), a, parent)
	var dn: Vector3 = (b - a) / maxf(len, 0.0001)
	mi.basis = Basis.looking_at(-dn, Vector3.UP if absf(dn.y) < 0.99 else Vector3.RIGHT)
	return mi


## A grinder's cutting disc, `r` in radius, facing +x, centred on `at`.
static func disc(stage: PyroluxDemoStage, at: Vector3, r: float, parent: Node3D = null) -> MeshInstance3D:
	var m: ArrayMesh = _cached("disc_%.3f" % r, func(b: PyroluxDemoProps.Builder) -> void:
		b.metal = 1.0
		b.tube(Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0), r, r, 28, true, true)
		b.tube(Vector3(-0.05, 0, 0), Vector3(-0.012, 0, 0), r * 0.25, r * 0.25, 14, true, true))
	return _put(stage, m, PROPS.metal_material(Color(0.5, 0.5, 0.54), 0.3, 0.8), at, parent)


## A flamethrower's nozzle (a steel tube with a wider muzzle and a tank strap) along -z of
## `parent` (the jet node), so it turns with the jet.
static func nozzle(stage: PyroluxDemoStage, parent: Node3D) -> MeshInstance3D:
	var m: ArrayMesh = _cached("nozzle", func(b: PyroluxDemoProps.Builder) -> void:
		b.metal = 1.0
		b.tube(Vector3(0, 0, 0.75), Vector3(0, 0, 0.1), 0.045, 0.045, 14, true, false)
		b.tube(Vector3(0, 0, 0.1), Vector3(0, 0, 0.0), 0.045, 0.07, 14, false, true)
		b.tube(Vector3(0, -0.02, 0.62), Vector3(0, -0.2, 0.7), 0.03, 0.03, 10, true, true))
	return _put(stage, m, PROPS.metal_material(Color(0.24, 0.24, 0.26)), Vector3.ZERO, parent)


## A rocket (white body, nose cone and four fins) standing with its nozzle at `at`, `h` tall.
static func rocket(stage: PyroluxDemoStage, at: Vector3, h: float = 3.0, parent: Node3D = null) -> void:
	var r: float = h * 0.13
	var body: ArrayMesh = _cached("rocket_%.2f" % h, func(b: PyroluxDemoProps.Builder) -> void:
		var prof: PackedVector2Array = PackedVector2Array()
		prof.append(Vector2(0.0, 0.08))
		prof.append(Vector2(r * 0.7, 0.08))
		prof.append(Vector2(r, 0.22))
		prof.append(Vector2(r, h * 0.62))
		for i: int in range(1, 9):
			var t: float = float(i) / 8.0
			prof.append(Vector2(r * cos(t * PI * 0.5), h * 0.62 + (h * 0.38) * sin(t * PI * 0.5)))
		b.lathe(prof, 28, Vector3.ZERO, 50.0)
		for k: int in 4:
			var a: float = TAU * float(k) / 4.0 + PI * 0.25
			var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var s: Vector3 = Vector3(-d.z, 0.0, d.x) * 0.015
			var p0: Vector3 = d * r * 0.95 + Vector3(0, 0.15, 0)
			var p1: Vector3 = d * r * 1.9 + Vector3(0, 0.05, 0)
			var p2: Vector3 = d * r * 0.95 + Vector3(0, h * 0.3, 0)
			b.tri(p0 + s, p1 + s, p2 + s, Vector2.ZERO, Vector2.ONE, Vector2(0, 1))
			b.tri(p0 - s, p2 - s, p1 - s, Vector2.ZERO, Vector2(0, 1), Vector2.ONE))
	_put(stage, body, stage.mat(Color(0.8, 0.8, 0.82), 0.35), at, parent)
	var bell: ArrayMesh = _cached("rocket_bell_%.2f" % h, func(b: PyroluxDemoProps.Builder) -> void:
		b.metal = 1.0
		b.lathe(PackedVector2Array([Vector2(r * 0.42, 0.1), Vector2(r * 0.3, 0.05), Vector2(r * 0.6, -0.12),
			Vector2(r * 0.55, -0.12), Vector2(r * 0.26, 0.04), Vector2(r * 0.36, 0.1)]), 22))
	_put(stage, bell, PROPS.metal_material(Color(0.22, 0.2, 0.19)), at, parent)


## A small wooden shed: plank walls with a dark doorway (the "Walls" mesh) and a gabled plank
## roof as its own mesh ("Roof", the one to set on fire). Returns the roof.
static func shed(stage: PyroluxDemoStage, at: Vector3, yaw: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
	var root: Node3D = Node3D.new()
	root.name = "Shed"
	root.position = at
	root.rotation.y = yaw
	(parent if parent != null else stage.props).add_child(root)
	var w: float = 2.8
	var d: float = 2.2
	var h: float = 1.9
	var walls: ArrayMesh = _cached("shed_walls", func(b: PyroluxDemoProps.Builder) -> void:
		b.box(Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(w * 0.5, h, d * 0.5), 1.0)
		# The gables: a triangle on the front and the back up to the ridge, facing out.
		for zs: float in [-1.0, 1.0]:
			var z: float = zs * d * 0.5
			var l: Vector3 = Vector3(-w * 0.5, h, z)
			var r: Vector3 = Vector3(w * 0.5, h, z)
			var top: Vector3 = Vector3(0.0, h + 0.95, z)
			if (r - l).cross(top - l).z * zs > 0.0:
				b.tri(l, r, top, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.4))
			else:
				b.tri(l, top, r, Vector2(0, 0), Vector2(0.5, 0.4), Vector2(1, 0))
		for cx: float in [-w * 0.5, w * 0.5]:
			b.cbox(Vector3(cx - 0.07, 0.0, -d * 0.5 - 0.04), Vector3(cx + 0.07, h, -d * 0.5 + 0.1), 0.01)
			b.cbox(Vector3(cx - 0.07, 0.0, d * 0.5 - 0.1), Vector3(cx + 0.07, h, d * 0.5 + 0.04), 0.01))
	var wm: MeshInstance3D = _put(stage, walls, PROPS.kit_material(&"wood_planks"), Vector3.ZERO, root)
	wm.name = "Walls"
	var door: ArrayMesh = _cached("shed_door", func(b: PyroluxDemoProps.Builder) -> void:
		b.box(Vector3(-0.36, 0.0, d * 0.5), Vector3(0.36, 1.35, d * 0.5 + 0.02), 1.0))
	_put(stage, door, PROPS.kit_material(&"char"), Vector3.ZERO, root)
	var roof: ArrayMesh = _cached("shed_roof", func(b: PyroluxDemoProps.Builder) -> void:
		var o: float = 0.22
		var ridge: float = h + 0.95
		for sx: float in [-1.0, 1.0]:
			# One slab per side, 7 cm thick, from the eave (o past the wall) to the ridge.
			var eave: Vector3 = Vector3(sx * (w * 0.5 + o), h - o * 0.68, 0.0)
			var top: Vector3 = Vector3(0.0, ridge + 0.04, 0.0)
			var up: Vector3 = Vector3(sx * 0.95, w * 0.5 + o, 0.0).normalized() * 0.07
			var z0: float = -d * 0.5 - o
			var z1: float = d * 0.5 + o
			var c: Array[Vector3] = [eave + Vector3(0, 0, z0), top + Vector3(0, 0, z0), top + Vector3(0, 0, z1),
				eave + Vector3(0, 0, z1)]
			var cu: Array[Vector3] = [c[0] + up, c[1] + up, c[2] + up, c[3] + up]
			var mid: Vector3 = (c[0] + c[2]) * 0.5 + up * 0.5
			b.quad_o(cu[0], cu[1], cu[2], cu[3], mid)
			b.quad_o(c[0], c[1], c[2], c[3], mid)
			b.quad_o(c[0], c[3], cu[3], cu[0], mid)
			b.quad_o(c[0], c[1], cu[1], cu[0], mid)
			b.quad_o(c[3], c[2], cu[2], cu[3], mid))
	var rm: MeshInstance3D = _put(stage, roof, PROPS.kit_material(&"wood_dark"), Vector3.ZERO, root)
	rm.name = "Roof"
	return rm

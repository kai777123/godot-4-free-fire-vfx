class_name PyroluxDemoFigure
extends RefCounted
## Demo only: the people of a demo stage, built in code (no imported mesh, no texture). Each is
## one MeshInstance3D with one surface, so an effect can take the whole figure as its target
## (GLYPHLUX's rune shell, UNDALUX's wet shell):
##   knight()     a stone statue of a knight in plate armour resting on his sword (GLYPHLUX's
##                hero target), on its own plinth (a child mesh) or standing on the floor
##   mannequin()  a white, faceless mannequin (kit 4: one smooth body with seam lines at the
##                joints): a body to put an effect on without a real person's face (the
##                stand-in for a buyer's own character)
##   walker()     kit 6: the same mannequin with bones and a DemoGait (demo_gait.gd) that walks,
##                stops, staggers and freezes it in code; its feet stay put on the floor
##   caster()     a hooded caster planting a staff and reaching out with the other hand: where a
##                spell comes from (meta "tip" = just past the staff's stone)
##   soldier()    a soldier on guard behind a round shield with a spear: what an arrow or a
##                bullet hits (meta "aim" = head, chest and shield points)
## All stand on `at` (the feet on the floor, or on the plinth) facing +Z turned by `yaw`, or
## toward `aim`. Human proportions throughout: the head 1/7.3 of the height, the crotch at 47 %,
## a ball in every joint of the painted figures so a bent limb never opens a crack. Meshes are cached and shared.
##
##   var fig: MeshInstance3D = PyroluxDemoFigure.mannequin(props, Vector3(1.2, 0.0, -0.5))
##   var who: Node3D = PyroluxDemoFigure.caster(props, Vector3(-1.5, 0, 0.4), Vector3.ZERO)
##   var tip: Vector3 = who.get_meta(&"tip")
##
## Generated from WS/shared/demo_kit/demo_figure.gd by tools/vfxpack/demo_kit_sync.py.

const DEMO_KIT_VERSION: int = 15
const SAND_SHADER: Shader = preload("res://demo/shared/demo_sandstone.gdshader")
const HEAD_SHARE: float = 1.0 / 7.3
const CROTCH_SHARE: float = 0.47
## The knight's plinth: its top, where his feet stand (GLYPHLUX: 0.2 m).
const PLINTH_TOP: float = 0.2

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}


# ---------------------------------------------------------------- materials

## The knight's weathered sandstone (demo_sandstone.gdshader; the vertex colour darkens the
## recesses).
static func sandstone_material(base: Color = Color(0.34, 0.31, 0.26)) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SAND_SHADER
	m.set_shader_parameter("base_col", base)
	return m


## The mannequin's white: between porcelain and brushed metal (roughness 0.35, specular 0.5,
## a pale blue-white fresnel rim), a little under pure white so the sun does not burn it out.
static func white_material() -> ShaderMaterial:
	if _mats.has(&"white"):
		var hit: ShaderMaterial = _mats[&"white"]
		return hit
	var m: ShaderMaterial = PyroluxDemoProps.flat_material(Color(0.76, 0.78, 0.81), 0.35, 0.0, 0.02)
	m.set_shader_parameter("specular", 0.5)
	m.set_shader_parameter("rim_color", Color(0.62, 0.72, 0.88))
	m.set_shader_parameter("rim_amount", 0.22)
	_mats[&"white"] = m
	return m


## The painted figures (caster, soldier): white in the material, the colours in the vertices.
static func paint_material() -> ShaderMaterial:
	if _mats.has(&"paint"):
		var hit: ShaderMaterial = _mats[&"paint"]
		return hit
	var m: ShaderMaterial = PyroluxDemoProps.flat_material(Color(1.0, 1.0, 1.0), 0.86, 0.0, 0.04)
	m.set_shader_parameter("metal_amount", 0.55)
	m.set_shader_parameter("metal_roughness", 0.42)
	_mats[&"paint"] = m
	return m


# ---------------------------------------------------------------- the rig

## The joints of a person `height` tall standing with the feet on y = `base`, facing +Z.
## Index 0 of the pairs is the side at -X, index 1 the side at +X.
class Rig:
	var height: float = 1.8
	var base: float = 0.0
	## How far the hips are lowered (a crouch, a guard stance).
	var drop: float = 0.0
	var head_size: float = 0.25
	var head: Vector3 = Vector3.ZERO
	var neck: Vector3 = Vector3.ZERO
	var upper_arm: float = 0.3
	var forearm: float = 0.25
	var thigh: float = 0.4
	var shin: float = 0.4
	var shoulder: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var elbow: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var wrist: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var hip: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var knee: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var ankle: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	## Which way each foot points (on the floor plane).
	var toe_dir: Array[Vector3] = [Vector3.BACK, Vector3.BACK]

	func _init(h: float, floor_y: float = 0.0, lower: float = 0.0) -> void:
		height = h
		base = floor_y
		drop = lower
		head_size = h / 7.3
		upper_arm = h * 0.172
		forearm = h * 0.142
		thigh = h * 0.226
		shin = h * 0.229
		head = Vector3(0.0, y(1.0) - head_size * 0.5, 0.0)
		neck = Vector3(0.0, y(0.82), -0.004 * h)
		for i: int in 2:
			var sx: float = -1.0 if i == 0 else 1.0
			shoulder[i] = Vector3(sx * 0.1 * h, y(0.808), -0.005 * h)
			hip[i] = Vector3(sx * 0.053 * h, y(0.5), 0.0)
		legs([Vector3(-0.06 * h, base + 0.045 * h, 0.0), Vector3(0.06 * h, base + 0.045 * h, 0.0)])
		arms([Vector3(-0.135 * h, y(0.5), 0.03 * h), Vector3(0.135 * h, y(0.5), 0.03 * h)],
			[Vector3(-0.4, 0.0, -1.0), Vector3(0.4, 0.0, -1.0)])

	## A height on the body (a share of the standing height), lowered by the crouch.
	func y(share: float) -> float:
		return base + share * height - drop * clampf(share / 0.5, 0.0, 1.0) if share < 0.5 else base + share * height - drop

	## Places the ankles; the knees bend forward to reach them.
	func legs(ankles: Array[Vector3]) -> void:
		for i: int in 2:
			var r: Array[Vector3] = PyroluxDemoFigure.reach(hip[i], ankles[i], thigh, shin, Vector3(0.0, 0.0, 1.0))
			knee[i] = r[0]
			ankle[i] = r[1]

	## Places the wrists; each elbow bends toward its pole direction.
	func arms(wrists: Array[Vector3], poles: Array[Vector3]) -> void:
		for i: int in 2:
			var r: Array[Vector3] = PyroluxDemoFigure.reach(shoulder[i], wrists[i], upper_arm, forearm, poles[i])
			elbow[i] = r[0]
			wrist[i] = r[1]


## Two-bone reach: from `root` toward `target` with bones `l1` and `l2`, the middle joint bent
## toward `pole`. Returns [middle joint, end] (the end stops short when the target is too far).
static func reach(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array[Vector3]:
	var d: Vector3 = target - root
	var dist: float = clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var dir: Vector3 = d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var a: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var hh: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var side: Vector3 = pole - dir * pole.dot(dir)
	if side.length_squared() < 0.000001:
		side = dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.UP)
	side = side.normalized()
	var out: Array[Vector3] = [root + dir * a + side * hh, root + dir * dist]
	return out


# ---------------------------------------------------------------- shapes

static func _grey(s: float) -> Color:
	return Color(s, s, s)


## A paint colour for the vertex colour, as it looks (sRGB): the kit's shaders take vertex
## colours to linear light themselves, the same in every renderer.
static func _paint(r: float, g: float, b: float) -> Color:
	return Color(r, g, b)


static func _ball(b: PyroluxDemoProps.Builder, p: Vector3, r: float, seg: int = 12) -> void:
	b.ellipsoid(p, Vector3.ONE * r, seg, maxi(seg >> 1, 4))


## An egg (a head): an ellipsoid whose lower half narrows to `chin` of its width.
static func _egg(b: PyroluxDemoProps.Builder, c: Vector3, r: Vector3, chin: float = 0.82,
		basis: Basis = Basis.IDENTITY, seg: int = 16, rings: int = 12) -> void:
	var loops: Array[PackedVector3Array] = []
	var centres: PackedVector3Array = PackedVector3Array()
	for i: int in rings + 1:
		var phi: float = PI * float(i) / float(rings)
		var yy: float = cos(phi) * r.y
		var k: float = 1.0 if phi < PI * 0.5 else lerpf(1.0, chin, (phi - PI * 0.5) / (PI * 0.5))
		var loop: PackedVector3Array = PackedVector3Array()
		for j: int in seg:
			var th: float = TAU * float(j) / float(seg)
			loop.append(c + basis * Vector3(cos(th) * sin(phi) * r.x * k, yy, sin(th) * sin(phi) * r.z * k))
		loops.append(loop)
		centres.append(c + basis * Vector3(0.0, yy * 0.5, 0.0))
	b.loft(loops, centres)


## A body round a vertical line through `axis` (x, z): rings at heights `ys` with half-widths
## `rx`, depths in front `rf` and behind `rb` (and `zo` shifting each ring forward), closed with
## a rounded end at the bottom and the top. `ridge` raises a crease down the front (a
## breastplate), `fold` and `folds` ripple the outline toward the last ring (cloth), `pec` (one
## per ring) raises two mounds on the front and `spine` sinks a groove down the back.
static func _trunk(b: PyroluxDemoProps.Builder, axis: Vector2, ys: PackedFloat32Array,
		rx: PackedFloat32Array, rf: PackedFloat32Array, rb: PackedFloat32Array,
		zo: PackedFloat32Array = PackedFloat32Array(), shades: PackedFloat32Array = PackedFloat32Array(),
		ridge: float = 0.0, fold: float = 0.0, folds: int = 0, close_bottom: bool = true,
		close_top: bool = true, seg: int = 18, pec: PackedFloat32Array = PackedFloat32Array(),
		spine: PackedFloat32Array = PackedFloat32Array()) -> void:
	var nr: int = ys.size()
	var loops: Array[PackedVector3Array] = []
	var centres: PackedVector3Array = PackedVector3Array()
	var sh: PackedFloat32Array = PackedFloat32Array()
	var last: int = nr - 1
	for i: int in nr:
		var z0: float = zo[i] if zo.size() == nr else 0.0
		var t: float = float(i) / float(maxi(last, 1))
		var loop: PackedVector3Array = PackedVector3Array()
		for j: int in seg:
			var th: float = TAU * float(j) / float(seg)
			var s: float = sin(th)
			var dz: float = rf[i] if s > 0.0 else rb[i]
			var k: float = 1.0 + fold * t * t * sin(th * float(folds) + 0.7)
			var px: float = cos(th) * rx[i] * k
			var pz: float = s * dz * k + ridge * pow(maxf(s, 0.0), 14.0)
			if pec.size() == nr:
				# Two soft mounds either side of the front centre (the chest plates).
				pz += pec[i] * (exp(-pow((th - 1.0) / 0.38, 2.0)) + exp(-pow((th - 2.14) / 0.38, 2.0)))
			if spine.size() == nr:
				# A groove down the back centre.
				pz += spine[i] * exp(-pow((th - 4.712) / 0.22, 2.0))
			loop.append(Vector3(axis.x + px, ys[i], axis.y + z0 + pz))
		loops.append(loop)
		centres.append(Vector3(axis.x, ys[i], axis.y + z0))
		sh.append(shades[i] if shades.size() == nr else 1.0)
	var rings: Array[PackedVector3Array] = []
	var cs: PackedVector3Array = PackedVector3Array()
	var ss: PackedFloat32Array = PackedFloat32Array()
	if close_bottom:
		# A rounded end: a ring halfway in and a point, a little below the first ring.
		var c0: Vector3 = centres[0]
		var dy: float = (ys[1] - ys[0]) * 0.35
		rings.append(_ring_point(c0 - Vector3(0.0, dy, 0.0), seg))
		cs.append(c0 - Vector3(0.0, dy * 0.2, 0.0))
		ss.append(sh[0])
		rings.append(_ring_scaled(loops[0], c0, 0.65, -dy * 0.75))
		cs.append(c0)
		ss.append(sh[0])
	for i: int in nr:
		rings.append(loops[i])
		cs.append(centres[i])
		ss.append(sh[i])
	if close_top:
		var c1: Vector3 = centres[last]
		var dy2: float = (ys[last] - ys[last - 1]) * 0.35
		rings.append(_ring_scaled(loops[last], c1, 0.65, dy2 * 0.75))
		cs.append(c1)
		ss.append(sh[last])
		rings.append(_ring_point(c1 + Vector3(0.0, dy2, 0.0), seg))
		cs.append(c1 + Vector3(0.0, dy2 * 0.2, 0.0))
		ss.append(sh[last])
	b.loft(rings, cs, ss)


static func _ring_point(p: Vector3, seg: int) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for _j: int in seg:
		out.append(p)
	return out


static func _ring_scaled(loop: PackedVector3Array, c: Vector3, k: float, dy: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in loop:
		out.append(c + (p - c) * k + Vector3(0.0, dy, 0.0))
	return out


## A strip lying on a _trunk() ring (half-width rx, front depth rf, the same `ridge`) between
## heights y0 and y1 over the arc th0..th1 (radians: 0 = +X, PI / 2 = the front), `out` proud of
## the surface: a visor slit, a breath, a trim that follows the shape instead of cutting it.
static func _band(b: PyroluxDemoProps.Builder, axis: Vector2, y0: float, y1: float, rx: float,
		rf: float, ridge: float, th0: float, th1: float, out: float, seg: int = 12) -> void:
	var grid: Array[PackedVector3Array] = []
	for yy: float in [y1, y0]:
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in seg + 1:
			var th: float = lerpf(th0, th1, float(j) / float(seg))
			var s: float = sin(th)
			row.append(Vector3(axis.x + cos(th) * (rx + out), yy, axis.y + s * (rf + out) + ridge * pow(maxf(s, 0.0), 14.0)))
		grid.append(row)
	var mid: float = (th0 + th1) * 0.5
	b.sheet(grid, Vector3(cos(mid), 0.0, sin(mid)), 1.0)


## A turn that takes +Y to `dir` with +Z as close to `front` as it can be.
static func _aim_basis(dir: Vector3, front: Vector3) -> Basis:
	var yy: Vector3 = dir.normalized()
	var zz: Vector3 = front - yy * front.dot(yy)
	if zz.length_squared() < 0.000001:
		zz = yy.cross(Vector3.RIGHT if absf(yy.x) < 0.9 else Vector3.UP)
	zz = zz.normalized()
	var xx: Vector3 = yy.cross(zz).normalized()
	return Basis(xx, yy, zz)


## A shoe or a bare foot under `ankle` pointing along `toe` (on the floor plane), its sole flat
## on y = `floor_y`.
static func _foot(b: PyroluxDemoProps.Builder, ankle: Vector3, toe: Vector3, floor_y: float,
		width: float, tall: float, length: float) -> void:
	var f: Vector3 = Vector3(toe.x, 0.0, toe.z).normalized()
	var basis: Basis = Basis(Vector3.UP.cross(f).normalized(), Vector3.UP, f)
	var c: Vector3 = Vector3(ankle.x, floor_y + tall, ankle.z) + f * length * 0.3
	b.ellipsoid(c, Vector3(width, tall * 1.15, length * 0.5), 12, 8, basis, -tall)


## An open hand at the end of the forearm (`dir` from the elbow), its palm facing `palm`.
static func _hand(b: PyroluxDemoProps.Builder, wrist: Vector3, dir: Vector3, palm: Vector3, h: float) -> void:
	var basis: Basis = _aim_basis(dir, palm)
	var c: Vector3 = wrist + dir.normalized() * h * 0.047
	b.ellipsoid(c, Vector3(h * 0.023, h * 0.05, h * 0.011), 10, 7, basis)
	var thumb_side: Vector3 = basis.x
	b.ellipsoid(wrist + dir.normalized() * h * 0.022 + thumb_side * h * 0.019 + basis.z * h * 0.006,
		Vector3(h * 0.008, h * 0.024, h * 0.008), 7, 4, Basis(thumb_side.cross(basis.z).normalized(), deg_to_rad(25.0)) * basis)


## A closed fist round a grip at `c`, the forearm coming in along `dir`.
static func _fist(b: PyroluxDemoProps.Builder, c: Vector3, dir: Vector3, h: float) -> void:
	var basis: Basis = _aim_basis(dir, Vector3.UP)
	b.ellipsoid(c, Vector3(h * 0.027, h * 0.029, h * 0.025), 10, 7, basis)


# ---------------------------------------------------------------- mannequin

## A white, faceless mannequin `height` tall standing at ease on `at`: arms hanging a little
## away from the body, one smooth skin from the seat to the crown with a shallow seam line at
## every joint (the art-class figure, so nobody reads it as a real person). One mesh, one
## surface.
static func mannequin(parent: Node, at: Vector3, yaw: float = 0.0, mat: Material = null,
		height: float = 1.8) -> MeshInstance3D:
	var key: String = "mannequin_%.2f" % height
	var m: ArrayMesh = _cached(key)
	if m == null:
		var r: Rig = _mannequin_rig(height)
		var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
		b.kind = 1.0
		_mannequin_body(b, r)
		m = _store(key, b)
	var mq: MeshInstance3D = _place(parent, m, mat if mat != null else white_material(), at, yaw, "Mannequin")
	PyroluxDemoProps.blob_shadow(mq, height * 0.15)
	return mq


## The mannequin's stance (arms hanging a little away from the body, feet a little apart and
## turned out): mannequin() and walker() share it.
static func _mannequin_rig(height: float) -> Rig:
	var r: Rig = Rig.new(height)
	var h: float = height
	r.legs([Vector3(-0.062 * h, 0.045 * h, 0.006 * h), Vector3(0.062 * h, 0.045 * h, -0.004 * h)])
	r.arms([Vector3(-0.142 * h, 0.505 * h, 0.035 * h), Vector3(0.14 * h, 0.51 * h, 0.022 * h)],
		[Vector3(-0.5, 0.0, -1.0), Vector3(0.5, 0.0, -1.0)])
	r.toe_dir = [Vector3(-0.12, 0.0, 1.0), Vector3(0.12, 0.0, 1.0)]
	return r


## `marks` (walker()): for each part, the index of its first vertex and its code (0 the body
## from the seat to the crown; per side i, 1 + 4 i the arm, + 1 the hand, + 2 the leg, + 3 the
## foot). The mesh is the same with or without it.
static func _mannequin_body(b: PyroluxDemoProps.Builder, r: Rig, marks: Array[int] = []) -> void:
	var h: float = r.height
	var seam: float = 0.9
	marks.append_array([b.mark(), 0])
	b.tint = _grey(1.0)
	# One skin from the seat to the crown: the flare of the pelvis, a narrow waist with its
	# seam, the ribs widening to the chest plates, the step of the collar bones, the slope of
	# the shoulders, a neck set a little forward, and the head (an egg with a chin and a round
	# back). Rings are (height, half-width, depth in front, behind, shift forward); `pec`
	# raises the chest plates, `spine` sinks the groove down the back.
	var ys: PackedFloat32Array = PackedFloat32Array([0.448, 0.47, 0.5, 0.53, 0.56, 0.585, 0.605, 0.625, 0.655, 0.69, 0.725, 0.755, 0.78, 0.8, 0.818, 0.835, 0.85, 0.864, 0.876, 0.892, 0.915, 0.94, 0.965, 0.985, 0.997])
	var rx: PackedFloat32Array = PackedFloat32Array([0.054, 0.084, 0.102, 0.101, 0.092, 0.08, 0.073, 0.076, 0.084, 0.09, 0.096, 0.1, 0.102, 0.098, 0.086, 0.06, 0.034, 0.028, 0.03, 0.038, 0.042, 0.044, 0.041, 0.032, 0.013])
	var rf: PackedFloat32Array = PackedFloat32Array([0.044, 0.056, 0.066, 0.064, 0.058, 0.052, 0.05, 0.054, 0.06, 0.068, 0.075, 0.078, 0.074, 0.062, 0.052, 0.04, 0.03, 0.028, 0.033, 0.047, 0.053, 0.053, 0.049, 0.04, 0.016])
	var rb: PackedFloat32Array = PackedFloat32Array([0.05, 0.066, 0.076, 0.075, 0.068, 0.06, 0.056, 0.058, 0.062, 0.065, 0.066, 0.064, 0.06, 0.056, 0.052, 0.042, 0.032, 0.03, 0.034, 0.05, 0.057, 0.06, 0.058, 0.046, 0.018])
	var zo: PackedFloat32Array = PackedFloat32Array([0.002, 0.003, 0.004, 0.004, 0.003, 0.002, 0.002, 0.003, 0.005, 0.007, 0.008, 0.008, 0.006, 0.002, -0.002, 0.0, 0.004, 0.006, 0.008, 0.009, 0.008, 0.006, 0.004, 0.003, 0.002])
	var sh: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, seam, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	var pec: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.001, 0.004, 0.007, 0.006, 0.002, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var spine: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.003, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.002, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	_trunk(b, Vector2(0.0, 0.0), _scale(ys, h, r.base - r.drop), _scale(rx, h), _scale(rf, h), _scale(rb, h),
		_scale(zo, h), sh, 0.0, 0.0, 0, true, true, 24, _scale(pec, h), _scale(spine, h))
	for i: int in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		# The arm: the round of the deltoid over the shoulder running smoothly into the upper
		# arm, a seam at the elbow, the forearm swelling below it and turning flat toward the
		# wrist; then the hand.
		var s0: Vector3 = r.shoulder[i] + Vector3(-sx * 0.004 * h, 0.012 * h, 0.0)
		var e: Vector3 = r.elbow[i]
		var w: Vector3 = r.wrist[i]
		marks.append_array([b.mark(), 1 + 4 * i])
		_chain(b, PackedVector3Array([s0, s0.lerp(e, 0.12), s0.lerp(e, 0.3), s0.lerp(e, 0.55), s0.lerp(e, 0.8), e,
				e.lerp(w, 0.12), e.lerp(w, 0.3), e.lerp(w, 0.55), e.lerp(w, 0.8), w]),
			_scale(PackedFloat32Array([0.04, 0.038, 0.035, 0.031, 0.025, 0.0205, 0.025, 0.028, 0.024, 0.019, 0.015]), h),
			PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, seam, 1.0, 1.0, 1.0, 1.0, 1.0]), Vector3.FORWARD, 16, 1.0,
			PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.94, 0.92, 1.0, 1.08, 1.15]))
		marks.append_array([b.mark(), 2 + 4 * i])
		_hand(b, w, w - e, Vector3(-sx, 0.0, 0.0), h)
		# The leg: the thigh from inside the pelvis thinning to the knee, a seam, the calf
		# swelling behind the shin and narrowing to the ankle; then the foot.
		var hp: Vector3 = r.hip[i] + Vector3(0.0, 0.02 * h, 0.0)
		var k: Vector3 = r.knee[i]
		var a: Vector3 = r.ankle[i]
		marks.append_array([b.mark(), 3 + 4 * i])
		_chain(b, PackedVector3Array([hp, hp.lerp(k, 0.2), hp.lerp(k, 0.45), hp.lerp(k, 0.7), hp.lerp(k, 0.88), k,
				k.lerp(a, 0.1), k.lerp(a, 0.28), k.lerp(a, 0.5), k.lerp(a, 0.72), k.lerp(a, 0.88), a]),
			_scale(PackedFloat32Array([0.049, 0.051, 0.047, 0.041, 0.036, 0.032, 0.034, 0.039, 0.034, 0.027, 0.021, 0.018]), h),
			PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, seam, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]), Vector3.FORWARD, 16, 1.1,
			PackedFloat32Array([1.12, 1.12, 1.1, 1.08, 1.06, 1.08, 1.1, 1.18, 1.16, 1.12, 1.15, 1.2]))
		marks.append_array([b.mark(), 4 + 4 * i])
		_foot(b, a, r.toe_dir[i], r.base, 0.027 * h, 0.022 * h, 0.14 * h)


## A smooth limb: rings along `path` (the joints and the stations between them), each
## perpendicular to the path there, `rad[i]` wide (`aspect`, or `aspects[i]`, deeper than wide:
## a forearm turning flat toward the wrist), `shade[i]` in
## the vertex colour (a touch darker at a joint: the seam line of an art-class figure).
## `front` says which way the rings' depth axis points (never along the limb). Closed with a
## rounded end at both ends.
static func _chain(b: PyroluxDemoProps.Builder, path: PackedVector3Array, rad: PackedFloat32Array,
		shade: PackedFloat32Array, front: Vector3, seg: int = 14, aspect: float = 1.0,
		aspects: PackedFloat32Array = PackedFloat32Array()) -> void:
	var n: int = path.size()
	if n < 2:
		return
	var loops: Array[PackedVector3Array] = []
	for i: int in n:
		var t: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var basis: Basis = _aim_basis(t, front)
		var asp: float = aspects[i] if aspects.size() == n else aspect
		var loop: PackedVector3Array = PackedVector3Array()
		for j: int in seg:
			var th: float = TAU * float(j) / float(seg)
			loop.append(path[i] + basis.x * (cos(th) * rad[i]) + basis.z * (sin(th) * rad[i] * asp))
		loops.append(loop)
	var t0: Vector3 = (path[1] - path[0]).normalized()
	var t1: Vector3 = (path[n - 1] - path[n - 2]).normalized()
	var rings: Array[PackedVector3Array] = []
	var cs: PackedVector3Array = PackedVector3Array()
	var ss: PackedFloat32Array = PackedFloat32Array()
	rings.append(_ring_point(path[0] - t0 * rad[0] * 0.9, seg))
	cs.append(path[0] - t0 * rad[0] * 0.5)
	ss.append(shade[0])
	rings.append(_ring_moved(loops[0], path[0], 0.62, -t0 * rad[0] * 0.6))
	cs.append(path[0] - t0 * rad[0] * 0.2)
	ss.append(shade[0])
	for i: int in n:
		rings.append(loops[i])
		cs.append(path[i])
		ss.append(shade[i])
	rings.append(_ring_moved(loops[n - 1], path[n - 1], 0.62, t1 * rad[n - 1] * 0.6))
	cs.append(path[n - 1] + t1 * rad[n - 1] * 0.2)
	ss.append(shade[n - 1])
	rings.append(_ring_point(path[n - 1] + t1 * rad[n - 1] * 0.9, seg))
	cs.append(path[n - 1] + t1 * rad[n - 1] * 0.5)
	ss.append(shade[n - 1])
	b.loft(rings, cs, ss)


static func _ring_moved(loop: PackedVector3Array, c: Vector3, k: float, shift: Vector3) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in loop:
		out.append(c + (p - c) * k + shift)
	return out


static func _scale(a: PackedFloat32Array, k: float, add: float = 0.0) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for v: float in a:
		out.append(v * k + add)
	return out


# ---------------------------------------------------------------- walker

## Kit 6: the mannequin with bones. The same body as mannequin() (its build, stance and size)
## skinned to a Skeleton3D of 19 bones (PyroluxDemoGait.BONES: hips, spine, chest, neck,
## head, and per side the upper arm, forearm, hand, thigh, shin, foot and toes; ".L" is the
## figure's own left, +X), each vertex blended over at most three bones at a joint, and a
## PyroluxDemoGait that walks, stops and staggers it by turning the bones in code. Returns
## the root (named "Walker", feet on `at`, facing +Z turned by `yaw`):
##   Walker / Skeleton / Body   the MeshInstance3D with its skin: what an effect takes
##   Walker / Gait              the PyroluxDemoGait
## Metas: "body" (MeshInstance3D), "skeleton" (Skeleton3D), "gait" (PyroluxDemoGait).
##
##   var who: Node3D = PyroluxDemoFigure.walker(props, Vector3(-2.0, 0.0, 0.0), PI * 0.5)
##   var gait: PyroluxDemoGait = who.get_meta(&"gait")
##   gait.walk_to(Vector3(1.5, 0.0, 0.0), 0.9)
static func walker(parent: Node, at: Vector3, yaw: float = 0.0, mat: Material = null,
		height: float = 1.8) -> Node3D:
	var r: Rig = _mannequin_rig(height)
	var joints: PackedVector3Array = _walker_joints(r)
	var key: String = "walker_%.2f" % height
	var m: ArrayMesh = _cached(key)
	if m == null:
		m = _walker_mesh(r, joints)
		_cache[key] = m
	var root: Node3D = Node3D.new()
	root.name = "Walker"
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	var skel: Skeleton3D = Skeleton3D.new()
	skel.name = "Skeleton"
	root.add_child(skel)
	var names: Array[String] = PyroluxDemoGait.BONES
	var parents: Array[int] = PyroluxDemoGait.PARENTS
	for i: int in names.size():
		skel.add_bone(names[i])
	var skin: Skin = Skin.new()
	for i: int in names.size():
		var p: int = parents[i]
		skel.set_bone_parent(i, p)
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, joints[i] - (joints[p] if p >= 0 else Vector3.ZERO)))
		skin.add_named_bind(names[i], Transform3D(Basis.IDENTITY, -joints[i]))
	skel.reset_bone_poses()
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = m
	body.material_override = mat if mat != null else white_material()
	skel.add_child(body)
	body.skin = skin
	body.skeleton = NodePath("..")
	# A box round every pose (a lean, a step), so the posed body is never culled.
	var k: float = height / 1.8
	body.custom_aabb = AABB(Vector3(-0.9, -0.15, -0.9) * k, Vector3(1.8, 2.25, 1.8) * k)
	var gait: PyroluxDemoGait = PyroluxDemoGait.new()
	gait.name = "Gait"
	gait.setup(skel, joints, height)
	root.add_child(gait)
	root.set_meta(&"body", body)
	root.set_meta(&"skeleton", skel)
	root.set_meta(&"gait", gait)
	PyroluxDemoProps.blob_shadow(root, height * 0.13)
	return root


## The joints of walker()'s bones in the rest pose (skeleton space), in DemoGait.BONES order.
## The spine and chest turn about a point toward the back (where the vertebrae are).
static func _walker_joints(r: Rig) -> PackedVector3Array:
	var h: float = r.height
	var j: PackedVector3Array = PackedVector3Array()
	j.append(Vector3(0.0, r.y(0.5), 0.0))
	j.append(Vector3(0.0, r.y(0.585), -0.012 * h))
	j.append(Vector3(0.0, r.y(0.7), -0.012 * h))
	j.append(Vector3(0.0, r.y(0.83), -0.006 * h))
	j.append(Vector3(0.0, r.y(0.872), 0.0))
	for i: int in 2:
		j.append(r.shoulder[i])
		j.append(r.elbow[i])
		j.append(r.wrist[i])
	for i: int in 2:
		var f: Vector3 = Vector3(r.toe_dir[i].x, 0.0, r.toe_dir[i].z).normalized()
		j.append(r.hip[i])
		j.append(r.knee[i])
		j.append(r.ankle[i])
		# The toes bend at the ball of the foot.
		j.append(Vector3(r.ankle[i].x, r.base + 0.012 * h, r.ankle[i].z) + f * 0.068 * h)
	return j


## The mannequin's mesh with bone weights (up to four per vertex, summing to 1).
static func _walker_mesh(r: Rig, joints: PackedVector3Array) -> ArrayMesh:
	var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	b.kind = 1.0
	var marks: Array[int] = []
	_mannequin_body(b, r, marks)
	var n: int = b.v.size()
	var bones: PackedInt32Array = PackedInt32Array()
	var wts: PackedFloat32Array = PackedFloat32Array()
	bones.resize(n * 4)
	wts.resize(n * 4)
	var part: int = 0
	for vi: int in n:
		while part + 2 < marks.size() and vi >= marks[part + 2]:
			part += 2
		var w: Dictionary = _walker_weights(marks[part + 1], b.v[vi], r, joints)
		var ids: Array[int] = []
		var vals: Array[float] = []
		for key: int in w.keys():
			var wv: float = w[key]
			if wv > 0.0005:
				ids.append(key)
				vals.append(wv)
		var total: float = 0.0
		for slot: int in 4:
			var best: int = -1
			for q: int in vals.size():
				if vals[q] >= 0.0 and (best < 0 or vals[q] > vals[best]):
					best = q
			if best < 0:
				break
			bones[vi * 4 + slot] = ids[best]
			wts[vi * 4 + slot] = vals[best]
			total += vals[best]
			vals[best] = -1.0
		for slot: int in 4:
			wts[vi * 4 + slot] = wts[vi * 4 + slot] / maxf(total, 0.0001)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b.v
	arrays[Mesh.ARRAY_NORMAL] = b.n
	arrays[Mesh.ARRAY_TEX_UV] = b.uv
	arrays[Mesh.ARRAY_TEX_UV2] = b.uv2
	arrays[Mesh.ARRAY_COLOR] = b.col
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = wts
	arrays[Mesh.ARRAY_INDEX] = b.idx
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Bone weights of a vertex at `p` (rest pose) of part `code` (see _mannequin_body's marks).
## The body is banded by height (hips, spine, chest, neck, head); the low sides of the pelvis
## lean on the thighs and the shoulder caps on the upper arms, so the hip and the shoulder bend
## instead of opening. Limbs blend across each joint by where the vertex lies along the bones.
static func _walker_weights(code: int, p: Vector3, r: Rig, j: PackedVector3Array) -> Dictionary:
	var h: float = r.height
	var w: Dictionary = {}
	if code == 0:
		var yy: float = (p.y - r.base) / h
		var bs: float = smoothstep(0.555, 0.605, yy)
		var bc: float = smoothstep(0.65, 0.71, yy)
		var bn: float = smoothstep(0.818, 0.842, yy)
		var bh: float = smoothstep(0.862, 0.885, yy)
		w[PyroluxDemoGait.B_HIPS] = 1.0 - bs
		w[PyroluxDemoGait.B_SPINE] = bs * (1.0 - bc)
		w[PyroluxDemoGait.B_CHEST] = bs * bc * (1.0 - bn)
		w[PyroluxDemoGait.B_NECK] = bs * bc * bn * (1.0 - bh)
		w[PyroluxDemoGait.B_HEAD] = bs * bc * bn * bh
		var side: int = 1 if p.x > 0.0 else 0
		var lat: float = absf(p.x) / (0.1 * h)
		_shift(w, PyroluxDemoGait.B_LEG + 4 * side,
			0.8 * (1.0 - smoothstep(0.455, 0.53, yy)) * smoothstep(0.15, 0.65, lat))
		_shift(w, PyroluxDemoGait.B_ARM + 3 * side,
			0.5 * smoothstep(0.62, 0.95, lat) * smoothstep(0.72, 0.775, yy) * (1.0 - smoothstep(0.815, 0.84, yy)))
		return w
	var side_i: int = (code - 1) >> 2
	var kind: int = (code - 1) % 4
	if kind == 0:
		var arm: int = PyroluxDemoGait.B_ARM + 3 * side_i
		var t: Vector3 = _along(p, j[arm], j[arm + 1], j[arm + 2])
		var fore: float = smoothstep(-0.016 * h, 0.016 * h, t.y)
		var hand: float = smoothstep(-0.006 * h, 0.012 * h, t.z)
		w[arm] = 1.0 - fore
		w[arm + 1] = fore * (1.0 - hand)
		w[arm + 2] = fore * hand
		_shift(w, PyroluxDemoGait.B_CHEST, 0.45 * (1.0 - smoothstep(-0.012 * h, 0.045 * h, t.x)))
	elif kind == 1:
		w[PyroluxDemoGait.B_ARM + 3 * side_i + 2] = 1.0
	elif kind == 2:
		var leg: int = PyroluxDemoGait.B_LEG + 4 * side_i
		var t: Vector3 = _along(p, j[leg], j[leg + 1], j[leg + 2])
		var shin: float = smoothstep(-0.022 * h, 0.022 * h, t.y)
		var foot: float = smoothstep(-0.022 * h, 0.008 * h, t.z)
		w[leg] = 1.0 - shin
		w[leg + 1] = shin * (1.0 - foot)
		w[leg + 2] = shin * foot
		_shift(w, PyroluxDemoGait.B_HIPS, 0.7 * (1.0 - smoothstep(-0.02 * h, 0.06 * h, t.x)))
	else:
		var leg: int = PyroluxDemoGait.B_LEG + 4 * side_i
		var a: Vector3 = j[leg + 2]
		var toe: Vector3 = j[leg + 3]
		var f: Vector3 = Vector3(toe.x - a.x, 0.0, toe.z - a.z)
		var lf: float = f.length()
		var u: float = Vector3(p.x - a.x, 0.0, p.z - a.z).dot(f / lf)
		var tw: float = smoothstep(lf - 0.011 * h, lf + 0.011 * h, u)
		w[leg + 2] = 1.0 - tw
		w[leg + 3] = tw
	return w


## Moves `amount` of every weight in `w` onto `bone`.
static func _shift(w: Dictionary, bone: int, amount: float) -> void:
	if amount <= 0.0:
		return
	for key: Variant in w.keys():
		var wv: float = w[key]
		w[key] = wv * (1.0 - amount)
	var had: float = w.get(bone, 0.0)
	w[bone] = had + amount


## Where `p` lies along the chain j0 -> j1 -> j2: x = along the first bone from j0, y = from the
## middle joint (negative on the first bone's side), z = past j2 along the second bone.
static func _along(p: Vector3, j0: Vector3, j1: Vector3, j2: Vector3) -> Vector3:
	var la: float = j0.distance_to(j1)
	var lb: float = j1.distance_to(j2)
	var da: Vector3 = (j1 - j0) / la
	var db: Vector3 = (j2 - j1) / lb
	var ta: float = (p - j0).dot(da)
	var tb: float = (p - j1).dot(db)
	var qa: Vector3 = j0 + da * clampf(ta, 0.0, la)
	var qb: Vector3 = j1 + db * clampf(tb, 0.0, lb)
	var s: float = tb if p.distance_squared_to(qb) < p.distance_squared_to(qa) else ta - la
	return Vector3(ta, s, tb - lb)


# ---------------------------------------------------------------- knight

## A stone statue of a knight in plate armour, 1.82 m to the crown of his helm's skull, resting
## both hands on the grip of a sword planted point-down in front of him. GLYPHLUX's hero target
## (sabatons, greaves, knee cops with wings, cuisses, tassets, a skirt of lames, a ridged
## breastplate, a gorget, a great helm with an eye slit and breaths, pauldrons of three lames,
## a cloak to the calves) on the kit's proportions. `pedestal`: on a low stepped plinth (its top
## 0.2 m, a child MeshInstance3D named "Plinth" so a rune walk stays on the figure) or standing
## on the floor. One mesh, one surface.
static func knight(parent: Node, at: Vector3, pedestal: bool = true, mat: Material = null,
		yaw: float = 0.0) -> MeshInstance3D:
	var base: float = PLINTH_TOP if pedestal else 0.0
	var key: String = "knight_%.2f" % base
	var m: ArrayMesh = _cached(key)
	if m == null:
		var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
		b.kind = 1.0
		_knight_body(b, base)
		m = _store(key, b)
	var material: Material = mat if mat != null else sandstone_material()
	var mi: MeshInstance3D = _place(parent, m, material, at, yaw, "Knight")
	PyroluxDemoProps.blob_shadow(mi, 0.47 if pedestal else 0.33)
	if pedestal:
		var pm: ArrayMesh = _cached("knight_plinth")
		if pm == null:
			var pb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
			pb.kind = 1.0
			pb.cbox(Vector3(-0.47, 0.0, -0.47), Vector3(0.47, 0.12, 0.47), 0.018)
			pb.tint = _grey(1.06)
			pb.cbox(Vector3(-0.39, 0.12, -0.39), Vector3(0.39, PLINTH_TOP, 0.39), 0.014)
			pm = _store("knight_plinth", pb)
		var plinth: MeshInstance3D = MeshInstance3D.new()
		plinth.name = "Plinth"
		plinth.mesh = pm
		plinth.material_override = material
		mi.add_child(plinth)
	return mi


static func _knight_body(b: PyroluxDemoProps.Builder, base: float) -> void:
	var h: float = 1.82
	var r: Rig = Rig.new(h, base)
	var sword_z: float = 0.3
	r.legs([Vector3(-0.15, base + 0.082, 0.0), Vector3(0.15, base + 0.082, 0.0)])
	var grip_hi: Vector3 = Vector3(0.0, base + 1.12, sword_z)
	var grip_lo: Vector3 = Vector3(0.0, base + 1.03, sword_z)
	r.arms([grip_lo + Vector3(-0.05, 0.01, -0.05), grip_hi + Vector3(0.05, 0.01, -0.05)],
		[Vector3(-1.0, -0.6, -0.4), Vector3(1.0, -0.6, -0.4)])
	r.toe_dir = [Vector3(-0.1, 0.0, 1.0), Vector3(0.1, 0.0, 1.0)]
	var dk: float = 0.6
	for i: int in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		var ank: Vector3 = r.ankle[i]
		var kn: Vector3 = r.knee[i]
		var hp: Vector3 = r.hip[i]
		var f: Vector3 = r.toe_dir[i].normalized()
		# Sabaton and its toe cap, flat on the plinth; a dark ring at the ankle.
		b.tint = _grey(1.0)
		_foot(b, ank, f, base, 0.06, 0.048, 0.29)
		b.tint = _grey(0.9)
		b.ellipsoid(Vector3(ank.x, base + 0.035, ank.z) + f * 0.2, Vector3(0.05, 0.036, 0.06), 10, 6,
			Basis(Vector3.UP.cross(f).normalized(), Vector3.UP, f), -0.035)
		b.tint = _grey(dk)
		b.tube(ank + Vector3(0.0, -0.025, 0.0), ank + Vector3(0.0, 0.012, 0.0), 0.06, 0.058, 12)
		# Greave with a calf, the knee cop with its wing, a dark ring, the cuisse.
		b.tint = _grey(1.0)
		var calf: Vector3 = ank.lerp(kn, 0.45) + Vector3(0.0, 0.0, -0.012)
		b.tube(ank, calf, 0.054, 0.071, 14)
		b.tube(calf, kn, 0.071, 0.062, 14)
		b.ellipsoid(kn + Vector3(0.0, 0.0, 0.03), Vector3(0.07, 0.068, 0.062), 12, 8)
		b.tint = _grey(0.88)
		b.ellipsoid(kn + Vector3(sx * 0.062, 0.0, 0.0), Vector3(0.02, 0.062, 0.058), 8, 6)
		b.tint = _grey(dk)
		b.tube(kn + Vector3(0.0, 0.05, 0.0), kn + Vector3(0.0, 0.075, 0.0), 0.073, 0.074, 12)
		b.tint = _grey(1.0)
		b.tube(kn + Vector3(0.0, 0.07, 0.0), hp, 0.075, 0.1, 14)
		# A tasset hanging over the front of the thigh.
		var mk: int = b.mark()
		b.cbox(Vector3(-0.085, -0.1, -0.016), Vector3(0.085, 0.1, 0.016), 0.012)
		b.xform_from(mk, Transform3D(Basis.from_euler(Vector3(deg_to_rad(-14.0), 0.0, deg_to_rad(sx * 7.0))),
			Vector3(sx * 0.105, hp.y - 0.02, 0.11)))
	# Mail between the thighs; a skirt of four lames; the belt.
	b.tint = _grey(0.5)
	b.ellipsoid(Vector3(0.0, r.y(0.478), 0.0), Vector3(0.085, 0.07, 0.085), 12, 8)
	for k: int in 4:
		var ytop: float = base + 1.13 - float(k) * 0.045
		b.tint = _grey(1.0 if k % 2 == 0 else 0.84)
		b.tube(Vector3(0.0, ytop, 0.004), Vector3(0.0, ytop - 0.052, 0.004), 0.19 + float(k) * 0.012, 0.2 + float(k) * 0.012, 20, k == 3, false)
	b.tint = _grey(0.55)
	b.tube(Vector3(0.0, base + 1.135, 0.004), Vector3(0.0, base + 1.17, 0.004), 0.193, 0.192, 20)
	# The breastplate (ridged down the front) and backplate.
	b.tint = _grey(1.0)
	_trunk(b, Vector2(0.0, 0.0),
		_add(PackedFloat32Array([1.135, 1.2, 1.29, 1.38, 1.45, 1.5, 1.54]), base),
		PackedFloat32Array([0.19, 0.2, 0.214, 0.218, 0.205, 0.17, 0.11]),
		PackedFloat32Array([0.135, 0.15, 0.168, 0.172, 0.16, 0.13, 0.085]),
		PackedFloat32Array([0.13, 0.135, 0.14, 0.14, 0.135, 0.115, 0.08]),
		PackedFloat32Array(), PackedFloat32Array([0.95, 1.0, 1.0, 1.0, 1.0, 0.95, 0.9]), 0.02)
	# Gorget.
	b.tint = _grey(0.85)
	b.tube(Vector3(0.0, base + 1.53, -0.006), Vector3(0.0, base + 1.56, -0.006), 0.135, 0.13, 16)
	b.tint = _grey(1.0)
	b.tube(Vector3(0.0, base + 1.55, -0.006), Vector3(0.0, base + 1.64, -0.006), 0.126, 0.1, 16)
	# The great helm: a flat-topped pot with a vertical ridge, the eye slit, breaths, a crest.
	_trunk(b, Vector2(0.0, -0.004),
		_add(PackedFloat32Array([1.6, 1.66, 1.74, 1.81, 1.85]), base),
		PackedFloat32Array([0.126, 0.12, 0.118, 0.116, 0.1]),
		PackedFloat32Array([0.128, 0.13, 0.129, 0.124, 0.104]),
		PackedFloat32Array([0.124, 0.122, 0.121, 0.118, 0.1]),
		PackedFloat32Array(), PackedFloat32Array(), 0.016, 0.0, 0, true, true, 18)
	b.tint = _grey(0.1)
	_band(b, Vector2(0.0, -0.004), base + 1.733, base + 1.757, 0.118, 0.129, 0.016, 0.45, PI - 0.45, 0.003, 16)
	b.tint = _grey(0.97)
	b.cbox(Vector3(-0.012, base + 1.6, 0.125), Vector3(0.012, base + 1.728, 0.153), 0.006)
	b.tint = _grey(0.25)
	for c: int in 2:
		for row: int in 3:
			var th: float = 0.95 + float(c) * 0.2
			var yb: float = base + 1.645 - float(row) * 0.026
			_band(b, Vector2(0.0, -0.004), yb, yb + 0.012, 0.121, 0.131, 0.016, th - 0.05, th + 0.05, 0.002, 3)
	b.tint = _grey(1.0)
	b.cbox(Vector3(-0.013, base + 1.84, -0.13), Vector3(0.013, base + 1.95, 0.1), 0.008)
	# Pauldrons of three lames, rerebraces, couters with wings, vambraces, gauntlets.
	for i: int in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		var sh: Vector3 = r.shoulder[i]
		var el: Vector3 = r.elbow[i]
		var wr: Vector3 = r.wrist[i]
		for k: int in 3:
			b.tint = _grey(1.0 if k == 0 else 0.86)
			b.ellipsoid(sh + Vector3(sx * (0.035 + float(k) * 0.03), 0.07 - float(k) * 0.07, 0.0),
				Vector3(0.165 - float(k) * 0.014, 0.07, 0.15 - float(k) * 0.01), 16, 8,
				Basis(Vector3.BACK, -sx * deg_to_rad(34.0 + float(k) * 10.0)))
		b.tint = _grey(1.0)
		b.tube(sh, el, 0.064, 0.057, 12)
		b.ellipsoid(el, Vector3.ONE * 0.062, 12, 7)
		var arm_dir: Vector3 = (wr - el).normalized()
		var out_dir: Vector3 = Vector3(el.x, 0.0, el.z)
		out_dir = (out_dir - arm_dir * out_dir.dot(arm_dir)).normalized()
		b.tint = _grey(0.88)
		b.ellipsoid(el + out_dir * 0.05 - arm_dir * 0.01, Vector3(0.052, 0.05, 0.016), 10, 6, _aim_basis(out_dir.cross(arm_dir), out_dir))
		b.tint = _grey(1.0)
		b.tube(el, wr, 0.056, 0.047, 12)
		b.tint = _grey(0.95)
		b.tube(wr - arm_dir * 0.012, wr + arm_dir * 0.04, 0.05, 0.058, 12)
		var fist: Vector3 = grip_lo if i == 0 else grip_hi
		b.tint = _grey(0.92)
		_fist(b, fist, arm_dir, h)
		b.tube(wr + arm_dir * 0.03, fist, 0.046, 0.044, 10)
	# The sword, point on the plinth between the feet: a ridged blade tapering to the point,
	# a cross-guard drooping a little at its ends, the grip under the hands, a round pommel.
	b.tint = _grey(1.0)
	var blade: Array[PackedVector3Array] = []
	var bc: PackedVector3Array = PackedVector3Array()
	for yb: float in [0.0, 0.12, 0.5, 0.93]:
		var w: float = 0.034 if yb > 0.05 else 0.002
		var tk: float = 0.011 if yb > 0.05 else 0.002
		if yb > 0.05 and yb < 0.2:
			w = 0.03
		blade.append(PackedVector3Array([Vector3(w, base + yb, sword_z), Vector3(0.0, base + yb, sword_z + tk),
			Vector3(-w, base + yb, sword_z), Vector3(0.0, base + yb, sword_z - tk)]))
		bc.append(Vector3(0.0, base + yb, sword_z))
	b.loft(blade, bc)
	b.tint = _grey(0.95)
	for sx2: float in [-1.0, 1.0]:
		b.tube(Vector3(0.0, base + 0.955, sword_z), Vector3(sx2 * 0.16, base + 0.94, sword_z), 0.021, 0.017, 8)
		_ball(b, Vector3(sx2 * 0.165, base + 0.938, sword_z), 0.024, 8)
	b.tint = _grey(0.8)
	b.tube(Vector3(0.0, base + 0.95, sword_z), Vector3(0.0, base + 1.17, sword_z), 0.02, 0.018, 10)
	b.tint = _grey(1.0)
	b.ellipsoid(Vector3(0.0, base + 1.2, sword_z), Vector3(0.04, 0.035, 0.04), 10, 6)
	# The cloak, from under the pauldrons to the calves, open in front, lined.
	b.tint = _grey(0.86)
	var rows: int = 9
	var cols: int = 15
	var grid: Array[PackedVector3Array] = []
	for ri: int in rows:
		var t: float = float(ri) / float(rows - 1)
		var yy: float = base + lerpf(1.53, 0.44, t)
		var rxx: float = 0.215 + 0.14 * t
		var rzz: float = 0.17 + 0.12 * t
		var row: PackedVector3Array = PackedVector3Array()
		for ci: int in cols:
			var phi: float = lerpf(-1.9, 1.9, float(ci) / float(cols - 1))
			var k: float = 1.0 + 0.07 * t * sin(phi * 7.0 + 0.5)
			row.append(Vector3(sin(phi) * rxx * k, yy, -0.02 - 0.05 * t - cos(phi) * rzz * k))
		grid.append(row)
	b.sheet(grid, Vector3(-1.0, 0.0, -0.3), 0.62)


static func _add(a: PackedFloat32Array, add: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for v: float in a:
		out.append(v + add)
	return out


# ---------------------------------------------------------------- caster

## Pose 1 staff: the butt on the floor just outside the left foot, up past the head leaning a
## little forward and out, the fist round it at chest height (CASTER_STAFF_GRIP along it).
const CASTER_STAFF_BUTT: Vector3 = Vector3(-0.414, 0.03, -0.015)
const CASTER_STAFF_DIR: Vector3 = Vector3(0.1, 0.96, 0.26)   # about 16 degrees off upright
const CASTER_STAFF_LEN: float = 1.9
const CASTER_STAFF_GRIP: float = 1.135

## A hooded caster at `at` facing `aim` (on the floor plane): one hand plants a staff, the other
## reaches toward `aim`, palm out - where a spell comes from. Dark and plain, so it never
## competes with the effect. A root Node3D with the body ("Robe", one mesh) and the staff's
## stone ("Stone", drawn flat in `gem`). Metas: "tip" = the world point just past the stone,
## "tip_local" = the same in the root's space, "hand_local" = the reaching palm, "gem" = the
## stone's material (tint it).
## `pose` (kit 11): 0 = as above (the staff planted in the right hand, the left hand reaching).
## 1 = the staff levelled: the left hand (the near hand when the caster stands at the left of
## the frame facing right) holds the staff slanted toward `aim`, its stone up front above the
## head, and the right hand hangs at the side - nothing is raised but the staff, so the spell
## plainly comes from it (CINELUX desk k120 / q123: the empty raised hand read as odd).
static func caster(parent: Node, at: Vector3, aim: Vector3, gem: Color = Color(0.75, 0.6, 1.0),
		mat: Material = null, pose: int = 0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Caster"
	parent.add_child(root)
	root.position = at
	var flat: Vector3 = Vector3(aim.x, at.y, aim.z)
	if flat.distance_to(at) > 0.01:
		root.rotation.y = atan2(flat.x - at.x, flat.z - at.z)
	var key: String = "caster" if pose == 0 else "caster_%d" % pose
	var m: ArrayMesh = _cached(key)
	var staff_top: Vector3 = Vector3(0.34, 1.9, 0.14)
	var staff_up: Vector3 = Vector3.UP
	var hand_at: Vector3 = Vector3(-0.1, 1.36, 0.56)
	if pose == 1:
		staff_top = CASTER_STAFF_BUTT + CASTER_STAFF_DIR * CASTER_STAFF_LEN
		staff_up = CASTER_STAFF_DIR
		hand_at = Vector3(0.235, 0.86, 0.04)
	var stone_at: Vector3 = staff_top + staff_up * 0.085
	if m == null:
		var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
		b.kind = 1.0
		_caster_body(b, staff_top, hand_at, pose)
		m = _store(key, b)
	var body: MeshInstance3D = _place(root, m, mat if mat != null else paint_material(), Vector3.ZERO, 0.0, "Robe")
	body.set_meta(&"figure", true)
	PyroluxDemoProps.blob_shadow(root, 0.3)
	var gm: ShaderMaterial = PyroluxDemoProps.glow_material(Color(gem.r * 1.5, gem.g * 1.5, gem.b * 1.5))
	var stone: MeshInstance3D = MeshInstance3D.new()
	stone.name = "Stone"
	var sb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	sb.ellipsoid(Vector3.ZERO, Vector3(0.034, 0.046, 0.034), 10, 6)
	stone.mesh = sb.mesh()
	stone.material_override = gm
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stone.position = stone_at
	root.add_child(stone)
	var tip_local: Vector3 = stone_at + staff_up * 0.06 + Vector3(0.0, 0.0, 0.05)
	root.set_meta(&"tip_local", tip_local)
	root.set_meta(&"hand_local", hand_at + Vector3(0.0, 0.0, 0.06))
	root.set_meta(&"tip", root.global_transform * tip_local if root.is_inside_tree() else at + tip_local)
	root.set_meta(&"gem", gm)
	return root


static func _caster_body(b: PyroluxDemoProps.Builder, staff_top: Vector3, hand_at: Vector3,
		pose: int = 0) -> void:
	var h: float = 1.78
	var r: Rig = Rig.new(h)
	var robe: Color = _paint(0.16, 0.17, 0.27)
	var mantle: Color = _paint(0.27, 0.2, 0.31)
	var trim: Color = _paint(0.62, 0.5, 0.28)
	var dark: Color = _paint(0.04, 0.035, 0.05)
	var glove: Color = _paint(0.24, 0.19, 0.17)
	var wood: Color = _paint(0.46, 0.33, 0.2)
	var staff_x: float = staff_top.x
	var staff_z: float = staff_top.z
	var grip: Vector3 = Vector3(staff_x, 1.2, staff_z)
	if pose == 1:
		# The left fist round the levelled staff at chest height, the right arm hanging.
		grip = CASTER_STAFF_BUTT + CASTER_STAFF_DIR * CASTER_STAFF_GRIP
		r.arms([grip + Vector3(0.02, -0.02, -0.04), hand_at], [Vector3(-0.7, -0.8, -0.4), Vector3(1.0, -0.2, -0.7)])
	else:
		r.arms([hand_at - Vector3(0.0, 0.0, 0.05), grip + Vector3(0.03, -0.02, -0.05)],
			[Vector3(-0.6, -1.0, -0.2), Vector3(1.0, -0.4, -0.6)])
	# The robe, from the shoulders to just above the floor, belted, falling in folds.
	# Rings from the neck down to the hem, so the folds (growing with the ring index) ripple the
	# skirt and leave the chest smooth.
	b.tint = robe
	_trunk(b, Vector2(0.0, 0.0),
		PackedFloat32Array([1.52, 1.47, 1.4, 1.28, 1.12, 1.04, 0.92, 0.62, 0.3, 0.03]),
		PackedFloat32Array([0.1, 0.19, 0.205, 0.19, 0.172, 0.188, 0.205, 0.245, 0.29, 0.33]),
		PackedFloat32Array([0.075, 0.11, 0.125, 0.13, 0.125, 0.135, 0.15, 0.19, 0.225, 0.26]),
		PackedFloat32Array([0.07, 0.105, 0.12, 0.125, 0.125, 0.135, 0.15, 0.2, 0.24, 0.28]),
		PackedFloat32Array([0.0, 0.0, 0.008, 0.012, 0.005, 0.005, 0.008, 0.015, 0.02, 0.02]),
		PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.95, 0.88, 0.8]),
		0.0, 0.07, 9, true, false, 36)
	# Under the hem: dark, and the toes of two boots on the floor.
	b.tint = dark
	b.ellipsoid(Vector3(0.0, 0.05, 0.015), Vector3(0.3, 0.012, 0.24), 16, 4)
	b.tint = _paint(0.2, 0.14, 0.1)
	for sx: float in [-1.0, 1.0]:
		_foot(b, Vector3(sx * 0.09, 0.08, 0.14), Vector3(sx * 0.15, 0.0, 1.0), 0.0, 0.045, 0.04, 0.24)
	# A rope belt with a hanging end.
	b.tint = trim
	b.tube(Vector3(0.0, 1.075, 0.006), Vector3(0.0, 1.105, 0.006), 0.18, 0.176, 20)
	b.tube(Vector3(-0.07, 1.08, 0.13), Vector3(-0.09, 0.82, 0.16), 0.012, 0.01, 6)
	# The mantle over the shoulders, a little wider than the robe, its edge trimmed.
	b.tint = mantle
	_trunk(b, Vector2(0.0, 0.0),
		PackedFloat32Array([1.25, 1.3, 1.4, 1.47, 1.525, 1.55]),
		PackedFloat32Array([0.215, 0.235, 0.245, 0.225, 0.15, 0.09]),
		PackedFloat32Array([0.14, 0.15, 0.145, 0.13, 0.1, 0.07]),
		PackedFloat32Array([0.15, 0.158, 0.15, 0.13, 0.1, 0.07]),
		PackedFloat32Array([0.006, 0.008, 0.008, 0.002, 0.0, 0.0]),
		PackedFloat32Array([0.85, 0.95, 1.0, 1.0, 1.0, 1.0]), 0.0, 0.0, 0, false, true, 22)
	b.tint = Color(trim.r * 0.8, trim.g * 0.8, trim.b * 0.8)
	b.tube(Vector3(0.0, 1.235, 0.006), Vector3(0.0, 1.26, 0.006), 0.218, 0.218, 22)
	# Sleeves, wide at the cuff and dark inside; gloved hands.
	for i: int in 2:
		var sh: Vector3 = r.shoulder[i]
		var el: Vector3 = r.elbow[i]
		var wr: Vector3 = r.wrist[i]
		var dir: Vector3 = (wr - el).normalized()
		b.tint = robe
		_ball(b, sh, 0.06)
		b.tube(sh, el, 0.062, 0.064, 12)
		_ball(b, el, 0.064)
		var cuff: Vector3 = wr - dir * 0.02
		b.tube(el, cuff, 0.064, 0.1, 14)
		b.tint = dark
		b.ellipsoid(cuff - dir * 0.004, Vector3(0.094, 0.006, 0.094), 12, 3, _aim_basis(dir, Vector3.UP))
		b.tint = glove
		b.tube(cuff - dir * 0.03, wr + dir * 0.01, 0.035, 0.03, 8)
		if pose == 1:
			if i == 0:
				_fist(b, grip, dir, h)
			else:
				# The hanging hand, palm toward the robe.
				_hand(b, wr, dir, Vector3(-1.0, 0.0, 0.3), h)
		elif i == 0:
			# The reaching hand, palm toward the target, fingers up.
			_hand(b, wr, Vector3(0.0, 1.0, 0.25), Vector3(0.0, 0.15, 1.0), h)
		else:
			_fist(b, grip, dir, h)
	# Head: dark face in the hood's opening, the hood itself and its peak, a cowl round the neck.
	b.tint = mantle
	b.tube(Vector3(0.0, 1.47, -0.01), Vector3(0.0, 1.6, -0.01), 0.15, 0.11, 18)
	var hood_c: Vector3 = r.head + Vector3(0.0, 0.015, -0.03)
	_trunk(b, Vector2(0.0, hood_c.z),
		_add(PackedFloat32Array([-0.13, -0.07, 0.0, 0.07, 0.12, 0.155]), hood_c.y),
		PackedFloat32Array([0.12, 0.128, 0.13, 0.12, 0.09, 0.04]),
		PackedFloat32Array([0.07, 0.085, 0.09, 0.085, 0.06, 0.03]),
		PackedFloat32Array([0.14, 0.15, 0.15, 0.14, 0.11, 0.05]),
		PackedFloat32Array([0.0, 0.0, 0.0, 0.0, -0.01, -0.03]), PackedFloat32Array(),
		0.0, 0.0, 0, true, true, 18)
	# The opening of the hood: a dark oval set into its front.
	b.tint = dark
	b.ellipsoid(hood_c + Vector3(0.0, -0.025, 0.075), Vector3(0.078, 0.098, 0.03), 14, 8)
	b.tint = mantle
	b.tube(hood_c + Vector3(0.0, 0.13, -0.08), hood_c + Vector3(0.0, 0.07, -0.21), 0.035, 0.004, 8)
	# The staff: from the floor up past the head, three claws holding the stone. Built upright
	# from the origin, then turned and placed (pose 1 slants it toward the target).
	b.tint = wood
	var butt: Vector3 = Vector3(staff_x - 0.01, 0.0, staff_z)
	var axis: Vector3 = Vector3.UP
	var length: float = staff_top.y
	if pose == 1:
		butt = CASTER_STAFF_BUTT
		axis = CASTER_STAFF_DIR
		length = CASTER_STAFF_LEN
	var start: int = b.mark()
	var top: Vector3 = Vector3(0.0, length, 0.0)
	b.tube(Vector3.ZERO, top, 0.024, 0.02, 8, true, false)
	_ball(b, top, 0.03, 8)
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		var c: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var mid: Vector3 = top + c * 0.045 + Vector3(0.0, 0.06, 0.0)
		b.tube(top, mid, 0.011, 0.008, 5)
		b.tube(mid, top + c * 0.02 + Vector3(0.0, 0.13, 0.0), 0.008, 0.004, 5)
	b.xform_from(start, Transform3D(_aim_basis(axis, Vector3.BACK), butt))


# ---------------------------------------------------------------- soldier

## A soldier on guard at `at` facing `aim`: the left foot forward, knees bent, a round shield
## raised before the chest and a spear held upright - the target an arrow or a bullet hits.
## Padded coat, hose and boots, a mail coif and a brimmed kettle hat. One mesh, one surface
## (the shield and spear are part of it). Meta "aim" = {"head", "chest", "shield"} points in
## the mesh's space; aim_point() turns one into a world point.
static func soldier(parent: Node, at: Vector3, aim: Vector3, mat: Material = null) -> MeshInstance3D:
	var m: ArrayMesh = _cached("soldier")
	if m == null:
		var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
		b.kind = 1.0
		_soldier_body(b)
		m = _store("soldier", b)
	var yaw: float = 0.0
	var flat: Vector3 = Vector3(aim.x, at.y, aim.z)
	if flat.distance_to(at) > 0.01:
		yaw = atan2(flat.x - at.x, flat.z - at.z)
	var mi: MeshInstance3D = _place(parent, m, mat if mat != null else paint_material(), at, yaw, "Soldier")
	PyroluxDemoProps.blob_shadow(mi, 0.33)
	mi.set_meta(&"aim", {"head": Vector3(0.0, 1.62, 0.02), "chest": Vector3(0.05, 1.25, 0.1), "shield": Vector3(-0.08, 1.16, 0.46)})
	return mi


## The world point of one of a figure's "aim" metas (head, chest, shield), or its origin.
static func aim_point(fig: Node3D, which: String) -> Vector3:
	if fig.has_meta(&"aim"):
		var d: Dictionary = fig.get_meta(&"aim")
		if d.has(which):
			var p: Vector3 = d[which]
			return fig.global_transform * p
	return fig.global_position


static func _soldier_body(b: PyroluxDemoProps.Builder) -> void:
	var h: float = 1.8
	var drop: float = 0.05
	var r: Rig = Rig.new(h, 0.0, drop)
	var coat: Color = _paint(0.55, 0.45, 0.3)
	var hose: Color = _paint(0.27, 0.25, 0.24)
	var boot: Color = _paint(0.3, 0.2, 0.13)
	var leather: Color = _paint(0.36, 0.24, 0.14)
	var steel: Color = _paint(0.62, 0.63, 0.66)
	var face: Color = _paint(0.12, 0.1, 0.09)
	var wood: Color = _paint(0.52, 0.38, 0.23)
	var paint: Color = _paint(0.5, 0.09, 0.07)
	r.legs([Vector3(-0.13, 0.081, 0.19), Vector3(0.15, 0.081, -0.17)])
	r.toe_dir = [Vector3(-0.15, 0.0, 1.0), Vector3(0.55, 0.0, 1.0)]
	var spear_x: float = 0.31
	var spear_z: float = 0.2
	var shield_c: Vector3 = Vector3(-0.08, 1.16, 0.4)
	var spear_hand: Vector3 = Vector3(spear_x, 1.06, spear_z)
	r.arms([shield_c + Vector3(0.02, 0.0, -0.12), spear_hand + Vector3(0.0, 0.0, -0.06)],
		[Vector3(-1.0, -0.8, -0.2), Vector3(0.35, -1.0, -0.5)])
	# Legs: hose, boots to mid-calf, feet.
	for i: int in 2:
		var hp: Vector3 = r.hip[i]
		var kn: Vector3 = r.knee[i]
		var ank: Vector3 = r.ankle[i]
		b.tint = hose
		_ball(b, hp, 0.074)
		b.tube(hp, kn, 0.073, 0.054, 12)
		_ball(b, kn, 0.055)
		var calf: Vector3 = kn.lerp(ank, 0.3)
		b.tube(kn, calf, 0.054, 0.058, 12)
		b.tint = boot
		var boot_top: Vector3 = kn.lerp(ank, 0.5)
		b.tube(boot_top, ank, 0.062, 0.048, 12, true, false)
		_ball(b, ank, 0.048)
		_foot(b, ank, r.toe_dir[i], 0.0, 0.05, 0.045, 0.27)
	# The padded coat: quilted bands from the shoulders to mid-thigh, its skirt flaring.
	var ys: PackedFloat32Array = PackedFloat32Array()
	var rx: PackedFloat32Array = PackedFloat32Array()
	var rf: PackedFloat32Array = PackedFloat32Array()
	var rb: PackedFloat32Array = PackedFloat32Array()
	var sh: PackedFloat32Array = PackedFloat32Array()
	var key_y: Array[float] = [0.7, 0.8, 0.92, 1.02, 1.08, 1.2, 1.3, 1.38, 1.45, 1.48]
	var key_x: Array[float] = [0.245, 0.225, 0.2, 0.175, 0.168, 0.185, 0.2, 0.205, 0.185, 0.12]
	var key_f: Array[float] = [0.19, 0.175, 0.15, 0.125, 0.12, 0.14, 0.15, 0.14, 0.115, 0.075]
	var key_b: Array[float] = [0.2, 0.18, 0.15, 0.12, 0.115, 0.12, 0.125, 0.12, 0.105, 0.07]
	var steps: int = 22
	for k: int in steps + 1:
		var f: float = float(k) / float(steps) * float(key_y.size() - 1)
		var i0: int = mini(int(f), key_y.size() - 2)
		var t: float = f - float(i0)
		ys.append(lerpf(key_y[i0], key_y[i0 + 1], t) - drop)
		rx.append(lerpf(key_x[i0], key_x[i0 + 1], t))
		rf.append(lerpf(key_f[i0], key_f[i0 + 1], t))
		rb.append(lerpf(key_b[i0], key_b[i0 + 1], t))
		sh.append(1.0 if k % 2 == 0 else 0.86)
	b.tint = coat
	_trunk(b, Vector2(0.0, 0.0), ys, rx, rf, rb, PackedFloat32Array(), sh, 0.0, 0.0, 0, false, true, 20)
	b.tint = Color(coat.r * 0.5, coat.g * 0.5, coat.b * 0.5)
	b.ellipsoid(Vector3(0.0, 0.72 - drop, 0.0), Vector3(0.235, 0.01, 0.185), 16, 3)
	b.tint = leather
	b.tube(Vector3(0.0, 1.0 - drop, 0.0), Vector3(0.0, 1.05 - drop, 0.0), 0.185, 0.178, 20)
	b.tint = steel
	b.metal = 1.0
	b.cbox(Vector3(-0.03, 1.0 - drop, 0.16), Vector3(0.03, 1.05 - drop, 0.19), 0.005)
	b.metal = 0.0
	# Arms in quilted sleeves, leather gloves.
	for i: int in 2:
		var sho: Vector3 = r.shoulder[i]
		var el: Vector3 = r.elbow[i]
		var wr: Vector3 = r.wrist[i]
		var dir: Vector3 = (wr - el).normalized()
		b.tint = coat
		_ball(b, sho, 0.066)
		b.tube(sho, el, 0.064, 0.054, 12)
		b.tint = Color(coat.r * 0.88, coat.g * 0.88, coat.b * 0.88)
		_ball(b, el, 0.055)
		b.tint = coat
		b.tube(el, wr, 0.054, 0.044, 12)
		b.tint = leather
		b.tube(wr - dir * 0.03, wr + dir * 0.015, 0.047, 0.04, 10)
		_fist(b, wr + dir * 0.055, dir, h)
	# The head under a mail coif and a kettle hat with a wide brim; the face in shadow.
	var hc: Vector3 = r.head + Vector3(0.0, 0.0, 0.01)
	b.tint = face
	_egg(b, hc + Vector3(0.0, -0.005, 0.012), Vector3(0.075, 0.115, 0.093), 0.82)
	b.tint = steel
	b.metal = 1.0
	b.tint = Color(steel.r * 0.75, steel.g * 0.75, steel.b * 0.75)
	_trunk(b, Vector2(0.0, -0.01),
		_add(PackedFloat32Array([-0.22, -0.17, -0.11, -0.05, 0.02, 0.07]), hc.y),
		PackedFloat32Array([0.16, 0.135, 0.1, 0.095, 0.097, 0.09]),
		PackedFloat32Array([0.115, 0.1, 0.09, 0.08, 0.06, 0.05]),
		PackedFloat32Array([0.12, 0.11, 0.1, 0.105, 0.105, 0.098]),
		PackedFloat32Array(), PackedFloat32Array(), 0.0, 0.0, 0, false, false, 20)
	b.tint = steel
	var brim_y: float = hc.y + 0.055
	var hat: PackedVector2Array = PackedVector2Array([Vector2(0.0, brim_y - 0.004), Vector2(0.12, brim_y - 0.004),
		Vector2(0.2, brim_y - 0.03), Vector2(0.205, brim_y - 0.022), Vector2(0.125, brim_y + 0.006),
		Vector2(0.115, brim_y + 0.07), Vector2(0.08, brim_y + 0.115), Vector2(0.02, brim_y + 0.13), Vector2(0.0, brim_y + 0.13)])
	b.lathe(hat, 24, Vector3(0.0, 0.0, hc.z - 0.005), 40.0)
	b.metal = 0.0
	# The spear: an ash shaft from the floor to well over the head, a leaf-shaped head.
	b.tint = wood
	b.tube(Vector3(spear_x, 0.0, spear_z), Vector3(spear_x, 2.24, spear_z), 0.017, 0.016, 8, true, false)
	b.metal = 1.0
	b.tint = steel
	b.tube(Vector3(spear_x, 2.2, spear_z), Vector3(spear_x, 2.27, spear_z), 0.021, 0.018, 8)
	var leaf: Array[PackedVector3Array] = []
	var lc: PackedVector3Array = PackedVector3Array()
	for yy: float in [2.26, 2.3, 2.38, 2.45, 2.5]:
		var w: float = 0.004
		if yy > 2.27 and yy < 2.49:
			w = 0.042 * sin((yy - 2.26) / 0.24 * PI)
		leaf.append(PackedVector3Array([Vector3(spear_x + w, yy, spear_z), Vector3(spear_x, yy, spear_z + 0.009),
			Vector3(spear_x - w, yy, spear_z), Vector3(spear_x, yy, spear_z - 0.009)]))
		lc.append(Vector3(spear_x, yy, spear_z))
	b.loft(leaf, lc)
	b.metal = 0.0
	# The round shield before the chest: a painted, slightly domed face, an iron rim and boss.
	var mk: int = b.mark()
	var face_prof: PackedVector2Array = PackedVector2Array([Vector2(0.0, -0.02), Vector2(0.3, -0.02),
		Vector2(0.33, -0.004), Vector2(0.3, 0.012), Vector2(0.2, 0.03), Vector2(0.0, 0.04)])
	b.tint = paint
	b.lathe(face_prof, 28, Vector3.ZERO, 30.0, PackedFloat32Array([0.55, 0.55, 0.9, 1.0, 1.0, 1.0]))
	b.metal = 1.0
	b.tint = _paint(0.4, 0.4, 0.42)
	var rim: PackedVector2Array = PackedVector2Array([Vector2(0.295, 0.004), Vector2(0.335, -0.012),
		Vector2(0.345, 0.0), Vector2(0.335, 0.016), Vector2(0.295, 0.02)])
	b.lathe(rim, 28, Vector3.ZERO, 50.0)
	var boss: PackedVector2Array = PackedVector2Array([Vector2(0.085, 0.03), Vector2(0.075, 0.06),
		Vector2(0.05, 0.085), Vector2(0.0, 0.095)])
	b.lathe(boss, 16, Vector3.ZERO, 60.0)
	b.metal = 0.0
	b.xform_from(mk, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(80.0)), shield_c))


# ---------------------------------------------------------------- placing, cache

static func _place(parent: Node, m: Mesh, mat: Material, at: Vector3, yaw: float, label: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = label
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


static func _cached(key: String) -> ArrayMesh:
	if _cache.has(key):
		var m: ArrayMesh = null
		m = _cache[key]
		return m
	return null


static func _store(key: String, b: PyroluxDemoProps.Builder) -> ArrayMesh:
	var m: ArrayMesh = b.mesh()
	_cache[key] = m
	return m

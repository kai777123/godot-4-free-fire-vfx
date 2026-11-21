class_name PyroluxDemoSdf
extends RefCounted
## Demo only: smooth shapes built as ONE surface. Round cones and ellipsoids are blended with a
## smooth minimum (a signed distance field), polygonised with surface nets on a regular grid, and
## lit with normals taken from the field's gradient, so there is no seam or facet where a leg,
## the neck or the tail meets the body (the parts of a Builder mesh cut into each other there).
## Kit v12 (2026-10-31, look_1031): the hound standing and the hound fallen on its belly.
##
##   var dog: MeshInstance3D = PyroluxDemoSdf.fallen_hound(root, Vector3(0, 0, 0), -PI * 0.5)
##
## Building takes about a second on a desktop (the mesh is cached per pose), so a web demo builds
## it during the warm-up: call hound_mesh() / fallen_hound_mesh() from a warm-up job.
## Generated from WS/shared/demo_kit/demo_sdf.gd by tools/vfxpack/demo_kit_sync.py.

## The grid's cell in metres. 0.011 made 22.6k vertices in 2.9 s; the normals come from the
## field, so a coarser grid still reads as smooth.
const CELL: float = 0.0135
## The fallen hound is built at the standing hound's proportions and scaled by this.
const DOWN_SCALE: float = 0.92
## Half the soft edge of a colour band (a belt), in metres: about half a grid cell.
const BAND_SOFT: float = 0.006

static var _cache: Dictionary = {}


## One field: a list of primitives, each blended into the ones before it.
class Shape:
	extends RefCounted
	# [type, a, b, ra, rb, k, tint, carve, zs]: type 0 = round cone a -> b (radii ra, rb; with zs < 1
	# its section is an ellipse squashed to zs in depth), 1 = ellipsoid (a = centre, b = radii),
	# 2 = the half-space under the height a.y; k = the blend width with what came before (0 = a
	# hard union); carve = the primitive is cut out of what came before (smooth by k) instead of
	# added. A primitive changes only what came before it: add a part inside a cut after the cut.
	var prims: Array = []
	## The colour of the primitives added from now on (vertex colour, as it looks), and whether
	## the mesh carries colours at all (set by the first tint).
	var tint: Color = Color(1, 1, 1):
		set(value):
			tint = value
			colored = true
	var colored: bool = false
	## Colour bands: [y0, y1, colour, only_tint] - vertices between y0 and y1 whose own colour is
	## only_tint take the band's colour (a belt, a hem), a crisp line on one smooth surface.
	var bands: Array = []

	func cone(a: Vector3, b: Vector3, ra: float, rb: float, k: float, zs: float = 1.0) -> void:
		var q: Vector3 = Vector3(1.0, 1.0, 1.0 / zs)
		prims.append([0, a * q, b * q, ra, rb, k, tint, false, zs])

	func ell(c: Vector3, r: Vector3, k: float) -> void:
		prims.append([1, c, r, 0.0, 0.0, k, tint, false, 1.0])

	## Cuts an ellipsoid out of what came before (a hood's opening).
	func cut_ell(c: Vector3, r: Vector3, k: float) -> void:
		prims.append([1, c, r, 0.0, 0.0, k, tint, true, 1.0])

	## Cuts away everything under the height y (a robe's hem on the floor).
	func cut_below(y: float, k: float) -> void:
		prims.append([2, Vector3(0.0, y, 0.0), Vector3.ZERO, 0.0, 0.0, k, tint, true, 1.0])

	## Both sides of the body: the primitive at x and at -x.
	func cone2(a: Vector3, b: Vector3, ra: float, rb: float, k: float) -> void:
		cone(a, b, ra, rb, k)
		cone(a * Vector3(-1, 1, 1), b * Vector3(-1, 1, 1), ra, rb, k)

	func ell2(c: Vector3, r: Vector3, k: float) -> void:
		ell(c, r, k)
		ell(c * Vector3(-1, 1, 1), r, k)

	func prim_d(pr: Array, p: Vector3) -> float:
		var ty: int = pr[0]
		if ty == 0:
			var a: Vector3 = pr[1]
			var b: Vector3 = pr[2]
			var ra: float = pr[3]
			var rb: float = pr[4]
			var zs: float = pr[8]
			var q: Vector3 = Vector3(p.x, p.y, p.z / zs)
			var ba: Vector3 = b - a
			var t: float = clampf((q - a).dot(ba) / ba.length_squared(), 0.0, 1.0)
			return ((q - (a + ba * t)).length() - lerpf(ra, rb, t)) * minf(zs, 1.0)
		if ty == 2:
			var h: Vector3 = pr[1]
			return p.y - h.y
		var c: Vector3 = pr[1]
		var r: Vector3 = pr[2]
		var k0: float = ((p - c) / r).length()
		var k1: float = ((p - c) / (r * r)).length()
		if k1 < 1e-6:
			return -minf(r.x, minf(r.y, r.z))
		return k0 * (k0 - 1.0) / k1

	func sdf(p: Vector3, idx: PackedInt32Array) -> float:
		var d: float = 1e9
		for i: int in idx:
			var pr: Array = prims[i]
			var di: float = prim_d(pr, p)
			var k: float = pr[5]
			var carve: bool = pr[7]
			if carve:
				if k <= 0.0:
					d = maxf(d, -di)
				else:
					var hc: float = maxf(k - absf(d + di), 0.0) / k
					d = maxf(d, -di) + hc * hc * k * 0.25
			elif k <= 0.0 or d > 1e8:
				d = minf(d, di)
			else:
				var h: float = maxf(k - absf(d - di), 0.0) / k
				d = minf(d, di) - h * h * k * 0.25
		return d

	## The colour at surface point p: the primitives whose own surface is nearest, mixed over about
	## a centimetre (a soft edge between colours, not the grid's stair steps), each primitive's
	## colour first given its bands (with a soft edge of BAND_SOFT).
	func colour(p: Vector3, idx: PackedInt32Array) -> Color:
		var best: float = 1e9
		var ds: PackedFloat32Array = PackedFloat32Array()
		ds.resize(idx.size())
		for j: int in idx.size():
			var pr: Array = prims[idx[j]]
			var di: float = absf(prim_d(pr, p))
			ds[j] = di
			best = minf(best, di)
		var acc: Color = Color(0, 0, 0, 0)
		var wsum: float = 0.0
		for j: int in idx.size():
			var w: float = exp(-(ds[j] - best) / 0.009)
			if w < 0.01:
				continue
			var pr: Array = prims[idx[j]]
			var c: Color = pr[6]
			acc += banded(c, p.y) * w
			wsum += w
		var out: Color = acc / maxf(wsum, 1e-6)
		out.a = 1.0
		return out

	## A primitive's colour `c` at height y after the bands that apply to it.
	func banded(c: Color, y: float) -> Color:
		var out: Color = c
		for bd: Array in bands:
			var only: Color = bd[3]
			if not c.is_equal_approx(only):
				continue
			var y0: float = bd[0]
			var y1: float = bd[1]
			var w: float = smoothstep(y0 - BAND_SOFT, y0 + BAND_SOFT, y) * (1.0 - smoothstep(y1 - BAND_SOFT, y1 + BAND_SOFT, y))
			var bc: Color = bd[2]
			out = out.lerp(bc, w)
		return out

	func near(c: Vector3, rad: float) -> PackedInt32Array:
		var out: PackedInt32Array = PackedInt32Array()
		for i: int in prims.size():
			var pr: Array = prims[i]
			if prim_d(pr, c) < rad + 0.14:
				out.append(i)
		return out

	## The field polygonised inside lo..hi (surface nets), scaled by `scale` about the origin.
	func build(lo: Vector3, hi: Vector3, cell: float, scale: float = 1.0) -> ArrayMesh:
		var n: Vector3i = Vector3i(((hi - lo) / cell).ceil()) + Vector3i.ONE
		var blk: int = 6
		var vals: PackedFloat32Array = PackedFloat32Array()
		vals.resize(n.x * n.y * n.z)
		vals.fill(1.0)
		var all_idx: PackedInt32Array = PackedInt32Array(range(prims.size()))
		for bx: int in range(0, n.x, blk):
			for by: int in range(0, n.y, blk):
				for bz: int in range(0, n.z, blk):
					var c: Vector3 = lo + Vector3(bx + blk * 0.5, by + blk * 0.5, bz + blk * 0.5) * cell
					var brad: float = blk * cell * 0.9
					var dc: float = sdf(c, all_idx)
					if absf(dc) > brad + 0.02:
						var fillv: float = signf(dc)
						for x: int in range(bx, mini(bx + blk + 1, n.x)):
							for y: int in range(by, mini(by + blk + 1, n.y)):
								for z: int in range(bz, mini(bz + blk + 1, n.z)):
									vals[(x * n.y + y) * n.z + z] = fillv
						continue
					var idx: PackedInt32Array = near(c, brad)
					for x: int in range(bx, mini(bx + blk + 1, n.x)):
						for y: int in range(by, mini(by + blk + 1, n.y)):
							for z: int in range(bz, mini(bz + blk + 1, n.z)):
								vals[(x * n.y + y) * n.z + z] = sdf(lo + Vector3(x, y, z) * cell, idx)
		# Surface nets: one vertex per cell the surface crosses, at the mean of its edge crossings.
		var vid: Dictionary = {}
		var verts: PackedVector3Array = PackedVector3Array()
		var norms: PackedVector3Array = PackedVector3Array()
		var corners: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
			Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
		var edges: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7])
		var cv: PackedFloat32Array = PackedFloat32Array()
		cv.resize(8)
		for x: int in n.x - 1:
			for y: int in n.y - 1:
				for z: int in n.z - 1:
					var neg: int = 0
					for ci: int in 8:
						var co: Vector3i = corners[ci]
						var v: float = vals[((x + co.x) * n.y + y + co.y) * n.z + z + co.z]
						cv[ci] = v
						if v < 0.0:
							neg += 1
					if neg == 0 or neg == 8:
						continue
					var acc: Vector3 = Vector3.ZERO
					var cnt: int = 0
					for ei: int in 12:
						var ea: int = edges[ei * 2]
						var eb: int = edges[ei * 2 + 1]
						var va: float = cv[ea]
						var vb: float = cv[eb]
						if (va < 0.0) != (vb < 0.0):
							acc += Vector3(corners[ea]).lerp(Vector3(corners[eb]), va / (va - vb))
							cnt += 1
					vid[Vector3i(x, y, z)] = verts.size()
					verts.append(lo + (Vector3(x, y, z) + acc / cnt) * cell)
		var eps: float = cell * 0.5
		var cols: PackedColorArray = PackedColorArray()
		for i: int in verts.size():
			var p: Vector3 = verts[i]
			var idx: PackedInt32Array = near(p, 0.02)
			if colored:
				cols.append(colour(p, idx))
			var g: Vector3 = Vector3(
				sdf(p + Vector3(eps, 0, 0), idx) - sdf(p - Vector3(eps, 0, 0), idx),
				sdf(p + Vector3(0, eps, 0), idx) - sdf(p - Vector3(0, eps, 0), idx),
				sdf(p + Vector3(0, 0, eps), idx) - sdf(p - Vector3(0, 0, eps), idx))
			norms.append(g.normalized())
			verts[i] = p * scale
		var axes: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
		var us: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)]
		var ws: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)]
		var ids: PackedInt32Array = PackedInt32Array()
		for x: int in range(1, n.x - 1):
			for y: int in range(1, n.y - 1):
				for z: int in range(1, n.z - 1):
					var v0: float = vals[(x * n.y + y) * n.z + z]
					for ax: int in 3:
						var q: Vector3i = Vector3i(x, y, z) + axes[ax]
						if q.x >= n.x or q.y >= n.y or q.z >= n.z:
							continue
						var v1: float = vals[(q.x * n.y + q.y) * n.z + q.z]
						if (v0 < 0.0) == (v1 < 0.0):
							continue
						var c00: Vector3i = Vector3i(x, y, z) - us[ax] - ws[ax]
						var keys: Array[Vector3i] = [c00, c00 + us[ax], c00 + us[ax] + ws[ax], c00 + ws[ax]]
						var q4: PackedInt32Array = PackedInt32Array()
						for kk: Vector3i in keys:
							if not vid.has(kk):
								break
							var vi: int = vid[kk]
							q4.append(vi)
						if q4.size() < 4:
							continue
						# Godot's front faces wind clockwise seen from outside.
						if v0 < 0.0:
							ids.append_array(PackedInt32Array([q4[0], q4[2], q4[1], q4[0], q4[3], q4[2]]))
						else:
							ids.append_array(PackedInt32Array([q4[0], q4[1], q4[2], q4[0], q4[2], q4[3]]))
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_INDEX] = ids
		if colored:
			# The kit's prop shader: COLOR is the paint, UV2 = (metal 0, face kind 1 = side).
			arr[Mesh.ARRAY_COLOR] = cols
			var uv2: PackedVector2Array = PackedVector2Array()
			uv2.resize(verts.size())
			uv2.fill(Vector2(0.0, 1.0))
			arr[Mesh.ARRAY_TEX_UV2] = uv2
		var m: ArrayMesh = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


## A hound standing on `at`, facing +Z turned by `yaw`: a deep chest and a tucked waist, a long
## neck and muzzle, pricked ears, four legs with real joints, a low tail. About 1.9 m from the
## tail tip to the nose, 1.0 m to the ear tips. One MeshInstance3D (white unless `mat` is given).
static func hound(parent: Node, at: Vector3, yaw: float = 0.0, mat: Material = null) -> MeshInstance3D:
	var h: MeshInstance3D = _place(hound_mesh(), parent, at, yaw, mat)
	PyroluxDemoProps.blob_shadow(h, 0.33, 1.6)
	return h


## The hound fallen on its belly at `at`, muzzle along the local +Z turned by `yaw`: the head laid
## on the floor between the stretched forelegs, the hind legs folded along the flanks with the
## paws forward, the tail laid out behind and curling to one side. About 1.6 m long, 0.4 m high.
static func fallen_hound(parent: Node, at: Vector3, yaw: float = 0.0, mat: Material = null) -> MeshInstance3D:
	var h: MeshInstance3D = _place(fallen_hound_mesh(), parent, at, yaw, mat)
	PyroluxDemoProps.blob_shadow(h, 0.37, 1.5)
	return h


## Kit 13: the shapes a demo uses, baked to .res once (1-3 s each to build on a desktop, several
## times that in a browser: JANULUX's first effect 19.1 s -> 13.9 s once baked). `names` are the
## cache keys: "hound", "hound_down", "caster_0", "caster_1". bake() writes them (run headless:
## a SceneTree script calling <P>DemoSdf.bake(["caster_1"]) and quit(); again when the kit's
## version changes), use_baked() puts what is there in the cache before anything is built.
const BAKED_DIR: String = "res://demo/sdf_baked/"


static func bake(names: Array, dir: String = BAKED_DIR) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for v: Variant in names:
		var n: String = str(v)
		var m: ArrayMesh = null
		if n == "hound":
			m = hound_mesh()
		elif n == "hound_down":
			m = fallen_hound_mesh()
		elif n.begins_with("caster_"):
			m = caster_mesh(int(n.substr(7)))
		if m != null:
			print("DemoSdf.bake %s %d" % [n, ResourceSaver.save(m, dir + n + ".res", ResourceSaver.FLAG_COMPRESS)])


static func use_baked(names: Array, dir: String = BAKED_DIR) -> void:
	for v: Variant in names:
		var n: String = str(v)
		var key: StringName = StringName(n)
		if _cache.has(key) or not ResourceLoader.exists(dir + n + ".res"):
			continue
		var m: ArrayMesh = load(dir + n + ".res") as ArrayMesh
		if m != null:
			_cache[key] = m


static func hound_mesh() -> ArrayMesh:
	var m: ArrayMesh = _cache.get(&"hound", null)
	if m == null:
		m = _hound_shape().build(Vector3(-0.25, -0.02, -1.02), Vector3(0.25, 1.06, 0.92), CELL)
		_cache[&"hound"] = m
	return m


static func fallen_hound_mesh() -> ArrayMesh:
	var m: ArrayMesh = _cache.get(&"hound_down", null)
	if m == null:
		m = _down_shape().build(Vector3(-0.32, -0.02, -1.0), Vector3(0.32, 0.54, 0.92), CELL, DOWN_SCALE)
		_cache[&"hound_down"] = m
	return m


static func _place(m: ArrayMesh, parent: Node, at: Vector3, yaw: float, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Hound"
	mi.mesh = m
	mi.material_override = mat if mat != null else PyroluxDemoFigure.white_material()
	mi.position = at
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


static func _head(s: Shape, skull: Vector3, down: float) -> void:
	# Skull, a muzzle tapering forward (lowered by `down` at the nose), the jaw, the nose, the ears.
	s.ell(skull, Vector3(0.088, 0.088, 0.105), 0.05)
	s.cone(skull + Vector3(0, -0.01, 0.055), skull + Vector3(0, -0.045 - down, 0.235), 0.064, 0.04, 0.05)
	s.ell(skull + Vector3(0, -0.075, 0.115), Vector3(0.05, 0.035, 0.09), 0.03)
	s.ell(skull + Vector3(0, -0.04 - down, 0.258), Vector3(0.028, 0.024, 0.022), 0.015)


static func _hound_shape() -> Shape:
	var s: Shape = Shape.new()
	# Body: a deep chest, the tucked waist, the rump.
	s.ell(Vector3(0, 0.555, 0.20), Vector3(0.165, 0.235, 0.26), 0.0)
	s.cone(Vector3(0, 0.58, 0.18), Vector3(0, 0.58, -0.28), 0.15, 0.115, 0.09)
	s.ell(Vector3(0, 0.585, -0.38), Vector3(0.14, 0.145, 0.17), 0.08)
	# Neck and head.
	s.cone(Vector3(0, 0.62, 0.28), Vector3(0, 0.83, 0.52), 0.13, 0.078, 0.1)
	_head(s, Vector3(0, 0.875, 0.585), 0.0)
	s.cone2(Vector3(0.045, 0.93, 0.565), Vector3(0.085, 1.02, 0.54), 0.03, 0.007, 0.018)
	# Front legs: the upper arm from inside the chest (a wide blend: a separate shoulder ball showed
	# as a lump, look_1031) back to the elbow, the forearm straight down, the pastern, the paw.
	s.cone2(Vector3(0.09, 0.56, 0.27), Vector3(0.115, 0.34, 0.22), 0.06, 0.042, 0.12)
	s.cone2(Vector3(0.115, 0.34, 0.22), Vector3(0.118, 0.1, 0.25), 0.036, 0.026, 0.03)
	s.cone2(Vector3(0.118, 0.1, 0.25), Vector3(0.12, 0.04, 0.28), 0.026, 0.024, 0.02)
	s.ell2(Vector3(0.12, 0.028, 0.295), Vector3(0.038, 0.028, 0.05), 0.02)
	# Hind legs: the thigh, forward to the stifle, back down to the hock, the metatarsus nearly
	# upright to the paw (both hind legs alike, the weight on all four feet).
	s.ell2(Vector3(0.085, 0.53, -0.38), Vector3(0.06, 0.13, 0.13), 0.18)
	s.cone2(Vector3(0.1, 0.48, -0.38), Vector3(0.122, 0.33, -0.3), 0.07, 0.045, 0.1)
	s.cone2(Vector3(0.122, 0.33, -0.3), Vector3(0.126, 0.18, -0.44), 0.042, 0.028, 0.03)
	s.cone2(Vector3(0.126, 0.18, -0.44), Vector3(0.128, 0.045, -0.41), 0.027, 0.024, 0.02)
	s.ell2(Vector3(0.128, 0.028, -0.385), Vector3(0.038, 0.028, 0.05), 0.02)
	# Tail, low and curving.
	s.cone(Vector3(0, 0.6, -0.52), Vector3(0, 0.5, -0.7), 0.038, 0.03, 0.04)
	s.cone(Vector3(0, 0.5, -0.7), Vector3(0, 0.43, -0.88), 0.03, 0.02, 0.02)
	s.cone(Vector3(0, 0.43, -0.88), Vector3(0, 0.44, -0.98), 0.02, 0.012, 0.015)
	return s


static func _down_shape() -> Shape:
	var s: Shape = Shape.new()
	# Body on the floor: the chest and the rump rest on it (bottoms at about 0.035 m).
	s.ell(Vector3(0, 0.255, 0.12), Vector3(0.17, 0.22, 0.25), 0.0)
	s.cone(Vector3(0, 0.25, 0.1), Vector3(0, 0.235, -0.24), 0.15, 0.125, 0.09)
	s.ell(Vector3(0, 0.215, -0.34), Vector3(0.155, 0.165, 0.18), 0.08)
	# Neck stretched forward and down, the head laid on the floor between the forepaws.
	s.cone(Vector3(0, 0.31, 0.22), Vector3(0, 0.23, 0.5), 0.13, 0.088, 0.1)
	_head(s, Vector3(0, 0.175, 0.6), 0.03)
	# Ears laid back along the neck.
	s.cone2(Vector3(0.05, 0.24, 0.575), Vector3(0.095, 0.34, 0.53), 0.036, 0.009, 0.02)
	# Forelegs: the upper arm from inside the chest down to the elbow on the floor, the forearm stretched out
	# ahead along the floor, the paw.
	s.cone2(Vector3(0.09, 0.2, 0.22), Vector3(0.13, 0.055, 0.36), 0.06, 0.04, 0.12)
	s.cone2(Vector3(0.13, 0.05, 0.36), Vector3(0.125, 0.034, 0.62), 0.038, 0.028, 0.03)
	s.ell2(Vector3(0.122, 0.028, 0.66), Vector3(0.04, 0.028, 0.054), 0.02)
	# Hind legs folded along the flanks: the thigh, forward to the stifle beside the belly, back
	# down to the hock on the floor, the metatarsus and the paw forward along the floor.
	s.ell2(Vector3(0.1, 0.2, -0.31), Vector3(0.07, 0.13, 0.14), 0.18)
	s.cone2(Vector3(0.12, 0.19, -0.27), Vector3(0.18, 0.085, -0.14), 0.07, 0.045, 0.1)
	s.cone2(Vector3(0.18, 0.085, -0.14), Vector3(0.19, 0.04, -0.39), 0.042, 0.03, 0.03)
	s.cone2(Vector3(0.2, 0.035, -0.39), Vector3(0.215, 0.03, -0.21), 0.027, 0.025, 0.02)
	s.ell2(Vector3(0.218, 0.027, -0.175), Vector3(0.04, 0.027, 0.052), 0.02)
	# Tail laid out behind, curling to one side.
	s.cone(Vector3(0, 0.24, -0.48), Vector3(0.04, 0.12, -0.66), 0.045, 0.036, 0.04)
	s.cone(Vector3(0.04, 0.12, -0.66), Vector3(0.12, 0.05, -0.8), 0.036, 0.026, 0.02)
	s.cone(Vector3(0.12, 0.05, -0.8), Vector3(0.2, 0.04, -0.9), 0.026, 0.016, 0.015)
	return s


# ---------------------------------------------------------------- the caster

## The hooded caster (DemoFigure.caster's pose and metas) as one smooth robed body: robe, mantle,
## hood with a dark opening, sleeves and gloved hands blended into each other, the rope belt a
## crisp colour band; the staff a fine round shaft with three claws round the glowing stone.
## Pose 0: the staff planted upright in the right hand, the left hand reaching toward `aim`;
## pose 1: the staff levelled toward `aim` in the left hand, the right hand hanging. Metas
## tip_local / hand_local / tip / gem as DemoFigure.caster (gem: the stone's ShaderMaterial).
static func caster(parent: Node, at: Vector3, aim: Vector3, gem: Color = Color(0.75, 0.6, 1.0),
		mat: Material = null, pose: int = 0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Caster"
	parent.add_child(root)
	root.position = at
	var flat: Vector3 = Vector3(aim.x, at.y, aim.z)
	if flat.distance_to(at) > 0.01:
		root.rotation.y = atan2(flat.x - at.x, flat.z - at.z)
	var staff_top: Vector3 = Vector3(0.34, 1.9, 0.14)
	var staff_up: Vector3 = Vector3.UP
	if pose == 1:
		staff_top = PyroluxDemoFigure.CASTER_STAFF_BUTT + PyroluxDemoFigure.CASTER_STAFF_DIR * PyroluxDemoFigure.CASTER_STAFF_LEN
		staff_up = PyroluxDemoFigure.CASTER_STAFF_DIR
	var stone_at: Vector3 = staff_top + staff_up * 0.085
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Robe"
	body.mesh = caster_mesh(pose)
	body.material_override = mat if mat != null else PyroluxDemoFigure.paint_material()
	body.set_meta(&"figure", true)
	root.add_child(body)
	PyroluxDemoProps.blob_shadow(root, 0.3)
	var gm: ShaderMaterial = PyroluxDemoProps.glow_material(Color(gem.r * 1.5, gem.g * 1.5, gem.b * 1.5))
	var stone: MeshInstance3D = MeshInstance3D.new()
	stone.name = "Stone"
	var sb: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	sb.ellipsoid(Vector3.ZERO, Vector3(0.034, 0.046, 0.034), 24, 14)
	stone.mesh = sb.mesh()
	stone.material_override = gm
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stone.position = stone_at
	root.add_child(stone)
	var hand_at: Vector3 = Vector3(-0.1, 1.36, 0.56) if pose == 0 else Vector3(0.235, 0.86, 0.04)
	var tip_local: Vector3 = stone_at + staff_up * 0.06 + Vector3(0.0, 0.0, 0.05)
	root.set_meta(&"tip_local", tip_local)
	root.set_meta(&"hand_local", hand_at + Vector3(0.0, 0.0, 0.06))
	root.set_meta(&"tip", root.global_transform * tip_local if root.is_inside_tree() else at + tip_local)
	root.set_meta(&"gem", gm)
	return root


## The caster's mesh for `pose` (cached): the smooth body and, as a second surface, the staff.
static func caster_mesh(pose: int = 0) -> ArrayMesh:
	var key: StringName = StringName("caster_%d" % pose)
	var m: ArrayMesh = _cache.get(key, null)
	if m != null:
		return m
	var h: float = 1.78
	var r: PyroluxDemoFigure.Rig = PyroluxDemoFigure.Rig.new(h)
	var staff_top: Vector3 = Vector3(0.34, 1.9, 0.14)
	var hand_at: Vector3 = Vector3(-0.1, 1.36, 0.56)
	var grip: Vector3 = Vector3(staff_top.x, 1.2, staff_top.z)
	if pose == 1:
		staff_top = PyroluxDemoFigure.CASTER_STAFF_BUTT + PyroluxDemoFigure.CASTER_STAFF_DIR * PyroluxDemoFigure.CASTER_STAFF_LEN
		hand_at = Vector3(0.235, 0.86, 0.04)
		grip = PyroluxDemoFigure.CASTER_STAFF_BUTT + PyroluxDemoFigure.CASTER_STAFF_DIR * PyroluxDemoFigure.CASTER_STAFF_GRIP
		r.arms([grip + Vector3(0.02, -0.02, -0.04), hand_at], [Vector3(-0.7, -0.8, -0.4), Vector3(1.0, -0.2, -0.7)])
	else:
		r.arms([hand_at - Vector3(0.0, 0.0, 0.05), grip + Vector3(0.03, -0.02, -0.05)],
			[Vector3(-0.6, -1.0, -0.2), Vector3(1.0, -0.4, -0.6)])
	var robe: Color = Color(0.16, 0.17, 0.27)
	var mantle: Color = Color(0.27, 0.2, 0.31)
	var trim: Color = Color(0.62, 0.5, 0.28)
	var dark: Color = Color(0.03, 0.028, 0.04)
	var glove: Color = Color(0.24, 0.19, 0.17)
	var s: Shape = Shape.new()
	# The robe: chest, the belted waist, the skirt widening to the hem on the floor. Oval in
	# section (zs: the depth's share of the width).
	s.tint = robe
	s.cone(Vector3(0.0, 1.43, -0.01), Vector3(0.0, 1.08, 0.0), 0.19, 0.17, 0.0, 0.68)
	s.cone(Vector3(0.0, 1.08, 0.0), Vector3(0.0, 0.56, 0.01), 0.17, 0.235, 0.1, 0.78)
	s.cone(Vector3(0.0, 0.56, 0.01), Vector3(0.0, 0.12, 0.02), 0.235, 0.3, 0.12, 0.86)
	s.cut_below(0.012, 0.03)
	s.bands.append([1.07, 1.105, trim, robe])
	# The toes of two boots under the hem.
	s.tint = Color(0.2, 0.14, 0.1)
	for sx: float in [-1.0, 1.0]:
		s.ell(Vector3(sx * 0.09, 0.035, 0.24), Vector3(0.05, 0.035, 0.08), 0.015)
	# The mantle: the robe's colour over the shoulders and the upper sleeves (a band, so no extra
	# volume: a mantle shape of its own read as a bust), its lower edge trimmed; the cowl round
	# the neck.
	s.bands.append([1.205, 1.228, Color(trim.r * 0.8, trim.g * 0.8, trim.b * 0.8), robe])
	s.bands.append([1.228, 9.0, mantle, robe])
	s.tint = mantle
	s.cone(Vector3(0.0, 1.46, -0.01), Vector3(0.0, 1.6, -0.01), 0.14, 0.1, 0.05)
	# The hood, its peak falling back, the opening cut into its front, the dark face inside.
	var hood_c: Vector3 = r.head + Vector3(0.0, 0.015, -0.03)
	s.ell(hood_c, Vector3(0.128, 0.152, 0.15), 0.04)
	s.cone(hood_c + Vector3(0.0, 0.13, -0.08), hood_c + Vector3(0.0, 0.06, -0.22), 0.035, 0.006, 0.03)
	s.tint = dark
	s.cut_ell(hood_c + Vector3(0.0, -0.03, 0.14), Vector3(0.078, 0.102, 0.12), 0.02)
	s.ell(hood_c + Vector3(0.0, -0.035, -0.03), Vector3(0.08, 0.095, 0.06), 0.0)
	# Sleeves widening to the cuff, the glove coming out of it, the hands.
	for i: int in 2:
		var sh: Vector3 = r.shoulder[i]
		var el: Vector3 = r.elbow[i]
		var wr: Vector3 = r.wrist[i]
		var dir: Vector3 = (wr - el).normalized()
		var cuff: Vector3 = wr - dir * 0.03
		s.tint = robe
		s.cone(sh + Vector3(0.0, -0.02, 0.0), el, 0.07, 0.066, 0.06)
		s.cone(el, cuff, 0.066, 0.092, 0.03)
		s.tint = dark
		s.cut_ell(cuff + dir * 0.03, Vector3(0.07, 0.07, 0.07), 0.01)
		s.tint = glove
		s.cone(cuff - dir * 0.04, wr + dir * 0.02, 0.036, 0.032, 0.01)
		if pose == 1:
			if i == 0:
				s.ell(grip, Vector3(0.048, 0.056, 0.05), 0.015)
			else:
				s.cone(wr + dir * 0.02, wr + dir * 0.11, 0.038, 0.028, 0.015)
		elif i == 0:
			# The reaching hand, an open palm toward the target, the fingers up.
			s.ell(wr + Vector3(0.0, 0.055, 0.02), Vector3(0.046, 0.065, 0.022), 0.015)
		else:
			s.ell(grip, Vector3(0.048, 0.056, 0.05), 0.015)
	m = s.build(Vector3(-0.56, -0.02, -0.42), Vector3(0.56, 1.88, 0.66), CELL)
	# The staff: a fine round shaft from the floor past the head, a knob and three claws round the
	# stone. Built upright from the origin, then turned and placed (pose 1 slants it).
	var b: PyroluxDemoProps.Builder = PyroluxDemoProps.Builder.new()
	b.kind = 1.0
	b.tint = Color(0.46, 0.33, 0.2)
	var butt: Vector3 = Vector3(staff_top.x - 0.01, 0.0, staff_top.z)
	var axis: Vector3 = Vector3.UP
	var length: float = staff_top.y
	if pose == 1:
		butt = PyroluxDemoFigure.CASTER_STAFF_BUTT
		axis = PyroluxDemoFigure.CASTER_STAFF_DIR
		length = PyroluxDemoFigure.CASTER_STAFF_LEN
	var top: Vector3 = Vector3(0.0, length, 0.0)
	b.tube(Vector3.ZERO, top, 0.022, 0.019, 20, true, false)
	b.ellipsoid(top, Vector3.ONE * 0.03, 20, 10)
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		var c: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var mid: Vector3 = top + c * 0.045 + Vector3(0.0, 0.06, 0.0)
		b.tube(top, mid, 0.011, 0.008, 10)
		b.ellipsoid(mid, Vector3.ONE * 0.008, 10, 6)
		b.tube(mid, top + c * 0.02 + Vector3(0.0, 0.13, 0.0), 0.008, 0.003, 10)
	var up: Vector3 = axis.normalized()
	var side: Vector3 = up.cross(Vector3.BACK).normalized()
	var basis: Basis = Basis(side, up, side.cross(up))
	var staff: ArrayMesh = b.mesh()
	var arr: Array = staff.surface_get_arrays(0)
	var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i: int in pv.size():
		pv[i] = basis * pv[i] + butt
		pn[i] = basis * pn[i]
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_NORMAL] = pn
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache[key] = m
	return m

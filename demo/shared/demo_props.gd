class_name PyroluxDemoProps
extends RefCounted
## Demo only: the props of a demo stage, built in code. No texture, no imported mesh.
## Barrels (staves with a bulge, a sunk head and four iron hoops), crates (a frame of battens and
## a diagonal brace on every face over planked panels), a bookshelf with books, trees (a flared
## trunk, branches and lumpy leaf clumps) and pines, rocks (an icosphere warped by smooth lumps
## and cut flat underneath), walls with holes for windows, beams and lit cards. Kit 2 adds
## torches (standing and on a wall), braziers, pedestals, columns, urns, an iron cauldron, dock
## posts, stone wall segments, and TorchFlame (a flame and its light that needs no fire pack and
## that water puts out).
##
## Every mesh carries UV2.y = face kind (0 top, 1 side, 2 underside) and UV2.x = 1 on metal
## parts for demo_prop.gdshader, and every triangle goes in clockwise seen from outside, which is
## Godot's front face: a builder that wrote them anticlockwise drew every rock and crate inside
## out under cull_back (TERRALUX 1.0.1, the Reddit report of 2026-10-15). Kit 2's Builder turns
## a triangle by the normal it is given (tri_s, quad_o, the lathe, tube and ellipsoid), so a new
## shape cannot come out inside out.
##
##   var stone := PyroluxDemoProps.material(Color(0.32, 0.3, 0.28))
##   PyroluxDemoProps.rock_cluster(props, Vector3(-5.1, 0.0, 1.4), 0.56, 4, 7, stone)
##   PyroluxDemoProps.crate(props, Vector3(3.0, 0.0, -2.0), 0.8)        # the kit's woods
##   PyroluxDemoProps.torch(props, Vector3(-2.0, 0.0, -1.0))            # burning
##
## A material left out (null) is the kit's own (kit_material()). Meshes are cached by their
## arguments and shared. A demo stage passes what these return to its adopt(), so the web
## first-visit swap (one unshaded shader until the effects are up) covers them too.
## From ATMOLUX demo_props.gd (step 2b) with the winding fix of TERRALUX demo_rocks.gd.
## Generated from WS/shared/demo_kit/demo_props.gd by tools/vfxpack/demo_kit_sync.py.

const DEMO_KIT_VERSION: int = 15
const PROP_SHADER: Shader = preload("res://demo/shared/demo_prop.gdshader")
const WALL_SHADER: Shader = preload("res://demo/shared/demo_stone_wall.gdshader")
const BLOB_SHADER: Shader = preload("res://demo/shared/demo_blob.gdshader")
const GLOW_SHADER: Shader = preload("res://demo/shared/demo_quick.gdshader")
const FLAME_SHADER: Shader = preload("res://demo/shared/demo_torch_flame.gdshader")

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}

static var _blob_mat: ShaderMaterial = null
## How much larger than `radius` the ellipse is drawn (the dark falls off to nothing at the rim,
## so its visible part is about half of it): 1.7 x the half width of what stands on it.
const BLOB_GROW: float = 1.7


## Moves each blob shadow under its target every frame. One per parent, named "Blobs", beside the
## targets and never inside them: an effect that walks a target's descendant MeshInstance3Ds and
## swaps their materials (Shock3D, Dissolve3D, Wet ...) must not find a shadow.
class BlobTracker extends Node3D:
	var _pairs: Array = []

	func _ready() -> void:
		process_priority = 100

	func add(target: Node3D, blob: MeshInstance3D) -> void:
		_pairs.append([target, blob])
		_follow(target, blob)

	func _process(_delta: float) -> void:
		for k: int in range(_pairs.size() - 1, -1, -1):
			var target: Node3D = _pairs[k][0]
			var blob: MeshInstance3D = _pairs[k][1]
			if not is_instance_valid(target) or not is_instance_valid(blob):
				if is_instance_valid(blob):
					blob.queue_free()
				_pairs.remove_at(k)
				continue
			_follow(target, blob)

	func _follow(target: Node3D, blob: MeshInstance3D) -> void:
		blob.visible = target.is_visible_in_tree()
		if not blob.visible or not blob.is_inside_tree() or not target.is_inside_tree():
			return
		var t: Transform3D = target.global_transform
		var yaw: float = atan2(t.basis.z.x, t.basis.z.z)
		var lv: Variant = blob.get_meta(&"blob_y")
		var lift: float = 0.012
		if lv is float:
			lift = lv
		blob.global_transform = Transform3D(Basis(Vector3.UP, yaw), t.origin + Vector3(0.0, lift, 0.0))


## Kit 15: a soft dark ellipse flat on the floor under `node`, the demo's stand-in for a shadow
## now that no light casts one. It is NOT a child of `node` (see BlobTracker): it sits in a
## "Blobs" node beside it and follows it. `radius` is the half width of what stands on it in
## metres; the ellipse is drawn BLOB_GROW times that. `stretch` lengthens it along the node's
## local z. Darkest in the middle (0.75), 0 at the rim, one shared unshaded shader. `y` lifts it
## off the floor; the node must stand on y = 0 in its own space. Returns the MeshInstance3D
## (name "BlobShadow", meta "blob_shadow"). A node with no parent yet gets the blob as its child.
static func blob_shadow(node: Node3D, radius: float, stretch: float = 1.0, y: float = 0.012) -> MeshInstance3D:
	if _blob_mat == null:
		_blob_mat = ShaderMaterial.new()
		_blob_mat.shader = BLOB_SHADER
	var q: PlaneMesh = PlaneMesh.new()
	var r: float = radius * BLOB_GROW
	q.size = Vector2(r * 2.0, r * 2.0 * stretch)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = q
	mi.material_override = _blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(&"blob_shadow", true)
	mi.set_meta(&"blob_y", y)
	var holder: Node = node.get_parent()
	if holder == null:
		mi.position = Vector3(0.0, y, 0.0)
		node.add_child(mi)
		return mi
	var tr: BlobTracker = holder.get_node_or_null("Blobs") as BlobTracker
	if tr == null:
		tr = BlobTracker.new()
		tr.name = "Blobs"
		holder.add_child(tr)
	tr.add_child(mi)
	tr.add(node, mi)
	return mi



## A prop material: `side` on the sides, a lighter top, a dark underside.
static func material(side: Color, top_lift: float = 1.15, mottle: float = 0.12,
		planks: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = PROP_SHADER
	mat.set_shader_parameter("side_color", side)
	mat.set_shader_parameter("top_color", side * top_lift)
	mat.set_shader_parameter("under_color", side * 0.35)
	mat.set_shader_parameter("mottle", mottle)
	mat.set_shader_parameter("planks", planks)
	return mat


## One colour on every face (figures, and meshes without the kit's face kinds).
static func flat_material(color: Color, rough: float = 0.85, metal: float = 0.0,
		mottle: float = 0.05) -> ShaderMaterial:
	var mat: ShaderMaterial = material(color, 1.0, mottle, 0.0)
	mat.set_shader_parameter("under_color", color)
	mat.set_shader_parameter("roughness", rough)
	mat.set_shader_parameter("metallic", metal)
	return mat


## Iron, bronze: metal all over.
static func metal_material(color: Color, rough: float = 0.4, metal: float = 0.8) -> ShaderMaterial:
	var mat: ShaderMaterial = flat_material(color, rough, metal, 0.06)
	mat.set_shader_parameter("metal_amount", metal)
	mat.set_shader_parameter("metal_roughness", rough)
	return mat


## Coursed stone for walls whose mesh carries UV in metres (stone_wall_segment, the stage's
## arcade). demo_stone_wall.gdshader space 1.
static func wall_material(stone: Color, mortar: Color, course: float = 0.34, block: float = 0.66) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = WALL_SHADER
	mat.set_shader_parameter("stone_color", stone)
	mat.set_shader_parameter("mortar_color", mortar)
	mat.set_shader_parameter("course_height", course)
	mat.set_shader_parameter("block_length", block)
	mat.set_shader_parameter("space", 1)
	return mat


## Something that shines by itself and needs no light (a gem, embers, the day behind a window):
## the stage's one unshaded shader drawn flat, so it costs no shader of its own.
static func glow_material(color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("col", color)
	mat.set_shader_parameter("glow", 1.0)
	return mat


## The flame's material, for a web warm-up to draw once.
static func flame_material() -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	return mat


## The kit's own materials, made once and shared: wood, wood_planks (crate panels), wood_staves,
## wood_dark, bark, leaf, pine, iron, stone, stone_dark, stone_light, terracotta, rope, cloth,
## char (a burnt torch head), ember, wet_wood (a dock post, dark below 0.32 m), rock.
static func kit_material(id: StringName) -> ShaderMaterial:
	if _mats.has(id):
		var hit: ShaderMaterial = _mats[id]
		return hit
	var m: ShaderMaterial = null
	match id:
		&"wood":
			m = material(Color(0.44, 0.3, 0.17), 1.12, 0.12, 0.0)
		&"wood_planks":
			m = material(Color(0.5, 0.36, 0.21), 1.1, 0.1, 4.0)
		&"wood_staves":
			m = material(Color(0.43, 0.28, 0.15), 1.1, 0.12, 1.0)
		&"wood_dark":
			m = material(Color(0.29, 0.19, 0.11), 1.1, 0.12, 0.0)
		&"bark":
			m = material(Color(0.25, 0.19, 0.14), 1.05, 0.3, 0.0)
			m.set_shader_parameter("mottle_scale", 0.12)
		&"leaf":
			m = material(Color(0.19, 0.3, 0.11), 1.35, 0.32, 0.0)
			m.set_shader_parameter("mottle_scale", 0.2)
			m.set_shader_parameter("under_color", Color(0.07, 0.11, 0.05))
		&"pine":
			m = material(Color(0.1, 0.2, 0.12), 1.3, 0.26, 0.0)
			m.set_shader_parameter("mottle_scale", 0.18)
			m.set_shader_parameter("under_color", Color(0.04, 0.07, 0.04))
		&"iron":
			m = metal_material(Color(0.22, 0.21, 0.2), 0.45, 0.7)
		&"stone":
			m = material(Color(0.42, 0.4, 0.37), 1.1, 0.16, 0.0)
		&"stone_dark":
			m = material(Color(0.27, 0.26, 0.25), 1.08, 0.16, 0.0)
		&"stone_light":
			m = material(Color(0.55, 0.52, 0.48), 1.08, 0.12, 0.0)
		&"rock":
			m = material(Color(0.35, 0.33, 0.3), 1.12, 0.22, 0.0)
		&"terracotta":
			m = material(Color(0.56, 0.31, 0.19), 1.1, 0.1, 0.0)
		&"rope":
			m = flat_material(Color(0.52, 0.44, 0.3), 0.95, 0.0, 0.1)
		&"cloth":
			m = flat_material(Color(0.42, 0.07, 0.06), 0.95, 0.0, 0.06)
		&"char":
			m = flat_material(Color(0.06, 0.05, 0.045), 0.95, 0.0, 0.2)
		&"ember":
			m = glow_material(Color(1.0, 0.36, 0.08))
		&"wet_wood":
			m = material(Color(0.36, 0.26, 0.17), 1.1, 0.18, 0.0)
			m.set_shader_parameter("damp_height", 0.32)
		_:
			m = material(Color(0.5, 0.5, 0.5))
	_mats[id] = m
	return m


static func _mat_or(mat: Material, id: StringName) -> Material:
	if mat != null:
		return mat
	return kit_material(id)


# ---------------------------------------------------------------- builder

class Builder:
	var v: PackedVector3Array = PackedVector3Array()
	var n: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var col: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	## Kit 2: what the next vertices carry. `metal` goes to UV2.x (demo_prop.gdshader's metal
	## parts), `tint` to the vertex colour (a part's own shade in a merged mesh), `kind` >= 0
	## forces the face kind (figures use 1: one colour all round).
	var metal: float = 0.0
	var tint: Color = Color(1.0, 1.0, 1.0)
	var kind: float = -1.0

	func _kind_of(nrm: Vector3, given: float) -> float:
		if given >= 0.0:
			return given
		if kind >= 0.0:
			return kind
		if nrm.y > 0.55:
			return 0.0
		if nrm.y < -0.55:
			return 2.0
		return 1.0

	func _put(p: Vector3, nrm: Vector3, t: Vector2, k: float, shade: float = 1.0) -> void:
		v.append(p)
		n.append(nrm)
		uv.append(t)
		uv2.append(Vector2(metal, k))
		col.append(Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0))
		idx.append(v.size() - 1)

	## A flat-shaded triangle; a, b, c anticlockwise seen from outside. The face kind comes
	## from the normal unless given.
	func tri(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2,
			face_kind: float = -1.0) -> void:
		var nrm: Vector3 = (b - a).cross(c - a)
		if nrm.length_squared() < 0.00000001:
			return
		nrm = nrm.normalized()
		var k: float = _kind_of(nrm, face_kind)
		# `nrm` is (b - a) x (c - a): a, b, c run anticlockwise seen from the side it points
		# to. Godot's front face is clockwise, so the corners go in as a, c, b.
		_put(a, nrm, ua, k)
		_put(c, nrm, uc, k)
		_put(b, nrm, ub, k)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, face_kind: float = -1.0,
			uv_scale: float = 1.0) -> void:
		var w: float = (b - a).length() * uv_scale
		var h: float = (d - a).length() * uv_scale
		tri(a, b, c, Vector2(0, 0), Vector2(w, 0), Vector2(w, h), face_kind)
		tri(a, c, d, Vector2(0, 0), Vector2(w, h), Vector2(0, h), face_kind)

	## A flat quad with its own UVs, turned to face away from `inside` whatever order the
	## corners come in.
	func quad_o(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3,
			ua: Vector2 = Vector2(0, 0), ub: Vector2 = Vector2(1, 0), uc: Vector2 = Vector2(1, 1),
			ud: Vector2 = Vector2(0, 1), face_kind: float = -1.0) -> void:
		var nrm: Vector3 = (b - a).cross(c - a)
		if nrm.dot((a + b + c + d) * 0.25 - inside) >= 0.0:
			tri(a, b, c, ua, ub, uc, face_kind)
			tri(a, c, d, ua, uc, ud, face_kind)
		else:
			tri(a, c, b, ua, uc, ub, face_kind)
			tri(a, d, c, ua, ud, uc, face_kind)

	## A smooth triangle (one normal per corner), in any order: it is turned so that the side
	## its normals point to is the front.
	func tri_s(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
			ua: Vector2, ub: Vector2, uc: Vector2, sa: float = 1.0, sb: float = 1.0, sc: float = 1.0) -> void:
		var g: Vector3 = (b - a).cross(c - a)
		if g.length_squared() < 0.000000000001:
			return
		if g.dot(na + nb + nc) > 0.0:
			_put(a, na, ua, _kind_of(na, -1.0), sa)
			_put(c, nc, uc, _kind_of(nc, -1.0), sc)
			_put(b, nb, ub, _kind_of(nb, -1.0), sb)
		else:
			_put(a, na, ua, _kind_of(na, -1.0), sa)
			_put(b, nb, ub, _kind_of(nb, -1.0), sb)
			_put(c, nc, uc, _kind_of(nc, -1.0), sc)

	func quad_s(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3,
			nc: Vector3, nd: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2,
			sa: float = 1.0, sb: float = 1.0, sc: float = 1.0, sd: float = 1.0) -> void:
		tri_s(a, b, c, na, nb, nc, ua, ub, uc, sa, sb, sc)
		tri_s(a, c, d, na, nc, nd, ua, uc, ud, sa, sc, sd)

	## A box from `lo` to `hi`, faces outward.
	func box(lo: Vector3, hi: Vector3, uv_scale: float = 1.0) -> void:
		var p: Array[Vector3] = [
			Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
			Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
		]
		quad(p[3], p[2], p[6], p[7], -1.0, uv_scale)
		quad(p[1], p[0], p[4], p[5], -1.0, uv_scale)
		quad(p[0], p[3], p[7], p[4], -1.0, uv_scale)
		quad(p[2], p[1], p[5], p[6], -1.0, uv_scale)
		quad(p[7], p[6], p[5], p[4], 0.0, uv_scale)
		quad(p[0], p[1], p[2], p[3], 2.0, uv_scale)

	## A box with UVs in metres on every face (x along on the faces facing Z, z along on the
	## ends, x/z on top and bottom): demo_stone_wall.gdshader space 1 draws courses on it.
	## `u0` / `v0` shift the UVs (a wall continued from another piece).
	func box_m(lo: Vector3, hi: Vector3, u0: float = 0.0, v0: float = 0.0) -> void:
		var c: Vector3 = (lo + hi) * 0.5
		var x0: float = lo.x
		var x1: float = hi.x
		var y0: float = lo.y
		var y1: float = hi.y
		var z0: float = lo.z
		var z1: float = hi.z
		for zz: float in [z0, z1]:
			quad_o(Vector3(x0, y0, zz), Vector3(x1, y0, zz), Vector3(x1, y1, zz), Vector3(x0, y1, zz), c,
				Vector2(u0 + x0, v0 + y0), Vector2(u0 + x1, v0 + y0), Vector2(u0 + x1, v0 + y1), Vector2(u0 + x0, v0 + y1))
		for xx: float in [x0, x1]:
			quad_o(Vector3(xx, y0, z0), Vector3(xx, y0, z1), Vector3(xx, y1, z1), Vector3(xx, y1, z0), c,
				Vector2(z0, v0 + y0), Vector2(z1, v0 + y0), Vector2(z1, v0 + y1), Vector2(z0, v0 + y1))
		for yy: float in [y0, y1]:
			quad_o(Vector3(x0, yy, z0), Vector3(x1, yy, z0), Vector3(x1, yy, z1), Vector3(x0, yy, z1), c,
				Vector2(u0 + x0, z0), Vector2(u0 + x1, z0), Vector2(u0 + x1, z1), Vector2(u0 + x0, z1))

	## A box from `lo` to `hi` with every edge cut at 45 degrees by `bevel` (dressed stone,
	## planks): the cut edges catch the light, which is what makes a block read as a block.
	func cbox(lo: Vector3, hi: Vector3, bevel: float, uv_scale: float = 1.0) -> void:
		var e: float = minf(bevel, minf(hi.x - lo.x, minf(hi.y - lo.y, hi.z - lo.z)) * 0.45)
		if e <= 0.0001:
			box(lo, hi, uv_scale)
			return
		var c: Vector3 = (lo + hi) * 0.5
		# Three points per corner: on its X face, its Y face and its Z face.
		var px: Dictionary = {}
		var py: Dictionary = {}
		var pz: Dictionary = {}
		for ix: int in 2:
			for iy: int in 2:
				for iz: int in 2:
					var cx: float = hi.x if ix == 1 else lo.x
					var cy: float = hi.y if iy == 1 else lo.y
					var cz: float = hi.z if iz == 1 else lo.z
					var dx: float = -e if ix == 1 else e
					var dy: float = -e if iy == 1 else e
					var dz: float = -e if iz == 1 else e
					var key: int = ix * 4 + iy * 2 + iz
					px[key] = Vector3(cx, cy + dy, cz + dz)
					py[key] = Vector3(cx + dx, cy, cz + dz)
					pz[key] = Vector3(cx + dx, cy + dy, cz)
		# The six faces.
		for ix: int in 2:
			_cq(px, ix * 4 + 0, ix * 4 + 1, ix * 4 + 3, ix * 4 + 2, c, uv_scale)
		for iy: int in 2:
			_cq(py, iy * 2 + 0, iy * 2 + 1, 4 + iy * 2 + 1, 4 + iy * 2 + 0, c, uv_scale)
		for iz: int in 2:
			_cq(pz, iz, 2 + iz, 6 + iz, 4 + iz, c, uv_scale)
		# The twelve cut edges: between the X and Y faces (running along Z), X and Z, Y and Z.
		for ix: int in 2:
			for iy: int in 2:
				var k0: int = ix * 4 + iy * 2
				_cq2(px, py, k0, k0 + 1, c)
		for ix: int in 2:
			for iz: int in 2:
				var k0: int = ix * 4 + iz
				_cq2(px, pz, k0, k0 + 2, c)
		for iy: int in 2:
			for iz: int in 2:
				var k0: int = iy * 2 + iz
				_cq2(py, pz, k0, k0 + 4, c)
		# The eight corners.
		for key: int in 8:
			var a: Vector3 = px[key]
			var b: Vector3 = py[key]
			var d: Vector3 = pz[key]
			var nrm: Vector3 = (b - a).cross(d - a)
			if nrm.dot((a + b + d) / 3.0 - c) >= 0.0:
				tri(a, b, d, Vector2(0, 0), Vector2(e, 0), Vector2(0, e))
			else:
				tri(a, d, b, Vector2(0, 0), Vector2(0, e), Vector2(e, 0))

	func _cq(pts: Dictionary, k0: int, k1: int, k2: int, k3: int, c: Vector3, uv_scale: float) -> void:
		var a: Vector3 = pts[k0]
		var b: Vector3 = pts[k1]
		var cc: Vector3 = pts[k2]
		var d: Vector3 = pts[k3]
		var w: float = (b - a).length() * uv_scale
		var h: float = (d - a).length() * uv_scale
		quad_o(a, b, cc, d, c, Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h))

	func _cq2(pa: Dictionary, pb: Dictionary, k0: int, k1: int, c: Vector3) -> void:
		var a0: Vector3 = pa[k0]
		var a1: Vector3 = pa[k1]
		var b0: Vector3 = pb[k0]
		var b1: Vector3 = pb[k1]
		var l: float = (a1 - a0).length()
		quad_o(a0, a1, b1, b0, c, Vector2(0, 0), Vector2(l, 0), Vector2(l, 0.05), Vector2(0, 0.05))

	## A surface of revolution round the Y axis through `origin`. `profile` is (radius, height)
	## points walked so that the solid is on the left: out along the bottom, up the outside,
	## in across the top (and down the inside of a vessel). Corners sharper than `crease`
	## degrees stay hard. `shades` (one per point) darken the vertex colour, e.g. inside a pot.
	func lathe(profile: PackedVector2Array, segs: int, origin: Vector3 = Vector3.ZERO,
			crease: float = 40.0, shades: PackedFloat32Array = PackedFloat32Array(), u_scale: float = 1.0) -> void:
		var np: int = profile.size()
		if np < 2:
			return
		var seg_n: Array[Vector2] = []
		for k: int in np - 1:
			var d: Vector2 = profile[k + 1] - profile[k]
			seg_n.append(Vector2(d.y, -d.x).normalized() if d.length() > 0.000001 else Vector2(1, 0))
		var cos_crease: float = cos(deg_to_rad(crease))
		var vlen: float = 0.0
		for k: int in np - 1:
			var p0: Vector2 = profile[k]
			var p1: Vector2 = profile[k + 1]
			var n0: Vector2 = seg_n[k]
			var n1: Vector2 = seg_n[k]
			if k > 0 and seg_n[k - 1].dot(seg_n[k]) > cos_crease:
				n0 = (seg_n[k - 1] + seg_n[k]).normalized()
			if k + 1 < np - 1 and seg_n[k + 1].dot(seg_n[k]) > cos_crease:
				n1 = (seg_n[k + 1] + seg_n[k]).normalized()
			var s0: float = shades[k] if shades.size() == np else 1.0
			var s1: float = shades[k + 1] if shades.size() == np else 1.0
			var l: float = (p1 - p0).length()
			for j: int in segs:
				var t0: float = TAU * float(j) / float(segs)
				var t1: float = TAU * float(j + 1) / float(segs)
				var c0: Vector3 = Vector3(cos(t0), 0.0, sin(t0))
				var c1: Vector3 = Vector3(cos(t1), 0.0, sin(t1))
				var a: Vector3 = origin + c0 * p0.x + Vector3(0, p0.y, 0)
				var b: Vector3 = origin + c1 * p0.x + Vector3(0, p0.y, 0)
				var cc: Vector3 = origin + c1 * p1.x + Vector3(0, p1.y, 0)
				var d: Vector3 = origin + c0 * p1.x + Vector3(0, p1.y, 0)
				var na: Vector3 = (c0 * n0.x + Vector3(0, n0.y, 0)).normalized()
				var nb: Vector3 = (c1 * n0.x + Vector3(0, n0.y, 0)).normalized()
				var nc: Vector3 = (c1 * n1.x + Vector3(0, n1.y, 0)).normalized()
				var nd: Vector3 = (c0 * n1.x + Vector3(0, n1.y, 0)).normalized()
				var u0: float = float(j) / float(segs) * u_scale
				var u1: float = float(j + 1) / float(segs) * u_scale
				quad_s(a, b, cc, d, na, nb, nc, nd, Vector2(u0, vlen), Vector2(u1, vlen),
					Vector2(u1, vlen + l), Vector2(u0, vlen + l), s0, s0, s1, s1)
			vlen += l

	## A smooth tube from `a` (radius ra) to `b` (radius rb), open at both ends unless capped.
	func tube(a: Vector3, b: Vector3, ra: float, rb: float, segs: int = 10, cap_a: bool = false,
			cap_b: bool = false, phase: float = 0.0) -> void:
		var axis: Vector3 = b - a
		var length: float = axis.length()
		if length < 0.00001:
			return
		axis /= length
		var ref: Vector3 = Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
		var bu: Vector3 = axis.cross(ref).normalized()
		var bw: Vector3 = axis.cross(bu).normalized()
		var slope: float = (ra - rb) / length
		for j: int in segs:
			var t0: float = TAU * float(j) / float(segs) + phase
			var t1: float = TAU * float(j + 1) / float(segs) + phase
			var r0: Vector3 = bu * cos(t0) + bw * sin(t0)
			var r1: Vector3 = bu * cos(t1) + bw * sin(t1)
			var n0: Vector3 = (r0 + axis * slope).normalized()
			var n1: Vector3 = (r1 + axis * slope).normalized()
			var u0: float = float(j) / float(segs)
			var u1: float = float(j + 1) / float(segs)
			quad_s(a + r0 * ra, a + r1 * ra, b + r1 * rb, b + r0 * rb, n0, n1, n1, n0,
				Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, length), Vector2(u0, length))
			if cap_a:
				tri_s(a, a + r0 * ra, a + r1 * ra, -axis, -axis, -axis, Vector2(0.5, 0.5), Vector2(u0, 0), Vector2(u1, 0))
			if cap_b:
				tri_s(b, b + r0 * rb, b + r1 * rb, axis, axis, axis, Vector2(0.5, 0.5), Vector2(u0, 1), Vector2(u1, 1))

	## A smooth ellipsoid of half-sizes `r` round `c`, turned by `basis`. Points below
	## `floor_y` (local, before turning) are pressed flat onto it: a foot with a sole.
	func ellipsoid(c: Vector3, r: Vector3, segs: int = 12, rings: int = 8,
			basis: Basis = Basis.IDENTITY, floor_y: float = -1000.0) -> void:
		var pts: Array[PackedVector3Array] = []
		var nrs: Array[PackedVector3Array] = []
		var inv_t: Basis = basis.inverse().transposed()
		for i: int in rings + 1:
			var phi: float = PI * float(i) / float(rings)
			var row_p: PackedVector3Array = PackedVector3Array()
			var row_n: PackedVector3Array = PackedVector3Array()
			for j: int in segs + 1:
				var th: float = TAU * float(j) / float(segs)
				var u: Vector3 = Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				var lp: Vector3 = u * r
				var ln: Vector3 = Vector3(u.x / maxf(r.x, 0.0001), u.y / maxf(r.y, 0.0001), u.z / maxf(r.z, 0.0001))
				if lp.y < floor_y:
					lp.y = floor_y
					ln = Vector3.DOWN
				row_p.append(c + basis * lp)
				row_n.append((inv_t * ln).normalized())
			pts.append(row_p)
			nrs.append(row_n)
		for i: int in rings:
			for j: int in segs:
				var uv0: Vector2 = Vector2(float(j) / float(segs), float(i) / float(rings))
				var uv1: Vector2 = Vector2(float(j + 1) / float(segs), float(i + 1) / float(rings))
				quad_s(pts[i][j], pts[i][j + 1], pts[i + 1][j + 1], pts[i + 1][j],
					nrs[i][j], nrs[i][j + 1], nrs[i + 1][j + 1], nrs[i + 1][j],
					uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y))

	## A closed smooth skin through `rings` (loops of points, all the same count, walked the
	## same way round), each round its `centres` point. Normals are taken from the grid and
	## turned away from the centre; `shade_rows` (one per ring) darken the vertex colour.
	func loft(rings: Array[PackedVector3Array], centres: PackedVector3Array,
			shade_rows: PackedFloat32Array = PackedFloat32Array()) -> void:
		var nr: int = rings.size()
		if nr < 2:
			return
		var m: int = rings[0].size()
		var nrs: Array[PackedVector3Array] = []
		for i: int in nr:
			var row: PackedVector3Array = PackedVector3Array()
			for j: int in m:
				var along: Vector3 = rings[mini(i + 1, nr - 1)][j] - rings[maxi(i - 1, 0)][j]
				var around: Vector3 = rings[i][(j + 1) % m] - rings[i][(j + m - 1) % m]
				var nn: Vector3 = along.cross(around)
				if nn.length_squared() < 0.0000001:
					nn = rings[i][j] - centres[i]
				if nn.dot(rings[i][j] - centres[i]) < 0.0:
					nn = -nn
				row.append(nn.normalized())
			nrs.append(row)
		for i: int in nr - 1:
			var s0: float = shade_rows[i] if shade_rows.size() == nr else 1.0
			var s1: float = shade_rows[i + 1] if shade_rows.size() == nr else 1.0
			for j: int in m:
				var j1: int = (j + 1) % m
				var u0: float = float(j) / float(m)
				var u1: float = float(j + 1) / float(m)
				quad_s(rings[i][j], rings[i][j1], rings[i + 1][j1], rings[i + 1][j],
					nrs[i][j], nrs[i][j1], nrs[i + 1][j1], nrs[i + 1][j],
					Vector2(u0, float(i)), Vector2(u1, float(i)), Vector2(u1, float(i + 1)), Vector2(u0, float(i + 1)),
					s0, s0, s1, s1)

	## A thin sheet seen from both sides (a banner, a cloak): the same grid of points drawn
	## twice with opposite normals. `front` says which way the first side faces at (0, 0).
	func sheet(grid: Array[PackedVector3Array], front: Vector3, back_shade: float = 0.8) -> void:
		var nr: int = grid.size()
		var m: int = grid[0].size()
		var nrs: Array[PackedVector3Array] = []
		for i: int in nr:
			var row: PackedVector3Array = PackedVector3Array()
			for j: int in m:
				var du: Vector3 = grid[i][mini(j + 1, m - 1)] - grid[i][maxi(j - 1, 0)]
				var dv: Vector3 = grid[mini(i + 1, nr - 1)][j] - grid[maxi(i - 1, 0)][j]
				var nn: Vector3 = du.cross(dv)
				if nn.length_squared() < 0.0000001:
					nn = front
				row.append(nn.normalized())
			nrs.append(row)
		var flip: float = 1.0 if nrs[0][0].dot(front) >= 0.0 else -1.0
		for side: int in 2:
			var sg: float = flip if side == 0 else -flip
			var sh: float = 1.0 if side == 0 else back_shade
			for i: int in nr - 1:
				for j: int in m - 1:
					var u0: float = float(j) / float(m - 1)
					var u1: float = float(j + 1) / float(m - 1)
					var v0: float = float(i) / float(nr - 1)
					var v1: float = float(i + 1) / float(nr - 1)
					quad_s(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j],
						nrs[i][j] * sg, nrs[i][j + 1] * sg, nrs[i + 1][j + 1] * sg, nrs[i + 1][j] * sg,
						Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), sh, sh, sh, sh)

	## Where the next vertex will go: pass it to xform_from() to move what was built after it.
	func mark() -> int:
		return v.size()

	## Moves (turns, places) every vertex built since `start`. No mirroring.
	func xform_from(start: int, t: Transform3D) -> void:
		var nb: Basis = t.basis.inverse().transposed()
		for i: int in range(start, v.size()):
			v[i] = t * v[i]
			n[i] = (nb * n[i]).normalized()

	func mesh() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_INDEX] = idx
		var m: ArrayMesh = ArrayMesh.new()
		if v.size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


static func _instance(parent: Node3D, m: Mesh, mat: Material, at: Vector3, yaw: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	parent.add_child(mi)
	return mi


static func _root(parent: Node3D, at: Vector3, yaw: float, label: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = label
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	return root


## A stable 0..1 number for an integer (per-stave and per-board tones).
static func _rand01(i: int) -> float:
	var x: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return x - floorf(x)


static func _grey(s: float) -> Color:
	return Color(s, s, s)


# ---------------------------------------------------------------- barrels, crates

static func _bulge(radius: float, t: float) -> float:
	return radius * (0.85 + 0.15 * sin(t * PI))


## A barrel of `radius` and `height` standing on `at`: staves (a board each, flat across and
## bulging along), the head sunk below the chime with its boards, a bung, four iron hoops a
## little proud of the staves.
static func barrel(parent: Node3D, at: Vector3, radius: float = 0.32, height: float = 0.9,
		mat: Material = null, hoop_mat: Material = null, yaw: float = 0.0) -> Node3D:
	var key: String = "barrel2_%.3f_%.3f" % [radius, height]
	var m: ArrayMesh = _cached(key)
	var hm: ArrayMesh = _cached(key + "_hoops")
	if m == null:
		var b: Builder = Builder.new()
		var staves: int = clampi(roundi(radius * 50.0), 12, 22)
		var rings: int = 10
		var chime: float = clampf(height * 0.045, 0.02, 0.05)
		var wall_t: float = clampf(radius * 0.07, 0.012, 0.03)
		var head_y: float = height - chime
		var half: float = PI / float(staves)
		for s: int in staves:
			var a0: float = TAU * float(s) / float(staves)
			var a1: float = a0 + half * 2.0
			var am: float = a0 + half
			b.tint = _grey(0.88 + 0.22 * _rand01(s * 13 + 5))
			for r: int in rings:
				var t0: float = float(r) / float(rings)
				var t1: float = float(r + 1) / float(rings)
				var r0: float = _bulge(radius, t0)
				var r1: float = _bulge(radius, t1)
				# The stave is flat across (a board) and follows the bulge along its length.
				var n0: Vector3 = Vector3(cos(am), -radius * 0.15 * PI * cos(t0 * PI) / height, sin(am)).normalized()
				var n1: Vector3 = Vector3(cos(am), -radius * 0.15 * PI * cos(t1 * PI) / height, sin(am)).normalized()
				var p00: Vector3 = Vector3(cos(a0) * r0, t0 * height, sin(a0) * r0)
				var p10: Vector3 = Vector3(cos(a1) * r0, t0 * height, sin(a1) * r0)
				var p11: Vector3 = Vector3(cos(a1) * r1, t1 * height, sin(a1) * r1)
				var p01: Vector3 = Vector3(cos(a0) * r1, t1 * height, sin(a0) * r1)
				# UV.y runs across the staves (one per unit), so a planks = 1 material draws the
				# joints between them; UV.x runs along the grain.
				b.quad_s(p00, p10, p11, p01, n0, n0, n1, n1,
					Vector2(t0 * 2.5, float(s)), Vector2(t0 * 2.5, float(s + 1)),
					Vector2(t1 * 2.5, float(s + 1)), Vector2(t1 * 2.5, float(s)))
			# The rim of the chime, the inside of the chime above the head (dark).
			var rt: float = _bulge(radius, 1.0)
			var rh: float = _bulge(radius, head_y / height)
			var c0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
			var c1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
			b.quad_s(c0 * rt + Vector3(0, height, 0), c1 * rt + Vector3(0, height, 0),
				c1 * (rt - wall_t) + Vector3(0, height, 0), c0 * (rt - wall_t) + Vector3(0, height, 0),
				Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
				Vector2(0, float(s)), Vector2(0, float(s + 1)), Vector2(0.05, float(s + 1)), Vector2(0.05, float(s)))
			var cin: Vector3 = -Vector3(cos(am), 0.0, sin(am))
			b.quad_s(c0 * (rt - wall_t) + Vector3(0, height, 0), c1 * (rt - wall_t) + Vector3(0, height, 0),
				c1 * (rh - wall_t) + Vector3(0, head_y, 0), c0 * (rh - wall_t) + Vector3(0, head_y, 0),
				cin, cin, cin, cin, Vector2(0, float(s)), Vector2(0, float(s + 1)),
				Vector2(0.1, float(s + 1)), Vector2(0.1, float(s)), 0.55, 0.55, 0.55, 0.55)
			# The head (three boards across) and the bottom.
			b.tint = _grey(0.82)
			var hr: float = rh - wall_t
			var hc: Vector3 = Vector3(0, head_y, 0)
			b.tri_s(hc, hc + c0 * hr, hc + c1 * hr, Vector3.UP, Vector3.UP, Vector3.UP,
				Vector2(0.5, 1.5), Vector2(0.5 + c0.x * 0.5, (c0.z * 0.5 + 0.5) * 3.0),
				Vector2(0.5 + c1.x * 0.5, (c1.z * 0.5 + 0.5) * 3.0))
			var r0b: float = _bulge(radius, 0.0)
			b.tri_s(Vector3.ZERO, c0 * r0b, c1 * r0b, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN,
				Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0))
		# The bung: a small round plug on the first stave at the bulge.
		b.tint = _grey(0.5)
		var bd: float = _bulge(radius, 0.5) * cos(half) + 0.003
		var bc: Vector3 = Vector3(cos(half) * bd, 0.5 * height, sin(half) * bd)
		var bn: Vector3 = Vector3(cos(half), 0.0, sin(half))
		var bt: Vector3 = Vector3(-sin(half), 0.0, cos(half))
		var br: float = radius * 0.08
		for k: int in 10:
			var q0: float = TAU * float(k) / 10.0
			var q1: float = TAU * float(k + 1) / 10.0
			b.tri_s(bc, bc + (bt * cos(q0) + Vector3.UP * sin(q0)) * br, bc + (bt * cos(q1) + Vector3.UP * sin(q1)) * br,
				bn, bn, bn, Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0))
		var hb: Builder = Builder.new()
		hb.metal = 1.0
		var hoop_h: float = clampf(height * 0.05, 0.025, 0.05)
		var proud: float = clampf(radius * 0.025, 0.005, 0.012)
		var segs: int = staves * 2
		for hy: float in [0.075, 0.25, 0.75, 0.925]:
			var y0: float = hy * height - hoop_h * 0.5
			var y1: float = hy * height + hoop_h * 0.5
			var r0: float = _bulge(radius, y0 / height) + proud
			var r1: float = _bulge(radius, y1 / height) + proud
			var ri0: float = _bulge(radius, y0 / height) * cos(half) - 0.002
			var ri1: float = _bulge(radius, y1 / height) * cos(half) - 0.002
			var sl: float = (r0 - r1) / (y1 - y0)
			for j: int in segs:
				var t0: float = TAU * float(j) / float(segs)
				var t1: float = TAU * float(j + 1) / float(segs)
				var c0: Vector3 = Vector3(cos(t0), 0.0, sin(t0))
				var c1: Vector3 = Vector3(cos(t1), 0.0, sin(t1))
				var na: Vector3 = (c0 + Vector3(0, sl, 0)).normalized()
				var nb: Vector3 = (c1 + Vector3(0, sl, 0)).normalized()
				hb.quad_s(c0 * r0 + Vector3(0, y0, 0), c1 * r0 + Vector3(0, y0, 0), c1 * r1 + Vector3(0, y1, 0),
					c0 * r1 + Vector3(0, y1, 0), na, nb, nb, na, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
				hb.quad_s(c0 * ri1 + Vector3(0, y1, 0), c1 * ri1 + Vector3(0, y1, 0), c1 * r1 + Vector3(0, y1, 0),
					c0 * r1 + Vector3(0, y1, 0), Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
					Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
				hb.quad_s(c0 * ri0 + Vector3(0, y0, 0), c1 * ri0 + Vector3(0, y0, 0), c1 * r0 + Vector3(0, y0, 0),
					c0 * r0 + Vector3(0, y0, 0), Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN,
					Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		m = _store(key, b)
		hm = _store(key + "_hoops", hb)
	var root: Node3D = _root(parent, at, yaw, "Barrel")
	blob_shadow(root, radius)
	_instance(root, m, _mat_or(mat, &"wood_staves"), Vector3.ZERO)
	_instance(root, hm, _mat_or(hoop_mat, &"iron"), Vector3.ZERO)
	return root


## A crate of `size` metres standing on `at`: planked panels inside a frame of battens on all
## twelve edges and a diagonal brace on every face but the bottom (the shape every game crate
## has, so it reads as a crate at 640 px).
static func crate(parent: Node3D, at: Vector3, size: float = 0.8, mat: Material = null,
		edge_mat: Material = null, yaw: float = 0.0) -> Node3D:
	var key: String = "crate2_%.3f" % size
	var m: ArrayMesh = _cached(key)
	var em: ArrayMesh = _cached(key + "_frame")
	if m == null:
		var h: float = size * 0.5
		var w: float = size * 0.12
		var t: float = size * 0.035
		var b: Builder = Builder.new()
		b.box(Vector3(-h + t, t, -h + t), Vector3(h - t, size - t, h - t), 1.0 / size)
		var eb: Builder = Builder.new()
		# Battens: four uprights, then the rails between them, top and bottom.
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var x0: float = minf(sx * h, sx * (h - w))
				var z0: float = minf(sz * h, sz * (h - w))
				eb.tint = _grey(0.9 + 0.2 * _rand01(int(sx * 3.0 + sz * 7.0 + 11.0)))
				eb.box(Vector3(x0, 0.0, z0), Vector3(x0 + w, size, z0 + w))
		for sy: float in [0.0, 1.0]:
			var y0: float = sy * (size - w)
			for sz: float in [-1.0, 1.0]:
				var z0: float = minf(sz * h, sz * (h - w))
				eb.tint = _grey(0.92 + 0.16 * _rand01(int(sy * 5.0 + sz * 3.0 + 21.0)))
				eb.box(Vector3(-h + w, y0, z0), Vector3(h - w, y0 + w, z0 + w))
			for sx: float in [-1.0, 1.0]:
				var x0: float = minf(sx * h, sx * (h - w))
				eb.tint = _grey(0.92 + 0.16 * _rand01(int(sy * 5.0 + sx * 3.0 + 31.0)))
				eb.box(Vector3(x0, y0, -h + w), Vector3(x0 + w, y0 + w, h - w))
		# Diagonal braces on the four sides and the top, alternating their slope.
		var lo: float = -h + w
		var hi: float = h - w
		var bw: float = w * 0.95
		eb.tint = _grey(1.0)
		var faces: Array[Dictionary] = [
			{"o": Vector3(0, h, h), "u": Vector3.RIGHT, "v": Vector3.UP, "out": Vector3.BACK, "flip": false},
			{"o": Vector3(h, h, 0), "u": Vector3.FORWARD, "v": Vector3.UP, "out": Vector3.RIGHT, "flip": true},
			{"o": Vector3(0, h, -h), "u": Vector3.LEFT, "v": Vector3.UP, "out": Vector3.FORWARD, "flip": false},
			{"o": Vector3(-h, h, 0), "u": Vector3.BACK, "v": Vector3.UP, "out": Vector3.LEFT, "flip": true},
			{"o": Vector3(0, size, 0), "u": Vector3.RIGHT, "v": Vector3.FORWARD, "out": Vector3.UP, "flip": true},
		]
		for f: Dictionary in faces:
			var o: Vector3 = f["o"]
			var fu: Vector3 = f["u"]
			var fv: Vector3 = f["v"]
			var fo: Vector3 = f["out"]
			var flip: bool = f["flip"]
			var su: float = -1.0 if flip else 1.0
			# The brace in face coordinates: from the inner corner low-left to high-right
			# (mirrored when flipped), cut flat where it meets the rails.
			var pts: Array[Vector2] = [Vector2(lo * su, lo), Vector2(lo * su + bw * 1.414 * su, lo),
				Vector2(hi * su, hi), Vector2(hi * su - bw * 1.414 * su, hi)]
			_slab(eb, o, fu, fv, fo, pts, -t, -t * 0.15)
		m = _store(key, b)
		em = _store(key + "_frame", eb)
	var root: Node3D = _root(parent, at, yaw, "Crate")
	blob_shadow(root, size * 0.5)
	_instance(root, m, _mat_or(mat, &"wood_planks"), Vector3.ZERO)
	_instance(root, em, _mat_or(edge_mat, &"wood_dark"), Vector3.ZERO)
	return root


## A board lying on a face: the convex outline `pts` (face coordinates along `fu` / `fv` from
## `o`) raised from depth d0 to d1 along `fo` (negative = inside the face).
static func _slab(b: Builder, o: Vector3, fu: Vector3, fv: Vector3, fo: Vector3, pts: Array[Vector2],
		d0: float, d1: float) -> void:
	var lo_pts: Array[Vector3] = []
	var hi_pts: Array[Vector3] = []
	var centre: Vector3 = Vector3.ZERO
	for p: Vector2 in pts:
		lo_pts.append(o + fu * p.x + fv * p.y + fo * d0)
		hi_pts.append(o + fu * p.x + fv * p.y + fo * d1)
		centre += o + fu * p.x + fv * p.y + fo * (d0 + d1) * 0.5
	centre /= float(pts.size())
	var k: int = pts.size()
	if k == 4:
		b.quad_o(hi_pts[0], hi_pts[1], hi_pts[2], hi_pts[3], centre,
			Vector2(pts[0].x, pts[0].y), Vector2(pts[1].x, pts[1].y), Vector2(pts[2].x, pts[2].y), Vector2(pts[3].x, pts[3].y))
	for i: int in k:
		var j: int = (i + 1) % k
		var l: float = (pts[j] - pts[i]).length()
		b.quad_o(lo_pts[i], lo_pts[j], hi_pts[j], hi_pts[i], centre,
			Vector2(0, 0), Vector2(l, 0), Vector2(l, 0.03), Vector2(0, 0.03))


## A bookshelf `width` wide and `height` tall against a wall, its back at `at` facing
## `yaw`, with four shelves of books.
static func bookshelf(parent: Node3D, at: Vector3, width: float, height: float, mat: Material,
		book_mats: Array[Material], yaw: float = 0.0, seed_value: int = 3) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	var depth: float = 0.32
	var t: float = 0.03
	var b: Builder = Builder.new()
	var hw: float = width * 0.5
	b.box(Vector3(-hw, 0, 0), Vector3(-hw + t, height, depth))
	b.box(Vector3(hw - t, 0, 0), Vector3(hw, height, depth))
	b.box(Vector3(-hw, 0, 0), Vector3(hw, height, t))
	b.box(Vector3(-hw, height - t, 0), Vector3(hw, height, depth))
	var shelves: int = 4
	for s: int in shelves:
		var y: float = height * float(s) / float(shelves)
		b.box(Vector3(-hw, y, 0), Vector3(hw, y + t, depth))
	_instance(root, b.mesh(), mat, Vector3.ZERO)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var bb: Array[Builder] = []
	for _i: int in book_mats.size():
		bb.append(Builder.new())
	for s: int in shelves:
		var y: float = height * float(s) / float(shelves) + t
		var x: float = -hw + t + 0.02
		var limit: float = hw - t - 0.02
		while x < limit - 0.03:
			var w: float = rng.randf_range(0.025, 0.06)
			if x + w > limit:
				break
			var h: float = rng.randf_range(0.16, 0.26)
			var d: float = rng.randf_range(0.16, 0.24)
			var lean: float = 0.0
			bb[rng.randi_range(0, bb.size() - 1)].box(Vector3(x, y, depth - d - 0.02 + lean),
				Vector3(x + w, y + h, depth - 0.02))
			x += w + rng.randf_range(0.0, 0.012)
			if rng.randf() < 0.12:
				x += rng.randf_range(0.03, 0.08)
	for i: int in bb.size():
		_instance(root, bb[i].mesh(), book_mats[i], Vector3.ZERO)
	return root


# ---------------------------------------------------------------- walls, rafters

## A wall quad from `a` to `b` on the floor, `height` tall, facing `inward` (the side
## the room is on), with rectangular `holes` cut out: each hole is (along from a, bottom,
## width, height). The wall is built as strips around the holes.
static func wall(parent: Node3D, a: Vector3, b: Vector3, height: float, holes: Array[Rect2],
		mat: Material, uv_scale: float = 1.0) -> MeshInstance3D:
	var bld: Builder = Builder.new()
	var dir: Vector3 = (b - a).normalized()
	var len: float = (b - a).length()
	# Cut the wall into vertical bands at every hole edge, then each band into the
	# pieces under, between and over its holes.
	var xs: Array[float] = [0.0, len]
	for h: Rect2 in holes:
		xs.append(clampf(h.position.x, 0.0, len))
		xs.append(clampf(h.position.x + h.size.x, 0.0, len))
	xs.sort()
	for i: int in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 0.0001:
			continue
		var mid: float = (x0 + x1) * 0.5
		var ys: Array[float] = [0.0, height]
		for h: Rect2 in holes:
			if mid > h.position.x and mid < h.position.x + h.size.x:
				ys.append(clampf(h.position.y, 0.0, height))
				ys.append(clampf(h.position.y + h.size.y, 0.0, height))
		ys.sort()
		for j: int in ys.size() - 1:
			var y0: float = ys[j]
			var y1: float = ys[j + 1]
			if y1 - y0 < 0.0001:
				continue
			var ym: float = (y0 + y1) * 0.5
			var in_hole: bool = false
			for h: Rect2 in holes:
				if mid > h.position.x and mid < h.position.x + h.size.x \
						and ym > h.position.y and ym < h.position.y + h.size.y:
					in_hole = true
			if in_hole:
				continue
			var p0: Vector3 = a + dir * x0 + Vector3.UP * y0
			var p1: Vector3 = a + dir * x1 + Vector3.UP * y0
			var p2: Vector3 = a + dir * x1 + Vector3.UP * y1
			var p3: Vector3 = a + dir * x0 + Vector3.UP * y1
			bld.quad(p0, p1, p2, p3, 1.0, uv_scale)
			bld.quad(p1, p0, p3, p2, 1.0, uv_scale)
	return _instance(parent, bld.mesh(), mat, Vector3.ZERO)


## A free-standing stone wall from `a` to `b` on the floor: `height` tall, `thickness` deep,
## coursed masonry (demo_stone_wall.gdshader with UVs in metres, so it can run any way) under a
## row of dressed coping stones. Returns the root; its "Wall" child is the masonry mesh.
static func stone_wall_segment(parent: Node3D, a: Vector3, b: Vector3, height: float = 1.6,
		thickness: float = 0.42, mat: Material = null, coping_mat: Material = null) -> Node3D:
	var d: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	var len: float = d.length()
	var root: Node3D = _root(parent, a, atan2(-d.z, d.x), "StoneWall")
	if len < 0.01:
		return root
	var key: String = "swall_%.2f_%.2f_%.2f" % [len, height, thickness]
	var m: ArrayMesh = _cached(key)
	var cm: ArrayMesh = _cached(key + "_coping")
	if m == null:
		var bw: Builder = Builder.new()
		var cop_h: float = 0.1
		bw.box_m(Vector3(0.0, 0.0, -thickness * 0.5), Vector3(len, height - cop_h, thickness * 0.5))
		m = _store(key, bw)
		var cb: Builder = Builder.new()
		var x: float = -0.04
		var i: int = 0
		while x < len + 0.03:
			var piece: float = minf(0.55 + 0.25 * _rand01(i * 7 + 3), len + 0.04 - x)
			if piece < 0.08:
				break
			cb.tint = _grey(0.9 + 0.18 * _rand01(i * 5 + 1))
			cb.cbox(Vector3(x + 0.004, height - cop_h, -thickness * 0.5 - 0.05),
				Vector3(x + piece - 0.004, height, thickness * 0.5 + 0.05), 0.022)
			x += piece
			i += 1
		cm = _store(key + "_coping", cb)
	var wmi: MeshInstance3D = _instance(root, m, mat if mat != null else default_wall_material(), Vector3.ZERO)
	wmi.name = "Wall"
	_instance(root, cm, _mat_or(coping_mat, &"stone"), Vector3.ZERO)
	return root


## The kit's coursed stone for walls built here (grey sandstone).
static func default_wall_material() -> ShaderMaterial:
	if _mats.has(&"wall"):
		var hit: ShaderMaterial = _mats[&"wall"]
		return hit
	var m: ShaderMaterial = wall_material(Color(0.42, 0.4, 0.37), Color(0.2, 0.19, 0.17), 0.24, 0.46)
	_mats[&"wall"] = m
	return m


## A beam of square section `t` from `p0` to `p1`.
static func beam(parent: Node3D, p0: Vector3, p1: Vector3, t: float, mat: Material) -> MeshInstance3D:
	var bld: Builder = Builder.new()
	var d: Vector3 = p1 - p0
	var len: float = d.length()
	bld.box(Vector3(-t * 0.5, -t * 0.5, 0.0), Vector3(t * 0.5, t * 0.5, len))
	var mi: MeshInstance3D = _instance(parent, bld.mesh(), mat, p0)
	if len > 0.0001:
		# In the parent's space (look_at_from_position is global: a branch of a tree
		# placed at (-6, 0, -6) landed at the world origin, step 2b). The box runs along
		# +Z and looking_at points -Z at the target, so look away from it.
		var dn: Vector3 = d / len
		var up: Vector3 = Vector3.UP if absf(dn.y) < 0.99 else Vector3.RIGHT
		mi.basis = Basis.looking_at(-dn, up)
	return mi


## A flat lit card (a bright quad behind a window: the day outside). Kit 2 draws it with the
## stage's unshaded shader (glow_material) instead of a StandardMaterial3D of its own.
static func card(parent: Node3D, centre: Vector3, right: Vector3, up: Vector3, color: Color) -> MeshInstance3D:
	var bld: Builder = Builder.new()
	var r: Vector3 = right * 0.5
	var u: Vector3 = up * 0.5
	bld.quad(centre - r - u, centre + r - u, centre + r + u, centre - r + u, 0.0)
	bld.quad(centre + r - u, centre - r - u, centre - r + u, centre + r + u, 0.0)
	return _instance(parent, bld.mesh(), glow_material(color), Vector3.ZERO)


# ---------------------------------------------------------------- trees, rocks

## A tree at `at`: a trunk flaring into its roots, branches reaching up and out, and leaf
## clumps on their ends and over the crown (gaps between them, not one ball on a stick).
static func tree(parent: Node3D, at: Vector3, height: float = 3.4, seed_value: int = 1,
		trunk_mat: Material = null, leaf_mat: Material = null) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var root: Node3D = _root(parent, at, rng.randf_range(0.0, TAU), "Tree")
	var tm: Material = _mat_or(trunk_mat, &"bark")
	var lm: Material = _mat_or(leaf_mat, &"leaf")
	var key: String = "tree2_%d_%.2f" % [seed_value, height]
	var wood: ArrayMesh = _cached(key)
	var tips: Array[Vector3] = []
	var b: Builder = Builder.new()
	var trunk_h: float = height * 0.56
	var r0: float = height * 0.05
	# The trunk: a few rings that lean and wander, the lowest one swollen into four roots.
	var rings: int = 6
	var sides: int = 10
	var centres: PackedVector3Array = PackedVector3Array()
	var loops: Array[PackedVector3Array] = []
	var lean: Vector3 = Vector3(rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.06, 0.06)) * height
	var root_ph: float = rng.randf_range(0.0, TAU)
	for r: int in rings + 1:
		var f: float = float(r) / float(rings)
		var c: Vector3 = Vector3(0.0, f * trunk_h, 0.0) + lean * f * f + Vector3(rng.randf_range(-0.012, 0.012), 0.0, rng.randf_range(-0.012, 0.012)) * height * f
		if r == 0:
			c.y = -0.04
		var rad: float = lerpf(r0, r0 * 0.5, f)
		var loop: PackedVector3Array = PackedVector3Array()
		for s: int in sides:
			var th: float = TAU * float(s) / float(sides)
			var k: float = 1.0
			if r == 0:
				k = 1.35 + 0.55 * pow(maxf(0.0, cos(th * 2.0 + root_ph)), 4.0)
			elif r == 1:
				k = 1.08 + 0.12 * pow(maxf(0.0, cos(th * 2.0 + root_ph)), 4.0)
			k *= 1.0 + 0.05 * sin(th * 3.0 + float(r))
			loop.append(c + Vector3(cos(th), 0.0, sin(th)) * rad * k)
		loops.append(loop)
		centres.append(c)
	b.loft(loops, centres)
	var top: Vector3 = centres[rings]
	b.ellipsoid(top, Vector3.ONE * r0 * 0.52, 8, 4)
	tips.append(top + Vector3(0.0, height * 0.12, 0.0))
	# Branches: tapered tubes from the upper trunk, each forking once near its end.
	var branches: int = rng.randi_range(3, 5)
	for i: int in branches:
		var y: float = trunk_h * rng.randf_range(0.5, 0.92)
		var ang: float = TAU * float(i) / float(branches) + rng.randf_range(-0.4, 0.4)
		var start: Vector3 = Vector3(0.0, y, 0.0) + lean * (y / trunk_h) * (y / trunk_h)
		var out: Vector3 = Vector3(cos(ang), rng.randf_range(0.7, 1.2), sin(ang)).normalized() * height * rng.randf_range(0.24, 0.34)
		var mid: Vector3 = start + out
		var br: float = r0 * rng.randf_range(0.36, 0.48)
		b.tube(start, mid, br, br * 0.55, 7)
		b.ellipsoid(mid, Vector3.ONE * br * 0.55, 7, 4)
		for k: int in 2:
			var a2: float = ang + (0.55 if k == 0 else -0.55)
			var out2: Vector3 = Vector3(cos(a2), rng.randf_range(0.6, 1.1), sin(a2)).normalized() * height * rng.randf_range(0.12, 0.18)
			b.tube(mid, mid + out2, br * 0.55, br * 0.25, 6)
			tips.append(mid + out2)
	if wood == null:
		wood = _store(key, b)
	_instance(root, wood, tm, Vector3.ZERO)
	# Leaf clumps on the tips and round the crown.
	for c: int in tips.size():
		var s: float = height * rng.randf_range(0.17, 0.25)
		if c == 0:
			s = height * 0.3
		var p: Vector3 = tips[c]
		rock(root, p - Vector3(0, s * 0.42, 0), Vector3(s * 1.3, s * 0.95, s * 1.3), rng.randf_range(0.0, TAU),
			seed_value * 7 + c, lm, true)
	return root


## A pine at `at`: a straight trunk and five tiers of drooping, ragged boughs, the top a spike.
static func pine(parent: Node3D, at: Vector3, height: float = 4.0, seed_value: int = 1,
		trunk_mat: Material = null, needle_mat: Material = null) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + 3
	var root: Node3D = _root(parent, at, rng.randf_range(0.0, TAU), "Pine")
	var key: String = "pine_%d_%.2f" % [seed_value, height]
	var tm: ArrayMesh = _cached(key + "_trunk")
	var nm: ArrayMesh = _cached(key + "_needles")
	if tm == null:
		var tb: Builder = Builder.new()
		tb.tube(Vector3(0, -0.04, 0), Vector3(0, height * 0.82, 0), height * 0.035, height * 0.01, 8)
		tm = _store(key + "_trunk", tb)
		var nb: Builder = Builder.new()
		var tiers: int = 5
		var segs: int = 18
		for t: int in tiers:
			var f: float = float(t) / float(tiers)
			var base_y: float = height * (0.2 + 0.68 * f)
			var reach: float = height * (0.3 - 0.21 * f) * rng.randf_range(0.92, 1.08)
			var tip_y: float = base_y + height * (0.24 - 0.06 * f)
			var droop: float = height * 0.06
			for j: int in segs:
				var t0: float = TAU * float(j) / float(segs)
				var t1: float = TAU * float(j + 1) / float(segs)
				var k0: float = 1.0 + (0.18 if j % 2 == 0 else -0.08) * rng.randf_range(0.6, 1.2)
				var k1: float = 1.0 + (0.18 if (j + 1) % 2 == 0 else -0.08) * rng.randf_range(0.6, 1.2)
				if j == segs - 1:
					k1 = 1.0 + 0.18 * 0.9
				var e0: Vector3 = Vector3(cos(t0) * reach * k0, base_y - droop * k0, sin(t0) * reach * k0)
				var e1: Vector3 = Vector3(cos(t1) * reach * k1, base_y - droop * k1, sin(t1) * reach * k1)
				var apex: Vector3 = Vector3(0.0, tip_y, 0.0)
				var mid0: Vector3 = Vector3(cos(t0) * reach * 0.5, (base_y + tip_y) * 0.5 + droop * 0.2, sin(t0) * reach * 0.5)
				var mid1: Vector3 = Vector3(cos(t1) * reach * 0.5, (base_y + tip_y) * 0.5 + droop * 0.2, sin(t1) * reach * 0.5)
				nb.quad_o(e0, e1, mid1, mid0, Vector3(0, base_y - height * 0.2, 0))
				nb.tri(apex, mid1, mid0, Vector2(0.5, 1), Vector2(1, 0), Vector2(0, 0))
				# Underside of the tier, dark (the shader's underside colour).
				var hub: Vector3 = Vector3(0.0, base_y + height * 0.02, 0.0)
				nb.quad_o(e0, e1, hub, hub, Vector3(0, base_y + height * 0.3, 0))
		nm = _store(key + "_needles", nb)
	_instance(root, tm, _mat_or(trunk_mat, &"bark"), Vector3.ZERO)
	_instance(root, nm, _mat_or(needle_mat, &"pine"), Vector3.ZERO)
	return root


## One rock of `size` at `at` (the point on the floor under its middle).
static func rock(parent: Node3D, at: Vector3, size: Vector3, yaw: float, seed_value: int,
		mat: Material, blob: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = rock_mesh(size, seed_value, blob)
	mi.material_override = mat
	mi.position = at + Vector3(0.0, -0.02, 0.0)
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


## A cluster of rocks round `at`: one of about `big` metres and the rest smaller.
static func rock_cluster(parent: Node3D, at: Vector3, big: float, count: int, seed_value: int,
		mat: Material) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var group: Node3D = Node3D.new()
	group.position = at
	parent.add_child(group)
	var main_size: Vector3 = Vector3(big * rng.randf_range(0.95, 1.25), big * rng.randf_range(0.7, 0.95),
		big * rng.randf_range(0.85, 1.1))
	rock(group, Vector3.ZERO, main_size, rng.randf_range(0.0, TAU), seed_value, mat)
	for i: int in clampi(count, 1, 8) - 1:
		var s: float = big * rng.randf_range(0.3, 0.58)
		var ang: float = rng.randf_range(0.0, TAU)
		var d: float = main_size.x * 0.5 + s * rng.randf_range(0.25, 0.55)
		rock(group, Vector3(cos(ang) * d, 0.0, sin(ang) * d),
			Vector3(s * rng.randf_range(0.9, 1.3), s * rng.randf_range(0.6, 0.95), s * rng.randf_range(0.85, 1.2)),
			rng.randf_range(0.0, TAU), seed_value + 101 + i, mat)
	return group


## A rock mesh: an icosahedron subdivided (twice for a rock bigger than 0.6 m or a leaf clump,
## so its outline is not a polygon), warped by three smooth lumps, cut flat underneath, flat
## shaded.
static func rock_mesh(size: Vector3, seed_value: int, blob: bool = false) -> ArrayMesh:
	var key: String = "rock_%d_%.2f_%.2f_%.2f_%s" % [seed_value, size.x, size.y, size.z, str(blob)]
	var hit: ArrayMesh = _cached(key)
	if hit != null:
		return hit
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var verts: PackedVector3Array = PackedVector3Array()
	var tris: PackedInt32Array = PackedInt32Array()
	_icosphere(verts, tris)
	if blob or maxf(size.x, maxf(size.y, size.z)) > 0.6:
		var finer: PackedInt32Array = PackedInt32Array()
		var mids: Dictionary = {}
		var k0: int = 0
		while k0 + 2 < tris.size():
			var a0: int = tris[k0]
			var b0: int = tris[k0 + 1]
			var c0: int = tris[k0 + 2]
			var ab: int = _mid(verts, mids, a0, b0)
			var bc: int = _mid(verts, mids, b0, c0)
			var ca: int = _mid(verts, mids, c0, a0)
			finer.append_array(PackedInt32Array([a0, ab, ca, b0, bc, ab, c0, ca, bc, ab, bc, ca]))
			k0 += 3
		tris = finer
	var ph: Array[float] = []
	for _i: int in 6:
		ph.append(rng.randf_range(0.0, TAU))
	var fq: Vector3 = Vector3(rng.randf_range(2.2, 3.4), rng.randf_range(2.0, 3.2), rng.randf_range(2.4, 3.6))
	var amp: float = rng.randf_range(0.1, 0.17) * (1.25 if blob else 1.0)
	var cut: float = -1.0 if blob else rng.randf_range(-0.52, -0.36)
	var warped: PackedVector3Array = PackedVector3Array()
	for p0: Vector3 in verts:
		var nn: Vector3 = p0.normalized()
		var lump: float = 1.0 + amp * sin(nn.x * fq.x + ph[0]) * cos(nn.y * fq.y + ph[1]) \
			+ amp * 0.8 * sin(nn.z * fq.z + ph[2]) * sin(nn.x * fq.y + ph[3]) \
			+ amp * 0.5 * cos(nn.y * fq.x * 1.7 + ph[4]) * cos(nn.z * fq.y * 1.3 + ph[5])
		if blob:
			lump += amp * 0.35 * sin(nn.x * 7.0 + ph[1]) * sin(nn.y * 6.0 + ph[3]) * sin(nn.z * 7.5 + ph[5])
		var p: Vector3 = nn * lump
		p.y = maxf(p.y, cut)
		warped.append(Vector3(p.x * size.x * 0.5, (p.y - cut) / (1.0 - cut) * size.y, p.z * size.z * 0.5))
	var b: Builder = Builder.new()
	var k: int = 0
	while k + 2 < tris.size():
		var a: Vector3 = warped[tris[k]]
		var bb: Vector3 = warped[tris[k + 1]]
		var c: Vector3 = warped[tris[k + 2]]
		b.tri(a, bb, c, Vector2(a.x, a.z), Vector2(bb.x, bb.z), Vector2(c.x, c.z))
		k += 3
	return _store(key, b)


static func _icosphere(verts: PackedVector3Array, tris: PackedInt32Array) -> void:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var base: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for v: Vector3 in base:
		verts.append(v.normalized())
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var mids: Dictionary = {}
	for f: Array in faces:
		var a: int = f[0]
		var b: int = f[1]
		var c: int = f[2]
		var ab: int = _mid(verts, mids, a, b)
		var bc: int = _mid(verts, mids, b, c)
		var ca: int = _mid(verts, mids, c, a)
		tris.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))


static func _mid(verts: PackedVector3Array, mids: Dictionary, a: int, b: int) -> int:
	var key: int = mini(a, b) * 100000 + maxi(a, b)
	if mids.has(key):
		var got: int = 0
		got = mids[key]
		return got
	var p: Vector3 = ((verts[a] + verts[b]) * 0.5).normalized()
	verts.append(p)
	mids[key] = verts.size() - 1
	return verts.size() - 1


# ---------------------------------------------------------------- fire

## A flame for a torch or a brazier: camera-facing quads of demo_torch_flame.gdshader and a
## flickering warm light, no fire pack needed. Water puts it out: is_burning() and
## extinguish() are what UNDALUX's douse_fires looks for; relight() lights it again. A demo
## stage hides it while it is in its web first-visit mode and lets it catch (catch_fire())
## when the real stage comes back.
class TorchFlame extends Node3D:
	const SHADER: Shader = preload("res://demo/shared/demo_torch_flame.gdshader")
	const OUT_TIME: float = 0.6
	## The quad of the main tongue (metres); the others are smaller.
	var size: Vector2 = Vector2(0.34, 0.56)
	var tongues: int = 1
	var energy: float = 1.8
	var reach: float = 5.0
	## false: a steady light (the mean of the flicker). VULNALUX's stage turns it off (desk k59:
	## the floor and the back wall breathing with the torches distracted from the wound).
	var flicker: bool = true
	var color: Color = Color(1.0, 0.6, 0.3)
	var light: OmniLight3D
	var _quads: Array[MeshInstance3D] = []
	var _flame_mats: Array[ShaderMaterial] = []
	var _lit: bool = true
	var _level: float = 1.0
	var _time: float = 0.0
	var _seed: float = 0.0

	func _ready() -> void:
		_seed = float(get_instance_id() % 997) * 0.37
		light = OmniLight3D.new()
		light.name = "FlameLight"
		light.light_color = color
		light.light_energy = energy
		light.omni_range = reach
		light.position = Vector3(0.0, size.y * 0.35, 0.0)
		light.shadow_enabled = false
		add_child(light)
		for i: int in maxi(tongues, 1):
			var q: QuadMesh = QuadMesh.new()
			var k: float = 1.0 if i == 0 else 0.68
			q.size = size * k
			var m: ShaderMaterial = ShaderMaterial.new()
			m.shader = SHADER
			m.set_shader_parameter("seed", _seed + float(i) * 13.7)
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "Tongue%d" % i
			mi.mesh = q
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var off: Vector3 = Vector3.ZERO
			if i > 0:
				var ang: float = TAU * float(i) / float(maxi(tongues - 1, 1)) + _seed
				off = Vector3(cos(ang), 0.0, sin(ang)) * size.x * 0.32
			mi.position = off + Vector3(0.0, q.size.y * 0.5 - 0.02, 0.0)
			add_child(mi)
			_quads.append(mi)
			_flame_mats.append(m)

	func _process(delta: float) -> void:
		if light == null:
			return
		_time += delta
		var target: float = 1.0 if _lit else 0.0
		_level = move_toward(_level, target, delta / OUT_TIME)
		for m: ShaderMaterial in _flame_mats:
			m.set_shader_parameter("level", _level)
		for q: MeshInstance3D in _quads:
			q.visible = _level > 0.001
		var flick: float = 0.85
		if flicker:
			flick += 0.09 * sin(_time * 13.0 + _seed) + 0.06 * sin(_time * 7.3 + 1.3 + _seed)
		light.light_energy = energy * flick * _level
		light.visible = _level > 0.001

	func is_burning() -> bool:
		return _lit

	## Puts the flame out (it shrinks and fades over a moment).
	func extinguish() -> void:
		_lit = false

	func relight() -> void:
		_lit = true

	## Lights it from nothing, as if it had just caught.
	func catch_fire() -> void:
		_lit = true
		_level = 0.0

	## On or off; `instant` skips the fade (a change of look, not water).
	func set_burning(on: bool, instant: bool = false) -> void:
		_lit = on
		if instant:
			_level = 1.0 if on else 0.0


## A TorchFlame under `parent` at `at` (the root of the flame).
static func flame(parent: Node3D, at: Vector3, size: Vector2 = Vector2(0.34, 0.56), energy: float = 1.8,
		reach: float = 5.0, tongues: int = 1) -> TorchFlame:
	var f: TorchFlame = TorchFlame.new()
	f.name = "Flame"
	f.size = size
	f.energy = energy
	f.reach = reach
	f.tongues = tongues
	f.position = at
	parent.add_child(f)
	return f


## A standing torch at `at`: a dressed stone foot, a wooden post with iron bands, an iron cup
## with four prongs holding a burnt-black head, and (lit) a flame and its light. `yaw` turns the
## prongs and the foot. Meta "flame" = the TorchFlame (or null when unlit).
static func torch(parent: Node3D, at: Vector3, yaw: float = 0.0, lit: bool = true) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "Torch")
	var m: ArrayMesh = _cached("torch_wood")
	var im: ArrayMesh = _cached("torch_iron")
	var sm: ArrayMesh = _cached("torch_stone")
	var cm: ArrayMesh = _cached("torch_char")
	var head_y: float = 1.46
	if m == null:
		var wb: Builder = Builder.new()
		wb.tube(Vector3(0, 0.12, 0), Vector3(0, head_y - 0.02, 0), 0.046, 0.038, 8)
		m = _store("torch_wood", wb)
		var ib: Builder = Builder.new()
		ib.metal = 1.0
		for y: float in [0.42, 1.02]:
			ib.tube(Vector3(0, y, 0), Vector3(0, y + 0.035, 0), 0.051, 0.05, 12, true, true)
		var cup: PackedVector2Array = PackedVector2Array([Vector2(0.0, head_y - 0.06), Vector2(0.048, head_y - 0.06),
			Vector2(0.06, head_y - 0.03), Vector2(0.105, head_y + 0.05), Vector2(0.115, head_y + 0.065),
			Vector2(0.1, head_y + 0.065), Vector2(0.09, head_y + 0.04), Vector2(0.0, head_y + 0.02)])
		ib.lathe(cup, 14, Vector3.ZERO, 40.0, PackedFloat32Array([1, 1, 1, 1, 1, 0.6, 0.45, 0.4]))
		for k: int in 4:
			var a: float = TAU * float(k) / 4.0 + PI * 0.25
			var c: Vector3 = Vector3(cos(a), 0.0, sin(a))
			ib.tube(c * 0.108 + Vector3(0, head_y + 0.055, 0), c * 0.125 + Vector3(0, head_y + 0.2, 0), 0.008, 0.005, 5)
		im = _store("torch_iron", ib)
		var sb: Builder = Builder.new()
		sb.cbox(Vector3(-0.14, 0.0, -0.14), Vector3(0.14, 0.13, 0.14), 0.025)
		sm = _store("torch_stone", sb)
		var hb: Builder = Builder.new()
		hb.ellipsoid(Vector3(0, head_y + 0.07, 0), Vector3(0.062, 0.075, 0.062), 10, 6)
		for k: int in 5:
			var a2: float = TAU * float(k) / 5.0
			hb.ellipsoid(Vector3(cos(a2) * 0.035, head_y + 0.05 + 0.03 * float(k % 2), sin(a2) * 0.035),
				Vector3(0.04, 0.03, 0.04), 7, 4)
		cm = _store("torch_char", hb)
	_instance(root, m, kit_material(&"wood_dark"), Vector3.ZERO)
	_instance(root, im, kit_material(&"iron"), Vector3.ZERO)
	_instance(root, sm, kit_material(&"stone"), Vector3.ZERO)
	_instance(root, cm, kit_material(&"char"), Vector3.ZERO)
	var f: TorchFlame = null
	if lit:
		f = flame(root, Vector3(0, head_y + 0.08, 0))
	root.set_meta(&"flame", f)
	return root


## A torch on a wall: `at` is the point on the wall face where the bracket is fixed, `yaw`
## turns it to face out of the wall (0 = facing +Z). An iron plate, an arm and a ring hold a
## wooden torch leaning out. Meta "flame" = the TorchFlame (or null).
static func wall_torch(parent: Node3D, at: Vector3, yaw: float = 0.0, lit: bool = true) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "WallTorch")
	var m: ArrayMesh = _cached("wtorch_wood")
	var im: ArrayMesh = _cached("wtorch_iron")
	var cm: ArrayMesh = _cached("wtorch_char")
	var lean: Vector3 = Vector3(0.0, cos(deg_to_rad(22.0)), sin(deg_to_rad(22.0)))
	var base: Vector3 = Vector3(0.0, -0.22, 0.17)
	var head: Vector3 = base + lean * 0.48
	if m == null:
		var wb: Builder = Builder.new()
		wb.tube(base, head, 0.022, 0.03, 7, true, false)
		m = _store("wtorch_wood", wb)
		var ib: Builder = Builder.new()
		ib.metal = 1.0
		ib.cbox(Vector3(-0.045, -0.12, 0.0), Vector3(0.045, 0.1, 0.014), 0.006)
		ib.tube(Vector3(0, -0.05, 0.01), base + lean * 0.2 + Vector3(0, 0, -0.03), 0.009, 0.009, 6)
		ib.tube(Vector3(0, -0.11, 0.01), base + lean * 0.05, 0.008, 0.008, 6)
		var ring_c: Vector3 = base + lean * 0.2
		for k: int in 8:
			var a0: float = TAU * float(k) / 8.0
			var a1: float = TAU * float(k + 1) / 8.0
			var side: Vector3 = Vector3.RIGHT
			var fwd: Vector3 = lean.cross(side).normalized()
			ib.tube(ring_c + (side * cos(a0) + fwd * sin(a0)) * 0.036, ring_c + (side * cos(a1) + fwd * sin(a1)) * 0.036, 0.007, 0.007, 5)
		im = _store("wtorch_iron", ib)
		var hb: Builder = Builder.new()
		hb.ellipsoid(head + lean * 0.03, Vector3(0.045, 0.06, 0.045), 9, 5, Basis(Vector3.RIGHT, deg_to_rad(22.0)))
		cm = _store("wtorch_char", hb)
	_instance(root, m, kit_material(&"wood_dark"), Vector3.ZERO)
	_instance(root, im, kit_material(&"iron"), Vector3.ZERO)
	_instance(root, cm, kit_material(&"char"), Vector3.ZERO)
	var f: TorchFlame = null
	if lit:
		f = flame(root, head + lean * 0.06, Vector2(0.3, 0.5), 1.7, 4.5)
	root.set_meta(&"flame", f)
	return root


## An iron brazier at `at`: three curved legs and a ring, a wide shallow bowl with a rolled
## rim, a heap of coals and (lit) a big flame and its light. Bowl rim at 0.98 m.
## Metas: "flame" = the TorchFlame (or null), "coals" = the coals' MeshInstance3D (swap its
## material to kit_material(&"char") when the fire is out), "top" = the local point the fire
## sits on.
static func brazier(parent: Node3D, at: Vector3, lit: bool = true, yaw: float = 0.0) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "Brazier")
	blob_shadow(root, 0.33)
	var im: ArrayMesh = _cached("brazier_iron")
	var cm: ArrayMesh = _cached("brazier_coal")
	var rim_y: float = 0.98
	if im == null:
		var ib: Builder = Builder.new()
		ib.metal = 1.0
		var bowl: PackedVector2Array = PackedVector2Array([Vector2(0.0, rim_y - 0.17), Vector2(0.12, rim_y - 0.17),
			Vector2(0.24, rim_y - 0.1), Vector2(0.31, rim_y - 0.02), Vector2(0.335, rim_y + 0.005),
			Vector2(0.33, rim_y + 0.02), Vector2(0.305, rim_y + 0.01), Vector2(0.23, rim_y - 0.07), Vector2(0.0, rim_y - 0.12)])
		ib.lathe(bowl, 20, Vector3.ZERO, 40.0, PackedFloat32Array([1, 1, 1, 1, 1, 1, 0.55, 0.4, 0.35]))
		for k: int in 3:
			var a: float = TAU * float(k) / 3.0
			var c: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var p0: Vector3 = c * 0.16 + Vector3(0, rim_y - 0.15, 0)
			var p1: Vector3 = c * 0.25 + Vector3(0, 0.45, 0)
			var p2: Vector3 = c * 0.3 + Vector3(0, 0.03, 0)
			ib.tube(p0, p1, 0.016, 0.014, 6)
			ib.ellipsoid(p1, Vector3.ONE * 0.014, 6, 4)
			ib.tube(p1, p2, 0.014, 0.017, 6)
			ib.ellipsoid(p2 + Vector3(0, -0.018, 0) + c * 0.02, Vector3(0.035, 0.018, 0.03), 7, 4, Basis(Vector3.UP, -a), -0.012)
		for k: int in 3:
			var a0: float = TAU * float(k) / 3.0
			var a1: float = TAU * float(k + 1) / 3.0
			ib.tube(Vector3(cos(a0), 0, sin(a0)) * 0.23 + Vector3(0, 0.52, 0), Vector3(cos(a1), 0, sin(a1)) * 0.23 + Vector3(0, 0.52, 0), 0.009, 0.009, 5)
		im = _store("brazier_iron", ib)
		var cb: Builder = Builder.new()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 41
		for k: int in 9:
			cb.tint = _grey(rng.randf_range(0.3, 1.0))
			var a2: float = rng.randf_range(0.0, TAU)
			var d: float = rng.randf_range(0.0, 0.2)
			cb.ellipsoid(Vector3(cos(a2) * d, rim_y - 0.08 + rng.randf_range(0.0, 0.05) + (0.2 - d) * 0.25, sin(a2) * d),
				Vector3(rng.randf_range(0.05, 0.08), rng.randf_range(0.035, 0.05), rng.randf_range(0.05, 0.08)), 7, 4)
		cm = _store("brazier_coal", cb)
	_instance(root, im, kit_material(&"iron"), Vector3.ZERO)
	var coals: MeshInstance3D = _instance(root, cm, kit_material(&"ember") if lit else kit_material(&"char"), Vector3.ZERO)
	coals.name = "Coals"
	var f: TorchFlame = null
	if lit:
		f = flame(root, Vector3(0, rim_y - 0.02, 0), Vector2(0.5, 0.74), 2.4, 6.0, 3)
	root.set_meta(&"flame", f)
	root.set_meta(&"coals", coals)
	root.set_meta(&"top", Vector3(0, rim_y, 0))
	return root


# ---------------------------------------------------------------- stone and pots

## A stone pedestal at `at`, `w` wide and `h` tall: a plinth, a moulding, the die, a moulding
## and a cap, every edge cut. Meta "top" = the local point on its top face (y = h).
static func pedestal(parent: Node3D, at: Vector3, w: float = 0.8, h: float = 0.9, mat: Material = null,
		yaw: float = 0.0) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "Pedestal")
	blob_shadow(root, w * 0.5)
	var key: String = "pedestal_%.2f_%.2f" % [w, h]
	var m: ArrayMesh = _cached(key)
	if m == null:
		var b: Builder = Builder.new()
		var parts: Array[Vector3] = [
			# (width factor, height share, bevel share of the width)
			Vector3(1.16, 0.13, 0.04), Vector3(1.06, 0.06, 0.05), Vector3(1.0, 0.6, 0.02),
			Vector3(1.07, 0.07, 0.05), Vector3(1.15, 0.14, 0.035),
		]
		var y: float = 0.0
		for i: int in parts.size():
			var p: Vector3 = parts[i]
			var hw: float = w * p.x * 0.5
			var ph: float = h * p.y
			b.tint = _grey(1.0 if i % 2 == 0 else 0.92)
			b.cbox(Vector3(-hw, y, -hw), Vector3(hw, y + ph, hw), w * p.z)
			y += ph
		m = _store(key, b)
	_instance(root, m, _mat_or(mat, &"stone_light"), Vector3.ZERO)
	root.set_meta(&"top", Vector3(0.0, h, 0.0))
	return root


## A stone column at `at`, `h` tall: a square plinth, a moulded base, a shaft of drums with a
## slight swell (entasis) and a capital with its abacus. At 2 m or less it is broken off in a
## jagged top with a fallen drum at its foot (GLYPHLUX's rule: column(at, 2.0) is the broken one).
static func column(parent: Node3D, at: Vector3, h: float = 3.0, mat: Material = null, yaw: float = 0.0) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "Column")
	blob_shadow(root, 0.235)
	var whole: bool = h > 2.0
	var key: String = "column_%.2f" % h
	var m: ArrayMesh = _cached(key)
	var r_lo: float = 0.235
	var r_hi: float = 0.2
	var shaft_y0: float = 0.34
	var shaft_y1: float = (h - 0.36) if whole else h
	if m == null:
		var b: Builder = Builder.new()
		b.cbox(Vector3(-0.32, 0.0, -0.32), Vector3(0.32, 0.17, 0.32), 0.02)
		var base: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.17), Vector2(0.3, 0.17), Vector2(0.305, 0.2),
			Vector2(0.29, 0.235), Vector2(0.26, 0.25), Vector2(0.255, 0.27), Vector2(0.27, 0.29), Vector2(0.262, 0.32),
			Vector2(r_lo, shaft_y0), Vector2(0.0, shaft_y0)])
		b.lathe(base, 24, Vector3.ZERO, 50.0)
		# The shaft, drum by drum, a shallow groove at each joint.
		var drum: float = 0.62
		var y: float = shaft_y0
		var prof: PackedVector2Array = PackedVector2Array([Vector2(0.0, shaft_y0 - 0.001)])
		var span: float = shaft_y1 - shaft_y0
		while y < shaft_y1 - 0.001:
			var y_next: float = minf(y + drum, shaft_y1)
			for s: int in 4:
				var yy: float = lerpf(y, y_next, float(s) / 4.0)
				var tt: float = (yy - shaft_y0) / maxf(span, 0.01)
				var rr: float = lerpf(r_lo, r_hi, tt) + 0.012 * sin(tt * PI)
				if s == 0 and y > shaft_y0 + 0.01:
					prof.append(Vector2(rr - 0.007, yy))
					prof.append(Vector2(rr - 0.007, yy + 0.008))
				prof.append(Vector2(rr, yy + (0.012 if s == 0 and y > shaft_y0 + 0.01 else 0.0)))
			y = y_next
		var t_end: float = 1.0
		var r_end: float = lerpf(r_lo, r_hi, t_end)
		if whole:
			prof.append(Vector2(r_end, shaft_y1))
			# Capital: necking, echinus flaring out, then the abacus (a slab, below).
			prof.append(Vector2(r_end + 0.012, shaft_y1 + 0.02))
			prof.append(Vector2(r_end - 0.004, shaft_y1 + 0.045))
			prof.append(Vector2(r_end + 0.02, shaft_y1 + 0.1))
			prof.append(Vector2(r_end + 0.08, shaft_y1 + 0.18))
			prof.append(Vector2(r_end + 0.1, shaft_y1 + 0.22))
			prof.append(Vector2(0.0, shaft_y1 + 0.22))
			b.lathe(prof, 24, Vector3.ZERO, 35.0)
			b.cbox(Vector3(-0.33, shaft_y1 + 0.22, -0.33), Vector3(0.33, h, 0.33), 0.02)
		else:
			prof.append(Vector2(r_end, shaft_y1 - 0.25))
			b.lathe(prof, 24, Vector3.ZERO, 35.0)
			# The break: a ring of jagged points over the last 0.25 m and a rough top.
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 5
			var segs: int = 24
			var tops: PackedVector3Array = PackedVector3Array()
			var ph: float = rng.randf_range(0.0, TAU)
			for j: int in segs:
				var a: float = TAU * float(j) / float(segs)
				var yb: float = shaft_y1 - 0.25 + 0.17 * (0.5 + 0.5 * sin(a + ph)) + rng.randf_range(0.0, 0.08)
				tops.append(Vector3(cos(a) * r_end, yb, sin(a) * r_end))
			var core: Vector3 = Vector3(0.03, shaft_y1 - 0.1, -0.02)
			for j: int in segs:
				var a0: float = TAU * float(j) / float(segs)
				var a1: float = TAU * float(j + 1) / float(segs)
				var lo0: Vector3 = Vector3(cos(a0) * r_end, shaft_y1 - 0.25, sin(a0) * r_end)
				var lo1: Vector3 = Vector3(cos(a1) * r_end, shaft_y1 - 0.25, sin(a1) * r_end)
				var c0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
				var c1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
				b.quad_s(lo0, lo1, tops[(j + 1) % segs], tops[j], c0, c1, c1, c0,
					Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
				b.tri(tops[j], core, tops[(j + 1) % segs], Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0))
		m = _store(key, b)
	_instance(root, m, _mat_or(mat, &"stone_light"), Vector3.ZERO)
	if not whole:
		var dm: ArrayMesh = _cached("column_drum")
		if dm == null:
			var db: Builder = Builder.new()
			db.tube(Vector3(0, r_hi, -0.24), Vector3(0, r_hi, 0.24), r_hi, r_hi * 0.98, 20, true, true)
			dm = _store("column_drum", db)
		var drum_mi: MeshInstance3D = _instance(root, dm, _mat_or(mat, &"stone_light"), Vector3(0.62, 0.0, 0.18))
		drum_mi.rotation.y = 0.7
	return root


## A stone urn at `at`: a foot, a swelling body, a shoulder, a neck and a flared lip, hollow
## (dark inside), two loop handles. About 0.72 m tall.
static func urn(parent: Node3D, at: Vector3, mat: Material = null, yaw: float = 0.0) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "Urn")
	blob_shadow(root, 0.155)
	var m: ArrayMesh = _cached("urn")
	if m == null:
		var b: Builder = Builder.new()
		var prof: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.155, 0.025),
			Vector2(0.13, 0.05), Vector2(0.125, 0.07), Vector2(0.17, 0.12), Vector2(0.225, 0.22), Vector2(0.245, 0.32),
			Vector2(0.235, 0.42), Vector2(0.2, 0.5), Vector2(0.145, 0.57), Vector2(0.11, 0.61), Vector2(0.105, 0.65),
			Vector2(0.125, 0.69), Vector2(0.15, 0.715), Vector2(0.155, 0.73), Vector2(0.135, 0.73),
			Vector2(0.09, 0.68), Vector2(0.085, 0.6), Vector2(0.0, 0.56)])
		var sh: PackedFloat32Array = PackedFloat32Array()
		for i: int in prof.size():
			sh.append(1.0 if i < 17 else 0.35)
		b.lathe(prof, 22, Vector3.ZERO, 45.0, sh)
		for s: float in [-1.0, 1.0]:
			var p0: Vector3 = Vector3(s * 0.19, 0.5, 0.0)
			var p3: Vector3 = Vector3(s * 0.11, 0.645, 0.0)
			var prev: Vector3 = p0
			for k: int in 7:
				var t: float = float(k + 1) / 7.0
				var p: Vector3 = p0.lerp(p3, t) + Vector3(s * 0.075 * sin(t * PI), 0.04 * sin(t * PI), 0.0)
				b.tube(prev, p, 0.016, 0.016, 6)
				b.ellipsoid(p, Vector3.ONE * 0.016, 6, 3)
				prev = p
		m = _store("urn", b)
	_instance(root, m, _mat_or(mat, &"stone"), Vector3.ZERO)
	return root


## An iron cauldron at `at`: a round-bellied pot on three stubby legs, a rolled rim, two lugs
## and a bail handle laid back, dark inside. Dark metal, the surface UNDALUX's W11 check uses
## (wet only by its glint). About 0.5 m tall.
static func metal_pot(parent: Node3D, at: Vector3, mat: Material = null, yaw: float = 0.0) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "Cauldron")
	blob_shadow(root, 0.32)
	var m: ArrayMesh = _cached("cauldron")
	if m == null:
		var b: Builder = Builder.new()
		var prof: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.07), Vector2(0.1, 0.075), Vector2(0.2, 0.11),
			Vector2(0.27, 0.19), Vector2(0.295, 0.28), Vector2(0.285, 0.37), Vector2(0.26, 0.43), Vector2(0.27, 0.45),
			Vector2(0.278, 0.47), Vector2(0.262, 0.485), Vector2(0.244, 0.475), Vector2(0.238, 0.43),
			Vector2(0.255, 0.33), Vector2(0.21, 0.17), Vector2(0.0, 0.12)])
		var sh: PackedFloat32Array = PackedFloat32Array()
		for i: int in prof.size():
			sh.append(1.0 if i < 10 else 0.32)
		b.lathe(prof, 24, Vector3.ZERO, 45.0, sh)
		for k: int in 3:
			var a: float = TAU * float(k) / 3.0 + 0.5
			var c: Vector3 = Vector3(cos(a), 0.0, sin(a))
			b.tube(c * 0.16 + Vector3(0, 0.1, 0), c * 0.2 + Vector3(0, 0.0, 0), 0.03, 0.022, 7, false, true)
		var lugs: Array[Vector3] = []
		for s: float in [-1.0, 1.0]:
			var lug: Vector3 = Vector3(s * 0.285, 0.44, 0.0)
			b.ellipsoid(lug, Vector3(0.022, 0.03, 0.03), 7, 4)
			lugs.append(lug + Vector3(s * 0.012, 0.0, 0.0))
		# The bail handle: a half circle from lug to lug, laid back 35 degrees.
		var prev: Vector3 = lugs[0]
		var lay: Basis = Basis(Vector3.RIGHT, deg_to_rad(-35.0))
		for k: int in 12:
			var t: float = PI * float(k + 1) / 12.0
			var p: Vector3 = Vector3(-cos(t) * 0.297, 0.44, 0.0) + lay * Vector3(0.0, sin(t) * 0.25, 0.0)
			b.tube(prev, p, 0.009, 0.009, 5)
			prev = p
		m = _store("cauldron", b)
	_instance(root, m, mat if mat != null else metal_material(Color(0.075, 0.075, 0.08), 0.36, 0.85), Vector3.ZERO)
	return root


## A wooden dock post at `at`, standing `h` out of the water (or the floor; it goes 0.25 m
## below): a weathered, not quite round pile with a rounded top, a few turns of rope, dark and
## green where the water reaches (the wet_wood material).
static func dock_post(parent: Node3D, at: Vector3, h: float = 1.1, mat: Material = null, yaw: float = 0.0) -> Node3D:
	var root: Node3D = _root(parent, at, yaw, "DockPost")
	blob_shadow(root, 0.14)
	var key: String = "dockpost_%.2f" % h
	var m: ArrayMesh = _cached(key)
	var rm: ArrayMesh = _cached(key + "_rope")
	var r: float = 0.12
	if m == null:
		var b: Builder = Builder.new()
		var rings: int = 6
		var sides: int = 9
		var loops: Array[PackedVector3Array] = []
		var centres: PackedVector3Array = PackedVector3Array()
		for i: int in rings + 1:
			var y: float = lerpf(-0.25, h - 0.04, float(i) / float(rings))
			var c: Vector3 = Vector3(0.006 * sin(float(i) * 1.7), y, 0.006 * cos(float(i) * 2.3))
			var loop: PackedVector3Array = PackedVector3Array()
			for s: int in sides:
				var a: float = TAU * float(s) / float(sides)
				var k: float = 1.0 + 0.06 * sin(a * 2.0 + 1.0) + 0.04 * _rand01(s * 11 + i * 3)
				loop.append(c + Vector3(cos(a), 0.0, sin(a)) * r * k)
			loops.append(loop)
			centres.append(c)
		# The rounded top: rings closing in.
		var last: Vector3 = centres[rings]
		for i: int in 3:
			var f: float = float(i + 1) / 3.0
			var y2: float = h - 0.04 + 0.05 * sin(f * PI * 0.5)
			var loop2: PackedVector3Array = PackedVector3Array()
			for s: int in sides:
				var a2: float = TAU * float(s) / float(sides)
				loop2.append(Vector3(last.x, y2, last.z) + Vector3(cos(a2), 0.0, sin(a2)) * r * cos(f * PI * 0.5) * 0.98)
			loops.append(loop2)
			centres.append(Vector3(last.x, y2 - 0.05, last.z))
		b.loft(loops, centres)
		m = _store(key, b)
		var rb: Builder = Builder.new()
		var turns: float = 3.0
		var steps: int = 54
		var prev: Vector3 = Vector3.ZERO
		for k: int in steps + 1:
			var t: float = float(k) / float(steps)
			var a3: float = t * turns * TAU
			var p: Vector3 = Vector3(cos(a3) * (r + 0.014), h - 0.36 + t * 0.12, sin(a3) * (r + 0.014))
			if k > 0:
				rb.tube(prev, p, 0.017, 0.017, 6)
			prev = p
		rm = _store(key + "_rope", rb)
	_instance(root, m, _mat_or(mat, &"wet_wood"), Vector3.ZERO)
	_instance(root, rm, kit_material(&"rope"), Vector3.ZERO)
	return root


# ---------------------------------------------------------------- cache

static func _cached(key: String) -> ArrayMesh:
	if _cache.has(key):
		var m: ArrayMesh = null
		m = _cache[key]
		return m
	return null


static func _store(key: String, b: Builder) -> ArrayMesh:
	var m: ArrayMesh = b.mesh()
	_cache[key] = m
	return m

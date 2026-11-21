class_name PyroluxDemoFrame
extends RefCounted
## Demo only: where the camera stands for an effect, as numbers a slot table can hold
## instead of positions written by hand. Two ways a pack has framed its effects:
##
##  radius() - TERRALUX: an effect of `radius` metres fills a fixed share of the frame. The
##    camera stands dist_per_radius x radius away at `elevation_deg`, with the middle of the
##    effect `center_y` of the frame height down from the top (a slam's soil column needs
##    the room above it).
##  span() - ATMOLUX: a vertical thing (a beam from a window to the floor, a particle box)
##    fills `share` of the frame height, seen at eye height and a small pitch, from the
##    front, optionally `side` metres to the right and yawed back.
##
## A stage keeps its own look constants (fov, elevation, eye height) and passes them in;
## nothing here knows a stage. Static, no state.
##
##   PyroluxDemoFrame.radius(camera, Vector3.ZERO, 2.75, 12.0, 2.4, 56.0, 0.62)
##   PyroluxDemoFrame.span(camera, top, bottom, 0.62, 50.0, 6.0, 0.45, 1.6, 1.2)
##
## Generated from WS/shared/demo_kit/demo_frame.gd by tools/vfxpack/demo_kit_sync.py.

const DEMO_KIT_VERSION: int = 15


## Frames an effect of `radius` metres around `center` (TERRALUX's frame_effect): the camera
## at `dist_per_radius * radius`, `elevation_deg` up, the middle of the effect `center_y`
## of the frame height from the top. Returns the distance.
static func radius(camera: Camera3D, center: Vector3, r: float, elevation_deg: float,
		dist_per_radius: float, fov_deg: float, center_y: float) -> float:
	if camera == null:
		return 0.0
	var dist: float = maxf(r, 0.1) * dist_per_radius
	var el: float = deg_to_rad(elevation_deg)
	var pos: Vector3 = center + Vector3(0.0, sin(el), cos(el)) * dist
	camera.position = pos
	# Aiming straight at the middle would put it in the centre of the frame. It has to sit
	# at center_y, so the aim is lifted by the angle that offset is.
	var to_center: Vector3 = (center - pos).normalized()
	var off_ndc: float = 1.0 - 2.0 * center_y
	var lift: float = atan(absf(off_ndc) * tan(deg_to_rad(fov_deg * 0.5)))
	var right: Vector3 = to_center.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.5:
		right = Vector3.RIGHT
	# `right` is to_center x UP and a positive turn around it lifts the aim, so a middle
	# below the centre of the frame (off_ndc < 0) means aiming higher.
	var aim: Vector3 = to_center.rotated(right, lift if off_ndc < 0.0 else -lift)
	camera.look_at(pos + aim, Vector3.UP)
	return dist


## Frames the vertical span from `top` to `bottom` (ATMOLUX's frame_shaft): it fills
## `share` of the frame height, the camera stands in front of its middle (+z), `side`
## metres to the right, at `eye` height unless the middle would leave the frame, pitched
## `pitch_deg` down and yawed back to the middle. Returns the distance.
static func span(camera: Camera3D, top: Vector3, bottom: Vector3, share: float, fov_deg: float,
		pitch_deg: float, center_y: float, eye: float, side: float) -> float:
	if camera == null:
		return 0.0
	var mid: Vector3 = (top + bottom) * 0.5
	var h: float = maxf(absf(top.y - bottom.y), 1.0)
	var dist: float = h / (share * 2.0 * tan(deg_to_rad(fov_deg * 0.5)))
	# The middle sits center_y down the frame when the camera is this much higher than it
	# (the ray to the middle is pitched less than the axis by `lift`).
	var lift: float = atan((1.0 - 2.0 * center_y) * tan(deg_to_rad(fov_deg * 0.5)))
	var ray_pitch: float = deg_to_rad(pitch_deg) - lift
	var y: float = mid.y + dist * tan(ray_pitch)
	var cam_y: float = eye if absf(y - eye) < 0.6 else clampf(y, 1.2, 3.0)
	camera.position = Vector3(mid.x + side, cam_y, mid.z + dist)
	aim_yaw(camera, Vector3(mid.x, cam_y, mid.z), pitch_deg)
	return dist


## Frames a particle box: its height fills `share` of the frame (span() on its middle line).
static func box(camera: Camera3D, centre: Vector3, size: Vector3, share: float, fov_deg: float,
		pitch_deg: float, center_y: float, eye: float, side: float) -> float:
	var half: Vector3 = Vector3(0.0, size.y * 0.5, 0.0)
	return span(camera, centre + half, centre - half, share, fov_deg, pitch_deg, center_y, eye, side)


## Yaws the camera so `point` sits at the horizontal centre of the frame, keeping the
## pitch at `pitch_deg` and the horizon level. The point's height is ignored.
static func aim_yaw(camera: Camera3D, point: Vector3, pitch_deg: float) -> void:
	if camera == null:
		return
	var d: Vector3 = point - camera.position
	var yaw: float = atan2(-d.x, -d.z)
	camera.rotation = Vector3(-deg_to_rad(pitch_deg), yaw, 0.0)


## Puts the camera `dist` metres from `centre`, `azimuth_deg` round from +x towards +z, at
## `eye` height, yawed back to `centre` (ATMOLUX's three-window shot).
static func azimuth(camera: Camera3D, centre: Vector3, azimuth_deg: float, dist: float,
		eye: float, pitch_deg: float) -> void:
	if camera == null:
		return
	var a: float = deg_to_rad(azimuth_deg)
	var pos: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * dist
	pos.y = eye
	camera.position = pos
	aim_yaw(camera, centre, pitch_deg)


## The frame rate a capture runs at: the `--fixed-fps` on the command line (every capture
## script passes one), else the engine's own. The LOOP lines use it: the process delta of
## the first frames of a `--write-movie` run is not the fixed step.
static func capture_fps() -> int:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i: int in args.size() - 1:
		if args[i] == "--fixed-fps":
			return maxi(int(args[i + 1]), 1)
	return maxi(roundi(Engine.get_frames_per_second()), 1)

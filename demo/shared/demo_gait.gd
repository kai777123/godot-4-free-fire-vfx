class_name PyroluxDemoGait
extends Node
## Demo only (kit 6): walks the kit's skinned mannequin (PyroluxDemoFigure.walker()) by
## turning its bones in code - no Animation, no imported clip. Each foot lands heel first, rolls
## flat, lifts the heel over the ball and pushes off; while it is down it stays where it landed
## in world space and the leg reaches it (two-bone IK), so the feet never slide at any speed.
## The hips rise over the standing leg, sway toward it and turn with the stepping leg, the chest
## turns against them, the arms swing against the legs. Every rate is per second, so the walk
## is the same at any frame rate.
##
##   var gait: PyroluxDemoGait = who.get_meta(&"gait")
##   gait.walk(0.9)                          walk on along the root's facing at 0.9 m/s
##   gait.walk_to(Vector3(2.0, 0.0, 0.0))    turn toward the point, walk there, stop (`arrived`)
##   gait.idle()                             finish the step, settle (0.3 s) and stand breathing
##   gait.stop()                             the same, then stand still (no breathing)
##   gait.flinch(hit_dir, 1.0)               take a hit travelling along hit_dir (world): the
##                                           knees give, then the back, chest and head bend
##                                           with it one after the other, the arms come up;
##                                           back in 0.6 s (kit 7)
##   gait.hurt(2.5, 1.0) / gait.calm()       hurt where it burns (kit 7): the knees bend first,
##                                           then the hands beat at the legs (low 1) or the
##                                           chest (low 0) in turn, then the back rounds over
##                                           it; it comes out in the reverse order
##   gait.freeze_pose() / gait.resume()      hold the pose as it is (stone, ice) / carry on
##
## The root: walk() and walk_to() move the walker's root forward by a small step each frame,
## added to whatever else moves it, so an effect that shoves or leans the whole body (a status
## reaction) still works and the planted feet stay where they are. With move_root = false the
## gait only turns the bones; the caller then moves the root along its facing at
## current_speed() m/s (not at the speed it asked for: the gait speeds up and slows down).
## Its "GaitClock" child is an AnimationPlayer with nothing to play: when an effect pauses the
## first AnimationPlayer under a body (speed_scale 0, as freezing and petrifying effects do),
## the gait holds the same as with freeze_pose().
##
## Generated from WS/shared/demo_kit/demo_gait.gd by tools/vfxpack/demo_kit_sync.py.

## Emitted when walk_to() has stopped at its point.
signal arrived

const DEMO_KIT_VERSION: int = 15
## The walker's bones (DemoFigure.walker() builds them in this order). ".L" is the figure's own
## left (+X: it faces +Z).
const BONES: Array[String] = ["hips", "spine", "chest", "neck", "head",
	"upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "forearm.L", "hand.L",
	"thigh.R", "shin.R", "foot.R", "toe.R", "thigh.L", "shin.L", "foot.L", "toe.L"]
const PARENTS: Array[int] = [-1, 0, 1, 2, 3, 2, 5, 6, 2, 8, 9, 0, 11, 12, 13, 0, 15, 16, 17]
const B_HIPS: int = 0
const B_SPINE: int = 1
const B_CHEST: int = 2
const B_NECK: int = 3
const B_HEAD: int = 4
## Upper arm of the right side; side i (0 right, 1 left) adds 3 i: upper arm, forearm, hand.
const B_ARM: int = 5
## Thigh of the right side; side i adds 4 i: thigh, shin, foot, toes.
const B_LEG: int = 11
## Share of a stride a foot is down; the heel rolls flat by Q_HEEL and lifts from Q_OFF.
const DUTY: float = 0.6
const Q_HEEL: float = 0.07
const Q_OFF: float = 0.38
const SETTLE_SEC: float = 0.3
## A flinch: the hips take it first and each joint up the chain follows a little later
## (FLINCH_LAG seconds per joint); all back by FLINCH_SEC after the last one started.
const FLINCH_SEC: float = 0.6
const FLINCH_LAG: float = 0.035
## hurt(): seconds to bend into it and to come back out of it.
const HURT_IN_SEC: float = 0.55
const HURT_OUT_SEC: float = 0.75
## hurt(): strikes per second of each hand (the hands take turns).
const SWAT_HZ: float = 1.5

const _IDLE: int = 0
const _WALK: int = 1
const _STOP: int = 2
const _SETTLE: int = 3

## Move the root (walk(), walk_to()); false = the caller moves it at current_speed().
@export var move_root: bool = true
## How fast the walk speeds up and slows down (m/s per second).
@export var accel_m_s2: float = 2.2
## How fast walk_to() turns toward its point.
@export var turn_deg_s: float = 150.0
## 0 = arms hang still, 1 = a natural swing.
@export var arm_swing: float = 1.0
## Standing: a slow breath and weight shift (idle() sets it, stop() clears it).
@export var breathe: bool = true

var _skel: Skeleton3D
var _root: Node3D
var _clock: AnimationPlayer
var _h: float = 1.8
var _k: float = 1.0
var _j: PackedVector3Array = PackedVector3Array()
var _l1: PackedFloat32Array = PackedFloat32Array()
var _l2: PackedFloat32Array = PackedFloat32Array()
var _f0t: Array[Basis] = []
var _f0s: Array[Basis] = []
var _fwd: Array[Vector3] = []
var _lat: Array[Vector3] = []
var _heel: PackedVector3Array = PackedVector3Array()
var _ball: PackedVector3Array = PackedVector3Array()
var _tip: PackedVector3Array = PackedVector3Array()
var _ax_u: Array[Vector3] = []
var _ax_f: Array[Vector3] = []
var _ax_out: Array[Vector3] = []

var _mode: int = _IDLE
var _want_v: float = 0.9
var _v: float = 0.0
var _s: float = 0.5
var _p: float = 0.0
var _stop_end: float = 0.0
var _stop_span: float = 1.0
var _stop_rate: float = 0.0
var _to_goal: bool = false
var _goal: Vector3 = Vector3.ZERO
var _has_goal: bool = false
var _pending_walk: bool = false
var _settle_t: float = 0.0
var _heading: float = 0.0
var _user: float = 1.0
var _t: float = 0.0
var _breath: float = 1.0
var _fl_t: float = 10.0
var _fl_dir: Vector3 = Vector3.FORWARD
var _fl_s: float = 0.0
# hurt(): on, seconds left (-1 until calm()), how far into it (0..1), where (1 legs, 0 chest),
# the swatting clock.
var _hu_on: bool = false
var _hu_left: float = -1.0
var _hu_a: float = 0.0
var _hu_low: float = 1.0
var _hu_t: float = 0.0
var _idle_off: Vector3 = Vector3.ZERO
var _feet_ready: bool = false
# Per foot (0 right, 1 left).
var _down: Array[bool] = [true, true]
var _contact: Array[int] = [2, 2]
var _anchor: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _ayaw: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _lift_cycle: Array[int] = [0, 0]
var _lift_a: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _lift_yaw: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _lift_th: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _lift_toe: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _lift_floor: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _u0: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _settle_to: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _ank_w: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _fb: Array[Basis] = [Basis.IDENTITY, Basis.IDENTITY]
var _toe: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _th: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _fyaw: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])


## Called by DemoFigure.walker(): the skeleton, its joints in the rest pose (BONES order,
## skeleton space, feet on y = 0) and the figure's height.
func setup(skel: Skeleton3D, joints: PackedVector3Array, height: float) -> void:
	_skel = skel
	_root = skel.get_parent() as Node3D
	_j = joints
	_h = height
	_k = height / 1.8
	for i: int in 2:
		var leg: int = B_LEG + 4 * i
		var hip: Vector3 = _j[leg]
		var knee: Vector3 = _j[leg + 1]
		var ank: Vector3 = _j[leg + 2]
		var toe: Vector3 = _j[leg + 3]
		var f: Vector3 = Vector3(toe.x - ank.x, 0.0, toe.z - ank.z).normalized()
		_fwd.append(f)
		# Turning about f x UP by a positive angle lifts the toes.
		_lat.append(f.cross(Vector3.UP).normalized())
		_l1.append(hip.distance_to(knee))
		_l2.append(knee.distance_to(ank))
		_f0t.append(_aim(knee - hip, f))
		_f0s.append(_aim(ank - knee, f))
		var under: Vector3 = Vector3(ank.x, 0.0, ank.z)
		_heel.append(under + f * 0.003 * height)
		_ball.append(under + f * 0.07 * height)
		_tip.append(under + f * 0.11 * height + Vector3(0.0, 0.012 * height, 0.0))
		var arm: int = B_ARM + 3 * i
		_ax_u.append((_j[arm + 1] - _j[arm]).normalized().cross(Vector3.BACK).normalized())
		_ax_f.append((_j[arm + 2] - _j[arm + 1]).normalized().cross(Vector3.BACK).normalized())
		# Turning the upper arm about this lifts it away from the body (sideways, outward).
		_ax_out.append((_j[arm + 1] - _j[arm]).normalized().cross(Vector3(-1.0 if i == 0 else 1.0, 0.0, 0.0)).normalized())
	_clock = AnimationPlayer.new()
	_clock.name = "GaitClock"
	add_child(_clock)
	# After whatever else moves the body this frame (a reaction shoving the root).
	process_priority = 100


# ---------------------------------------------------------------- API

## Walks on along the root's facing at `speed_m_s` (changes speed smoothly when walking).
func walk(speed_m_s: float = 0.9) -> void:
	_has_goal = false
	_go(speed_m_s)


## Turns toward `target` (world) and walks there at `speed_m_s`, stopping within a few
## centimetres of it (the stop finishes a step); emits `arrived` once standing.
func walk_to(target: Vector3, speed_m_s: float = 0.9) -> void:
	_goal = target
	_has_goal = true
	_go(speed_m_s)


## Finishes the step, brings the other foot down beside it (SETTLE_SEC) and stands, breathing.
func idle() -> void:
	breathe = true
	_end_walk()


## The same as idle(), then stands quite still.
func stop() -> void:
	breathe = false
	_end_walk()


## A hit travelling along `dir` (world; the way the blow goes, from the attacker through the
## body): the knees give and the hips are pushed first, then the spine, the chest and last the
## head bend with it (a joint at a time, FLINCH_LAG apart), the arms come up, a walk staggers;
## all back by FLINCH_SEC. `strength` 1 = a solid hit (about 20 degrees at the chest).
func flinch(dir: Vector3, strength: float = 1.0) -> void:
	_fl_t = 0.0
	_fl_s = clampf(strength, 0.0, 2.0)
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.000001 and _skel != null:
		d = -_skel.global_basis.z
		d.y = 0.0
	_fl_dir = d.normalized() if d.length_squared() > 0.000001 else Vector3.FORWARD


## Hurt where it burns (or stings), for `seconds` (-1 = until calm()): the knees bend first and
## the hips drop, then the hands come up and beat at the hurt in turn, then the back rounds and
## the head looks down at it (HURT_IN_SEC); it comes out in the reverse order (HURT_OUT_SEC).
## `low` 1 = the legs (a burning floor), 0 = the chest. Standing or walking (a walk slows down
## and goes on hunched).
func hurt(seconds: float = -1.0, low: float = 1.0) -> void:
	if _hu_a <= 0.0:
		# The first strike lands about when the hands are up.
		_hu_t = 1.0 / SWAT_HZ - 0.5
	_hu_on = true
	_hu_left = seconds if seconds > 0.0 else -1.0
	_hu_low = clampf(low, 0.0, 1.0)


## Ends hurt(): straightens up over HURT_OUT_SEC.
func calm() -> void:
	_hu_on = false
	_hu_left = -1.0


## 0 not hurt, 1 fully into hurt().
func hurt_amount() -> float:
	return _hu_a


## Holds the pose exactly as it is (and the root where it is) until resume().
func freeze_pose() -> void:
	_user = 0.0


func resume() -> void:
	_user = 1.0


func is_frozen() -> bool:
	return _user <= 0.0 or (_clock != null and _clock.speed_scale <= 0.0)


## Metres per second the body is travelling at now (0 standing).
func current_speed() -> float:
	return _v if _mode == _WALK or _mode == _STOP else 0.0


func is_walking() -> bool:
	return _mode == _WALK or _mode == _STOP


## The world point under a foot (between heel and ball, on the sole): where a footprint goes.
func foot_position(left: bool) -> Vector3:
	var i: int = 1 if left else 0
	var mid: Vector3 = (_heel[i] + _ball[i]) * 0.5 - _j[B_LEG + 4 * i + 2]
	return _ank_w[i] + _fb[i] * mid


## True while the foot is on the floor.
func foot_down(left: bool) -> bool:
	return _down[1 if left else 0]


## 0 in the air, 1 on the heel, 2 flat, 3 on the ball (heel up).
func foot_contact(left: bool) -> int:
	return _contact[1 if left else 0]


# ---------------------------------------------------------------- clock

func _process(delta: float) -> void:
	if _skel == null or not is_instance_valid(_skel) or not _skel.is_inside_tree():
		return
	if not _feet_ready:
		_plant_rest()
		_update_feet(0.0)
		_pose()
	var rate: float = _user * (_clock.speed_scale if _clock != null else 1.0)
	if rate > 0.0:
		_advance(delta * rate)
	# Held or not, the legs still reach the planted feet: when something else shakes or leans
	# the held body, its feet stay on the floor.
	_pose()


func _go(speed_m_s: float) -> void:
	_want_v = maxf(speed_m_s, 0.05)
	if not _feet_ready and _skel != null and _skel.is_inside_tree():
		_plant_rest()
		_update_feet(0.0)
	if _mode == _IDLE:
		_start_walk()
	elif _mode == _STOP:
		_mode = _WALK
		_to_goal = false
	elif _mode == _SETTLE:
		_pending_walk = true


func _end_walk() -> void:
	_has_goal = false
	_pending_walk = false
	if _mode == _WALK:
		_begin_stop()


## Both feet down where they stand (the first frame in the tree).
func _plant_rest() -> void:
	var xf: Transform3D = _skel.global_transform
	var yaw: float = _yaw_of(xf.basis)
	for i: int in 2:
		var p: Vector3 = xf * _heel[i]
		p.y = _floor_y()
		_anchor[i] = p
		_ayaw[i] = yaw
		_down[i] = true
		_contact[i] = 2
	_heading = yaw
	_feet_ready = true


func _start_walk() -> void:
	if _root != null:
		_heading = _yaw_of(_root.global_basis)
	# The foot further back steps first, from half way through its swing (the other is at
	# mid-stance under the hips).
	var inv: Transform3D = _skel.global_transform.affine_inverse()
	var first: int = 1
	if (inv * _anchor[0]).z < (inv * _anchor[1]).z - 0.03 * _k:
		first = 0
	var off: float = _offset(first)
	_p = floorf(_p) + 1.8 - off
	var cyc: int = int(floorf(_p + off))
	_down[first] = false
	_contact[first] = 0
	_lift_cycle[first] = cyc
	_u0[first] = 0.5
	_lift_a[first] = _ank_w[first]
	_lift_th[first] = 0.0
	_lift_toe[first] = 0.0
	_lift_yaw[first] = _ayaw[first]
	_lift_floor[first] = _anchor[first].y
	_mode = _WALK
	_to_goal = false


## The right foot is half a stride behind the left.
func _offset(i: int) -> float:
	return 0.5 if i == 0 else 0.0


## Step length (heel to the other heel) for a speed: longer steps when faster, as people walk.
func _stride(v: float) -> float:
	return clampf(0.24 + 0.3 * v, 0.3, 0.7) * _k


## Where the walk can end: one foot at mid-stance (flat, under the hips) and the other in the
## air, at least a short way on from now. Returns the phase.
func _stop_plan() -> float:
	var a: float = _p + 0.15 * _v / (2.0 * _s)
	var c: float = floorf(a)
	var f: float = a - c
	if f < 0.15:
		return c + 0.15
	if f <= 0.36:
		return a
	if f < 0.65:
		return c + 0.65
	if f <= 0.86:
		return a
	return c + 1.15


func _begin_stop() -> void:
	_stop_end = _stop_plan()
	_stop_span = maxf(_stop_end - _p, 0.0001)
	# Slow down evenly to the end phase; no slower start than ending within 0.9 s.
	_stop_rate = maxf(_v / (2.0 * _s), 2.0 * _stop_span / 0.9)
	_mode = _STOP


func _begin_settle() -> void:
	_mode = _SETTLE
	_settle_t = 0.0
	_v = 0.0
	var xf: Transform3D = _skel.global_transform
	var inv: Transform3D = xf.affine_inverse()
	for i: int in 2:
		if _down[i]:
			continue
		var o: int = 1 - i
		var other: Vector3 = inv * _anchor[o]
		var spot: Vector3 = Vector3(_heel[i].x, 0.0, other.z + _heel[i].z - _heel[o].z)
		var w: Vector3 = xf * spot
		w.y = _floor_y()
		_settle_to[i] = w
		_lift_a[i] = _ank_w[i]
		_lift_th[i] = _th[i]
		_lift_toe[i] = _toe[i]
		_lift_yaw[i] = _fyaw[i]
		_lift_floor[i] = _floor_y()


func _end_settle() -> void:
	for i: int in 2:
		if not _down[i]:
			_down[i] = true
			_contact[i] = 2
			_anchor[i] = _settle_to[i]
			_ayaw[i] = _heading
	_mode = _IDLE
	if _pending_walk:
		_pending_walk = false
		_start_walk()
	elif _to_goal:
		_to_goal = false
		arrived.emit()


func _advance(dt: float) -> void:
	_t += dt
	_fl_t += dt
	var fl: float = _flinch_env(_fl_t) * _fl_s
	_breath = move_toward(_breath, 1.0 if breathe else 0.0, dt * 2.0)
	if _hu_on:
		_hu_a = minf(_hu_a + dt / HURT_IN_SEC, 1.0)
		if _hu_left > 0.0:
			_hu_left -= dt
			if _hu_left <= 0.0:
				_hu_on = false
	else:
		_hu_a = maxf(_hu_a - dt / HURT_OUT_SEC, 0.0)
	if _hu_a > 0.0:
		_hu_t += dt
	if _mode == _WALK:
		_v = move_toward(_v, _want_v, accel_m_s2 * dt)
		_s = _stride(_v)
		var v: float = _v * (1.0 - 0.55 * minf(fl, 1.0)) * (1.0 - 0.3 * smoothstep(0.0, 0.6, _hu_a))
		if _has_goal:
			_steer(dt)
		_p += v * dt / (2.0 * _s)
		_move(v * dt)
		if _has_goal and _mode == _WALK:
			var to: Vector3 = _goal - _root.global_position
			to.y = 0.0
			if to.length() <= (_stop_plan() - _p) * 2.0 * _s + 0.01 * _k:
				_has_goal = false
				_begin_stop()
				_to_goal = true
	elif _mode == _STOP:
		var rem: float = _stop_end - _p
		var rate: float = _stop_rate * sqrt(maxf(rem, 0.0) / _stop_span)
		var dp: float = rate * dt
		var done: bool = dp >= rem - 0.00001
		if done:
			dp = maxf(rem, 0.0)
		_p += dp
		_v = rate * 2.0 * _s
		_move(dp * 2.0 * _s)
		if done:
			_update_feet(dt)
			_begin_settle()
			return
	elif _mode == _SETTLE:
		_settle_t += dt
		if _settle_t >= SETTLE_SEC:
			_settle_t = SETTLE_SEC
			_update_feet(dt)
			_end_settle()
			return
	_update_feet(dt)


## Moves the root forward by `dist` metres (added to whatever else moved it).
func _move(dist: float) -> void:
	if not move_root or _root == null or dist == 0.0:
		return
	_root.global_position += Vector3(sin(_heading), 0.0, cos(_heading)) * dist


func _steer(dt: float) -> void:
	var to: Vector3 = _goal - _root.global_position
	to.y = 0.0
	if to.length() < 0.05 * _k:
		return
	var dh: float = wrapf(atan2(to.x, to.z) - _heading, -PI, PI)
	var turn: float = deg_to_rad(turn_deg_s) * dt
	var step: float = clampf(dh, -turn, turn)
	if absf(step) > 0.0:
		_heading += step
		# Turned about its own up, after any lean on it: a reaction's lean stays as it was.
		_root.rotate_object_local(Vector3.UP, step)


# ---------------------------------------------------------------- feet

func _update_feet(dt: float) -> void:
	var xf: Transform3D = _skel.global_transform
	var floor_y: float = _floor_y()
	var wp: float = clampf(_v / 0.8, 0.35, 1.0)
	var th_strike: float = deg_to_rad(18.0) * wp
	var th_off: float = deg_to_rad(-38.0) * wp
	var w_amt: float = _walk_amount()
	for i: int in 2:
		var ank_r: Vector3 = _j[B_LEG + 4 * i + 2]
		if _mode == _WALK or _mode == _STOP:
			var ph: float = _p + _offset(i)
			var q: float = ph - floorf(ph)
			var cyc: int = int(floorf(ph))
			if _down[i] and q >= DUTY:
				# Toe-off: the pose at the end of the stance is where the swing starts.
				var bb: Basis = Basis(Vector3.UP, _ayaw[i]) * Basis(_lat[i], th_off)
				var ball_w: Vector3 = _anchor[i] + Basis(Vector3.UP, _ayaw[i]) * (_ball[i] - _heel[i])
				_lift_a[i] = ball_w + bb * (ank_r - _ball[i])
				_lift_th[i] = th_off
				_lift_toe[i] = -th_off
				_lift_yaw[i] = _ayaw[i]
				_lift_floor[i] = _anchor[i].y
				_lift_cycle[i] = cyc
				_u0[i] = 0.0
				_down[i] = false
			elif not _down[i] and cyc > _lift_cycle[i]:
				# Heel strike: the landing spot (now under the swing's end) is fixed in the world.
				var land: Vector3 = _landing_heel(i, 0.0, w_amt)
				var hw: Vector3 = xf * land
				hw.y = floor_y
				_anchor[i] = hw
				_ayaw[i] = _yaw_of(xf.basis)
				_down[i] = true
			if _down[i]:
				_stance(i, q, th_strike, th_off)
			else:
				var u: float = (q - DUTY) / (1.0 - DUTY)
				var w: float = clampf((u - _u0[i]) / maxf(1.0 - _u0[i], 0.001), 0.0, 1.0)
				var land_h: Vector3 = _landing_heel(i, (1.0 - q) * 2.0 * _s, w_amt)
				var land_a: Vector3 = land_h + Basis(_lat[i], th_strike) * (ank_r - _heel[i])
				var target: Vector3 = xf * land_a
				target.y = floor_y + land_a.y
				var th: float = _lift_th[i] * (1.0 - smoothstep(0.0, 0.45, w)) + th_strike * smoothstep(0.45, 1.0, w)
				var toe: float = _lift_toe[i] * (1.0 - smoothstep(0.0, 0.35, w))
				_swing(i, w, target, th, toe, _yaw_of(xf.basis), floor_y, 0.045 * _k * wp)
		elif _mode == _SETTLE and not _down[i]:
			var w2: float = clampf(_settle_t / SETTLE_SEC, 0.0, 1.0)
			var target2: Vector3 = _settle_to[i] + Basis(Vector3.UP, _heading) * (ank_r - _heel[i])
			var e2: float = smoothstep(0.0, 1.0, w2)
			_swing(i, w2, target2, lerpf(_lift_th[i], 0.0, e2), lerpf(_lift_toe[i], 0.0, e2), _heading, floor_y, 0.02 * _k)
		else:
			_stance(i, 0.2, 0.0, 0.0)
	if dt > 0.0:
		# Standing: the hips settle over the middle of the feet.
		var inv: Transform3D = xf.affine_inverse()
		var want: Vector3 = Vector3.ZERO
		if _mode == _IDLE or _mode == _SETTLE:
			var mid: Vector3 = ((inv * _anchor[0]) + (inv * _anchor[1])) * 0.5 - (_heel[0] + _heel[1]) * 0.5
			want = Vector3(mid.x, 0.0, mid.z).limit_length(0.06 * _k)
		_idle_off = _idle_off.lerp(want, 1.0 - exp(-dt / 0.35))


## A foot on the floor at stance phase q: heel first (pivot on the heel), flat, then the heel
## lifts over the ball (pivot on the ball, the toes staying flat).
func _stance(i: int, q: float, th_strike: float, th_off: float) -> void:
	var ank_r: Vector3 = _j[B_LEG + 4 * i + 2]
	var flat: Basis = Basis(Vector3.UP, _ayaw[i])
	var th: float = 0.0
	if q < Q_HEEL:
		th = th_strike * (1.0 - smoothstep(0.0, Q_HEEL, q))
		_contact[i] = 1
	elif q < Q_OFF:
		_contact[i] = 2
	else:
		th = th_off * smoothstep(Q_OFF, DUTY, q)
		_contact[i] = 3
	var b: Basis = flat * Basis(_lat[i], th)
	if q < Q_OFF:
		_ank_w[i] = _anchor[i] + b * (ank_r - _heel[i])
		_toe[i] = 0.0
	else:
		var ball_w: Vector3 = _anchor[i] + flat * (_ball[i] - _heel[i])
		_ank_w[i] = ball_w + b * (ank_r - _ball[i])
		_toe[i] = -th
	_th[i] = th
	_fyaw[i] = _ayaw[i]
	_fb[i] = b


## A foot in the air, `w` (0..1) of the way from where it lifted to `target` (the ankle, world):
## eased so it leaves and lands without a jolt, raised by `bump` in the middle and never let
## through the floor.
func _swing(i: int, w: float, target: Vector3, th: float, toe: float, yaw_to: float,
		floor_y: float, bump: float) -> void:
	var e: float = smoothstep(0.0, 1.0, w)
	var a: Vector3 = _lift_a[i].lerp(target, e)
	a.y += bump * sin(PI * w)
	var low: float = _lowest(i, th, toe)
	var fl: float = lerpf(_lift_floor[i], floor_y, e)
	a.y = maxf(a.y, fl - low + 0.012 * _k * sin(PI * w))
	var yaw: float = lerp_angle(_lift_yaw[i], yaw_to, e)
	_ank_w[i] = a
	_th[i] = th
	_toe[i] = toe
	_fyaw[i] = yaw
	_fb[i] = Basis(Vector3.UP, yaw) * Basis(_lat[i], th)
	_contact[i] = 0


## The heel's landing spot in skeleton space, `ahead` metres further on (the walk to come
## before it lands). The feet come in toward the line of walking as the walk gets going.
func _landing_heel(i: int, ahead: float, w_amt: float) -> Vector3:
	return Vector3(lerpf(_heel[i].x, _heel[i].x * 0.72, w_amt), 0.0, _heel[i].z + DUTY * _s + ahead)


## How far below the ankle the lowest point of the foot is (negative) at pitch `th`, toes `toe`.
func _lowest(i: int, th: float, toe: float) -> float:
	var ank_r: Vector3 = _j[B_LEG + 4 * i + 2]
	var b: Basis = Basis(_lat[i], th)
	var heel: float = (b * (_heel[i] - ank_r)).y
	var ball_o: Vector3 = b * (_ball[i] - ank_r)
	var tip: float = ball_o.y + (Basis(_lat[i], th + toe) * (_tip[i] - _ball[i])).y
	return minf(heel, minf(ball_o.y, tip))


# ---------------------------------------------------------------- pose

func _pose() -> void:
	var xf: Transform3D = _skel.global_transform
	var inv: Transform3D = xf.affine_inverse()
	var w_amt: float = _walk_amount()
	# A flinch runs up the body a joint at a time: hips, spine, chest, arms, neck, head.
	var fl: float = _flinch_env(_fl_t) * _fl_s
	var fl_sp: float = _flinch_env(_fl_t - FLINCH_LAG) * _fl_s
	var fl_ch: float = _flinch_env(_fl_t - 2.0 * FLINCH_LAG) * _fl_s
	var fl_nk: float = _flinch_env(_fl_t - 3.0 * FLINCH_LAG) * _fl_s
	var fl_hd: float = _flinch_env(_fl_t - 4.5 * FLINCH_LAG) * _fl_s
	# hurt(): the knees first, then the hands, then the back (and out in the reverse order).
	var hk: float = smoothstep(0.0, 0.6, _hu_a)
	var ha: float = smoothstep(0.2, 0.85, _hu_a)
	var ht: float = smoothstep(0.3, 1.0, _hu_a)
	var low: float = _hu_low
	# Each hand: 1 drawn back (cocked), 0 struck home; a quick strike, a slower draw back.
	var cock: PackedFloat32Array = PackedFloat32Array([1.0, 1.0])
	var dip: float = 0.0
	if ha > 0.0:
		for i: int in 2:
			var u: float = fposmod(_hu_t * SWAT_HZ + 0.5 * float(i), 1.0)
			cock[i] = 1.0 - smoothstep(0.0, 0.2, u) if u < 0.2 else smoothstep(0.3, 0.8, u)
			dip = maxf(dip, 1.0 - cock[i])
		dip *= ht
	var fd: Vector3 = inv.basis * _fl_dir
	fd.y = 0.0
	fd = fd.normalized() if fd.length_squared() > 0.000001 else Vector3.FORWARD
	var bend_axis: Vector3 = Vector3.UP.cross(fd).normalized()
	var ph: float = TAU * _p
	var br: float = sin(TAU * _t / 4.2) * _breath * (1.0 - w_amt)
	# The hips: turn with the stepping leg, drop on the side of the leg in the air, a little
	# forward tilt; sway over the standing foot; give with a hit.
	var psi: float = -deg_to_rad(4.0) * w_amt * cos(ph)
	var phi: float = deg_to_rad(3.5) * w_amt * cos(ph - TAU * 0.3)
	# Hurt: the pelvis tips forward under the rounding back.
	var hunch_h: float = deg_to_rad(lerpf(5.0, 11.0, low)) * ht
	var rp: Basis = Basis(Vector3.UP, psi) * Basis(Vector3.BACK, phi) * Basis(Vector3.RIGHT, deg_to_rad(2.0) * w_amt + hunch_h)
	var sway: float = 0.022 * _k * w_amt * cos(ph - TAU * 0.3) + 0.004 * _k * _breath * (1.0 - w_amt) * sin(TAU * _t / 6.5)
	var hips_r: Vector3 = _j[B_HIPS]
	# Hurt: the hips go back to keep the bent body over the feet.
	var pp: Vector3 = hips_r + Vector3(sway, 0.0, 0.0) + _idle_off + fd * (0.05 * _k * fl) \
		+ Vector3(0.0, 0.0, -0.07 * _k * lerpf(0.6, 1.0, low) * ht)
	# A hit makes the knees give; hurt bends them (the legs reach the planted feet, so the knees
	# go forward over the toes).
	var h_want: float = hips_r.y - 0.004 * _k * w_amt - 0.05 * _k * fl - 0.001 * _k * br \
		- _h * lerpf(0.05, 0.1, low) * hk
	# As high as both legs can reach their feet (the hips rise over the standing leg).
	var targets: Array[Vector3] = [inv * _ank_w[0], inv * _ank_w[1]]
	var reach_k: float = lerpf(0.9975, 0.995, w_amt)
	var hy: float = h_want
	for i: int in 2:
		var c: Vector3 = Vector3(pp.x, 0.0, pp.z) + rp * (_j[B_LEG + 4 * i] - hips_r) - targets[i]
		var lm: float = (_l1[i] + _l2[i]) * reach_k
		var hi: float = -c.y + sqrt(maxf(lm * lm - c.x * c.x - c.z * c.z, 0.0))
		hy = _smin(hy, hi, 0.02 * _k)
	pp.y = hy
	_skel.set_bone_pose_position(B_HIPS, pp)
	_set_rot(B_HIPS, rp)
	# Legs: two-bone IK to the ankles, the knee toward the toes.
	for i: int in 2:
		var leg: int = B_LEG + 4 * i
		var hip: Vector3 = pp + rp * (_j[leg] - hips_r)
		var gf: Basis = (inv.basis * _fb[i]).orthonormalized()
		var pole: Vector3 = gf * _fwd[i]
		pole.y = 0.0
		pole = pole.normalized() if pole.length_squared() > 0.000001 else Vector3.BACK
		var r: PackedVector3Array = _reach(hip, targets[i], _l1[i], _l2[i], pole)
		var gt: Basis = _aim(r[0] - hip, pole) * _f0t[i].inverse()
		var gs: Basis = _aim(r[1] - r[0], pole) * _f0s[i].inverse()
		_set_rot(leg, rp.inverse() * gt)
		_set_rot(leg + 1, gt.inverse() * gs)
		_set_rot(leg + 2, gs.inverse() * gf)
		_set_rot(leg + 3, Basis(_lat[i], _toe[i]))
	# The trunk turns against the hips and leans a little into the walk; a hit bends the spine
	# and chest along it, the head whips after.
	var lean: float = deg_to_rad(2.5) * w_amt
	# Hurt: the back rounds a little more at each joint up the spine; a strike pulls the chest
	# down after the hand.
	var g_spine: Basis = Basis(bend_axis, deg_to_rad(8.0) * fl_sp) * (rp * (Basis(Vector3.UP, -0.55 * psi)
		* Basis(Vector3.BACK, -0.6 * phi) * Basis(Vector3.RIGHT, lean * 0.5 + deg_to_rad(lerpf(8.0, 12.0, low)) * ht)))
	_set_rot(B_SPINE, rp.inverse() * g_spine)
	var g_chest: Basis = Basis(bend_axis, deg_to_rad(12.0) * fl_ch) * (g_spine * (Basis(Vector3.UP, -0.75 * psi)
		* Basis(Vector3.BACK, -0.3 * phi) * Basis(Vector3.RIGHT, lean * 0.5 - deg_to_rad(0.8) * br
		+ deg_to_rad(lerpf(10.0, 15.0, low)) * ht + deg_to_rad(3.5) * dip)))
	_set_rot(B_CHEST, g_spine.inverse() * g_chest)
	var axis_c: Vector3 = (g_chest.inverse() * bend_axis).normalized()
	var look: float = deg_to_rad(2.0) * _breath * (1.0 - w_amt) * sin(TAU * _t / 9.0)
	# Hurt: the head looks down at it, toward the hand that is striking.
	var look_hurt: float = deg_to_rad(10.0) * (cock[0] - cock[1]) * ha
	_set_rot(B_NECK, Basis(axis_c, deg_to_rad(-6.0) * fl_nk) * Basis(Vector3.UP, 0.12 * psi)
		* Basis(Vector3.RIGHT, -lean * 0.4 + deg_to_rad(6.0) * ht))
	_set_rot(B_HEAD, Basis(axis_c, deg_to_rad(13.0) * fl_hd) * Basis(Vector3.UP, 0.12 * psi + look + look_hurt)
		* Basis(Vector3.RIGHT, -lean * 0.6 + deg_to_rad(0.5) * br + deg_to_rad(lerpf(6.0, 14.0, low)) * ht))
	# Arms swing against the legs (the right arm forward with the left leg), elbows bending
	# more on the forward swing. A hit: the arms come up after the chest (a guard). Hurt: the
	# hands take turns beating at the legs (low 1: arm down to the thigh, elbow straight) or the
	# chest (low 0: elbow bent, the hand at the breast), drawn back between strikes.
	var amp: float = deg_to_rad(8.0 + 11.0 * minf(_v, 1.4)) * w_amt * arm_swing
	for i: int in 2:
		var arm: int = B_ARM + 3 * i
		var sgn: float = 1.0 if i == 0 else -1.0
		var al: float = sgn * amp * cos(ph) + deg_to_rad(2.0) * w_amt * arm_swing
		var be: float = deg_to_rad(8.0) * w_amt * arm_swing + 0.35 * maxf(al, 0.0) + deg_to_rad(1.0) * br
		# Swinging forward the arm also opens a little, so the hand passes beside the hip.
		var opened: float = 0.45 * maxf(al, 0.0) + deg_to_rad(2.0) * w_amt * arm_swing
		al += deg_to_rad(18.0) * fl_ch
		be += deg_to_rad(38.0) * fl_ch
		opened += deg_to_rad(6.0) * fl_ch
		var wrist: float = deg_to_rad(5.0) * w_amt
		if ha > 0.0:
			var c: float = cock[i]
			var al_s: float = deg_to_rad(lerpf(lerpf(38.0, 32.0, low), lerpf(48.0, 42.0, low), c))
			var be_s: float = deg_to_rad(lerpf(lerpf(95.0, 10.0, low), lerpf(60.0, 72.0, low), c))
			var op_s: float = deg_to_rad(lerpf(2.0, 6.0, low))
			al = lerpf(al, al_s, ha)
			be = lerpf(be, be_s, ha)
			opened = lerpf(opened, op_s, ha)
			# The hand flaps down on the strike.
			wrist = lerpf(wrist, deg_to_rad(lerpf(4.0, 22.0, c)), ha)
		_set_rot(arm, Basis(_ax_out[i], opened) * Basis(_ax_u[i], al))
		_set_rot(arm + 1, Basis(_ax_f[i], be))
		_set_rot(arm + 2, Basis(_ax_f[i], wrist))


func _set_rot(bone: int, b: Basis) -> void:
	_skel.set_bone_pose_rotation(bone, b.orthonormalized().get_rotation_quaternion())


# ---------------------------------------------------------------- helpers

func _walk_amount() -> float:
	var v: float = _v if _mode == _WALK or _mode == _STOP else 0.0
	return smoothstep(0.0, 0.6, v)


func _floor_y() -> float:
	return _root.global_position.y if _root != null else _skel.global_position.y


## 0 outside a flinch; a quick eased rise (60 ms), a short hold and a long smooth return by
## FLINCH_SEC (no jump at either end).
static func _flinch_env(t: float) -> float:
	if t <= 0.0 or t >= FLINCH_SEC:
		return 0.0
	return smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.1, FLINCH_SEC, t))


## The world yaw of a basis's +Z (the way the figure faces).
static func _yaw_of(b: Basis) -> float:
	var z: Vector3 = b.z
	return atan2(z.x, z.z)


## A smooth minimum (never above min(a, b)).
static func _smin(a: float, b: float, k: float) -> float:
	var hh: float = maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - hh * hh * k * 0.25


## A turn that takes +Y to `dir` with +Z as close to `front` as it can be.
static func _aim(dir: Vector3, front: Vector3) -> Basis:
	var yy: Vector3 = dir.normalized()
	var zz: Vector3 = front - yy * front.dot(yy)
	if zz.length_squared() < 0.000001:
		zz = yy.cross(Vector3.RIGHT if absf(yy.x) < 0.9 else Vector3.UP)
	zz = zz.normalized()
	return Basis(yy.cross(zz).normalized(), yy, zz)


## Two-bone reach from `root` toward `target` (bones l1, l2), the middle joint bent toward
## `pole`: [middle joint, end] (the end stops short when the target is out of reach).
static func _reach(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> PackedVector3Array:
	var d: Vector3 = target - root
	var dist: float = clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.0005)
	var dir: Vector3 = d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var a: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var hh: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var side: Vector3 = pole - dir * pole.dot(dir)
	if side.length_squared() < 0.000001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	return PackedVector3Array([root + dir * a + side * hh, root + dir * dist])

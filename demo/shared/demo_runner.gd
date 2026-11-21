class_name PyroluxDemoRunner
extends Node
## Demo only: runs a showcase - a list of slots, one shown at a time - so that a product's
## showcase scene is its slot table and its slot builders and nothing else.
##
## What it does for every showcase the same way:
##  - the command line (after --): --quick (short slots, quits after the last one),
##    --slot=N, --hold (stay on one slot, rebuilt at the end of every loop when the slot
##    says "cut"); --no-intro, --autotest and --noui are read by the shared UI;
##  - the first slot is built before the UI, so it is already running behind the start
##    card (demo rule 1), and the timers pause while the card is up;
##  - one "<TAG>LOOP slot= frame= fps= start= period=" line per slot entered, which the
##    capture tools cut a store GIF to exactly one loop from (TXLOOP / AXLOOP before this);
##  - the bar: Prev / Next, the product's links and options in the order they were added,
##    the Quality button, Help; and the help card's rows from the same list;
##  - the caption (n / N, title, the line about it, the code) and which top corner the
##    card sits in.
##
## The product writes the table and the builders:
##
##   var run := PyroluxDemoRunner.new()
##   run.slots = [
##       {"title": "Ground slam", "about": "...", "code": "...", "period": 1.8,
##        "theme": &"STONE_YARD", "radius": 2.75},
##       ...]
##   run.root = slot_root            # its children are freed on every slot change
##   run.on_enter = _on_enter        # func(i: int, s: Dictionary): stage, camera
##   run.help_heading = "3D showcase  -  12 scenes"
##   run.add_link("Field", "F", KEY_F, "res://demo/field.tscn", "Field: break the ground")
##   run.add_cycle("Ground", "G", KEY_G, [&"STONE_YARD", &"DIRT_FIELD"], "Ground theme")
##   run.add_quality("Quality: High / Medium / Low (fewer elements)")
##   add_child(run)
##   run.stage = stage               # (v5) the stage the warm-up brings back from its first-visit look
##   run.start()                     # builds slot 0, then the UI (a browser's first visit: the UI only)
##   run.warm_up(stage.camera, true, func(w): w.lead_calls = [...])
##
## Web first visit (v5, godot-vfx-pack 2b-1b): create the stage with
## `stage.lite_start = PyroluxDemoRunner.lite_first_visit()`. Then start() builds only the UI
## and the start card, the warm-up (one job per frame) draws what slot 0 uses first, and slot 0 is
## built as soon as that is done or the card is closed, whichever comes first; the stage then comes
## back to its real look step by step. `--webwarm` does the same on a desktop for testing.
##
## A slot is built by "build" (a Callable, or the name of a method on `host`), else by the
## host's `_slot_<i>()`. Keys of a slot the runner reads: title, about, code, period
## (seconds of one loop), card_right (the info card in the top right corner), cut (false:
## --hold keeps the slot running instead of rebuilding it every period; default true),
## loop_start (seconds into the slot the loop begins, default 0). Every other key is the
## product's own (theme, radius, elevation ...), read in on_enter.
##
## Generated from WS/shared/demo_kit/demo_runner.gd by tools/vfxpack/demo_kit_sync.py.

signal slot_entered(index: int)

const DEMO_KIT_VERSION: int = 15
const DemoUi := preload("res://demo/shared/demo_ui.gd")
## The marker of the loop line the capture tools look for.
const LOOP_TAG: String = "PXLOOP"

var slots: Array[Dictionary] = []
## Where "_slot_<i>" and string "build" methods live. Default: the parent.
var host: Node
## The slot's own nodes. Its children are freed on every slot change.
var root: Node
## func(i: int, slot: Dictionary) -> void, called before the slot is built.
var on_enter: Callable
## Seconds on a slot before the slideshow moves on (--quick: quick_dwell).
var dwell: float = 7.0
var quick_dwell: float = 2.0
var help_heading: String = ""
## Text after the cycle name when no value is forced ("Ground: per scene").
var per_slot_label: String = "per scene"

var ui: DemoUi
## Optional: the kit's DemoStage, for the first-visit mode (see above).
var stage: Node
var timers: PyroluxDemoTimers
var slot: int = 0
var slot_time: float = 0.0
var hold: bool = false
var quick: bool = false

var _items: Array[Dictionary] = []
var _cycles: Dictionary = {}
var _quality_button: PanelContainer
var _started: bool = false
var _loop_pending: bool = false
var _loop_frame: int = -1
var _warm: PyroluxDemoWarmup
## Slot 0 is built when the warm-up has drawn what it uses (a browser's first visit).
var _first_pending: bool = false


## A button that changes to another demo scene.
func add_link(text: String, key: String, keycode: Key, scene_path: String, help: String) -> void:
	add_action(text, key, keycode, func() -> void: get_tree().change_scene_to_file(scene_path), help)


## A button (and its key) that calls `fn`.
func add_action(text: String, key: String, keycode: Key, fn: Callable, help: String) -> void:
	_items.append({"kind": "action", "text": text, "key": key, "keycode": keycode, "fn": fn,
		"help": help})


## A button that steps through `values` and back to "per scene" (each slot's own), then
## enters the slot again. Read the current value with cycle_value(name).
func add_cycle(name: String, key: String, keycode: Key, values: Array[StringName], help: String) -> void:
	_cycles[name] = {"values": values, "i": -1}
	_items.append({"kind": "cycle", "name": name, "key": key, "keycode": keycode, "help": help})


## The Quality button: Pyrolux.quality High -> Medium -> Low, the slot entered again.
## A browser build starts on MEDIUM (demo rule 7).
func add_quality(help: String) -> void:
	_items.append({"kind": "quality", "key": "Q", "keycode": KEY_Q, "help": help})


## A gap between groups of buttons in the bar.
func add_gap() -> void:
	_items.append({"kind": "gap"})


## The forced value of a cycle, or &"" while it is on each slot's own.
func cycle_value(name: String) -> StringName:
	if not _cycles.has(name):
		return &""
	var c: Dictionary = _cycles[name]
	var i: int = c["i"]
	if i < 0:
		return &""
	var values: Array[StringName] = c["values"]
	return values[i]


## The forced value of a cycle, else the slot's own value under `key`.
func pick(name: String, key: String) -> Variant:
	var v: StringName = cycle_value(name)
	if v != &"":
		return v
	return slots[slot].get(key)


func period(i: int = -1) -> float:
	var s: Dictionary = slots[slot if i < 0 else i]
	var p: float = s.get("period", dwell)
	return p


## True on a browser's first visit to the first scene (and with --webwarm): the stage should
## start in its quick look and the first slot waits for the warm-up. Call it before creating the
## stage, and before the UI exists (the UI marks the card as seen).
static func lite_first_visit() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--nowarm"):
		return false
	if not (OS.has_feature("web") or args.has("--webwarm")):
		return false
	if Engine.has_meta(DemoUi.INTRO_META):
		return false
	for a: String in args:
		if DemoUi.NO_INTRO_ARGS.has(a) or a.begins_with("--slot="):
			return false
	return true


## Builds the first slot, then the UI (demo rule 1). On a browser's first visit the UI comes
## first and the slot waits for the warm-up (v5).
func start() -> void:
	if host == null:
		host = get_parent()
	for a: String in OS.get_cmdline_user_args():
		if a == "--quick":
			dwell = quick_dwell
			quick = true
		elif a == "--hold":
			hold = true
		elif a.begins_with("--slot="):
			slot = clampi(int(a.substr(7)), 0, slots.size() - 1)
	if OS.has_feature("web") and _has_quality():
		Pyrolux.quality = Pyrolux.Quality.MEDIUM
	timers = PyroluxDemoTimers.new()
	timers.name = "Timers"
	add_child(timers)
	_started = true
	if lite_first_visit():
		_build_ui()
		if ui.is_help_open():
			_first_pending = true
		else:
			enter(slot)
		return
	enter(slot)
	_build_ui()


## Adds the shader warm-up (behind the start card). `cam` null for a 2D scene. `setup`, if
## given, is called with the warm-up before it starts: set its lead_* lists there (what slot 0
## uses, drawn first).
func warm_up(cam: Camera3D, do_2d: bool = true, setup: Callable = Callable()) -> PyroluxDemoWarmup:
	var w: PyroluxDemoWarmup = PyroluxDemoWarmup.new()
	w.camera = cam
	w.do_2d = do_2d
	w.stage = stage
	if setup.is_valid():
		setup.call(w)
	_warm = w
	if _first_pending:
		w.lead_ready.connect(_enter_first)
		w.finished.connect(_enter_first)
	if ui != null and ui.has_method(&"watch_warmup"):
		ui.call(&"watch_warmup", w)
	add_child(w)
	return w


func _enter_first() -> void:
	if _first_pending:
		_mark("First")
		enter(slot)


## Web only: writes a timestamp (ms since the page started) to window.__fx<name>, so a probe
## (status/_dev/webprobe/measure.py) can read when slot 0 was built and when the stage was back.
static func _mark(mark_name: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__fx%s = performance.now() | 0" % mark_name)


func next_slot() -> void:
	if quick and slot + 1 >= slots.size():
		get_tree().quit()
		return
	enter((slot + 1) % slots.size())


func prev_slot() -> void:
	enter((slot + slots.size() - 1) % slots.size())


## Enters slot `i`. `replay` rebuilds the same slot for its next loop (--hold) without a
## new loop line: the capture tools count loops from the first one.
func enter(i: int, replay: bool = false) -> void:
	_first_pending = false
	slot = i
	slot_time = 0.0
	timers.clear()
	if root != null:
		for c: Node in root.get_children():
			root.remove_child(c)
			c.queue_free()
	var s: Dictionary = slots[i]
	if on_enter.is_valid():
		on_enter.call(i, s)
	caption()
	if not replay:
		_loop_pending = true
		_loop_frame = -1
	var b: Variant = s.get("build")
	if b is Callable:
		var cb: Callable = b
		cb.call()
	elif b is String or b is StringName:
		var m: StringName = b
		host.call(m)
	elif host.has_method("_slot_%d" % i):
		host.call("_slot_%d" % i)
	slot_entered.emit(i)


## The top-left card: "n / N   title", the line about it, the code; and its corner.
func caption() -> void:
	if ui == null:
		return
	var s: Dictionary = slots[slot]
	var right: bool = s.get("card_right", false)
	ui.set_info("%d / %d   %s" % [slot + 1, slots.size(), str(s.get("title", ""))],
		str(s.get("about", "")), str(s.get("code", "")))
	ui.card_right = right


func _process(delta: float) -> void:
	if not _started:
		return
	if is_instance_valid(_warm) and ui != null and not ui.is_help_open():
		# The card is closed: the visitor is watching, so the warm-up goes slowly.
		_warm.gap_frames = 8
	if _first_pending:
		# Slot 0 normally waits for the warm-up; the card closing or no warm-up ends the wait.
		if not is_instance_valid(_warm) or not ui.is_help_open():
			enter(slot)
		return
	var s: Dictionary = slots[slot]
	var cut: bool = s.get("cut", true)
	if hold and cut and slot_time >= period() - 0.001:
		# The capture's next loop: a fresh slot, cut in at the seam, never cleared in view.
		# Checked before slot_time moves on, so every loop is exactly `period` long.
		enter(slot, true)
		s = slots[slot]
	if _loop_pending:
		# The frame is taken on the slot's first frame and printed on its second, whose
		# delta is the capture's fixed step (the first frame's is whatever the engine did).
		if _loop_frame < 0:
			_loop_frame = Engine.get_frames_drawn()
		else:
			_loop_pending = false
			var start_s: float = s.get("loop_start", 0.0)
			print("%s slot=%d frame=%d fps=%d start=%.2f period=%.2f" % [LOOP_TAG, slot,
				_loop_frame, PyroluxDemoFrame.capture_fps(), start_s, period()])
	if not timers.paused:
		slot_time += delta
	if not hold and slot_time > dwell:
		next_slot()


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_RIGHT:
		next_slot()
		return
	if k.keycode == KEY_LEFT:
		prev_slot()
		return
	for it: Dictionary in _items:
		if it.has("keycode") and k.keycode == it["keycode"]:
			get_viewport().set_input_as_handled()
			_run_item(it)
			return


func _run_item(it: Dictionary) -> void:
	match str(it["kind"]):
		"action":
			var fn: Callable = it["fn"]
			fn.call()
		"cycle":
			var c: Dictionary = _cycles[it["name"]]
			var values: Array[StringName] = c["values"]
			var i: int = c["i"]
			i += 1
			c["i"] = -1 if i >= values.size() else i
			_update_buttons()
			enter(slot)
		"quality":
			Pyrolux.quality = ((int(Pyrolux.quality) + 2) % 3) as Pyrolux.Quality
			_update_buttons()
			enter(slot)


func _has_quality() -> bool:
	for it: Dictionary in _items:
		if it["kind"] == "quality":
			return true
	return false


func _build_ui() -> void:
	ui = DemoUi.new()
	add_child(ui)
	ui.add_bar_button("Prev", "<", prev_slot, "tri_left")
	ui.add_bar_button("Next", ">", next_slot, "tri_right", true)
	ui.add_bar_gap()
	var rows: Array[Dictionary] = [
		{"keys": PackedStringArray(["<", ">"]), "text": "Previous / next scene"}]
	for it: Dictionary in _items:
		var kind: String = it["kind"]
		if kind == "gap":
			ui.add_bar_gap()
			continue
		var b: PanelContainer = ui.add_bar_button(_item_text(it), str(it["key"]), _run_item.bind(it))
		it["button"] = b
		if kind == "quality":
			_quality_button = b
		if str(it.get("help", "")) != "":
			rows.append({"keys": PackedStringArray([str(it["key"])]), "text": str(it["help"])})
	ui.add_bar_gap()
	ui.add_bar_button("Help", "H", ui.show_help.bind(false))
	rows.append({"keys": PackedStringArray(["H", "?"]), "text": "Show this help again"})
	ui.help_heading = help_heading
	ui.help_rows = rows
	_update_buttons()
	# The first slot was built before the UI existed, so its caption is set here.
	caption()
	ui.show_intro_once()
	if ui.is_help_open():
		timers.paused = true
		ui.help_closed.connect(func() -> void: timers.paused = false)


func _item_text(it: Dictionary) -> String:
	match str(it["kind"]):
		"cycle":
			var cname: String = it["name"]
			var v: StringName = cycle_value(cname)
			var t: String = per_slot_label if v == &"" else str(v).to_lower().replace("_", " ")
			return "%s: %s" % [it["name"], t]
		"quality":
			var names: PackedStringArray = PackedStringArray(["Low", "Medium", "High"])
			return "Quality: " + names[int(Pyrolux.quality)]
	return str(it.get("text", ""))


func _update_buttons() -> void:
	if ui == null:
		return
	for it: Dictionary in _items:
		if it.has("button"):
			var b: PanelContainer = it["button"]
			ui.set_button_text(b, _item_text(it))

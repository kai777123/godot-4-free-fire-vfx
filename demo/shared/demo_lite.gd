class_name PyroluxDemoLite
extends Node
## Demo only: the frame of a Lite demo - the free pack's one node and its few presets -
## so the product's lite_demo.gd is the node, its stage and its buttons and nothing else.
##
## What it does the same way for every pack:
##  - the full pack's one line in its own band above the buttons, and a button to the full
##    pack in the corner (the shared UI's add_lite_line / add_full_link; skill step 5: the
##    Lite demo says what the paid pack adds, and never less);
##  - buttons that step through a short list ("Ground: dirt / grass / stone") or run an
##    action, each with its key, and the help card's rows from the same list;
##  - --autotest presses the given steps in turn (the capture and the test table use it);
##  - the timers pause while the start card is up; a browser starts on MEDIUM quality.
##
##   var lite := PyroluxDemoLite.new()
##   lite.help_heading = "Free footstep dust  -  one node, three grounds"
##   lite.add_help_row(PackedStringArray(["W", "A", "S", "D"]), "Walk")
##   lite.add_cycle("Ground", "N", KEY_N, PackedStringArray(["dirt", "grass"]), _on_ground, "Ground: ...")
##   lite.add_action("Jump", "Space", KEY_SPACE, _jump, "Jump: ...")
##   lite.autotest_steps = [_next_ground, _jump]
##   add_child(lite)
##   lite.start()
##   lite.info("Free: footstep dust", "One node ...", "Pyrolux.step(self, foot)")
##
## The full pack's line and URL come from pack.json (demo_kit.lite_line, itch.full_slug)
## when this file is generated; a scene can still set `line` / `url` before start().
##
## Generated from WS/shared/demo_kit/demo_lite.gd by tools/vfxpack/demo_kit_sync.py.

const DEMO_KIT_VERSION: int = 15
const DemoUi := preload("res://demo/shared/demo_ui.gd")

var line: String = "The full pack adds burning objects, lava, smoke, sparks, meteors and 2D  -  49 presets."
var url: String = "https://gennai.itch.io/pyrolux-fire-explosion-vfx"
var link_text: String = "Get the full pack"
var help_heading: String = ""
## --autotest: the first step after `autotest_first` seconds, then one every `autotest_every`.
var autotest_steps: Array[Callable] = []
var autotest_first: float = 1.2
var autotest_every: float = 2.0
## Off for a Lite pack whose node does not follow Pyrolux.quality.
var use_quality: bool = true

var ui: DemoUi
var timers: PyroluxDemoTimers
var autotest: bool = false

var _items: Array[Dictionary] = []
var _rows_before: Array[Dictionary] = []
var _clock: float = 0.0
var _auto_next: float = 0.0
var _auto_i: int = 0
var _started: bool = false


## A help row with no button of its own (WASD).
func add_help_row(keys: PackedStringArray, text: String) -> void:
	_rows_before.append({"keys": keys, "text": text})


## A button that steps through `labels`; `on_change` gets the new index.
func add_cycle(name: String, key: String, keycode: Key, labels: PackedStringArray,
		on_change: Callable, help: String) -> void:
	_items.append({"kind": "cycle", "name": name, "key": key, "keycode": keycode,
		"labels": labels, "i": 0, "fn": on_change, "help": help})


## A button (and its key) that calls `fn`.
func add_action(text: String, key: String, keycode: Key, fn: Callable, help: String) -> void:
	_items.append({"kind": "action", "text": text, "key": key, "keycode": keycode, "fn": fn,
		"help": help})


## Steps the cycle `name` on by one (what its button does). For autotest_steps.
func step_cycle(name: String) -> void:
	for it: Dictionary in _items:
		if it["kind"] == "cycle" and it["name"] == name:
			_run_item(it)
			return


## The current index of the cycle `name`.
func cycle_index(name: String) -> int:
	for it: Dictionary in _items:
		if it["kind"] == "cycle" and it["name"] == name:
			var i: int = it["i"]
			return i
	return 0


## Sets the three lines of the top-left card.
func info(title: String, description: String, code: String) -> void:
	if ui != null:
		ui.set_info(title, description, code)


## Whether the scene should hold still (the start card is up).
func is_paused() -> bool:
	return timers == null or timers.paused


func start() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
	if OS.has_feature("web") and use_quality:
		Pyrolux.quality = Pyrolux.Quality.MEDIUM
	if timers == null:
		timers = PyroluxDemoTimers.new()
		add_child(timers)
	_auto_next = autotest_first
	_build_ui()
	_started = true


## The timers, before start(): a Lite scene that schedules things while it builds its
## stage calls this first.
func make_timers() -> PyroluxDemoTimers:
	if timers == null:
		timers = PyroluxDemoTimers.new()
		add_child(timers)
	return timers


func _build_ui() -> void:
	ui = DemoUi.new()
	add_child(ui)
	var rows: Array[Dictionary] = []
	rows.append_array(_rows_before)
	for it: Dictionary in _items:
		var b: PanelContainer = ui.add_bar_button(_item_text(it), str(it["key"]), _run_item.bind(it))
		it["button"] = b
		var help: String = it["help"]
		if help != "":
			rows.append({"keys": PackedStringArray([str(it["key"])]), "text": help})
	ui.add_bar_gap()
	ui.add_bar_button("Help", "H", ui.show_help.bind(false))
	rows.append({"keys": PackedStringArray(["H", "?"]), "text": "Show this help again"})
	ui.help_heading = help_heading
	ui.help_rows = rows
	ui.add_lite_line(line, url)
	ui.add_full_link(link_text, url)
	ui.show_intro_once()
	if ui.is_help_open():
		timers.paused = true
		ui.help_closed.connect(func() -> void: timers.paused = false)


func _item_text(it: Dictionary) -> String:
	if it["kind"] == "cycle":
		var labels: PackedStringArray = it["labels"]
		var i: int = it["i"]
		return "%s: %s" % [str(it["name"]), labels[i]]
	return str(it["text"])


func _run_item(it: Dictionary) -> void:
	var fn: Callable = it["fn"]
	if it["kind"] == "cycle":
		var labels: PackedStringArray = it["labels"]
		var i: int = it["i"]
		i = (i + 1) % labels.size()
		it["i"] = i
		var b: PanelContainer = it["button"]
		ui.set_button_text(b, _item_text(it))
		fn.call(i)
	else:
		fn.call()


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	for it: Dictionary in _items:
		if k.keycode == it["keycode"]:
			_run_item(it)
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	_clock += delta
	if not _started or timers.paused or not autotest or autotest_steps.is_empty():
		return
	if _clock < _auto_next:
		return
	_auto_next = _clock + autotest_every
	_auto_i += 1
	autotest_steps[_auto_i % autotest_steps.size()].call()

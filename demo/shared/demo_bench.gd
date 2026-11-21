class_name PyroluxDemoBench
extends Node
## Demo only: the benchmark of a pack - how many of its effects one frame holds. Up / Down
## change how many run at once, Space holds the count, Q changes quality, R resets the
## numbers, B goes back to the showcase.
## Command line (after --): --autotest (climbs the steps on its own and quits), --noui.
##
## The product builds the nodes (where they stand is its stage's business) and hands them
## over; this file counts, prints and draws the UI:
##
##   var bench := PyroluxDemoBench.new()
##   add_child(bench)
##   var nodes := bench.build_nodes(effects_root, P3, KINDS, func(i: int, n: Node3D) -> void:
##       n.position = Vector3(...))
##   bench.mode = PyroluxDemoBench.Mode.FIRE      # or RUN for looping effects
##   bench.start()
##
## Two modes, because packs come in two kinds:
##  FIRE - one-shot effects (a slam, a burst): the first STEPS[step] nodes are re-triggered
##    every `fire_every` seconds; R calls reset() on every node.
##  RUN - looping effects (a shaft, fireflies): the first STEPS[step] nodes play, the rest
##    are stopped.
##
## Prints "BENCH step=N effects=N fps=F worst_ms=F" after each step of the --autotest climb,
## then "BENCH done steps=N". Every step is measured, the last one too.
##
## Generated from WS/shared/demo_kit/demo_bench.gd by tools/vfxpack/demo_kit_sync.py.

enum Mode { FIRE, RUN }

const DEMO_KIT_VERSION: int = 15
const DemoUi := preload("res://demo/shared/demo_ui.gd")

## The steps the count climbs through. The last one is far past anything a game does.
var steps: Array[int] = [1, 2, 4, 8, 16, 32, 64]
## Seconds spent on each step before the number is taken.
var dwell: float = 4.0
var mode: Mode = Mode.FIRE
var fire_every: float = 0.5
## Every node the highest step needs, built once up front: a benchmark that instanced its
## own nodes while it counted would be measuring the instancing.
var nodes: Array[Node] = []
var back_scene: String = "res://demo/showcase.tscn"
var help_heading: String = "Benchmark  -  how many PYROLUX effects one frame can hold"
var quality_help: String = "Quality: High / Medium / Low (fewer elements per effect)"
## The second line of the card, after the numbers.
var describe: String = ""

var ui: DemoUi
var timers: PyroluxDemoTimers
var step: int = 2
var holding: bool = false
var autotest: bool = false

var _count_button: PanelContainer
var _quality_button: PanelContainer
var _frames: int = 0
var _time: float = 0.0
var _worst: float = 0.0
var _dwell: float = 0.0
var _started: bool = false


## Instances `count` presets (default: the highest step) round-robin from `kinds` under
## `parent`, not playing, and lets `place` position and colour each one before it enters
## the tree. Returns them (also kept in `nodes`).
func build_nodes(parent: Node, dir: String, kinds: Array[String], place: Callable,
		count: int = -1) -> Array[Node]:
	var n_total: int = count if count > 0 else steps[steps.size() - 1]
	for i: int in n_total:
		var scene: PackedScene = load(dir + kinds[i % kinds.size()] + ".tscn") as PackedScene
		var n: Node = scene.instantiate()
		if &"autoplay" in n:
			n.set(&"autoplay", false)
		if &"preview_in_editor" in n:
			n.set(&"preview_in_editor", false)
		if place.is_valid():
			place.call(i, n)
		parent.add_child(n)
		nodes.append(n)
	return nodes


func start() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
			step = 0
	step = clampi(step, 0, steps.size() - 1)
	timers = PyroluxDemoTimers.new()
	add_child(timers)
	if mode == Mode.FIRE:
		timers.every(fire_every, 0.1, _fire_wave)
	else:
		_apply()
	_build_ui()
	_started = true


func _build_ui() -> void:
	ui = DemoUi.new()
	add_child(ui)
	_count_button = ui.add_bar_button("Effects: 4", "", _no_op)
	ui.add_bar_button("Fewer", "Down", _fewer)
	ui.add_bar_button("More", "Up", _more)
	ui.add_bar_gap()
	ui.add_bar_button("Hold", "Space", _toggle_hold)
	_quality_button = ui.add_bar_button("Quality: High", "Q", _cycle_quality)
	ui.add_bar_button("Reset", "R", _reset)
	ui.add_bar_gap()
	ui.add_bar_button("3D showcase", "B", _go_back)
	ui.add_bar_button("Help", "H", ui.show_help.bind(false))
	ui.help_heading = help_heading
	ui.help_rows = [
		{"keys": PackedStringArray(["Up", "Down"]), "text": "More / fewer effects at once"},
		{"keys": PackedStringArray(["Space"]), "text": "Hold the count where it is (the automatic climb stops)"},
		{"keys": PackedStringArray(["Q"]), "text": quality_help},
		{"keys": PackedStringArray(["R"]), "text": "Reset the frame times"},
		{"keys": PackedStringArray(["B"]), "text": "Back to the 3D showcase"},
		{"keys": PackedStringArray(["H", "?"]), "text": "Show this help again"},
	]
	_update()
	ui.show_intro_once()


func _no_op() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_UP:
			_more()
		KEY_DOWN:
			_fewer()
		KEY_SPACE:
			_toggle_hold()
		KEY_Q:
			_cycle_quality()
		KEY_R:
			_reset()
		KEY_B:
			_go_back()


func _more() -> void:
	step = mini(step + 1, steps.size() - 1)
	_reset()


func _fewer() -> void:
	step = maxi(step - 1, 0)
	_reset()


func _toggle_hold() -> void:
	holding = not holding
	_update()


func _cycle_quality() -> void:
	Pyrolux.quality = ((int(Pyrolux.quality) + 2) % 3) as Pyrolux.Quality
	_reset()


func _reset() -> void:
	_frames = 0
	_time = 0.0
	_worst = 0.0
	_dwell = 0.0
	if mode == Mode.FIRE:
		for n: Node in nodes:
			if n.has_method(&"reset"):
				n.call(&"reset")
	else:
		_apply()
	_update()


func _go_back() -> void:
	get_tree().change_scene_to_file(back_scene)


func _fire_wave() -> void:
	var live: int = mini(steps[step], nodes.size())
	for i: int in live:
		nodes[i].call(&"trigger")


## RUN mode: the first steps[step] nodes play, the rest stop.
func _apply() -> void:
	var live: int = steps[step]
	for i: int in nodes.size():
		var n: Node = nodes[i]
		var on: bool = n.call(&"is_playing")
		if i < live:
			if not on:
				n.call(&"play")
		elif on:
			n.call(&"stop")


func _process(delta: float) -> void:
	if not _started:
		return
	_frames += 1
	_time += delta
	_worst = maxf(_worst, delta)
	_dwell += delta
	if autotest and not holding and _dwell > dwell:
		_dwell = 0.0
		print("BENCH step=%d effects=%d fps=%.1f worst_ms=%.2f"
			% [step, steps[step], float(_frames) / maxf(_time, 0.001), _worst * 1000.0])
		if step + 1 >= steps.size():
			print("BENCH done steps=%d" % steps.size())
			get_tree().quit()
			return
		step += 1
		_frames = 0
		_time = 0.0
		_worst = 0.0
		if mode == Mode.RUN:
			_apply()
	if _frames % 15 == 0:
		_update()


func _update() -> void:
	if ui == null:
		return
	var fps: float = float(_frames) / maxf(_time, 0.001)
	ui.set_button_text(_count_button, "Effects: %d" % steps[step])
	var names: PackedStringArray = PackedStringArray(["Low", "Medium", "High"])
	ui.set_button_text(_quality_button, "Quality: " + names[int(Pyrolux.quality)])
	var what: String = describe
	if what == "":
		what = "One of each node type, re-fired every half second." if mode == Mode.FIRE \
			else "One of each node type, all running at once."
	# The code line is the live setting, not an example: a caption that says MEDIUM while
	# the button says High is what demo rule 3 is about.
	ui.set_info("Benchmark   %d effects at once" % steps[step],
		"%.1f fps average, worst frame %.1f ms. %s" % [fps, _worst * 1000.0, what],
		"Pyrolux.quality = Pyrolux.Quality.%s" % names[int(Pyrolux.quality)].to_upper())
	ui.set_hint("Holding the count" if holding else "")

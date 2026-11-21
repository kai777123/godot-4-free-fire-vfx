extends CanvasLayer
## On-screen help shared by the PYROLUX demo scenes (only used by the demos).
## Top left (or top right, `card_right`): scene title, one line about what it shows, and the
## code behind it.
## Bottom: a bar of buttons (mouse and touch) that also show their keyboard key.
## H or ?: a help card with every control. The first demo scene opened shows a small start note
## (the store name, the main keys, "H  All controls") above the button bar; it covers nothing,
## needs no click and fades after a few seconds (v5).
## Small or narrow screens (phones, a small browser window, an itch.io embed cut off by a narrow
## page): the UI is scaled up so the text stays readable, long lines wrap, the bottom buttons wrap
## onto more rows, and everything stays inside the part of the canvas the browser really shows.
##
## Every text on screen sits on a dark half-transparent band with a black outline, so it reads
## on a bright scene (white ice on snow, a white range wall) as well as on a dark one.
## No size below 18 px at 1280x720.
##
## This file is generated from WS/shared/demo_ui/demo_ui.gd by tools/vfxpack/demo_ui_sync.py:
## the product strings and colours come from <product>/pack.json ("demo_ui"). Edit the shared
## file, then run demo_ui_sync.py --write; DEMO_UI_VERSION says which revision this copy is.
## The revisions before the current one are kept in WS/shared/demo_ui/versions/.

## Revision of the shared demo UI this copy was generated from (checked by build_dist.py when
## demo_ui.managed is on). Bump it in the shared file whenever its behaviour changes.
## 2 (2026-10-16): the info card of ATMOLUX demo_card.gd - 26 / 19 / 18 px text by default
## (pack.json demo_ui.card_px) and `card_right` / place_card() for the top right corner.
## 3 (2026-10-26): `watch_warmup(w)` puts "Loading effects N / M" under the start card's key note
## while the warm-up runs (one job per frame, kit v5); the long-first-load
## sentence is gone - the default load_note is empty - and the page's first-visit note
## (web_note.js) is cleared two frames after the card is up (godot-vfx-pack 2b-1b).
## 4 (2026-10-27): a store name too long for one line on the start card shrinks (60/46 px down to
## 34) before it wraps (JANULUX at 960x540 left "4" alone on a second line).
## 5 (2026-10-31): no start card. The first scene plays at once, with a small start note above the
## button bar instead (store name, the first help row, "H  All controls", "Loading effects N / M"),
## which fades CHIP_SECONDS after the first effect is up. On a browser's first visit
## is_help_open() stays true for the warm-up, so the kit's runner still builds slot 0 on what the
## lead jobs compiled and starts its timers only when the hold ends; the note then calls
## window.fxPreviewDone() / fxNoteDone() (the page's loading clip, shared/web_shell, or
## web_note.js goes away). With the loading clip on the page the hold lasts until the whole
## warm-up is done (the progress goes to window.fxLoad(done, total)): BLASTLUX 2026-10-31, slot 0
## built at lead_ready froze for 8 s in a flat unlit stage right after the clip faded. Without the
## clip (Godot's own shell) it ends at `lead_ready`, as the card's click did before.
## 6 (2026-10-31): pack.json demo_ui.release picks when the hold on the first scene ends. "all"
## (default, as v5): the whole warm-up is done. "lead": slot 0's jobs are done AND the stage is back
## to its real look (stage.is_lite() false); the rest of the warm-up goes on after the switch, one
## job per 8 frames as before. The 60 s safety is counted in Time.get_ticks_msec, not in frames
## (a frozen frame of several seconds used to push it to 80 s). In "lead" mode the warm-up's
## gap_frames is set to 8 at the switch so no job runs in the two frames the page-ready call waits. v5 is in versions/demo_ui_v5.gd.
## 6.1 (2026-11-01, studio rollout): with a kit 13 stage (lite_ghosts) "lead" ends the hold when
## slot 0's jobs are drawn, without waiting for the stage (the kit 13 warm-up restores it after the
## switch); older stages are waited for as before. _release() still starts slot 0 again.
const DEMO_UI_VERSION: int = 6
## When the first scene's hold ends: "all" or "lead" (pack.json demo_ui.release).
const RELEASE_AT: String = "all"

## Emitted when the help card closes (a demo that pauses behind the card can resume on it).
signal help_closed

const ACCENT: Color = Color(1.0, 0.62, 0.25)
const TITLE: Color = Color(1.0, 0.86, 0.66)
const TEXT: Color = Color(1.0, 0.94, 0.88)
const DIM: Color = Color(0.74, 0.78, 0.88)
const INTRO_META: StringName = &"pyrolux_demo_intro_done"
## Command line arguments of the automated tests; they skip the start screen.
const NO_INTRO_ARGS: Array[String] = ["--no-intro", "--quick", "--autotest", "--hold", "--noui"]
## --noui hides the whole overlay: used for the store GIFs, which must carry no text.
const NO_UI_ARG: String = "--noui"
## CSS pixels per UI unit at the 960x540 itch embed. On smaller screens the UI is scaled up to this.
const CSS_PER_UNIT: float = 0.75
## Below this width (in UI units) the help card and the bar switch to their compact layout.
const NARROW_W: float = 900.0
## Below this height (in UI units) the help card and the playground tool list get shorter.
const SHORT_H: float = 600.0
const MARGIN: float = 16.0
## Seconds the start note stays after the first effect is up, then one more to fade.
const CHIP_SECONDS: float = 8.0
## Frames the start note waits for a warm-up to watch (watch_warmup) before it lets the scene run.
const HOLD_WAIT_FRAMES: int = 30
## Longest the first scene is held for its warm-up, in seconds, whatever happens.
const HOLD_MAX_SECONDS: float = 60.0
## The info card's text: title, the line about it, the code. ATMOLUX step 8 (t1) took them
## from 34 / 22 / 18 to 26 / 19 / 18: at 34 the card was a slab across the top of the frame,
## over the very window the beam came from. Nothing goes below 18 px (demo rule 7).
const CARD_TITLE_PX: int = 26
const CARD_DESC_PX: int = 19
const CARD_CODE_PX: int = 18
## The help card may shrink to this much to fit a short screen. 0.85 keeps its text above ~14 px;
## a pack with a long store name and the load note goes to 0.75 (in a 390 px wide itch embed its
## text is then ~12 px, still on screen).
const MIN_HELP_SCALE: float = 0.85
## Web only: watches which part of the canvas the browser shows. An itch.io embed is a fixed
## 960x540 frame, so in a narrow window its right side is cut off and the page scrolls sideways.
## Writes "left,right" (fractions of the canvas width) to window.__pxVis, checked twice a second.
const VIS_JS: String = "(function () { var c = document.getElementById('canvas'); if (!c || !window.IntersectionObserver || window.__pxVisObs) { return; } window.__pxVis = '0,1'; var t = []; for (var i = 0; i <= 50; i++) { t.push(i / 50); } var o = new IntersectionObserver(function (es) { var e = es[es.length - 1]; var b = e.boundingClientRect; var r = e.intersectionRect; if (!e.isIntersecting || b.width <= 0 || r.width <= 0) { return; } window.__pxVis = ((r.left - b.left) / b.width).toFixed(4) + ',' + ((r.right - b.left) / b.width).toFixed(4); }, { threshold: t }); o.observe(c); window.__pxVisObs = o; setInterval(function () { o.unobserve(c); o.observe(c); }, 500); })();"

var title_label: Label
var desc_label: Label
var code_label: Label
var left_column: VBoxContainer
var bar: HFlowContainer
var overlay: Control
var help_heading: String = ""
## Big title and the line under it on the help card / start screen (store name, not code name).
var card_title: String = "PYROLUX"
var card_subtitle: String = "Fire, explosion, smoke and lava VFX for Godot 4  -  live demo"
## Rows of the help card: {"keys": PackedStringArray, "text": String}. "<" and ">" draw arrow keys.
var help_rows: Array[Dictionary] = []
## The part of the canvas the UI lives in (the part on screen), in UI units, scaled by _k.
var frame: Control
## The info card in the top right corner instead of the top left: a scene whose effect
## starts in the top left (a window, a beam) sets it. Followed every frame, because the
## card's width changes with the caption and the frame's with the window.
var card_right: bool = false
## Web only: extra points a scene wants an automated walkthrough to be able to click (a range
## puts its target panels here, because its camera swings and their screen position changes
## every frame). Name -> position in viewport units. Published with the buttons, see _publish_ui.
var targets: Dictionary[String, Vector2] = {}

var _info: PanelContainer
var _bar_panel: PanelContainer
var _hint_box: CenterContainer
var _hint_label: Label
var _help_frame: Control
var _card: PanelContainer
var _card_sb: StyleBoxFlat
var _card_box: VBoxContainer
var _load_note: Label
var _load_base: String = ""
var _prompt: Label
var _card_title: Label
var _card_wrap: Array[Label] = []
var _card_grid: GridContainer
var _card_keys: Array[Control] = []
var _card_descs: Array[Label] = []
var _tool_list: GridContainer
var _gaps: Array[Control] = []
var _bar_keys: Array[Label] = []
var _clock: float = 0.0
var _tex: Dictionary = {}
var _k: float = 1.0
var _help_s: float = 1.0
var _frame_size: Vector2 = Vector2(1280.0, 720.0)
var _vis: Vector2 = Vector2(0.0, 1.0)
var _vis_poll: float = 0.0
var _pub_poll: float = 0.0
var _narrow: bool = false
var _card_moved: bool = false
var _short: bool = false
var _chip_box: CenterContainer
var _chip: PanelContainer
var _chip_title: Label
var _chip_keys: Label
var _chip_load: Label
## True while the first scene waits for the warm-up (a browser's first visit, see watch_warmup).
var _hold: bool = false
var _hold_frames: int = 0
var _hold_start_ms: int = 0
var _lead_hit: bool = false
var _warm_node: Node
var _watching: bool = false
## The page has the loading clip (shared/web_shell): the hold lasts the whole warm-up.
var _clip: bool = false
## Seconds since the start note's countdown began (-1 = not yet).
var _chip_t: float = -1.0


func _init() -> void:
	layer = 10


func _ready() -> void:
	_tex["tri_left"] = _shape_texture(true, false)
	_tex["tri_right"] = _shape_texture(false, false)
	_tex["arrow_left"] = _shape_texture(true, true)
	_tex["arrow_right"] = _shape_texture(false, true)

	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	left_column = VBoxContainer.new()
	left_column.position = Vector2(16, 14)
	left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.add_theme_constant_override("separation", 12)
	frame.add_child(left_column)
	_info = _panel(Color(0.03, 0.02, 0.025, 0.55), 10, 18, 10)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_column.add_child(_info)
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	_info.add_child(v)
	title_label = _label(CARD_TITLE_PX, TITLE)
	desc_label = _label(CARD_DESC_PX, TEXT)
	code_label = _label(CARD_CODE_PX, DIM)
	v.add_child(title_label)
	v.add_child(desc_label)
	v.add_child(code_label)

	_bar_panel = _panel(Color(0.0, 0.0, 0.0, 0.45), 0, 10, 8)
	_bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_panel.offset_top = -66.0
	_bar_panel.offset_bottom = 0.0
	_bar_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(_bar_panel)
	# A flow: one centred row when there is room, more rows on a narrow screen. It grows upwards.
	bar = HFlowContainer.new()
	bar.alignment = FlowContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("h_separation", 10)
	bar.add_theme_constant_override("v_separation", 8)
	_bar_panel.add_child(bar)

	_hint_box = CenterContainer.new()
	_hint_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_box.offset_top = -124.0
	_hint_box.offset_bottom = -74.0
	_hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_hint_box)
	var hp: PanelContainer = _panel(Color(0.03, 0.02, 0.025, 0.6), 10, 18, 6)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_box.add_child(hp)
	_hint_label = _label(23, TEXT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(_hint_label)
	_hint_box.visible = false

	_build_overlay()
	_build_chip()
	if OS.get_cmdline_user_args().has(NO_UI_ARG):
		visible = false
	get_viewport().size_changed.connect(_layout)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(VIS_JS, true)
	_layout()


func _process(delta: float) -> void:
	_clock += delta
	if overlay.visible:
		_prompt.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_clock * 4.0))
	_chip_step(delta)
	if OS.has_feature("web"):
		_vis_poll -= delta
		if _vis_poll <= 0.0:
			_vis_poll = 0.25
			_read_vis()
		_pub_poll -= delta
		if _pub_poll <= 0.0:
			_pub_poll = 0.2
			_publish_ui()
	# Only once the card has been sent right: a scene that places the card itself (the
	# ATMOLUX demo_card.gd of DEMO_UI_VERSION 1) keeps doing so.
	if card_right or _card_moved:
		place_card(card_right)
		_card_moved = card_right
	_sync()


func _input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if overlay.visible:
		hide_help()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_H or k.keycode == KEY_QUESTION or k.unicode == 63:
		show_help(false)
		get_viewport().set_input_as_handled()


## Sets the three lines at the top left.
func set_info(title: String, description: String, code: String) -> void:
	title_label.text = title
	desc_label.text = description
	code_label.text = code
	code_label.visible = code != ""
	_layout_info()


## Puts the info card in the top left or the top right corner (a compare and an assignment;
## _process calls it every frame with `card_right`).
func place_card(right: bool) -> void:
	if left_column == null or frame == null:
		return
	var x: float = MARGIN
	if right:
		var w: float = left_column.get_combined_minimum_size().x
		x = maxf(MARGIN, frame.size.x - w - MARGIN)
	if not is_equal_approx(left_column.position.x, x):
		left_column.position.x = x


## One line above the button bar saying what a click does here. Empty hides it.
func set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_box.visible = text != ""
	_wrap_if_needed(_hint_label, _frame_size.x - 2.0 * MARGIN - 36.0)


## Adds a button to the bottom bar. `key` is shown as a key cap ("<" / ">" draw arrows).
func add_bar_button(text: String, key: String, action: Callable, icon: String = "", icon_after: bool = false) -> PanelContainer:
	var b: PanelContainer = make_button(text, key, action, icon, icon_after)
	bar.add_child(b)
	var h: HBoxContainer = b.get_child(0) as HBoxContainer
	for c in h.get_children():
		var kc: PanelContainer = c as PanelContainer
		if kc and kc.get_child_count() > 0:
			var kl: Label = kc.get_child(0) as Label
			if kl:
				_bar_keys.append(kl)
				kl.add_theme_font_size_override(&"font_size", 21 if _narrow else 18)
	return b


## Thin gap between groups of buttons in the bar (left out when the bar wraps on a narrow screen).
func add_bar_gap() -> void:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(8, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = not _narrow
	bar.add_child(c)
	_gaps.append(c)


## A list of buttons under the info panel (the playground tools). One column; two on a short screen,
## so the list does not run into the buttons at the bottom.
func add_tool_list() -> GridContainer:
	_tool_list = GridContainer.new()
	_tool_list.columns = 2 if _short else 1
	_tool_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tool_list.add_theme_constant_override("h_separation", 6)
	_tool_list.add_theme_constant_override("v_separation", 6)
	left_column.add_child(_tool_list)
	return _tool_list


## A clickable / tappable button with an optional icon and a key cap.
func make_button(text: String, key: String, action: Callable, icon: String = "", icon_after: bool = false) -> PanelContainer:
	var b: PanelContainer = PanelContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	var ic: TextureRect = null
	if icon != "":
		ic = TextureRect.new()
		ic.texture = _tex[icon]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(20, 20)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not icon_after:
			h.add_child(ic)
	var l: Label = _label(21, TEXT, 0)
	l.text = text
	l.visible = text != ""
	h.add_child(l)
	if ic and icon_after:
		h.add_child(ic)
	if key != "":
		h.add_child(_keycap(key, 18))
	b.set_meta(&"label", l)
	b.set_meta(&"hover", false)
	b.set_meta(&"selected", false)
	_restyle(b)
	b.mouse_entered.connect(_on_hover.bind(b, true))
	b.mouse_exited.connect(_on_hover.bind(b, false))
	b.gui_input.connect(_on_button_input.bind(b, action))
	return b


func set_button_text(b: PanelContainer, text: String) -> void:
	var l: Label = b.get_meta(&"label")
	l.text = text
	b.reset_size()


func set_button_selected(b: PanelContainer, on: bool) -> void:
	b.set_meta(&"selected", on)
	_restyle(b)


## Shows the help card. `first` = start screen wording ("click to start"), which is also where
## the long first load is announced, so nobody thinks the page is broken.
func show_help(first: bool) -> void:
	_chip_box.visible = false
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	_card_wrap.clear()
	_card_keys.clear()
	_card_descs.clear()
	_card_title = _label(60, ACCENT, 8)
	_card_title.text = card_title
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(_card_title)
	_card_wrap.append(_card_title)
	var s: Label = _label(24, TEXT, 0)
	s.text = card_subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(s)
	_card_wrap.append(s)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	# A spacer must not eat the click that closes the card (GLYPHLUX step 10: a click at y 300 landed on it).
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(gap)
	if help_heading != "":
		var hh: Label = _label(25, TITLE, 0)
		hh.text = help_heading
		_card_box.add_child(hh)
		_card_wrap.append(hh)
	# Two columns, key caps | what they do. Each key stays on the line of its description; on a
	# narrow screen the descriptions wrap instead of running off the edge.
	_card_grid = GridContainer.new()
	_card_grid.columns = 2
	_card_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_grid.add_theme_constant_override("h_separation", 18)
	_card_grid.add_theme_constant_override("v_separation", 9)
	_card_box.add_child(_card_grid)
	for row in help_rows:
		var keys: PackedStringArray = row["keys"]
		var text: String = row["text"]
		var kh: HBoxContainer = HBoxContainer.new()
		kh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kh.alignment = BoxContainer.ALIGNMENT_END
		kh.add_theme_constant_override("separation", 6)
		kh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for key in keys:
			kh.add_child(_keycap(key, 20))
		_card_grid.add_child(kh)
		var dl: Label = _label(22, TEXT, 0)
		dl.text = text
		_card_grid.add_child(dl)
		_card_keys.append(kh)
		_card_descs.append(dl)
	var note: Label = _label(18, DIM, 0)
	note.text = "Every key also has a button at the bottom of the screen (mouse or touch)."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(note)
	_card_wrap.append(note)
	if first:
		var load_note: Label = _label(19, DIM, 0)
		_load_base = ""
		load_note.text = _load_base
		load_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_box.add_child(load_note)
		_card_wrap.append(load_note)
		_load_note = load_note
		_clear_page_note()
	var gap2: Control = Control.new()
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap2.custom_minimum_size = Vector2(0, 6)
	_card_box.add_child(gap2)
	_prompt = _label(28, ACCENT, 0)
	_prompt.text = "Click or tap anywhere to start" if first else "Click or tap anywhere to close"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(_prompt)
	_card_wrap.append(_prompt)
	_layout_help()
	overlay.visible = true


## Web only: removes the page's first-visit note (web_note.js) two frames after the card is
## on screen. The note covers the empty canvas before that; once the card is up it is in the way.
func _clear_page_note() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	JavaScriptBridge.eval("window.fxNoteDone && window.fxNoteDone()")


## Puts "Loading effects N / M" on the start card while a warm-up (kit v5, signals `progress` and
## `finished`) runs. Call it after the UI exists; works whenever the card is built.
func watch_warmup(w: Node) -> void:
	_watching = true
	_warm_node = w
	if RELEASE_AT == "lead":
		# slot 0's jobs are done: lead_ready (kit warm-up), first_ready (progressive warm-up), or the
		# first finished job when the warm-up has neither (ice).
		if w.has_signal(&"lead_ready"):
			w.connect("lead_ready", func() -> void: _lead_hit = true)
		elif w.has_signal(&"first_ready"):
			w.connect("first_ready", func() -> void: _lead_hit = true)
		else:
			w.connect("progress", func(done: int, _total: int) -> void:
				if done >= 1:
					_lead_hit = true)
	if OS.has_feature("web"):
		_clip = str(JavaScriptBridge.eval("document.getElementById('fx-preview') ? '1' : ''", true)) == "1"
	var clip: bool = _clip
	w.connect("progress", func(done: int, total: int) -> void:
		if is_instance_valid(_load_note):
			_load_note.text = ("%s  " % _load_base if _load_base != "" else "") + "Loading effects %d / %d" % [done, total]
		_chip_load.text = "Loading effects %d / %d" % [done, total]
		_chip_load.visible = true
		if _hold and clip:
			JavaScriptBridge.eval("window.fxLoad && window.fxLoad(%d, %d)" % [done, total]))
	w.connect("finished", func() -> void:
		if is_instance_valid(_load_note):
			_load_note.text = _load_base
		_chip_load.visible = false
		_release())
	if not clip and w.has_signal(&"lead_ready"):
		# Connected after the runner's own handler, so slot 0 is built before the timers start.
		w.connect("lead_ready", _release)


func hide_help() -> void:
	var was: bool = overlay.visible
	overlay.visible = false
	if was:
		help_closed.emit()


## True while the help card is up, and on a browser's first visit while the first scene waits for
## the warm-up (the kit's runner holds slot 0 and its timers on this).
func is_help_open() -> bool:
	return overlay != null and (overlay.visible or _hold)


## Shows the start note the first time any demo scene opens (not again after switching scenes,
## and never in the automated test runs). On a browser's first visit (or --webwarm) it also holds
## the first scene for the warm-up, see is_help_open().
func show_intro_once() -> void:
	if Engine.has_meta(INTRO_META):
		return
	Engine.set_meta(INTRO_META, true)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		if NO_INTRO_ARGS.has(a) or a.begins_with("--slot="):
			return
	_show_chip()
	_hold = (OS.has_feature("web") or args.has("--webwarm")) and not args.has("--nowarm")
	_hold_start_ms = Time.get_ticks_msec()
	if not _hold:
		_chip_t = 0.0
		_page_ready()


# ------------------------------------------------------------------ start note (v5)

func _build_chip() -> void:
	_chip_box = CenterContainer.new()
	_chip_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_chip_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_box.visible = false
	frame.add_child(_chip_box)
	_chip = _panel(Color(0.03, 0.02, 0.025, 0.6), 10, 20, 8)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_box.add_child(_chip)
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	_chip.add_child(v)
	_chip_title = _label(24, ACCENT)
	_chip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_chip_title)
	_chip_keys = _label(19, TEXT)
	_chip_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_chip_keys)
	_chip_load = _label(18, DIM)
	_chip_load.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip_load.visible = false
	v.add_child(_chip_load)


## The note's text: the store name, then the first help row and the help key on one line.
func _show_chip() -> void:
	_chip_title.text = card_title
	var line: String = ""
	if not help_rows.is_empty():
		var keys: PackedStringArray = help_rows[0]["keys"]
		var names: Dictionary = {"<": "Left", ">": "Right"}
		var shown: PackedStringArray = PackedStringArray()
		for k in keys:
			shown.append(str(names.get(k, k)))
		line = "%s  %s      " % [" / ".join(shown), str(help_rows[0]["text"])]
	_chip_keys.text = line + "H  All controls"
	_chip.modulate.a = 1.0
	_chip_box.visible = true
	_layout_chip()


## Ends the hold on the first scene: the runner's timers start (help_closed), and two frames
## later, with the first effect drawn, the page's loading clip / note goes away. Behind the clip
## the first scene was built at lead_ready and its story (a grenade rolling in, tweens that do
## not wait for the timers) has long played out, so the kit's runner (this UI's parent, with
## enter(i) and slot) starts it again: the visitor sees it from the beginning.
func _release() -> void:
	if not _hold:
		return
	_hold = false
	_chip_t = 0.0
	if RELEASE_AT == "lead" and is_instance_valid(_warm_node) and &"gap_frames" in _warm_node:
		# The page-ready call waits two frames; without a gap the next warm-up job (seconds of
		# shader compile) runs in the first of them and the switch comes that much later.
		_warm_node.set(&"gap_frames", 8)
	var r: Node = get_parent()
	# 6.1: only when the scene has been playing for a while behind the clip. With "lead" and a kit 13
	# stage the hold ends a frame or two after slot 0 is built: starting it again then freed what its
	# tweens were about to call (BLASTLUX web_check: "Lambda capture at index 0 was freed").
	var played: Variant = r.get(&"slot_time") if r != null else null
	var pt: float = played if played is float else 99.0
	var fresh: bool = pt < 1.0
	if _clip and not fresh and r != null and r.has_method(&"enter") and r.get(&"slot") is int:
		r.call(&"enter", r.get(&"slot"))
	help_closed.emit()
	_page_ready()


## True when the warm-up has no stage in its quick (lite) look any more.
func _stage_back() -> bool:
	if not is_instance_valid(_warm_node):
		return true
	var v: Variant = _warm_node.get(&"stage")
	if not (v is Object) or not is_instance_valid(v):
		return true
	var st: Object = v
	if st.has_method(&"lite_ghosts"):
		# 11/01 (kit 13): no wait for the stage. dissolve's first effect was up at 20 s and the
		# switch came at 52 s; the kit 13 warm-up brings the stage back after the switch, out of
		# sight (hidden copies), and swaps it at once. Older stages are still waited for.
		return true
	if st.has_method(&"is_lite"):
		var lite: Variant = st.call(&"is_lite")
		return not (lite is bool and lite == true)
	return true


func _page_ready() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	JavaScriptBridge.eval("window.fxNoteDone && window.fxNoteDone(); window.fxPreviewDone && window.fxPreviewDone()")


func _chip_step(delta: float) -> void:
	if _hold:
		_hold_frames += 1
		# A scene with no warm-up to watch, or one that never ends: let it run anyway. The time
		# is the clock, not the frames: one frame can take seconds while a shader compiles.
		var held_s: float = float(Time.get_ticks_msec() - _hold_start_ms) / 1000.0
		if (not _watching and _hold_frames > HOLD_WAIT_FRAMES) or held_s > HOLD_MAX_SECONDS:
			_release()
		elif RELEASE_AT == "lead" and _lead_hit and _stage_back():
			_release()
	if not _chip_box.visible or _chip_t < 0.0:
		return
	_chip_t += delta
	if _chip_t > CHIP_SECONDS:
		_chip.modulate.a = clampf(1.0 - (_chip_t - CHIP_SECONDS), 0.0, 1.0)
		if _chip.modulate.a <= 0.0:
			_chip_box.visible = false


func _layout_chip() -> void:
	if _chip_box == null:
		return
	var w: float = _frame_size.x - 2.0 * MARGIN - 40.0
	_wrap_if_needed(_chip_title, w)
	_wrap_if_needed(_chip_keys, w)
	_chip.reset_size()


# ------------------------------------------------------------------ Lite demo extras

## The Lite line: its own band just above the button bar, across the whole width, naming what
## the full pack adds, with the full pack's URL under it. Two lines of 28 px in the 1280x720
## design space, which is still 21 px on a 960x540 canvas (a one-line 16 px version was
## unreadable). Sits under the UI (layer 9), so the start / help card covers it instead of the
## band cutting off the bottom of the card. Hidden with --noui like everything else.
func add_lite_line(line: String, url: String) -> void:
	if OS.get_cmdline_user_args().has(NO_UI_ARG):
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 9
	_host().add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -158.0
	panel.offset_bottom = -72.0
	panel.offset_left = 10.0
	panel.offset_right = -10.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.07, 0.72)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override(&"panel", sb)
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	box.add_child(_lite_label(line, 28, TEXT))
	box.add_child(_lite_label(url, 27, ACCENT))


## The Lite upsell button: a small link in the bottom-right corner, in the row of the button bar
## and to the right of its buttons, that opens the full pack's store page in the browser. Its
## own layer (11) sits above the UI, whose bar panel would otherwise swallow the click.
## "»" in the text because the default font has no arrow glyph. Hidden with --noui.
func add_full_link(text: String, url: String) -> Button:
	if OS.get_cmdline_user_args().has(NO_UI_ARG):
		return null
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 11
	_host().add_child(layer)
	var b: Button = Button.new()
	b.text = text
	b.tooltip_text = url
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override(&"font_size", 18)
	b.add_theme_color_override(&"font_color", TITLE)
	b.add_theme_color_override(&"font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_stylebox_override(&"normal", _box(Color(0.06, 0.12, 0.2, 0.85), Color(0.56, 0.86, 1.0, 0.45)))
	b.add_theme_stylebox_override(&"hover", _box(Color(0.1, 0.2, 0.32, 0.95), Color(0.56, 0.86, 1.0, 0.8)))
	b.add_theme_stylebox_override(&"pressed", _box(Color(0.14, 0.34, 0.56, 0.95), Color(0.7, 0.9, 1.0, 0.9)))
	b.anchor_left = 1.0
	b.anchor_top = 1.0
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -14.0
	b.offset_top = -12.0
	b.offset_right = -14.0
	b.offset_bottom = -12.0
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.grow_vertical = Control.GROW_DIRECTION_BEGIN
	b.pressed.connect(_open_url.bind(url))
	layer.add_child(b)
	return b


func _open_url(url: String) -> void:
	var err: Error = OS.shell_open(url)
	if err != OK:
		push_warning("Could not open " + url)


## Where the Lite layers go: next to this UI in the scene (a CanvasLayer inside a CanvasLayer
## would still draw, but keeping them siblings keeps the scene tree flat and readable).
func _host() -> Node:
	var p: Node = get_parent()
	return p if p != null else self


func _lite_label(text: String, size: int, color: Color) -> Label:
	var l: Label = _label(size, color, 5)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	return sb


# ------------------------------------------------------------------ layout for the screen size

## Works out the UI scale and the visible part of the canvas, then lays every part out for it.
func _layout() -> void:
	if frame == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(get_window().size)
	if vp.x < 1.0 or vp.y < 1.0 or win.x < 1.0:
		return
	var dpr: float = 1.0
	if OS.has_feature("web"):
		dpr = clampf(DisplayServer.screen_get_scale(), 0.5, 4.0)
	var css: float = win.x / vp.x / dpr
	_k = clampf(CSS_PER_UNIT / maxf(css, 0.01), 1.0, 4.0)
	_frame_size = Vector2((_vis.y - _vis.x) * vp.x / _k, vp.y / _k)
	frame.position = Vector2(_vis.x * vp.x, 0.0)
	frame.scale = Vector2(_k, _k)
	frame.size = _frame_size
	_narrow = _frame_size.x < NARROW_W
	_short = _frame_size.y < SHORT_H
	for kl in _bar_keys:
		kl.add_theme_font_size_override(&"font_size", 21 if _narrow else 18)
	for g in _gaps:
		g.visible = not _narrow
	if _tool_list:
		_tool_list.columns = 2 if _short else 1
	code_label.visible = code_label.text != ""
	_layout_info()
	_wrap_if_needed(_hint_label, _frame_size.x - 2.0 * MARGIN - 36.0)
	_layout_help()
	_layout_chip()
	_apply_help_frame()


## The info panel at the top left: lines wrap only when they would not fit.
func _layout_info() -> void:
	var w: float = _frame_size.x - 2.0 * MARGIN - 36.0
	_wrap_if_needed(title_label, w)
	_wrap_if_needed(desc_label, w)
	_wrap_if_needed(code_label, w)
	_info.reset_size()
	left_column.reset_size()


## Fits the help card into the frame width: the subtitle, heading, descriptions, note and the
## prompt wrap only when they would not fit on one line. Shorter spacing on a short screen.
func _layout_help() -> void:
	if not is_instance_valid(_card_title):
		return
	var mx: float = 20.0 if _narrow else 40.0
	var my: float = 14.0 if _short else 24.0
	_card_sb.content_margin_left = mx
	_card_sb.content_margin_right = mx
	_card_sb.content_margin_top = my
	_card_sb.content_margin_bottom = my
	var avail: float = _frame_size.x - 2.0 * MARGIN - 2.0 * mx
	# The store name is long: smaller on a narrow screen too, so the card keeps its prompt on screen.
	# A name that still does not fit on one line shrinks (down to 34 px) before it wraps, so a lone
	# last word ("4") does not drop to a line of its own.
	var tpx: int = 46 if (_short or _narrow) else 60
	_card_title.add_theme_font_size_override(&"font_size", tpx)
	while tpx > 34 and _natural_w(_card_title) > avail:
		tpx -= 2
		_card_title.add_theme_font_size_override(&"font_size", tpx)
	_card_box.add_theme_constant_override("separation", 3 if _short else 6)
	_card_grid.add_theme_constant_override("v_separation", 4 if _short else 9)
	var hsep: float = 12.0 if _narrow else 18.0
	_card_grid.add_theme_constant_override("h_separation", int(hsep))
	for l in _card_wrap:
		_wrap_if_needed(l, avail)
	var kw: float = 0.0
	for kh in _card_keys:
		kw = maxf(kw, kh.get_combined_minimum_size().x)
	var dw: float = 0.0
	for d in _card_descs:
		dw = maxf(dw, _natural_w(d))
	var wrap: bool = kw + hsep + dw > avail
	for d in _card_descs:
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		d.custom_minimum_size.x = maxf(140.0, avail - kw - hsep) if wrap else 0.0
	_card.reset_size()


## Follows sizes that change after the containers have sorted (wrapped text, wrapped buttons).
func _sync() -> void:
	var hb: float = -_bar_panel.size.y - 8.0
	if not is_equal_approx(_hint_box.offset_bottom, hb):
		_hint_box.offset_bottom = hb
		_hint_box.offset_top = hb - 50.0
	if _chip_box.visible:
		# Above the button bar, and above the hint line when a scene has one.
		var cb: float = hb
		if _hint_box.visible:
			cb -= _hint_box.get_combined_minimum_size().y + 8.0
		if not is_equal_approx(_chip_box.offset_bottom, cb):
			_chip_box.offset_bottom = cb
			_chip_box.offset_top = cb - 40.0
	# The top-left column (info panel, playground tools) must stay above the hint and the buttons:
	# on a short screen the tool list gets more columns, then the code line steps aside.
	var low: float = _frame_size.y - _bar_panel.size.y - 8.0
	if _hint_box.visible:
		low = minf(low, _frame_size.y + _hint_box.offset_bottom - _hint_box.get_combined_minimum_size().y - 10.0)
	var col_bottom: float = left_column.position.y + left_column.get_combined_minimum_size().y
	if col_bottom > low:
		if _tool_list and _tool_list.columns < 4:
			_tool_list.columns += 1
		elif code_label.visible:
			code_label.visible = false
			_info.reset_size()
		left_column.reset_size()
	var hide_ui: bool = false
	if overlay.visible:
		var need: Vector2 = _card.get_combined_minimum_size()
		var s: float = 1.0
		var avail_h: float = _frame_size.y - 2.0 * MARGIN
		var avail_w: float = _frame_size.x - 2.0 * MARGIN
		if need.y > avail_h or need.x > avail_w:
			s = maxf(MIN_HELP_SCALE, minf(avail_h / need.y, avail_w / need.x))
		if absf(s - _help_s) > 0.002:
			_help_s = s
			_apply_help_frame()
		# On a small screen the card would sit on top of the info panel and the buttons, so they
		# step aside while it is open. On a large screen they stay, dimmed, as before.
		var card_bottom: float = (_frame_size.y + need.y * _help_s) * 0.5
		var ui_top: float = low if _hint_box.visible else _frame_size.y - _bar_panel.size.y
		hide_ui = _narrow or _short or card_bottom > ui_top
	if frame.visible == hide_ui:
		frame.visible = not hide_ui


func _apply_help_frame() -> void:
	_help_frame.position = frame.position
	_help_frame.scale = frame.scale * _help_s
	_help_frame.size = _frame_size / _help_s


## Web: reads which part of the canvas is on screen (see VIS_JS) and lays out again when it moves.
func _read_vis() -> void:
	var r: Variant = JavaScriptBridge.eval("window.__pxVis || ''", true)
	if r == null:
		return
	var parts: PackedStringArray = str(r).split(",")
	if parts.size() != 2:
		return
	var v: Vector2 = Vector2(clampf(parts[0].to_float(), 0.0, 1.0), clampf(parts[1].to_float(), 0.0, 1.0))
	if v.x < 0.01:
		v.x = 0.0
	if v.y > 0.99:
		v.y = 1.0
	if v.y - v.x < 0.15:
		return  # nearly out of view: keep the last layout
	if absf(v.x - _vis.x) > 0.004 or absf(v.y - _vis.y) > 0.004:
		_vis = v
		_layout()


## Web only: writes where every bar button and every scene target is, in viewport units, to
## window.__pxUI, so a browser walkthrough (tools/vfxpack/web_check.py "button:NAME" steps)
## clicks what is really there. The bar is a flow container whose wrapping depends on the font
## and on how much of the canvas the page shows, so positions measured in a desktop window are
## wrong in the browser. One viewport unit is (canvas width / 1280) CSS pixels.
func _publish_ui() -> void:
	if not OS.has_feature("web"):
		return
	var parts: PackedStringArray = PackedStringArray()
	for c in bar.get_children():
		var b: PanelContainer = c as PanelContainer
		if b == null or not b.has_meta(&"label") or not b.is_visible_in_tree():
			continue
		var l: Label = b.get_meta(&"label")
		var r: Rect2 = b.get_global_rect()
		parts.append('"%s":[%d,%d,%d,%d]' % [l.text.replace("\"", ""),
			roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)])
	var tp: PackedStringArray = PackedStringArray()
	for k: String in targets:
		tp.append('"%s":[%d,%d]' % [k, roundi(targets[k].x), roundi(targets[k].y)])
	JavaScriptBridge.eval('window.__pxUI = {"buttons":{%s},"targets":{%s},"help":%s};'
		% [",".join(parts), ",".join(tp), "true" if overlay.visible else "false"], true)


func _wrap_if_needed(l: Label, w: float) -> void:
	var wrap: bool = _natural_w(l) > w
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = maxf(100.0, w) if wrap else 0.0


## Width of a label's text on one line.
func _natural_w(l: Label) -> float:
	var mode: TextServer.AutowrapMode = l.autowrap_mode
	var cm: Vector2 = l.custom_minimum_size
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2.ZERO
	var w: float = l.get_minimum_size().x
	l.autowrap_mode = mode
	l.custom_minimum_size = cm
	return w


# ------------------------------------------------------------------ internals

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	# The dimming covers the whole canvas; the card sits in the part of it that is on screen.
	_help_frame = Control.new()
	_help_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_help_frame)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_frame.add_child(cc)
	_card = _panel(Color(0.06, 0.035, 0.03, 0.86), 14, 40, 24)
	_card_sb = _card.get_theme_stylebox(&"panel") as StyleBoxFlat
	_card_sb.border_color = Color(ACCENT, 0.7)
	_card_sb.set_border_width_all(2)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_theme_constant_override("separation", 6)
	_card.add_child(_card_box)
	overlay.gui_input.connect(_on_overlay_input)


func _on_overlay_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed:
		hide_help()
		overlay.accept_event()


func _on_button_input(event: InputEvent, b: PanelContainer, action: Callable) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		b.accept_event()
		action.call()


func _on_hover(b: PanelContainer, on: bool) -> void:
	b.set_meta(&"hover", on)
	_restyle(b)


func _restyle(b: PanelContainer) -> void:
	var hover: bool = b.get_meta(&"hover")
	var selected: bool = b.get_meta(&"selected")
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2 if selected else 1)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	if selected:
		sb.bg_color = Color(0.5, 0.22, 0.05, 0.95)
		sb.border_color = Color(1.0, 0.82, 0.5)
	elif hover:
		sb.bg_color = Color(0.3, 0.15, 0.06, 0.95)
		sb.border_color = ACCENT
	else:
		sb.bg_color = Color(0.13, 0.075, 0.05, 0.85)
		sb.border_color = Color(1.0, 0.62, 0.3, 0.45)
	b.add_theme_stylebox_override(&"panel", sb)


func _keycap(key: String, font_size: int) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.13)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.5)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 1.0
	p.add_theme_stylebox_override(&"panel", sb)
	if key == "<" or key == ">":
		var ic: TextureRect = TextureRect.new()
		ic.texture = _tex["arrow_left" if key == "<" else "arrow_right"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(font_size + 2, font_size + 4)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
	else:
		var l: Label = _label(font_size, Color(1, 1, 1), 0)
		l.text = key
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(font_size * 0.8, 0)
		p.add_child(l)
	return p


func _label(font_size: int, color: Color, outline: int = 5) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	if outline > 0:
		l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override(&"outline_size", outline)
	return l


func _panel(bg: Color, radius: int, margin_x: float, margin_y: float) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_bottom = margin_y
	p.add_theme_stylebox_override(&"panel", sb)
	return p


## Small white triangle (button icon) or arrow (arrow key cap), drawn once at start.
func _shape_texture(left: bool, arrow: bool) -> ImageTexture:
	var n: int = 32
	var ss: int = 4
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var cov: int = 0
			for sy in ss:
				for sx in ss:
					var u: float = (float(x) + (float(sx) + 0.5) / ss) / n
					var v: float = absf((float(y) + (float(sy) + 0.5) / ss) / n - 0.5)
					if left:
						u = 1.0 - u
					var inside: bool
					if arrow:
						inside = (u >= 0.5 and u <= 0.9 and v <= (0.9 - u) / 0.4 * 0.36) or (u >= 0.1 and u < 0.55 and v <= 0.08)
					else:
						inside = u >= 0.2 and u <= 0.86 and v <= (0.86 - u) / 0.66 * 0.4
					if inside:
						cov += 1
			img.set_pixel(x, y, Color(1, 1, 1, float(cov) / float(ss * ss)))
	return ImageTexture.create_from_image(img)

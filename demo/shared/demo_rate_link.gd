extends CanvasLayer
## Demo only: a small "Rate it on itch »" link in the bottom-right corner of every demo scene.
## It is an autoload (project.godot [autoload] RateLink), so the scene scripts stay as they
## are. Pressing it opens the /rate page of the product the demo belongs to in the browser:
## the Lite demo (lite scene below) opens the Lite's own page, every other demo scene the full
## pack's page. No popup, no timer, no count: one quiet button.
##
## Where it sits, found by looking at the scene's own UI (no per-pack layout):
##  - a Lite demo has a "Get the full pack" / "Full version: ..." button in the corner (found by
##    its text, or by a gennai.itch.io tooltip): the link sits to the left of it, in the same row;
##  - otherwise, with a button bar along the bottom edge (a wide, low Control touching the
##    bottom), the link sits in the right corner just above the bar;
##  - with neither, it takes the bottom-right corner.
## Hidden with --noui (the store-capture flag) and in the benchmark scene.
##
## Generated from WS/shared/rate_link/demo_rate_link.gd by tools/vfxpack/rate_link_sync.py.
## Edit the canonical file, never this copy.
##   --ratecheck   prints "RATELINK scene=<name> url=<rate url> lite=<0|1> visible=<0|1>" once.

const RATE_LINK_VERSION: int = 4
const FULL_RATE_URL: String = "https://gennai.itch.io/pyrolux-fire-explosion-vfx/rate"
const LITE_RATE_URL: String = "https://gennai.itch.io/pyrolux-lite/rate"
const LITE_SCENES: Array = ["lite_demo"]
const LINK_TEXT: String = "Rate it on itch »"
const NO_UI_ARG: String = "--noui"
const GAP: float = 8.0
const MARGIN: float = 14.0
const BAR_MAX_HEIGHT: float = 140.0
const SCAN_LIMIT: int = 3000

var _button: Button
var _full_button: Button
var _clock: float = 0.0
var _next_scan: float = 0.0
var _bar_top: float = -1.0
var _scanned: int = 0
var _printed: bool = false


func _ready() -> void:
	name = "RateLink"
	layer = 11
	if OS.get_cmdline_user_args().has(NO_UI_ARG):
		set_process(false)
		return
	_button = Button.new()
	_button.name = "RateButton"
	_button.text = LINK_TEXT
	_button.tooltip_text = FULL_RATE_URL
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.add_theme_font_size_override(&"font_size", 16)
	_button.add_theme_color_override(&"font_color", Color(0.86, 0.9, 0.95, 0.9))
	_button.add_theme_color_override(&"font_hover_color", Color(1.0, 1.0, 1.0))
	_button.add_theme_stylebox_override(&"normal", _box(Color(0.04, 0.06, 0.09, 0.8), Color(0.8, 0.88, 1.0, 0.3)))
	_button.add_theme_stylebox_override(&"hover", _box(Color(0.1, 0.14, 0.2, 0.95), Color(0.8, 0.9, 1.0, 0.7)))
	_button.add_theme_stylebox_override(&"pressed", _box(Color(0.16, 0.22, 0.32, 0.95), Color(0.9, 0.95, 1.0, 0.9)))
	_button.anchor_left = 1.0
	_button.anchor_top = 1.0
	_button.anchor_right = 1.0
	_button.anchor_bottom = 1.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(0.0, 12.0)
	_button.pressed.connect(_open)
	add_child(_button)
	visible = false


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


## The scene name of the running demo ("" before the first scene).
func _scene_name() -> String:
	var s: Node = get_tree().current_scene
	if s == null:
		return ""
	return s.scene_file_path.get_file().get_basename()


func _is_lite() -> bool:
	return LITE_SCENES.has(_scene_name())


func rate_url() -> String:
	return LITE_RATE_URL if _is_lite() else FULL_RATE_URL


func _open() -> void:
	var url: String = rate_url()
	var err: Error = OS.shell_open(url)
	if err != OK:
		push_warning("Could not open " + url)


## `full_w` > 0: shifted left by the Full button's width. `above` is the distance of the link's
## bottom edge from the bottom of the screen.
func _place(full_w: float, above: float) -> void:
	var r: float = -(MARGIN + (full_w + GAP if full_w > 0.0 else 0.0))
	_button.offset_left = r
	_button.offset_right = r
	_button.offset_top = -above
	_button.offset_bottom = -above


## The "Full version" button of a Lite demo: a button whose tooltip is a gennai.itch.io page or
## whose text says it opens the full pack.
func _is_full_button(b: Button) -> bool:
	if b == _button:
		return false
	var t: String = b.text.to_lower()
	if t.begins_with("full version") or t.begins_with("get the full") or t.contains("full pack"):
		return true
	return b.tooltip_text.begins_with("https://gennai.itch.io/") and not b.tooltip_text.ends_with("/rate")


## Looks through the scene's UI for the Full button and the bottom bar. Does not go into the 3D
## world (the effects), and stops after SCAN_LIMIT nodes.
func _scan(n: Node, vp: Vector2) -> void:
	if _scanned >= SCAN_LIMIT or n == self or (n is Node3D and n != get_tree().current_scene):
		return
	_scanned += 1
	var b: Button = n as Button
	if b != null and _full_button == null and b.visible and _is_full_button(b):
		_full_button = b
	var c: Control = n as Control
	if c != null and c.is_visible_in_tree():
		var r: Rect2 = c.get_global_rect()
		if r.size.x >= vp.x * 0.6 and r.size.y > 8.0 and r.size.y <= BAR_MAX_HEIGHT and r.end.y >= vp.y - 3.0 and r.position.y > vp.y * 0.5:
			_bar_top = maxf(vp.y - r.position.y, 0.0) if _bar_top < 0.0 else maxf(_bar_top, vp.y - r.position.y)
	for k: Node in n.get_children():
		_scan(k, vp)


func _process(delta: float) -> void:
	_clock += delta
	if _button == null:
		return
	var scene_name: String = _scene_name()
	var want: bool = scene_name != "" and not scene_name.contains("bench")
	if want != visible:
		visible = want
	if not want:
		return
	_button.tooltip_text = rate_url()
	if _clock >= _next_scan:
		_next_scan = _clock + (0.4 if _clock < 8.0 else 2.0)
		if _full_button != null and not is_instance_valid(_full_button):
			_full_button = null
		_bar_top = -1.0
		_scanned = 0
		if _full_button != null and not _full_button.is_inside_tree():
			_full_button = null
		_scan(get_tree().root, get_viewport().get_visible_rect().size)
	if _full_button != null and is_instance_valid(_full_button):
		_place(_full_button.size.x, 12.0)
	elif _bar_top > 0.0:
		_place(0.0, _bar_top + 8.0)
	else:
		_place(0.0, 12.0)
	if not _printed and OS.get_cmdline_user_args().has("--ratecheck") and _clock > 1.0:
		_printed = true
		print("RATELINK scene=%s url=%s lite=%d visible=%d" % [scene_name, rate_url(), 1 if _is_lite() else 0, 1 if visible else 0])

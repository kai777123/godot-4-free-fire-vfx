extends Node3D
## PYROLUX Lite demo: a campfire and a grenade explosion. Space: explosion, E: fire on/off.
## H or ?: help. Every key also has an on-screen button.
## Bottom right, in the button strip: a small link to the full PYROLUX page (opens in the
## browser only when clicked).

const PP := preload("res://demo/shared/pyrolux_studio_props.gd")
const UI := preload("res://demo/shared/demo_ui.gd")
const P3: String = "res://addons/pyrolux_fx/presets/3d/"
const FULL_URL: String = "https://gennai.itch.io/pyrolux-fire-explosion-vfx"
const CORNER: float = 16.0
const FULL_TEXT: String = "Full version: 49 presets\n2D effects, burning objects"
const FULL_TEXT_SHORT: String = "Full version"

var fire: PyroluxFire3D
var cam: Camera3D
var ui: UI
var full_button: PanelContainer
var _full_long_w: float = 0.0
var _full_short: bool = false
var _t: float = 0.0
var _next: float = 0.8
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	# The full pack's studio (shared demo kit 13): a dark seamless floor, so only the fire has
	# detail in the frame.
	var stage: PyroluxDemoStage = PyroluxDemoStage.new()
	stage.look = PyroluxDemoStage.LOOK_STUDIO
	stage.glow = true
	add_child(stage)
	stage.environment.glow_intensity = 0.55
	stage.environment.glow_hdr_threshold = 0.9
	stage.studio_centre(Vector3(0.5, 0, 0))
	PP.campfire_base(stage, Vector3(-1.5, 0, 0))
	PP.stone(stage, Vector3(-3.1, 0, 0.4), 0.7, 3)
	PP.crate(stage, Vector3(3.4, 0, -1.3), 0.9, null, 0.4)
	fire = (load(P3 + "fire_campfire.tscn") as PackedScene).instantiate() as PyroluxFire3D
	add_child(fire)
	fire.position = Vector3(-1.5, 0, 0)
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(0.5, 2.3, 6.6), Vector3(0.5, 0.8, 0.0))
	ui = UI.new()
	add_child(ui)
	ui.set_info("PYROLUX Lite", "Free sample: a campfire and a grenade explosion.", "The full pack adds 38 3D + 11 2D presets: lava, smoke, sparks, burning objects, meteors and more.")
	ui.add_bar_button("Explosion", "Space", _boom)
	ui.add_bar_button("Fire on / off", "E", _toggle_fire)
	ui.add_bar_gap()
	ui.add_bar_button("Help", "H", ui.show_help.bind(false))
	ui.help_heading = "Lite demo"
	ui.help_rows = [
		{"keys": PackedStringArray(["Space"]), "text": "Grenade explosion (one also goes off every few seconds)"},
		{"keys": PackedStringArray(["E"]), "text": "Put the campfire out / light it again"},
		{"keys": PackedStringArray(["H", "?"]), "text": "Show this help again"},
		{"keys": PackedStringArray(), "text": "Bottom right button: opens the full PYROLUX page on itch.io"},
	]
	_add_full_button()
	ui.show_intro_once()


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode == KEY_SPACE:
			_boom()
		elif k.keycode == KEY_E:
			_toggle_fire()


func _process(delta: float) -> void:
	_place_full_button()
	_t += delta
	if _t >= _next:
		_next = _t + 2.6
		_boom()
	if _t > 4.0 and _t < 4.0 + delta:
		fire.extinguish()
	if _t > 6.0 and _t < 6.0 + delta:
		fire.ignite()


func _toggle_fire() -> void:
	if fire.is_burning():
		fire.extinguish()
	else:
		fire.ignite()


func _boom() -> void:
	Pyrolux.spawn(self, "explosion_grenade", Vector3(_rng.randf_range(1.5, 3.5), 0.0, _rng.randf_range(-0.5, 1.0)))


## A small two-line button at the right end of the bottom button strip, styled like the other
## buttons, so it covers nothing the strip does not already cover. Only a click opens the full
## pack's page in the browser; nothing pops up on its own.
func _add_full_button() -> void:
	full_button = ui.make_button(FULL_TEXT, "", _open_full, "tri_right", true)
	var l: Label = full_button.get_meta(&"label")
	l.add_theme_font_size_override(&"font_size", 16)
	l.add_theme_constant_override(&"line_spacing", -2)
	full_button.tooltip_text = FULL_URL
	full_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	full_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	full_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pin_full_button(8.0)
	ui.frame.add_child(full_button)


func _pin_full_button(bottom: float) -> void:
	full_button.offset_left = -CORNER
	full_button.offset_right = -CORNER
	full_button.offset_top = -bottom
	full_button.offset_bottom = -bottom


## Sits in the strip, centred on its height. When the window is so narrow that the strip's own
## buttons reach the right end, it moves just above the strip; in a very small window it says
## only "Full version".
func _place_full_button() -> void:
	if full_button == null:
		return
	if _full_long_w <= 0.0 and not _full_short:
		_full_long_w = full_button.get_combined_minimum_size().x
	var short: bool = ui.frame.size.x - 2.0 * CORNER < _full_long_w
	if short != _full_short:
		_full_short = short
		ui.set_button_text(full_button, FULL_TEXT_SHORT if short else FULL_TEXT)
	var strip: Control = ui.bar.get_parent() as Control
	var sz: Vector2 = full_button.get_combined_minimum_size()
	var bottom: float = maxf(4.0, (strip.size.y - sz.y) * 0.5)
	var r: Rect2 = Rect2(ui.frame.size - Vector2(CORNER, bottom) - sz, sz).grow_individual(12.0, 0.0, 0.0, 0.0)
	for c in ui.bar.get_children():
		var bc: Control = c as Control
		if bc and bc.visible and Rect2(strip.position + ui.bar.position + bc.position, bc.size).intersects(r):
			bottom = strip.size.y + 8.0
			break
	if not is_equal_approx(full_button.offset_bottom, -bottom) or not is_equal_approx(full_button.offset_right, -CORNER):
		_pin_full_button(bottom)


func _open_full() -> void:
	OS.shell_open(FULL_URL)

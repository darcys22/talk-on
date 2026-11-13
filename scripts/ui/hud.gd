class_name Hud
extends Control
## The little that is always on screen: a dot, the interaction prompt, and
## radio chatter as text (standing in for voices until there is audio).

const LINE_LIFE := 22.0
const MAX_LINES := 7

var prompt := ""
var show_crosshair := true
var show_log := true
var binoculars := false

var _prompt_label: Label
var _log_label: Label
var _lines: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label = _make_label(20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.anchor_top = 0.62
	_prompt_label.anchor_bottom = 0.62
	_prompt_label.offset_bottom = 40.0
	_log_label = _make_label(17)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log_label.anchor_top = 0.55
	_log_label.offset_left = 24.0
	_log_label.offset_bottom = -20.0
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.anchor_right = 0.6
	Game.log_line.connect(_on_log_line)
	Game.mission_started.connect(func(_i: int) -> void: _lines.clear())


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", StationView.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


func _on_log_line(who: String, text: String) -> void:
	_lines.append({"text": "%s: %s" % [who, text], "age": 0.0})
	while _lines.size() > MAX_LINES:
		_lines.pop_front()


func _process(delta: float) -> void:
	_prompt_label.text = prompt
	var shown: PackedStringArray = []
	for line: Dictionary in _lines:
		if not Game.paused:
			line.age += delta
		if line.age < LINE_LIFE:
			shown.append(line.text)
	_log_label.text = "\n".join(shown) if show_log else ""
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	if binoculars:
		_draw_mask(centre, minf(size.x, size.y) * 0.46)
	elif show_crosshair:
		draw_circle(centre, 2.5, Color(1, 1, 1, 0.75))


## Blacks out everything outside a circle, for binoculars.
func _draw_mask(centre: Vector2, radius: float) -> void:
	var black := Color.BLACK
	draw_rect(Rect2(0, 0, centre.x - radius, size.y), black)
	draw_rect(Rect2(centre.x + radius, 0, size.x - centre.x - radius, size.y), black)
	draw_rect(Rect2(0, 0, size.x, centre.y - radius), black)
	draw_rect(Rect2(0, centre.y + radius, size.x, size.y - centre.y - radius), black)
	var ring := radius * 0.45
	draw_arc(centre, radius + ring * 0.5, 0.0, TAU, 96, black, ring + 2.0)

class_name StationView
extends Control
## Base for every full-screen view. In this prototype the views are flat
## panels standing in for the physical objects in the design doc.

const PAPER := Color(0.87, 0.83, 0.7)
const INK := Color(0.12, 0.11, 0.09)
const STEEL := Color(0.16, 0.19, 0.15, 0.96)
const AMBER := Color(1.0, 0.78, 0.35)

static var _mono: SystemFont


static func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray([
			"DejaVu Sans Mono", "Consolas", "Menlo", "Courier New", "monospace"])
	return _mono


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	pass


func opened() -> void:
	pass


func handle_key(_key: int, _event: InputEventKey) -> void:
	pass


func handle_mouse(_event: InputEvent) -> void:
	pass


## A centred panel with one text label filling it. Returns the label.
func make_panel(panel_size: Vector2, background: Color, text_color: Color, font_size: int = 18) -> Label:
	var panel := ColorRect.new()
	panel.color = background
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	add_child(panel)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 28.0
	label.offset_top = 22.0
	label.offset_right = -28.0
	label.offset_bottom = -22.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	panel.add_child(label)
	return label


static func bar(value: float, width: int = 10) -> String:
	var filled := clampi(int(round(value * width)), 0, width)
	return "#".repeat(filled) + "-".repeat(width - filled)

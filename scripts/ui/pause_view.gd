class_name PauseView
extends StationView


func _build() -> void:
	var label := make_panel(Vector2(520.0, 260.0), STEEL, AMBER, 20)
	label.text = "PAUSED\n\n  Esc   back to the tower\n  R     restart this mission\n  Q     quit to desktop"

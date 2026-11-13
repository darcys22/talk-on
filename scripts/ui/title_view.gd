class_name TitleView
extends StationView
## Title card with the controls.


func _build() -> void:
	var label := make_panel(Vector2(860.0, 600.0), STEEL, AMBER, 18)
	label.text = "\n".join(PackedStringArray([
		"TALK-ON",
		"forward air controller -- grey-box prototype",
		"",
		"You are alone in Tower 9. Find the target, fix its position,",
		"and talk the aircraft onto it. Nothing is done for you.",
		"",
		"  1  Teleprinter   read your orders and the air frequency",
		"  2  Scope         find the target, note bearing and range",
		"  3  Map table     plot them, pencil the grid on the card",
		"  4  Radio         start it, tune it, read the card, check",
		"                   the readback, then clear the aircraft hot",
		"",
		"  W A S D   move            Mouse   look",
		"  E         use / leave     Right mouse or B   binoculars",
		"  Esc       pause",
		"",
		"Every transmission helps the enemy find you. Keep it short.",
		"",
		"Press ENTER to start, then click to capture the mouse." if OS.has_feature("web") else "Press ENTER to start.        Esc quits.",
	]))

class_name DebriefView
extends StationView
## After-action report.

var _label: Label


func _build() -> void:
	_label = make_panel(Vector2(760.0, 460.0), PAPER, INK, 19)


func show_result(result: Dictionary) -> void:
	var next := "Press ENTER to try this mission again."
	if result.get("success", false):
		next = "Press ENTER for the next mission."
		if result.get("last_mission", false):
			next = "That was the last mission in the prototype.\nPress ENTER to start over."
	_label.text = "\n".join(PackedStringArray([
		"AFTER-ACTION REPORT -- %s" % str(Game.mission.get("title", "")).to_upper(),
		"",
		"  Ended because     %s" % str(result.get("reason", "")),
		"  Targets destroyed %d of %d" % [int(result.get("destroyed", 0)), int(result.get("total", 0))],
		"  Own troops lost   %d of %d" % [int(result.get("friendly_losses", 0)), int(result.get("friendlies", 0))],
		"  Transmissions     %d" % int(result.get("transmissions", 0)),
		"",
		"  Score %d     Grade %s" % [int(result.get("score", 0)), str(result.get("grade", "F"))],
		"",
		next,
	]))

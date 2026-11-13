class_name TeleprinterView
extends StationView
## Orders, the code card and the tasking board, all on one strip of paper.

var _label: Label


func _build() -> void:
	_label = make_panel(Vector2(820.0, 640.0), PAPER, INK, 17)


func _process(_delta: float) -> void:
	if not visible:
		return
	var m: Dictionary = Game.mission
	var lines: PackedStringArray = [
		"TOWER 9 -- OPERATION ORDER %d -- %s" % [Game.mission_index + 1, str(m.get("title", "")).to_upper()],
		"",
	]
	for line: String in m.get("orders", []):
		lines.append("  " + line)
	lines.append_array([
		"",
		"CODE CARD",
		"  AIR FREQUENCY  %.1f MC/S" % float(m.get("frequency", 0.0)),
		"",
		"FLIGHTS ON CALL",
	])
	if Game.flights_left.is_empty():
		lines.append("  NONE")
	for id: String in Game.flights_left:
		var ac: Dictionary = Game.aircraft.get(id, {})
		lines.append("  %-8s %-17s %3d S OUT" % [
			str(ac.get("callsign", id)).to_upper(), str(ac.get("name", "")).to_upper(), int(ac.get("eta", 0))])
		lines.append("           %s" % str(ac.get("note", "")))
	lines.append_array([
		"",
		"SMOKE ROUNDS  %d" % Game.smoke_rounds,
		"OWN TROOPS SHOW YELLOW GROUND PANELS.",
		"",
		"[E] leave",
	])
	_label.text = "\n".join(lines)

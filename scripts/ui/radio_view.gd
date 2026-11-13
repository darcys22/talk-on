class_name RadioView
extends StationView
## The radio set and the strike card clipped to its desk.

var _label: Label


func _build() -> void:
	_label = make_panel(Vector2(880.0, 690.0), STEEL, AMBER, 16)


func handle_key(key: int, _event: InputEventKey) -> void:
	var radio: Radio = Game.radio
	match key:
		KEY_G:
			radio.toggle_generator()
		KEY_F:
			Game.cycle_flight()
		KEY_H:
			Game.cycle_heading(-1 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)
		KEY_M:
			Game.toggle_mark()
		KEY_SPACE:
			radio.transmit_card()
		KEY_Y:
			radio.confirm_readback()
		KEY_N:
			radio.say_again()
		KEY_C:
			radio.clear_hot()
		KEY_X:
			radio.abort()


func _process(delta: float) -> void:
	if not visible:
		return
	var radio: Radio = Game.radio
	var rate := 0.3 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.0
	if Input.is_physical_key_pressed(KEY_A):
		radio.tune(-rate * delta)
	if Input.is_physical_key_pressed(KEY_D):
		radio.tune(rate * delta)
	_label.text = _text(radio)


func _text(radio: Radio) -> String:
	var t := int(ceil(Game.time_left))
	var valves := "COLD"
	if radio.generator_on:
		valves = "READY" if radio.is_ready() else "WARMING " + bar(radio.warm, 8)
	var card: Dictionary = Game.card
	var flight := "(none chosen)"
	if str(card.flight) != "":
		var ac: Dictionary = Game.aircraft.get(card.flight, {})
		flight = "%s \"%s\", %d s out" % [ac.get("name", "?"), ac.get("callsign", "?"), int(ac.get("eta", 0))]
	var lines: PackedStringArray = [
		"RADIO SET                                   CLOCK %02d:%02d" % [t / 60, t % 60],
		"",
		"  [G]   Generator      %s" % ("RUNNING" if radio.generator_on else "OFF"),
		"        Valves         %s" % valves,
		"  [A/D] Tuning         %5.1f Mc/s   (Shift = fine)" % radio.freq,
		"        Signal lamp    %s" % bar(radio.signal_strength(), 10),
		"        Enemy fix      %s" % bar(Game.exposure / 100.0, 10),
		"",
		"STRIKE CARD",
		"  1  Grid              %s" % ("------   (plot it at the map table)" if str(card.grid) == "" else str(card.grid)),
		"  2  Flight      [F]   %s" % flight,
		"  3  Heading     [H]   %03d" % int(card.heading),
		"  4  Mark        [M]   %s" % ("RED SMOKE" if card.mark else "NONE"),
		"",
		"HANDSET",
		"  [Space]  Key the handset and read the card",
		"  [Y]      Readback correct        [N]  Say again",
		"  [C]      CLEARED HOT             [X]  Abort",
		"",
		"  %s" % _phase_line(radio),
		"  %s" % radio.status,
		"",
		"  Flights on call: %s        Transmissions: %d" % [_flights(), Game.transmissions],
		"",
		"LOG",
	]
	var recent: Array = Game.radio_log.slice(-3)
	for entry: Dictionary in recent:
		lines.append("  " + ("%s: %s" % [entry.who, entry.text]).left(82))
	for i in 3 - recent.size():
		lines.append("")
	lines.append("  [E] leave the radio")
	return "\n".join(lines)


func _phase_line(radio: Radio) -> String:
	match radio.phase:
		Radio.Phase.SENDING:
			return "> TRANSMITTING"
		Radio.Phase.READBACK:
			return "> PILOT READ BACK GRID %s, HEADING %03d" % [radio.pending.heard_grid, int(radio.pending.heading)]
		Radio.Phase.INBOUND:
			return "> %s INBOUND, %d s" % [radio.callsign(), int(ceil(radio.timer))]
		Radio.Phase.RUN_IN:
			var state := "CLEARED" if radio.cleared else "AWAITING CLEARANCE"
			return "> %s RUNNING IN, %d s. %s" % [radio.callsign(), int(ceil(radio.timer)), state]
	return "> CHANNEL CLEAR"


func _flights() -> String:
	if Game.flights_left.is_empty():
		return "none"
	var names: PackedStringArray = []
	for id: String in Game.flights_left:
		names.append(str((Game.aircraft.get(id, {}) as Dictionary).get("callsign", id)))
	return ", ".join(names)

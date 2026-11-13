class_name Radio
extends RefCounted
## The radio set as a state machine: power, warm-up, tuning, and the
## call / readback / clearance conversation with a flight.

enum Phase { IDLE, SENDING, READBACK, INBOUND, RUN_IN }

const WARM_TIME := 8.0
const SEND_TIME := 3.0
const RUN_IN_TIME := 12.0
const GO_AROUND_TIME := 30.0
const FREQ_MIN := 30.0
const FREQ_MAX := 60.0
const MIN_SIGNAL := 0.6
const TUNE_WIDTH := 1.5

var game: Node
var generator_on := false
var warm := 0.0
var freq := 40.0
var target_freq := 45.0
var phase: Phase = Phase.IDLE
var timer := 0.0
var pending: Dictionary = {}
var cleared := false
var go_arounds := 0
var status := "Set is cold. Start the generator."


func _init(owner: Node) -> void:
	game = owner


func reset(new_target_freq: float) -> void:
	generator_on = false
	warm = 0.0
	freq = 40.0
	target_freq = new_target_freq
	phase = Phase.IDLE
	timer = 0.0
	pending = {}
	cleared = false
	go_arounds = 0
	status = "Set is cold. Start the generator."


func toggle_generator() -> void:
	generator_on = not generator_on
	if generator_on:
		status = "Generator running. Valves warming."
		game.say("RADIO", "Generator running. Valves warming.")
	else:
		warm = 0.0
		status = "Set is cold. Start the generator."
		game.say("RADIO", "Generator off.")
		if phase != Phase.IDLE:
			game.say("RADIO", "Set went dead. Contact with the flight is lost.")
			phase = Phase.IDLE
			pending = {}


func tune(amount: float) -> void:
	freq = clampf(freq + amount, FREQ_MIN, FREQ_MAX)


func detune(amount: float) -> void:
	tune(amount)


func is_ready() -> bool:
	return generator_on and warm >= 1.0


func signal_strength() -> float:
	if not is_ready():
		return 0.0
	return clampf(1.0 - absf(freq - target_freq) / TUNE_WIDTH, 0.0, 1.0)


func callsign() -> String:
	var ac: Dictionary = game.aircraft.get(pending.get("flight", ""), {})
	return str(ac.get("callsign", "Flight")).to_upper()


## Empty string when the card can be sent, otherwise the reason it cannot.
func transmit_problem() -> String:
	if not generator_on:
		return "Generator is off."
	if warm < 1.0:
		return "Valves are still warming."
	if signal_strength() < MIN_SIGNAL:
		return "No contact. Tune to the frequency on your orders."
	if phase != Phase.IDLE:
		return "Channel is busy."
	if str(game.card.get("grid", "")) == "":
		return "Strike card has no grid. Plot the target on the map."
	if str(game.card.get("flight", "")) == "":
		return "Strike card has no flight."
	return ""


func transmit_card() -> bool:
	var problem := transmit_problem()
	if problem != "":
		status = problem
		game.say("RADIO", problem)
		return false
	pending = {
		"flight": str(game.card.flight),
		"grid": str(game.card.grid),
		"heard_grid": str(game.card.grid),
		"heading": int(game.card.heading),
		"mark": bool(game.card.mark),
	}
	go_arounds = 0
	cleared = false
	_send()
	return true


func confirm_readback() -> void:
	if phase != Phase.READBACK:
		return
	game.consume_flight(pending.flight)
	var ac: Dictionary = game.aircraft.get(pending.flight, {})
	phase = Phase.INBOUND
	timer = float(ac.get("eta", 60.0))
	game.say("YOU", "Readback correct.")
	game.say(callsign(), "Inbound. %d seconds." % int(timer))
	status = "Flight inbound."


func say_again() -> void:
	if phase != Phase.READBACK:
		return
	game.say("YOU", "Negative. Say again.")
	_send()


func clear_hot() -> void:
	if phase != Phase.RUN_IN:
		status = "No aircraft is running in."
		return
	if cleared:
		return
	cleared = true
	game.add_exposure(game.EXPOSURE_SHORT, false)
	game.say("YOU", "Cleared hot.")
	status = "Cleared hot. Abort is still live."


func abort() -> void:
	match phase:
		Phase.INBOUND, Phase.RUN_IN:
			game.add_exposure(game.EXPOSURE_SHORT, false)
			game.say("YOU", "Abort, abort, abort.")
			game.say(callsign(), "Aborting. Returning to base.")
			status = "Strike aborted. That flight has gone home."
			phase = Phase.IDLE
			pending = {}
		Phase.READBACK, Phase.SENDING:
			game.say("YOU", "Disregard my last.")
			status = "Call cancelled."
			phase = Phase.IDLE
			pending = {}


func tick(delta: float) -> void:
	if generator_on and warm < 1.0:
		warm = minf(warm + delta / WARM_TIME, 1.0)
		if warm >= 1.0:
			status = "Set ready. Tune to your frequency."
			game.say("RADIO", "Valves warm. Set ready.")
	match phase:
		Phase.SENDING:
			timer -= delta
			if timer <= 0.0:
				_readback()
		Phase.INBOUND:
			timer -= delta
			if timer <= RUN_IN_TIME:
				_begin_run_in()
		Phase.RUN_IN:
			timer -= delta
			if timer <= 0.0:
				_end_run_in()


func _send() -> void:
	game.add_exposure(game.EXPOSURE_PER_TRANSMISSION, true)
	phase = Phase.SENDING
	timer = SEND_TIME
	game.say("YOU", "%s, Tower Nine. Target grid %s. Attack heading %03d. %s." % [
		callsign(), pending.grid, pending.heading, _mark_words()])
	status = "Transmitting."


func _mark_words() -> String:
	return "Mark is red smoke" if pending.get("mark", false) else "No mark"


func _readback() -> void:
	var p_error := 0.10 + 0.5 * (1.0 - signal_strength())
	pending.heard_grid = pending.grid
	if game.rng.randf() < p_error:
		pending.heard_grid = garble(pending.grid, game.rng)
	phase = Phase.READBACK
	game.say(callsign(), "Copy grid %s, heading %03d. %s. Confirm." % [
		pending.heard_grid, pending.heading, _mark_words()])
	status = "Check the readback against your card."


func _aim() -> Dictionary:
	var en: Vector2 = game.en_of_grid(pending.heard_grid)
	var marked := false
	if pending.get("mark", false) and not game.smoke.is_empty():
		en = game.smoke.en
		marked = true
	return {"en": en, "marked": marked}


func _begin_run_in() -> void:
	phase = Phase.RUN_IN
	cleared = false
	var aim := _aim()
	game.aircraft_run.emit(aim.en, float(pending.heading), timer)
	game.say(callsign(), "Running in, heading %03d. Request clearance." % pending.heading)
	status = "CLEAR HOT or ABORT."


func _end_run_in() -> void:
	if cleared:
		var aim := _aim()
		if pending.get("mark", false) and not aim.marked:
			game.say(callsign(), "No smoke seen. Dropping on the grid.")
		game.resolve_strike(pending.flight, aim.en, float(pending.heading), aim.marked)
		game.say(callsign(), "Weapons away. Off target.")
		status = "Strike delivered. Assess it through the scope."
		phase = Phase.IDLE
		pending = {}
	elif go_arounds < 1:
		go_arounds += 1
		phase = Phase.INBOUND
		timer = GO_AROUND_TIME + RUN_IN_TIME
		game.say(callsign(), "No clearance. Going around.")
		status = "Flight going around for one more pass."
	else:
		game.say(callsign(), "Fuel is low. Returning to base.")
		status = "Flight has gone home."
		phase = Phase.IDLE
		pending = {}


## A misheard grid: one of the two numbers is off by 100 to 300 metres.
static func garble(grid: String, rng: RandomNumberGenerator) -> String:
	var parts := grid.split("-")
	if parts.size() != 2:
		return grid
	var which := rng.randi_range(0, 1)
	var value := parts[which].to_int()
	var step := rng.randi_range(1, 3) * 10
	if rng.randf() < 0.5:
		step = -step
	var changed := clampi(value + step, 0, 999)
	if changed == value:
		changed = clampi(value - step, 0, 999)
	parts[which] = "%03d" % changed
	return "-".join(parts)

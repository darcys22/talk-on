extends Node
## Global game state, autoloaded as "Game": missions, the strike card,
## units on the ground, exposure and scoring. Scenes only listen to its signals.
##
## Coordinates: "EN" is a Vector2 of metres east (x) and north (y) of the tower.
## In the 3D world north is -Z, so EN (e, n) sits at Vector3(e, 0, -n).

signal log_line(who: String, text: String)
signal mission_started(index: int)
signal mission_ended(result: Dictionary)
signal card_changed
signal notepad_changed
signal unit_destroyed(unit: Dictionary)
signal impacts(points: Array, radius: float)
signal smoke_changed
signal aircraft_run(aim: Vector2, heading: float, duration: float)
signal tower_shaken(strength: float)

const GRID_ORIGIN := Vector2(-2000.0, -500.0)
const HEADINGS: Array[int] = [0, 45, 90, 135, 180, 225, 270, 315]
const EXPOSURE_PER_TRANSMISSION := 12.0
const EXPOSURE_SHORT := 4.0
const SMOKE_LIFETIME := 90.0
const SMOKE_DRIFT := 0.5
const END_DELAY := 5.0
const TOWER_LOST := "Tower knocked out"

var missions: Array = []
var aircraft: Dictionary = {}
var valley: Dictionary = {}
var landmarks: Array = []

var rng := RandomNumberGenerator.new()
var radio: Radio
var radio_log: Array = []

var mission_index := -1
var mission: Dictionary = {}
var running := false
var paused := false
var time_left := 0.0
var exposure := 0.0
var transmissions := 0
var wind_from := 0.0
var wind_speed := 0.0
var flights_left: Array = []
var smoke_rounds := 0
var smoke: Dictionary = {}
var targets: Array = []
var friendlies: Array = []
var card: Dictionary = {}
var notepad: Dictionary = {}
var last_impacts: Array = []

var _end_timer := -1.0
var _end_reason := ""


func _ready() -> void:
	rng.randomize()
	var m: Variant = _load_json("res://data/missions.json")
	if m is Array:
		missions = m
	var a: Variant = _load_json("res://data/aircraft.json")
	if a is Dictionary:
		aircraft = a
	var v: Variant = _load_json("res://data/valley.json")
	if v is Dictionary:
		valley = v
		landmarks = valley.get("landmarks", [])
	radio = Radio.new(self)
	_reset_card()


func _process(delta: float) -> void:
	if running and not paused:
		tick(delta)


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("Could not parse data file: " + path)
	return data


# --- Coordinates -----------------------------------------------------------

static func grid_of(en: Vector2) -> String:
	var e := int(round((en.x - GRID_ORIGIN.x) / 10.0))
	var n := int(round((en.y - GRID_ORIGIN.y) / 10.0))
	return "%03d-%03d" % [clampi(e, 0, 999), clampi(n, 0, 999)]


static func en_of_grid(grid: String) -> Vector2:
	var parts := grid.split("-")
	if parts.size() != 2:
		return Vector2.ZERO
	return Vector2(
		parts[0].to_int() * 10.0 + GRID_ORIGIN.x,
		parts[1].to_int() * 10.0 + GRID_ORIGIN.y)


static func en_from_polar(bearing_deg: float, range_m: float) -> Vector2:
	return Strike.dir_from_bearing(bearing_deg) * range_m


static func world_of(en: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(en.x, y, -en.y)


static func en_of_world(p: Vector3) -> Vector2:
	return Vector2(p.x, -p.z)


# --- Mission flow ----------------------------------------------------------

func say(who: String, text: String) -> void:
	radio_log.append({"who": who, "text": text})
	if radio_log.size() > 60:
		radio_log.pop_front()
	log_line.emit(who, text)


func start_mission(index: int) -> void:
	if missions.is_empty():
		push_error("No missions loaded.")
		return
	mission_index = clampi(index, 0, missions.size() - 1)
	mission = missions[mission_index]
	time_left = float(mission.get("time_limit", 480.0))
	exposure = 0.0
	transmissions = 0
	var wind: Dictionary = mission.get("wind", {})
	wind_from = float(wind.get("from", 0.0))
	wind_speed = float(wind.get("speed", 0.0))
	flights_left = (mission.get("flights", []) as Array).duplicate()
	smoke_rounds = int(mission.get("smoke_rounds", 3))
	smoke = {}
	targets = _make_units(mission.get("targets", []), false)
	friendlies = _make_units(mission.get("friendlies", []), true)
	last_impacts = []
	notepad = {}
	_reset_card()
	radio.reset(float(mission.get("frequency", 45.0)))
	_end_timer = -1.0
	_end_reason = ""
	running = true
	paused = false
	mission_started.emit(mission_index)
	card_changed.emit()
	notepad_changed.emit()
	smoke_changed.emit()
	say("TELEPRINTER", "New orders printing. Read them at the teleprinter.")


func tick(delta: float) -> void:
	if not running:
		return
	time_left = maxf(time_left - delta, 0.0)
	radio.tick(delta)
	_tick_smoke(delta)
	if _end_timer >= 0.0:
		_end_timer -= delta
		if _end_timer <= 0.0:
			_finish()
		return
	if targets_alive() == 0:
		_schedule_end("All targets destroyed", END_DELAY)
	elif time_left <= 0.0:
		_schedule_end("Out of time", 1.0)
	elif flights_left.is_empty() and radio.phase == Radio.Phase.IDLE:
		_schedule_end("No flights left", END_DELAY)


func targets_alive() -> int:
	return _count_alive(targets)


func friendlies_alive() -> int:
	return _count_alive(friendlies)


func _count_alive(units: Array) -> int:
	var count := 0
	for unit in units:
		if unit.alive:
			count += 1
	return count


func _make_units(defs: Array, friendly: bool) -> Array:
	var out: Array = []
	for i in defs.size():
		var d: Dictionary = defs[i]
		out.append({
			"id": ("f" if friendly else "t") + str(i),
			"type": str(d.get("type", "infantry")),
			"en": Vector2(float(d.get("x", 0.0)), float(d.get("n", 0.0))),
			"alive": true,
			"friendly": friendly,
		})
	return out


func _schedule_end(reason: String, delay: float) -> void:
	_end_reason = reason
	_end_timer = delay


func _finish() -> void:
	running = false
	var total := targets.size()
	var destroyed := total - targets_alive()
	var lost := friendlies.size() - friendlies_alive()
	var score := 100.0 * destroyed / maxf(total, 1.0)
	score -= 40.0 * lost
	score -= 5.0 * maxf(transmissions - 4.0, 0.0)
	if _end_reason == TOWER_LOST:
		score -= 50.0
	var grade := "F"
	if score >= 95.0:
		grade = "A"
	elif score >= 75.0:
		grade = "B"
	elif score >= 50.0:
		grade = "C"
	elif score >= 25.0:
		grade = "D"
	var result := {
		"reason": _end_reason,
		"destroyed": destroyed,
		"total": total,
		"friendly_losses": lost,
		"friendlies": friendlies.size(),
		"transmissions": transmissions,
		"score": int(round(score)),
		"grade": grade,
		"success": destroyed * 2 >= total and lost == 0 and _end_reason != TOWER_LOST,
		"last_mission": mission_index >= missions.size() - 1,
	}
	mission_ended.emit(result)


# --- Strike card and notepad -----------------------------------------------

func _reset_card() -> void:
	card = {"grid": "", "flight": "", "heading": 0, "mark": false}


func set_card_grid(grid: String) -> void:
	card.grid = grid
	card_changed.emit()


func set_notepad(bearing: float, range_m: float) -> void:
	notepad = {"bearing": bearing, "range": range_m}
	notepad_changed.emit()


func cycle_flight() -> void:
	var unique: Array = []
	for f in flights_left:
		if not unique.has(f):
			unique.append(f)
	if unique.is_empty():
		card.flight = ""
	else:
		card.flight = unique[(unique.find(card.flight) + 1) % unique.size()]
	card_changed.emit()


func cycle_heading(step: int) -> void:
	var i := HEADINGS.find(int(card.heading))
	card.heading = HEADINGS[posmod(i + step, HEADINGS.size())]
	card_changed.emit()


func toggle_mark() -> void:
	card.mark = not card.mark
	card_changed.emit()


func consume_flight(flight_id: String) -> void:
	flights_left.erase(flight_id)
	if not flights_left.has(card.flight):
		card.flight = ""
	card_changed.emit()


# --- Smoke, exposure, strikes ----------------------------------------------

## Fires a smoke round at the grid on the strike card. Returns what happened.
func fire_smoke() -> String:
	if not running:
		return "Nothing to mark."
	if smoke_rounds <= 0:
		return "Launcher is empty."
	if str(card.grid) == "":
		return "No grid on the strike card. Plot the target on the map first."
	smoke_rounds -= 1
	var en := en_of_grid(card.grid) + Vector2(rng.randfn(0.0, 12.0), rng.randfn(0.0, 12.0))
	smoke = {"en": en, "age": 0.0}
	smoke_changed.emit()
	return "Red smoke away on grid %s. %d rounds left." % [card.grid, smoke_rounds]


func _tick_smoke(delta: float) -> void:
	if smoke.is_empty():
		return
	smoke["age"] = float(smoke["age"]) + delta
	var downwind := Strike.dir_from_bearing(wind_from + 180.0)
	smoke["en"] = (smoke["en"] as Vector2) + downwind * wind_speed * SMOKE_DRIFT * delta
	if float(smoke["age"]) >= SMOKE_LIFETIME:
		smoke = {}
		smoke_changed.emit()


## Every transmission helps the enemy find the tower.
func add_exposure(amount: float, counts_as_transmission: bool) -> void:
	if counts_as_transmission:
		transmissions += 1
	var before := exposure
	exposure = minf(exposure + amount, 100.0)
	for mark: float in [50.0, 75.0]:
		if before < mark and exposure >= mark:
			say("TOWER", "Mortar rounds landing close. They are finding you.")
			tower_shaken.emit(0.6)
			radio.detune(rng.randf_range(-2.5, 2.5))
	if exposure >= 100.0 and _end_reason != TOWER_LOST:
		say("TOWER", "Direct hit on the tower.")
		tower_shaken.emit(1.5)
		_schedule_end(TOWER_LOST, 2.5)


func resolve_strike(flight_id: String, aim: Vector2, heading: float, marked: bool) -> Dictionary:
	var ac: Dictionary = aircraft.get(flight_id, {})
	var points := Strike.impact_points(ac, aim, heading, wind_from, wind_speed, marked, rng)
	var radius := float(ac.get("radius", 30.0))
	var kills: Array = ac.get("kills", [])
	var hit_enemy := 0
	var hit_friendly := 0
	for unit: Dictionary in targets + friendlies:
		if not unit.alive:
			continue
		for p in points:
			if (unit.en as Vector2).distance_to(p) > radius:
				continue
			if unit.friendly or kills.has(unit.type):
				unit.alive = false
				unit_destroyed.emit(unit)
				if unit.friendly:
					hit_friendly += 1
				else:
					hit_enemy += 1
			break
	last_impacts = points
	impacts.emit(points, radius)
	if hit_friendly > 0:
		say("GROUND", "Check fire! Check fire! You are hitting our own men!")
	return {"enemy": hit_enemy, "friendly": hit_friendly}

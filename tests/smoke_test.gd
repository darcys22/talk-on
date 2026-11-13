extends Node
## Headless end-to-end check, run by CI:
##   godot --headless --path . res://tests/smoke_test.tscn
## Loads the real main scene, opens every view, then flies one full strike
## through the radio state machine. Exits 0 on success, 1 on failure.

var _failures: PackedStringArray = []


func _ready() -> void:
	await _run()
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAILED: " + f)
		print("SMOKE TEST FAILED (%d)" % _failures.size())
		get_tree().quit(1)


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures.append(what)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	# --- Data and coordinate maths ---
	_check(Game.missions.size() >= 3, "three missions load")
	_check(Game.aircraft.has("dive_bomber"), "aircraft data loads")
	_check(Game.landmarks.size() >= 5, "landmarks load")
	var en := Vector2(510.0, 1020.0)
	_check(Game.en_of_grid(Game.grid_of(en)).distance_to(en) < 0.01, "grid round trip")
	_check(Game.grid_of(Vector2.ZERO) == "200-050", "tower grid is 200-050")
	_check(Game.en_from_polar(90.0, 100.0).distance_to(Vector2(100.0, 0.0)) < 0.01, "bearing 090 is east")
	_check(Game.world_of(Vector2(0.0, 100.0)).z < 0.0, "north is -Z")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 20:
		_check(Radio.garble("251-152", rng) != "251-152", "garble changes the grid")

	# --- The real scene ---
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	_check(main.mode == "title", "starts on the title card")
	main.start_mission(0)
	await _frames(2)
	_check(Game.running, "mission is running")
	_check(Game.targets.size() == 4, "mission one has four targets")
	for mode: String in ["scope", "map", "radio", "teleprinter", "pause", "walk"]:
		main.set_mode(mode)
		await _frames(3)
		_check(main.mode == mode, "view opens: " + mode)

	# --- Scope and map ---
	var scope: ScopeView = main.views.scope
	scope.yaw = 26.5
	scope.pitch = -1.6
	scope.drum = 1140.0
	main.set_mode("scope")
	await _frames(2)
	_check(not is_inf(scope.true_range()), "scope pointing at the ground has a range")
	scope.jot()
	_check(is_equal_approx(float(Game.notepad.bearing), 26.5), "notepad takes the bearing")
	var map: MapView = main.views.map
	map.bearing = 26.5
	map.range_m = 1140.0
	main.set_mode("map")
	await _frames(2)
	map.handle_key(KEY_ENTER, null)
	_check(str(Game.card.grid) != "", "map pencils a grid onto the card")

	# --- One full strike ---
	Game.rng.seed = 1
	Game.paused = true  # drive time by hand from here on
	var centre := Vector2.ZERO
	for unit: Dictionary in Game.targets:
		centre += unit.en
	centre /= Game.targets.size()
	Game.set_card_grid(Game.grid_of(centre))
	while str(Game.card.flight) != "dive_bomber":
		Game.cycle_flight()
	Game.cycle_heading(2)
	_check(int(Game.card.heading) == 90, "heading cycles to 090")

	var radio: Radio = Game.radio
	_check(not radio.transmit_card(), "cold radio refuses to transmit")
	radio.toggle_generator()
	Game.tick(Radio.WARM_TIME + 0.5)
	_check(radio.is_ready(), "valves warm up")
	_check(radio.transmit_problem() != "", "untuned radio has no contact")
	radio.freq = radio.target_freq
	_check(radio.transmit_card(), "tuned radio transmits")
	_check(Game.transmissions == 1, "transmission is counted")
	Game.tick(Radio.SEND_TIME + 0.1)
	_check(radio.phase == Radio.Phase.READBACK, "pilot reads back")
	radio.pending.heard_grid = radio.pending.grid
	radio.confirm_readback()
	_check(radio.phase == Radio.Phase.INBOUND, "flight is inbound")
	_check(not Game.flights_left.has("dive_bomber"), "flight is used up")
	var guard := 0
	while radio.phase != Radio.Phase.RUN_IN and guard < 400:
		Game.tick(0.5)
		guard += 1
	_check(radio.phase == Radio.Phase.RUN_IN, "flight runs in")
	radio.clear_hot()
	guard = 0
	while radio.phase != Radio.Phase.IDLE and guard < 400:
		Game.tick(0.5)
		guard += 1
	_check(radio.phase == Radio.Phase.IDLE, "strike completes")
	_check(Game.last_impacts.size() == 1, "one bomb lands")
	_check(Game.targets_alive() < 4, "the bomb destroys at least one truck")
	_check(Game.friendlies_alive() == 2, "no friendly losses")
	await _frames(3)

	# --- Smoke, exposure, mission end ---
	var before := Game.smoke_rounds
	Game.fire_smoke()
	_check(Game.smoke_rounds == before - 1 and not Game.smoke.is_empty(), "smoke round fires")
	var smoke_start: Vector2 = Game.smoke.en
	Game.tick(10.0)
	_check((Game.smoke.en as Vector2).distance_to(smoke_start) > 1.0, "smoke drifts with the wind")
	Game.add_exposure(200.0, false)
	guard = 0
	while Game.running and guard < 100:
		Game.tick(0.5)
		guard += 1
	_check(not Game.running, "mission ends when the tower is found")
	await _frames(3)
	_check(main.mode == "debrief", "debrief opens")

	# --- Every mission starts cleanly ---
	for i in Game.missions.size():
		main.start_mission(i)
		await _frames(3)
		_check(Game.running and not Game.targets.is_empty(), "mission %d starts" % (i + 1))

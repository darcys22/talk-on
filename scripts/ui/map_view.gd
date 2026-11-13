class_name MapView
extends StationView
## The paper map. Lay the protractor on the bearing and range you noted at
## the scope, then pencil the grid onto the strike card.

const E_MIN := -1600.0
const E_MAX := 1600.0
const N_MIN := -150.0
const N_MAX := 2500.0
const PANEL := Vector2(1120.0, 660.0)
const SIDE := 300.0

var bearing := 0.0
var range_m := 1000.0


func handle_key(key: int, _event: InputEventKey) -> void:
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		var grid := Game.grid_of(_plot())
		Game.set_card_grid(grid)
		Game.say("STRIKE CARD", "Grid %s pencilled in." % grid)


func _process(delta: float) -> void:
	if not visible:
		return
	var fine := Input.is_physical_key_pressed(KEY_SHIFT)
	var turn := 2.0 if fine else 30.0
	var slide := 20.0 if fine else 300.0
	if Input.is_physical_key_pressed(KEY_A):
		bearing -= turn * delta
	if Input.is_physical_key_pressed(KEY_D):
		bearing += turn * delta
	if Input.is_physical_key_pressed(KEY_W):
		range_m += slide * delta
	if Input.is_physical_key_pressed(KEY_S):
		range_m -= slide * delta
	bearing = fposmod(bearing, 360.0)
	range_m = clampf(range_m, 100.0, 3000.0)
	queue_redraw()


func _plot() -> Vector2:
	return Game.en_from_polar(snappedf(bearing, 0.5), snappedf(range_m, 10.0))


func _draw() -> void:
	var font := mono_font()
	var origin := (size - PANEL) * 0.5
	draw_rect(Rect2(origin, PANEL), STEEL)

	# Map sheet on the right, notes on the left.
	var sheet := Rect2(origin + Vector2(SIDE, 20), PANEL - Vector2(SIDE + 20, 40))
	draw_rect(sheet, PAPER)
	var scale_px := minf(sheet.size.x / (E_MAX - E_MIN), sheet.size.y / (N_MAX - N_MIN))
	var pad := (sheet.size - Vector2(E_MAX - E_MIN, N_MAX - N_MIN) * scale_px) * 0.5
	var to_px := func(en: Vector2) -> Vector2:
		return sheet.position + pad + Vector2((en.x - E_MIN) * scale_px, (N_MAX - en.y) * scale_px)

	var thin := Color(0.1, 0.1, 0.1, 0.16)
	var bold := Color(0.1, 0.1, 0.1, 0.4)
	var e := -1500.0
	while e <= 1500.0:
		var major := is_zero_approx(fmod(e, 500.0))
		draw_line(to_px.call(Vector2(e, N_MIN)), to_px.call(Vector2(e, N_MAX)), bold if major else thin, 1.0)
		if major:
			var label := "%03d" % int((e - Game.GRID_ORIGIN.x) / 10.0)
			draw_string(font, to_px.call(Vector2(e, N_MIN)) + Vector2(-14, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		e += 100.0
	var n := 0.0
	while n <= N_MAX:
		var major := is_zero_approx(fmod(n, 500.0))
		draw_line(to_px.call(Vector2(E_MIN, n)), to_px.call(Vector2(E_MAX, n)), bold if major else thin, 1.0)
		if major:
			var label := "%03d" % int((n - Game.GRID_ORIGIN.y) / 10.0)
			draw_string(font, to_px.call(Vector2(E_MIN, n)) + Vector2(4, -3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		n += 100.0

	var river_n := float(Game.valley.get("river_n", 1200.0))
	draw_line(to_px.call(Vector2(E_MIN, river_n)), to_px.call(Vector2(E_MAX, river_n)), Color(0.2, 0.4, 0.65), 5.0)
	for road: Dictionary in Game.valley.get("roads", []):
		var a := Vector2(float(road.from[0]), float(road.from[1]))
		var b := Vector2(float(road.to[0]), float(road.to[1]))
		draw_line(to_px.call(a), to_px.call(b), Color(0.45, 0.35, 0.25), 2.0)
	for lm: Dictionary in Game.landmarks:
		var at: Vector2 = to_px.call(Vector2(float(lm.x), float(lm.n)))
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), INK)
		draw_string(font, at + Vector2(8, 5), str(lm.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)

	var tower: Vector2 = to_px.call(Vector2.ZERO)
	draw_circle(tower, 6.0, Color(0.7, 0.1, 0.05))
	draw_string(font, tower + Vector2(10, 5), "TOWER 9", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.1, 0.05))

	# Protractor arm.
	var plot := _plot()
	var tip: Vector2 = to_px.call(plot)
	var red := Color(0.75, 0.1, 0.05)
	draw_line(tower, tip, red, 1.5)
	draw_line(tip - Vector2(8, 0), tip + Vector2(8, 0), red, 2.0)
	draw_line(tip - Vector2(0, 8), tip + Vector2(0, 8), red, 2.0)
	draw_string(font, tip + Vector2(10, -8), Game.grid_of(plot), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, red)

	# Notes column.
	var lines: PackedStringArray = ["MAP TABLE", ""]
	lines.append("NOTEPAD")
	if Game.notepad.is_empty():
		lines.append("  (nothing noted yet)")
	else:
		lines.append("  bearing %05.1f" % float(Game.notepad.bearing))
		lines.append("  range   %d m" % int(Game.notepad.range))
	lines.append_array(["", "PROTRACTOR"])
	lines.append("  bearing %05.1f" % snappedf(bearing, 0.5))
	lines.append("  range   %d m" % int(snappedf(range_m, 10.0)))
	lines.append("  grid    %s" % Game.grid_of(plot))
	lines.append_array(["", "STRIKE CARD"])
	lines.append("  grid    %s" % ("------" if str(Game.card.grid) == "" else str(Game.card.grid)))
	lines.append_array([
		"", "", "A / D   swing arm", "W / S   slide range", "Shift   fine",
		"Enter   pencil grid", "        onto the card", "E       leave"])
	var y := origin.y + 48.0
	for text in lines:
		draw_string(font, Vector2(origin.x + 24.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AMBER)
		y += 24.0

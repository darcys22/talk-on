class_name ScopeView
extends StationView
## The tripod scope and its rangefinder.
## Bearing comes off the mount ring. Range comes from turning the drum until
## the two halves of the split line meet.

const FOV := 4.0
const FAST_YAW := 12.0
const FAST_PITCH := 4.0
const FINE := 0.004
const YAW_LIMIT := 90.0
const PITCH_MIN := -35.0
const PITCH_MAX := 4.0
const DRUM_MIN := 100.0
const DRUM_MAX := 4000.0
const SPLIT_GAIN := 250000.0

var camera: Camera3D
## Degrees clockwise from north.
var yaw := 0.0
var pitch := -1.5
var drum := 1000.0


func opened() -> void:
	_apply()


func bearing() -> float:
	return fposmod(yaw, 360.0)


## Ground distance from the tower to where the scope is pointing.
func true_range() -> float:
	if camera == null:
		return INF
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	if dir.y > -0.0005:
		return INF
	var hit := origin + dir * (origin.y / -dir.y)
	return Vector2(hit.x, hit.z).length()


## Sideways gap between the two halves of the split line, in pixels.
func split_offset() -> float:
	var true_r := true_range()
	var inv_true := 0.0 if is_inf(true_r) else 1.0 / true_r
	return clampf(SPLIT_GAIN * (1.0 / drum - inv_true), -300.0, 300.0)


func jot() -> void:
	var b := snappedf(bearing(), 0.5)
	var r := snappedf(drum, 10.0)
	Game.set_notepad(b, r)
	Game.say("NOTEPAD", "Bearing %05.1f, range %d m." % [b, int(r)])


func handle_key(key: int, _event: InputEventKey) -> void:
	if key == KEY_SPACE:
		jot()


func handle_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		yaw += motion.relative.x * FINE
		pitch -= motion.relative.y * FINE
	elif event is InputEventMouseButton and event.pressed:
		var step := 100.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 10.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			drum += step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			drum -= step
	_apply()


func _process(delta: float) -> void:
	if not visible:
		return
	var rate := 0.1 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	if Input.is_physical_key_pressed(KEY_A):
		yaw -= FAST_YAW * rate * delta
	if Input.is_physical_key_pressed(KEY_D):
		yaw += FAST_YAW * rate * delta
	if Input.is_physical_key_pressed(KEY_W):
		pitch += FAST_PITCH * rate * delta
	if Input.is_physical_key_pressed(KEY_S):
		pitch -= FAST_PITCH * rate * delta
	if Input.is_physical_key_pressed(KEY_Z):
		drum -= 500.0 * rate * delta
	if Input.is_physical_key_pressed(KEY_X):
		drum += 500.0 * rate * delta
	_apply()
	queue_redraw()


func _apply() -> void:
	yaw = clampf(yaw, -YAW_LIMIT, YAW_LIMIT)
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	drum = clampf(drum, DRUM_MIN, DRUM_MAX)
	if camera != null:
		camera.rotation_degrees = Vector3(pitch, -yaw, 0.0)
		camera.fov = FOV


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	var black := Color.BLACK
	draw_rect(Rect2(0, 0, centre.x - radius, size.y), black)
	draw_rect(Rect2(centre.x + radius, 0, size.x - centre.x - radius, size.y), black)
	draw_rect(Rect2(0, 0, size.x, centre.y - radius), black)
	draw_rect(Rect2(0, centre.y + radius, size.x, size.y - centre.y - radius), black)
	var ring := radius * 0.45
	draw_arc(centre, radius + ring * 0.5, 0.0, TAU, 96, black, ring + 2.0)

	# Reticle and the rangefinder's split line.
	var line := Color(0.05, 0.05, 0.05, 0.85)
	draw_line(centre - Vector2(radius, 0), centre - Vector2(24, 0), line, 1.5)
	draw_line(centre + Vector2(24, 0), centre + Vector2(radius, 0), line, 1.5)
	var gap := split_offset()
	draw_line(centre - Vector2(0, radius * 0.5), centre - Vector2(0, 3), line, 2.0)
	draw_line(centre + Vector2(gap, 3), centre + Vector2(gap, radius * 0.5), Color(0.75, 0.1, 0.05, 0.9), 2.0)

	var font := mono_font()
	var readout := "RING  %05.1f deg        DRUM  %4d m" % [snappedf(bearing(), 0.5), int(snappedf(drum, 10.0))]
	draw_string(font, Vector2(0, 40), readout, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, AMBER)
	var help := "A/D W/S crank (Shift = slow)   Mouse = fine   Wheel or Z/X = range drum   Space = note it down   E = leave"
	draw_string(font, Vector2(0, 66), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(0.8, 0.8, 0.75))

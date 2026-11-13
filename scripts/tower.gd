class_name Tower
extends Node3D
## Builds the grey-box tower room and its stations out of primitive meshes.
## Swap these for real art later; the station list is what the game uses.

const FLOOR_Y := 30.0
const HALF := 3.0
const WALL_H := 2.8
const SILL := 1.2
const LINTEL := 2.0
const THICK := 0.3

const CONCRETE := Color(0.46, 0.47, 0.44)
const STEEL := Color(0.23, 0.27, 0.21)
const BRASS := Color(0.72, 0.58, 0.28)
const STENCIL := Color(0.92, 0.88, 0.72)

## Each station: {"id", "pos", "radius", "prompt"}.
var stations: Array = []
var scope_camera: Camera3D

var _wind_label: Label3D
var _clock_label: Label3D
var _lamp_material: StandardMaterial3D
var _refresh := 0.0


func _ready() -> void:
	_build_shell()
	_build_stations()


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.5
	# Needles lag and wobble a little, so one glance is never exact.
	var shown_from := snappedf(Game.wind_from + randf_range(-6.0, 6.0), 5.0)
	var shown_speed := maxf(Game.wind_speed + randf_range(-0.6, 0.6), 0.0)
	_wind_label.text = "WIND FROM %03d\n%.0f M/S" % [int(fposmod(shown_from, 360.0)), shown_speed]
	var t := int(ceil(Game.time_left))
	_clock_label.text = "%02d:%02d" % [t / 60, t % 60]
	var strength: float = Game.radio.signal_strength()
	var lamp := Color(0.15, 0.15, 0.12)
	if Game.radio.generator_on:
		lamp = Color(0.9, 0.35, 0.1).lerp(Color(0.3, 1.0, 0.3), strength)
	_lamp_material.albedo_color = lamp
	_lamp_material.emission = lamp


## The station the camera is looking at from close by, or an empty dictionary.
func station_in_view(cam: Camera3D) -> Dictionary:
	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z
	var best := {}
	var best_angle := 999.0
	for st: Dictionary in stations:
		var to: Vector3 = (st.pos as Vector3) - origin
		var dist := to.length()
		if dist > 3.2 or dist < 0.01:
			continue
		var angle := forward.angle_to(to)
		var allowed := atan2(float(st.radius), dist) + 0.12
		if angle < allowed and angle < best_angle:
			best = st
			best_angle = angle
	return best


func _build_shell() -> void:
	var span := HALF * 2.0 + THICK * 2.0
	var off := HALF + THICK * 0.5
	var upper_h := WALL_H - LINTEL
	# Floor, roof, and the shaft the tower stands on.
	_box(Vector3(span, THICK, span), Vector3(0, FLOOR_Y - THICK * 0.5, 0), CONCRETE.darkened(0.25))
	_box(Vector3(span, THICK, span), Vector3(0, FLOOR_Y + WALL_H + THICK * 0.5, 0), CONCRETE.darkened(0.1))
	_box(Vector3(5.0, FLOOR_Y, 5.0), Vector3(0, FLOOR_Y * 0.5 - THICK, 0), CONCRETE.darkened(0.3))
	# Back (south) wall is solid.
	_box(Vector3(span, WALL_H, THICK), Vector3(0, FLOOR_Y + WALL_H * 0.5, off), CONCRETE)
	# North, east and west walls have the observation slit.
	var low_y := FLOOR_Y + SILL * 0.5
	var up_y := FLOOR_Y + LINTEL + upper_h * 0.5
	_box(Vector3(span, SILL, THICK), Vector3(0, low_y, -off), CONCRETE)
	_box(Vector3(span, upper_h, THICK), Vector3(0, up_y, -off), CONCRETE)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(THICK, SILL, span), Vector3(off * side, low_y, 0), CONCRETE)
		_box(Vector3(THICK, upper_h, span), Vector3(off * side, up_y, 0), CONCRETE)
		# Corner posts carry the roof across the slit.
		_box(Vector3(0.4, WALL_H, 0.4), Vector3(off * side, FLOOR_Y + WALL_H * 0.5, -off), CONCRETE.darkened(0.15))
	var bulb := OmniLight3D.new()
	bulb.position = Vector3(0, FLOOR_Y + WALL_H - 0.3, 0.5)
	bulb.light_color = Color(1.0, 0.85, 0.6)
	bulb.light_energy = 1.2
	bulb.omni_range = 9.0
	add_child(bulb)


func _build_stations() -> void:
	# Scope on its tripod at the north window.
	_box(Vector3(0.08, 1.35, 0.08), Vector3(0, FLOOR_Y + 0.68, -2.45), STEEL)
	_box(Vector3(0.14, 0.14, 0.7), Vector3(0, FLOOR_Y + 1.45, -2.5), BRASS)
	_sign("SCOPE", Vector3(0.7, FLOOR_Y + 1.02, -2.98), 0.0, 40)
	_add_station("scope", Vector3(0, FLOOR_Y + 1.4, -2.5), 0.45, "Use the scope")
	scope_camera = Camera3D.new()
	scope_camera.position = Vector3(0, FLOOR_Y + 1.6, -3.4)
	scope_camera.near = 0.5
	scope_camera.far = 9000.0
	scope_camera.fov = 4.0
	add_child(scope_camera)

	# Map table in the middle of the room.
	_box(Vector3(1.6, 0.9, 1.0), Vector3(0, FLOOR_Y + 0.45, -0.3), STEEL.lightened(0.1))
	_box(Vector3(1.4, 0.02, 0.85), Vector3(0, FLOOR_Y + 0.91, -0.3), Color(0.85, 0.8, 0.65))
	_add_station("map", Vector3(0, FLOOR_Y + 0.92, -0.3), 0.7, "Use the map table")

	# Radio cabinet fills the middle of the back wall.
	_box(Vector3(2.2, 1.5, 0.6), Vector3(0, FLOOR_Y + 0.75, 2.65), STEEL)
	_box(Vector3(1.9, 0.5, 0.05), Vector3(0, FLOOR_Y + 1.05, 2.33), STEEL.darkened(0.3))
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.emission_enabled = true
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.05
	lamp_mesh.height = 0.1
	lamp.mesh = lamp_mesh
	lamp.material_override = _lamp_material
	lamp.position = Vector3(0.8, FLOOR_Y + 1.38, 2.33)
	add_child(lamp)
	_sign("RADIO", Vector3(0, FLOOR_Y + 1.75, 2.98), 180.0, 56)
	_add_station("radio", Vector3(0, FLOOR_Y + 1.0, 2.4), 0.9, "Use the radio")

	# Teleprinter in the back-left corner.
	_box(Vector3(0.7, 1.0, 0.5), Vector3(-2.2, FLOOR_Y + 0.5, 2.7), STEEL.lightened(0.15))
	_box(Vector3(0.4, 0.3, 0.02), Vector3(-2.2, FLOOR_Y + 1.15, 2.6), Color(0.9, 0.88, 0.78))
	_sign("TELEPRINTER", Vector3(-2.2, FLOOR_Y + 1.75, 2.98), 180.0, 36)
	_add_station("teleprinter", Vector3(-2.2, FLOOR_Y + 1.0, 2.6), 0.5, "Read the teleprinter")

	# Clock on the back wall.
	_clock_label = _sign("00:00", Vector3(2.0, FLOOR_Y + 1.75, 2.98), 180.0, 64)
	_clock_label.modulate = Color(1.0, 0.75, 0.3)

	# Smoke launcher at the east window.
	_box(Vector3(0.9, 0.16, 0.16), Vector3(2.6, FLOOR_Y + 1.3, -0.8), BRASS.darkened(0.3))
	_sign("SMOKE", Vector3(2.98, FLOOR_Y + 0.95, -0.8), -90.0, 40)
	_add_station("launcher", Vector3(2.6, FLOOR_Y + 1.3, -0.8), 0.45, "Fire a smoke marker at the card grid")

	# Wind instruments on the west wall, below the slit.
	_wind_label = _sign("WIND", Vector3(-2.98, FLOOR_Y + 0.85, -0.8), 90.0, 40)
	_wind_label.modulate = Color(1.0, 0.75, 0.3)


func _add_station(id: String, pos: Vector3, radius: float, prompt: String) -> void:
	stations.append({"id": id, "pos": pos, "radius": radius, "prompt": prompt})


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node


func _sign(text: String, pos: Vector3, yaw_deg: float, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.modulate = STENCIL
	label.position = pos
	label.rotation_degrees = Vector3(0, yaw_deg, 0)
	add_child(label)
	return label

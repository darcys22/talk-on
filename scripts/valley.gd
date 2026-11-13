class_name Valley
extends Node3D
## Everything outside the glass: ground, river, landmarks, units and the
## effects of strikes. Grey-box primitives only.

const GROUND := Color(0.36, 0.42, 0.28)
const ENEMY := Color(0.2, 0.2, 0.17)
const FRIEND := Color(0.42, 0.45, 0.32)
const PANEL := Color(0.95, 0.85, 0.15)

var _units: Node3D
var _effects: Node3D
var _unit_nodes: Dictionary = {}
var _smoke_node: MeshInstance3D
var _plane: Node3D
var _plane_dir := Vector3.ZERO
var _plane_time := 0.0
var _plane_total := 0.0
var _scenery_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_scenery_rng.seed = 9
	_build_ground()
	_build_landmarks()
	_units = Node3D.new()
	add_child(_units)
	_effects = Node3D.new()
	add_child(_effects)
	_build_smoke()
	_build_plane()
	Game.mission_started.connect(_on_mission_started)
	Game.unit_destroyed.connect(_on_unit_destroyed)
	Game.impacts.connect(_on_impacts)
	Game.smoke_changed.connect(_on_smoke_changed)
	Game.aircraft_run.connect(_on_aircraft_run)


func _process(delta: float) -> void:
	if _smoke_node.visible and not Game.smoke.is_empty():
		_smoke_node.position = Game.world_of(Game.smoke.en, 30.0)
	if _plane.visible:
		_plane_time += delta
		_plane.position += _plane_dir * 150.0 * delta
		if _plane_time > _plane_total + 14.0:
			_plane.visible = false


# --- Scenery ---------------------------------------------------------------

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	ground.mesh = plane
	ground.material_override = _mat(GROUND)
	add_child(ground)

	var river_n := float(Game.valley.get("river_n", 1200.0))
	_box(Vector3(7000.0, 0.2, 40.0), Game.world_of(Vector2(0, river_n), 0.1), Color(0.25, 0.38, 0.5))
	for road: Dictionary in Game.valley.get("roads", []):
		var a := Vector2(float(road.from[0]), float(road.from[1]))
		var b := Vector2(float(road.to[0]), float(road.to[1]))
		var mid := (a + b) * 0.5
		var size := Vector3(absf(b.x - a.x) + 8.0, 0.3, absf(b.y - a.y) + 8.0)
		_box(size, Game.world_of(mid, 0.2), Color(0.55, 0.52, 0.45))
	# Far hills close off the north end of the valley.
	for i in 7:
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		hill.mesh = sphere
		hill.material_override = _mat(GROUND.darkened(0.25))
		hill.scale = Vector3(
			_scenery_rng.randf_range(600.0, 1000.0),
			_scenery_rng.randf_range(120.0, 260.0),
			_scenery_rng.randf_range(400.0, 700.0))
		hill.position = Game.world_of(Vector2(-3000.0 + i * 1000.0, _scenery_rng.randf_range(3300.0, 3900.0)))
		add_child(hill)


func _build_landmarks() -> void:
	for lm: Dictionary in Game.landmarks:
		var en := Vector2(float(lm.x), float(lm.n))
		match str(lm.type):
			"barn":
				_box(Vector3(24, 12, 14), Game.world_of(en, 6), Color(0.62, 0.16, 0.12))
			"church":
				_box(Vector3(16, 12, 30), Game.world_of(en, 6), Color(0.75, 0.73, 0.68))
				_box(Vector3(7, 38, 7), Game.world_of(en + Vector2(0, 16), 19), Color(0.7, 0.68, 0.63))
			"bridge":
				_box(Vector3(14, 1.5, 56), Game.world_of(en, 1.2), Color(0.45, 0.36, 0.28))
			"water_tower":
				_cylinder(1.5, 22, Game.world_of(en, 11), Color(0.4, 0.4, 0.4))
				_cylinder(7, 8, Game.world_of(en, 26), Color(0.55, 0.57, 0.6))
			"chimney":
				_cylinder(3.5, 55, Game.world_of(en, 27.5), Color(0.5, 0.3, 0.25))
				_box(Vector3(50, 12, 30), Game.world_of(en + Vector2(30, 0), 6), Color(0.42, 0.4, 0.38))
			"wood":
				for i in 40:
					var offset := Vector2(_scenery_rng.randf_range(-90, 90), _scenery_rng.randf_range(-70, 70))
					var h := _scenery_rng.randf_range(10.0, 16.0)
					_cylinder(4.5, h, Game.world_of(en + offset, h * 0.5), Color(0.16, 0.3, 0.16), 0.0)
			"farm":
				_box(Vector3(20, 8, 12), Game.world_of(en, 4), Color(0.9, 0.9, 0.86))
				_box(Vector3(10, 6, 10), Game.world_of(en + Vector2(22, 6), 3), Color(0.5, 0.42, 0.32))


# --- Units -----------------------------------------------------------------

func _on_mission_started(_index: int) -> void:
	for child in _units.get_children():
		child.queue_free()
	for child in _effects.get_children():
		child.queue_free()
	_unit_nodes.clear()
	_plane.visible = false
	for unit: Dictionary in Game.targets + Game.friendlies:
		var node := _make_unit(unit)
		node.position = Game.world_of(unit.en)
		_units.add_child(node)
		_unit_nodes[unit.id] = node


func _make_unit(unit: Dictionary) -> Node3D:
	var root := Node3D.new()
	var color := FRIEND if unit.friendly else ENEMY
	match str(unit.type):
		"truck":
			_box(Vector3(2.6, 2.6, 6.5), Vector3(0, 1.5, 0), color, root)
			_box(Vector3(2.4, 1.2, 2.0), Vector3(0, 3.2, -1.8), color.darkened(0.2), root)
		"tank":
			_box(Vector3(3.6, 1.6, 7.0), Vector3(0, 1.0, 0), color, root)
			_box(Vector3(2.4, 1.0, 2.8), Vector3(0, 2.3, 0), color.darkened(0.2), root)
			_box(Vector3(0.3, 0.3, 4.0), Vector3(0, 2.4, -3.2), color.darkened(0.3), root)
		"bunker":
			_box(Vector3(8, 3, 8), Vector3(0, 1.5, 0), Color(0.5, 0.5, 0.48), root)
		_:
			# Infantry: a short trench line with a few figures behind it.
			_box(Vector3(9, 0.8, 1.6), Vector3(0, 0.4, 0), Color(0.5, 0.44, 0.32), root)
			for i in 4:
				_box(Vector3(0.6, 1.7, 0.5), Vector3(-3.0 + i * 2.0, 0.9, 1.6), color, root)
	if unit.friendly:
		# Air recognition panel: the only clear way to tell friend from foe.
		_box(Vector3(5, 0.15, 3), Vector3(0, 0.1, 5), PANEL, root)
	return root


func _on_unit_destroyed(unit: Dictionary) -> void:
	var node: Node3D = _unit_nodes.get(unit.id)
	if node == null:
		return
	node.visible = false
	var at := Game.world_of(unit.en)
	_box(Vector3(4, 1.2, 5), at + Vector3(0, 0.6, 0), Color(0.06, 0.06, 0.06), _effects)
	var column := _cylinder(3.0, 60.0, at + Vector3(0, 30, 0), Color(0.1, 0.1, 0.1, 0.55), 5.0, _effects)
	column.rotation_degrees.z = 8.0


# --- Strike effects --------------------------------------------------------

func _on_impacts(points: Array, radius: float) -> void:
	for p: Vector2 in points:
		var at := Game.world_of(p)
		# A scar that stays for the rest of the mission.
		_cylinder(radius * 0.45, 0.3, at + Vector3(0, 0.25, 0), Color(0.12, 0.1, 0.08), -1.0, _effects)
		var flash := _sphere(radius * 0.5, at + Vector3(0, radius * 0.3, 0), Color(1.0, 0.7, 0.25, 0.95))
		var dust := _sphere(radius * 0.35, at + Vector3(0, radius * 0.3, 0), Color(0.45, 0.42, 0.38, 0.7))
		# Each tween belongs to its own node, so clearing effects also stops it.
		var burst := flash.create_tween().set_parallel(true)
		burst.tween_property(flash, "scale", Vector3.ONE * 1.8, 0.35)
		burst.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.5)
		burst.chain().tween_callback(flash.queue_free)
		var settle := dust.create_tween().set_parallel(true)
		settle.tween_property(dust, "scale", Vector3(1.5, 2.0, 1.5), 6.0)
		settle.tween_property(dust.material_override, "albedo_color:a", 0.0, 6.0)
		settle.chain().tween_callback(dust.queue_free)


func _build_smoke() -> void:
	_smoke_node = _cylinder(5.0, 60.0, Vector3.ZERO, Color(0.9, 0.1, 0.1, 0.7), 9.0)
	_smoke_node.visible = false


func _on_smoke_changed() -> void:
	_smoke_node.visible = not Game.smoke.is_empty()
	if _smoke_node.visible:
		_smoke_node.position = Game.world_of(Game.smoke.en, 30.0)


func _build_plane() -> void:
	_plane = Node3D.new()
	_box(Vector3(1.6, 1.6, 12.0), Vector3.ZERO, Color(0.3, 0.33, 0.3), _plane)
	_box(Vector3(14.0, 0.3, 2.6), Vector3(0, 0, -1.0), Color(0.3, 0.33, 0.3), _plane)
	_box(Vector3(5.0, 0.3, 1.4), Vector3(0, 0, 5.2), Color(0.3, 0.33, 0.3), _plane)
	_box(Vector3(0.3, 2.2, 1.6), Vector3(0, 1.1, 5.2), Color(0.3, 0.33, 0.3), _plane)
	_plane.visible = false
	add_child(_plane)


func _on_aircraft_run(aim: Vector2, heading: float, duration: float) -> void:
	var dir2 := Strike.dir_from_bearing(heading)
	_plane_dir = Game.world_of(dir2)
	_plane.position = Game.world_of(aim - dir2 * 150.0 * duration, 160.0)
	_plane.rotation = Vector3(0.0, -deg_to_rad(heading), 0.0)
	_plane_time = 0.0
	_plane_total = duration
	_plane.visible = true


# --- Mesh helpers ----------------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _box(size: Vector3, pos: Vector3, color: Color, parent: Node = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = pos
	(parent if parent != null else self).add_child(node)
	return node


## top_radius < 0 means "same as the bottom"; 0 makes a cone.
func _cylinder(radius: float, height: float, pos: Vector3, color: Color, top_radius: float = -1.0, parent: Node = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = pos
	(parent if parent != null else self).add_child(node)
	return node


func _sphere(radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = pos
	_effects.add_child(node)
	return node

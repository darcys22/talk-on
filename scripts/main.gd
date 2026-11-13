extends Node3D
## Builds the world and routes input between walking around the tower and
## the station views (scope, map, radio, teleprinter).

const STATION_MODES := ["scope", "map", "radio", "teleprinter"]

var mode := ""
var player: Player
var tower: Tower
var valley: Valley
var hud: Hud
var views: Dictionary = {}

var _last_result: Dictionary = {}


func _ready() -> void:
	_build_environment()
	valley = Valley.new()
	add_child(valley)
	tower = Tower.new()
	add_child(tower)
	player = Player.new()
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	views = {
		"title": TitleView.new(),
		"scope": ScopeView.new(),
		"map": MapView.new(),
		"radio": RadioView.new(),
		"teleprinter": TeleprinterView.new(),
		"pause": PauseView.new(),
		"debrief": DebriefView.new(),
	}
	for key: String in views:
		layer.add_child(views[key])
	# Added last so radio chatter stays readable on top of the scope mask.
	hud = Hud.new()
	layer.add_child(hud)
	(views.scope as ScopeView).camera = tower.scope_camera

	Game.mission_ended.connect(_on_mission_ended)
	Game.tower_shaken.connect(player.shake)
	set_mode("title")


func _process(_delta: float) -> void:
	hud.binoculars = mode == "walk" and player.binoculars
	hud.show_crosshair = mode == "walk" and not player.binoculars
	hud.prompt = ""
	if OS.has_feature("web") and mode in ["walk", "scope"] and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		hud.prompt = "Click to capture mouse  |  Esc to release"
	elif mode == "walk":
		var st := tower.station_in_view(player.camera)
		if not st.is_empty():
			hud.prompt = "[E]  " + str(st.prompt)


func _unhandled_input(event: InputEvent) -> void:
	# Web keyboard events are buffered; mouse capture needs a mouse press.
	if OS.has_feature("web") and mode in ["walk", "scope"]:
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
		if event is InputEventMouseMotion and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if mode == "walk":
			player.handle_mouse(event)
		elif mode == "scope":
			(views.scope as StationView).handle_mouse(event)
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	match mode:
		"title":
			if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				start_mission(0)
			elif key == KEY_ESCAPE:
				get_tree().quit()
		"walk":
			if key == KEY_E:
				_interact()
			elif key == KEY_ESCAPE:
				set_mode("pause")
		"pause":
			if key == KEY_ESCAPE:
				set_mode("walk")
			elif key == KEY_R:
				start_mission(Game.mission_index)
			elif key == KEY_Q:
				get_tree().quit()
		"debrief":
			if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_after_debrief()
		_:
			if key == KEY_ESCAPE or key == KEY_E:
				set_mode("walk")
			else:
				(views[mode] as StationView).handle_key(key, key_event)


func start_mission(index: int) -> void:
	Game.start_mission(index)
	set_mode("walk")


func set_mode(new_mode: String) -> void:
	mode = new_mode
	for key: String in views:
		var view: StationView = views[key]
		view.visible = key == mode
	if views.has(mode):
		(views[mode] as StationView).opened()
	player.active = mode == "walk"
	if mode == "scope":
		tower.scope_camera.make_current()
	else:
		player.camera.make_current()
	var captured := mode == "walk" or mode == "scope"
	if not captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.paused = mode in ["title", "pause", "debrief"]
	hud.show_log = mode == "walk" or mode == "scope"


func _interact() -> void:
	var st := tower.station_in_view(player.camera)
	if st.is_empty():
		return
	var id := str(st.id)
	if id == "launcher":
		Game.say("LAUNCHER", Game.fire_smoke())
	elif id in STATION_MODES:
		set_mode(id)


func _on_mission_ended(result: Dictionary) -> void:
	_last_result = result
	(views.debrief as DebriefView).show_result(result)
	set_mode("debrief")


func _after_debrief() -> void:
	var next := Game.mission_index
	if _last_result.get("success", false):
		next = 0 if _last_result.get("last_mission", false) else next + 1
	start_mission(next)


func _build_environment() -> void:
	var haze := Color(0.72, 0.74, 0.73)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.5, 0.6)
	sky_material.sky_horizon_color = haze
	sky_material.ground_horizon_color = haze
	sky_material.ground_bottom_color = Color(0.3, 0.33, 0.28)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = haze
	env.fog_density = 0.00022
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

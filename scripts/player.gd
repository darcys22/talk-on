class_name Player
extends Node3D
## First-person body. The room is small and has no physics: the player is
## simply kept inside the walls.

const SPEED := 2.5
const BOUND := 2.4
const EYE_HEIGHT := 1.6
const FOV_NORMAL := 70.0
const FOV_BINOCULARS := 12.0
const LOOK_SENSITIVITY := 0.0025

var camera: Camera3D
var active := false
var binoculars := false

var _pitch := 0.0
var _shake := 0.0


func _init() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.near = 0.05
	camera.far = 9000.0
	camera.fov = FOV_NORMAL
	add_child(camera)
	position = Vector3(0.0, Tower.FLOOR_Y, 1.5)


func handle_mouse(event: InputEvent) -> void:
	if not active or not (event is InputEventMouseMotion):
		return
	var motion := event as InputEventMouseMotion
	var sens := LOOK_SENSITIVITY * (camera.fov / FOV_NORMAL)
	rotation.y -= motion.relative.x * sens
	_pitch = clampf(_pitch - motion.relative.y * sens, -1.3, 1.3)
	camera.rotation.x = _pitch


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if _shake > 0.001:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.05
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.05
		_shake = lerpf(_shake, 0.0, minf(delta * 3.0, 1.0))
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	binoculars = active and (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		or Input.is_physical_key_pressed(KEY_B))
	var target_fov := FOV_BINOCULARS if binoculars else FOV_NORMAL
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 12.0, 1.0))

	if not active:
		return
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1.0
	if move != Vector3.ZERO:
		var step := (global_transform.basis * move.normalized()) * SPEED * delta
		position.x = clampf(position.x + step.x, -BOUND, BOUND)
		position.z = clampf(position.z + step.z, -BOUND, BOUND)

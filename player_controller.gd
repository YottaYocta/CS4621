extends Node3D

@export var move_speed: float = 10.0
@export var rotation_speed: float = 2.0
@export var raycast_distance: float = 100.0

# Signals for voxel editing
signal block_add_requested(global_position: Vector3, normal: Vector3)
signal block_delete_requested(global_position: Vector3, normal: Vector3)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var raycast_collision_point: Vector3
var raycast_normal: Vector3
var has_raycast_hit: bool = false
var last_click_time: float = 0.0
var click_cooldown: float = 0.2  

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var movement = Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		movement -= transform.basis.z  
	if Input.is_key_pressed(KEY_S):
		movement += transform.basis.z  

	if Input.is_key_pressed(KEY_A):
		movement -= transform.basis.x  
	if Input.is_key_pressed(KEY_D):
		movement += transform.basis.x  

	if Input.is_key_pressed(KEY_Q):
		movement.y -= 1.0  
	if Input.is_key_pressed(KEY_E):
		movement.y += 1.0  

	if movement.length() > 0:
		movement = movement.normalized()

	position += movement * move_speed * delta

	var rotation_input = 0.0
	if Input.is_key_pressed(KEY_LEFT):
		rotation_input += 1.0  
	if Input.is_key_pressed(KEY_RIGHT):
		rotation_input -= 1.0  

	rotate_y(rotation_input * rotation_speed * delta)

	_perform_raycast()

	var current_time = Time.get_ticks_msec() / 1000.0

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if has_raycast_hit and (current_time - last_click_time) > click_cooldown:
			block_add_requested.emit(raycast_collision_point, raycast_normal)
			print("Add block at: ", raycast_collision_point, " normal: ", raycast_normal)
			last_click_time = current_time

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if has_raycast_hit and (current_time - last_click_time) > click_cooldown:
			block_delete_requested.emit(raycast_collision_point, raycast_normal)
			print("Delete block at: ", raycast_collision_point, " normal: ", raycast_normal)
			last_click_time = current_time

func _perform_raycast():
	var space_state = get_world_3d().direct_space_state
	var origin = global_position
	var end = origin + (-global_transform.basis.z * raycast_distance)

	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result:
		has_raycast_hit = true
		raycast_collision_point = result.position
		raycast_normal = result.normal
	else:
		has_raycast_hit = false
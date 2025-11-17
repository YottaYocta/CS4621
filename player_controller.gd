extends Node3D

@export var move_speed: float = 10.0
@export var rotation_speed: float = 2.0
@export var raycast_distance: float = 100.0

# Signals for voxel editing
signal voxel_add_requested(global_position: Vector3)
signal voxel_delete_requested(global_position: Vector3)

var raycast_collision_point: Vector3
var has_raycast_hit: bool = false

func _process(delta: float) -> void:
	var movement = Vector3.ZERO

	# Forward/backward movement (W/S) - relative to facing direction
	if Input.is_key_pressed(KEY_W):
		movement -= transform.basis.z  # Move forward
	if Input.is_key_pressed(KEY_S):
		movement += transform.basis.z  # Move backward

	# Strafe left/right (A/D) - relative to facing direction
	if Input.is_key_pressed(KEY_A):
		movement -= transform.basis.x  # Strafe left
	if Input.is_key_pressed(KEY_D):
		movement += transform.basis.x  # Strafe right

	# Vertical movement (Q/E) - world space up/down
	if Input.is_key_pressed(KEY_Q):
		movement.y -= 1.0  # Move down
	if Input.is_key_pressed(KEY_E):
		movement.y += 1.0  # Move up

	# Normalize to prevent faster diagonal movement
	if movement.length() > 0:
		movement = movement.normalized()

	# Apply movement
	position += movement * move_speed * delta

	# Horizontal rotation (Left/Right arrows)
	var rotation_input = 0.0
	if Input.is_key_pressed(KEY_LEFT):
		rotation_input += 1.0  # Rotate left
	if Input.is_key_pressed(KEY_RIGHT):
		rotation_input -= 1.0  # Rotate right

	# Apply rotation
	rotate_y(rotation_input * rotation_speed * delta)

	# Perform raycast from player forward direction
	_perform_raycast()

	# Handle voxel editing input
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if has_raycast_hit:
			voxel_add_requested.emit(raycast_collision_point)
			print("Add voxel at: ", raycast_collision_point)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if has_raycast_hit:
			voxel_delete_requested.emit(raycast_collision_point)
			print("Delete voxel at: ", raycast_collision_point)

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
		# Log collision point
		if result.position != raycast_collision_point or not has_raycast_hit:
			print("Raycast hit at: ", result.position)
	else:
		has_raycast_hit = false
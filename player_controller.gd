extends Node3D

@export var move_speed: float = 10.0
@export var rotation_speed: float = 2.0

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
extends CharacterBody3D

@onready var armature = $Armature
@onready var springarmpivot = $SpringArmPivot
@onready var springarm = $SpringArmPivot/SpringArm3D
@onready var animationtree = $AnimationTree
@onready var camera = $SpringArmPivot/SpringArm3D/Camera3D

var camera_yaw := 0.0
var camera_pitch := 0.0
var camera_sway_time := 0.0

const CAMERA_LAG = 0.03
const SWAY_AMOUNT = 0.02
const SWAY_SPEED = 4.0
const RUN_FOV = 80.0
const IDLE_FOV = 75.0


var state_machine

const SPEED = 5.0
const LERP_VAL = 0.15

func _ready() -> void:
	state_machine = animationtree["parameters/playback"]
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

	if event is InputEventMouseMotion:
		camera_yaw -= event.relative.x * 0.005
		camera_pitch -= event.relative.y * 0.005
		camera_pitch = clamp(camera_pitch, -PI/4, PI/4)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement input
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var vertical_input := Input.get_axis("down", "up")

	# Direction relative to camera pivot
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction = direction.rotated(Vector3.UP, springarmpivot.rotation.y)

	# Horizontal movement smoothing
	if direction:
		velocity.x = lerp(velocity.x, direction.x * SPEED, LERP_VAL)
		velocity.z = lerp(velocity.z, direction.z * SPEED, LERP_VAL)

	# Rotate character to face movement direction
		armature.rotation.y = lerp_angle(
			armature.rotation.y,
			atan2(velocity.x, velocity.z),
			LERP_VAL
		)
	else:
		velocity.x = lerp(velocity.x, 0.0, LERP_VAL)
		velocity.z = lerp(velocity.z, 0.0, LERP_VAL)

	# Vertical movement (UP / DOWN keys)
	if not is_zero_approx(vertical_input):
		var target_vertical_speed := vertical_input * SPEED
		velocity.y = lerp(velocity.y, target_vertical_speed, LERP_VAL)

	# -------------------------
	# ANIMATION STATE SELECTION
	# -------------------------

	var is_moving := direction.length() > 0.01

	if is_on_floor():
		if vertical_input > 0:
			state_machine.travel("flying")
		elif is_moving:
			state_machine.travel("running")
		else:
			state_machine.travel("idle")
	else:
		# airborne
		if vertical_input > 0:
			state_machine.travel("flying")
		else:
			state_machine.travel("falling")
	
	# -------------------------
	# CAMERA DELAY + ZOOM + SWAY
	# -------------------------

	# Smooth rotation delay
	springarmpivot.rotation.y = lerp(
		springarmpivot.rotation.y,
		camera_yaw,
		CAMERA_LAG
	)

	springarm.rotation.x = lerp(
		springarm.rotation.x,
		camera_pitch,
		CAMERA_LAG
	)

	# Camera sway while running
	var is_running := direction.length() > 0.01 and is_on_floor()

	if is_running:
		camera_sway_time += delta * SWAY_SPEED
		camera.rotation.z = sin(camera_sway_time) * SWAY_AMOUNT
	else:
		# Return to neutral
		camera.rotation.z = lerp(camera.rotation.z, 0.0, 0.1)
		camera_sway_time = 0.0

	# Dynamic zoom (FOV change)
	if is_running:
		camera.fov = lerp(camera.fov, RUN_FOV, 0.1)
	else:
		camera.fov = lerp(camera.fov, IDLE_FOV, 0.1)

	
	

	move_and_slide()

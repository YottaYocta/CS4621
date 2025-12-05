extends CharacterBody3D

@onready var armature = $Armature
@onready var springarmpivot = $SPringArmPivot
@onready var springarm = $SPringArmPivot/SpringArm3D
@onready var animationtree = $AnimationTree

const SPEED = 5.0
const LERP_VAL = .15

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	if event is InputEventMouseMotion:
		springarmpivot.rotate_y(-event.relative.x * .005)
		springarm.rotate_x(-event.relative.y * .005)
		springarm.rotation.x = clamp(springarm.rotation.x, -PI/4, PI/4)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var vertical_input := Input.get_axis("down", "up")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction = direction.rotated(Vector3.UP, springarmpivot.rotation.y)
	if direction:
		velocity.x = lerp(velocity.x, direction.x * SPEED, LERP_VAL)
		velocity.z = lerp(velocity.z, direction.z * SPEED, LERP_VAL)
		armature.rotation.y = lerp_angle(armature.rotation.y, atan2(-velocity.x, -velocity.z), LERP_VAL)
	else:
		velocity.x = lerp(velocity.x, 0.0, LERP_VAL)
		velocity.z = lerp(velocity.z, 0.0, LERP_VAL)
	
	if not is_zero_approx(vertical_input):
		var target_vertical_speed := vertical_input * SPEED
		velocity.y = lerp(velocity.y, target_vertical_speed, LERP_VAL)
		
	animationtree.set("parameters/BlendSpace1D/blend_position", velocity.length() / SPEED)
	move_and_slide()

extends MeshInstance3D

@export var player_path : NodePath
@onready var player : Node3D = get_node(player_path)

@onready var mat: ShaderMaterial = material_override as ShaderMaterial

# This is the height you want clouds to stay at
@export var cloud_height := 20.0  # adjust to whatever altitude you want

func _process(delta):
	if player == null:
		return

	# Get the player's position
	var pos = player.global_transform.origin

	# Keep X and Z from the player, but lock Y to fixed cloud height
	pos.y = cloud_height

	# Send this world-space position to the shader
	mat.set_shader_parameter("cloudContainerPos", pos)

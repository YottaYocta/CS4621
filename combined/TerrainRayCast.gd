extends RayCast3D
class_name TerrainRayCast

signal block_add_requested(global_pos: Vector3, normal: Vector3)
signal block_delete_requested(global_pos: Vector3, normal: Vector3)

@export var max_raycast_distance: float = 100.0

func _ready():
	enabled = true
	target_position = Vector3(0, 0, -max_raycast_distance)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_terrain_delete()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_terrain_add()

func _handle_terrain_delete():
	if is_colliding():
		var collision_point = get_collision_point()
		var collision_normal = get_collision_normal()
		print("TerrainRayCast: Delete at ", collision_point, " normal: ", collision_normal)
		block_delete_requested.emit(collision_point, collision_normal)

func _handle_terrain_add():
	if is_colliding():
		var collision_point = get_collision_point()
		var collision_normal = get_collision_normal()
		print("TerrainRayCast: Add at ", collision_point, " normal: ", collision_normal)
		block_add_requested.emit(collision_point, collision_normal)

extends Node3D
class_name IInfiniteTerrain

## Main terrain manager responsible for:
## - Managing chunks
## - Tracking player position
## - Loading/unloading chunks based on distance

@export var chunk_size: int = 16
@export var chunk_load_radius: int = 1  # Number of chunks to load around player

var chunk_generator: IChunkGenerator
var terrain_data: InfiniteTerrainData
var active_chunks := {}
var player: Node3D = null
var last_player_chunk: Vector3i = Vector3i(-999, -999, -999)

func _ready():
	terrain_data = InfiniteTerrainData.new()
	add_child(terrain_data)

	chunk_generator = IChunkGenerator.new()
	add_child(chunk_generator)

	await get_tree().process_frame
	player = get_node_or_null("PlayerController")

	if player == null:
		print("Warning: PlayerController not found!")
		return

	# initial chunk generation
	_update_chunks()

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):  # Escape key
		get_tree().quit()

	if player == null:
		return

	# track player pos
	var current_chunk = _world_to_chunk(player.global_position)

	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		_update_chunks()

func _world_to_chunk(world_pos: Vector3) -> Vector3i:
	"""Convert world position to chunk coordinates"""
	return Vector3i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.y / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

func _update_chunks():
	"""Update which chunks should be loaded based on player position"""
	if player == null:
		return

	var player_chunk = _world_to_chunk(player.global_position)
	var chunks_to_keep := {}

	for cx in range(player_chunk.x - chunk_load_radius, player_chunk.x + chunk_load_radius + 1):
		for cz in range(player_chunk.z - chunk_load_radius, player_chunk.z + chunk_load_radius + 1):
			for cy in range(-1, 2):
				var chunk_coord = Vector3i(cx, cy, cz)
				chunks_to_keep[chunk_coord] = true

				if not active_chunks.has(chunk_coord):
					_create_chunk(chunk_coord)

	var chunks_to_remove = []
	for chunk_coord in active_chunks.keys():
		if not chunks_to_keep.has(chunk_coord):
			chunks_to_remove.append(chunk_coord)

	for chunk_coord in chunks_to_remove:
		_remove_chunk(chunk_coord)

func _create_chunk(chunk_coord: Vector3i):
	"""Create and initialize a new chunk"""
	var chunk_scene = preload("res://combined/IChunk.tscn")
	var chunk: IChunk = chunk_scene.instantiate()

	var world_pos = Vector3i(
		chunk_coord.x * chunk_size,
		chunk_coord.y * chunk_size,
		chunk_coord.z * chunk_size
	)

	chunk.initialize(world_pos, chunk_size, terrain_data)

	add_child(chunk)
	active_chunks[chunk_coord] = chunk

	var voxel_data = chunk_generator.generate_chunk_data(world_pos, chunk_size)

	chunk.voxelData = voxel_data

func _remove_chunk(chunk_coord: Vector3i):
	"""Remove and free a chunk"""
	if active_chunks.has(chunk_coord):
		var chunk = active_chunks[chunk_coord]
		active_chunks.erase(chunk_coord)
		chunk.queue_free()

func get_chunk_at(chunk_coord: Vector3i) -> IChunk:
	"""Get chunk at coordinate if it exists"""
	if active_chunks.has(chunk_coord):
		return active_chunks[chunk_coord]
	return null

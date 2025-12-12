extends Node3D
class_name InfiniteTerrain

@export var chunk_size: int = 16
@export var chunk_load_radius: int = 1  # Number of chunks to load around player
@export var chunk_gen_speed: float = 0.0  # 0 = instant generation
@export var debug: bool = false
@export var sphere_radius: float = 0.1

var terrain_data: InfiniteTerrainData
var active_chunks := {}  # Dictionary of Vector3i -> Chunk
var player: Node3D = null
var last_player_chunk: Vector3i = Vector3i(-999, -999, -999)

func _ready():
	# Create terrain data generator
	terrain_data = InfiniteTerrainData.new()
	add_child(terrain_data)

	# Find player controller
	await get_tree().process_frame  # Wait one frame to ensure player is loaded
	player = get_node_or_null("PlayerController")

	if player == null:
		print("Warning: PlayerController not found!")
		return

	# Generate initial chunks around player
	_update_chunks()

func _process(_delta):
	if player == null:
		return

	# Check if player has moved to a new chunk
	var current_chunk = _world_to_chunk(player.global_position)

	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		_update_chunks()

func _world_to_chunk(world_pos: Vector3) -> Vector3i:
	# Convert world position to chunk coordinates
	return Vector3i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.y / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

func _update_chunks():
	if player == null:
		return

	var player_chunk = _world_to_chunk(player.global_position)

	# Track which chunks should exist
	var chunks_to_keep := {}

	# Generate chunks in a radius around the player
	# Only generate chunks at y=0 for now (flat plane approach)
	for cx in range(player_chunk.x - chunk_load_radius, player_chunk.x + chunk_load_radius + 1):
		for cz in range(player_chunk.z - chunk_load_radius, player_chunk.z + chunk_load_radius + 1):
			# For infinite terrain, we'll generate chunks at y=0 and y=-1 to have terrain
			for cy in range(-1, 2):  # Generate a few vertical layers
				var chunk_coord = Vector3i(cx, cy, cz)
				chunks_to_keep[chunk_coord] = true

				# Create chunk if it doesn't exist
				if not active_chunks.has(chunk_coord):
					_create_chunk(chunk_coord)

	# Remove chunks that are too far away
	var chunks_to_remove = []
	for chunk_coord in active_chunks.keys():
		if not chunks_to_keep.has(chunk_coord):
			chunks_to_remove.append(chunk_coord)

	for chunk_coord in chunks_to_remove:
		_remove_chunk(chunk_coord)

func _create_chunk(chunk_coord: Vector3i):
	# Load chunk scene
	var chunk_scene = preload("res://TerrainExperiments/chunk.tscn")
	var chunk_instance = chunk_scene.instantiate()

	# Calculate world position
	var world_x = chunk_coord.x * chunk_size
	var world_y = chunk_coord.y * chunk_size
	var world_z = chunk_coord.z * chunk_size

	# Position chunk
	chunk_instance.position = Vector3(world_x, world_y, world_z)

	# Set chunk properties
	chunk_instance.debug = debug
	chunk_instance.sphere_radius = sphere_radius
	chunk_instance.gen_speed = chunk_gen_speed

	# Add to scene
	add_child(chunk_instance)

	# Store reference
	active_chunks[chunk_coord] = chunk_instance

	# Start rendering
	if chunk_instance.has_method("render"):
		chunk_instance.render(terrain_data, world_x, world_y, world_z, chunk_size)

func _remove_chunk(chunk_coord: Vector3i):
	if active_chunks.has(chunk_coord):
		var chunk = active_chunks[chunk_coord]
		active_chunks.erase(chunk_coord)
		chunk.queue_free()

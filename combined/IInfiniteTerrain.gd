extends Node3D
class_name IInfiniteTerrain

## Main terrain manager responsible for:
## - Managing chunks
## - Tracking player position
## - Loading/unloading chunks based on distance

@export var chunk_size: int = 16
@export var chunk_load_radius: int = 1  # Number of chunks to load around player
@export var use_compute_shader: bool = true  # Use GPU compute shader for meshing

var chunk_generator: IChunkGenerator
var terrain_data: InfiniteTerrainData
var active_chunks := {}
@export var player: Node3D = null
@export var terrain_raycast: TerrainRayCast = null
var last_player_chunk: Vector3i = Vector3i(-999, -999, -999)

func _ready():
	# Set compute shader mode
	IChunkMesher.use_compute_shader = use_compute_shader

	terrain_data = InfiniteTerrainData.new()
	add_child(terrain_data)

	chunk_generator = IChunkGenerator.new()
	add_child(chunk_generator)

	await get_tree().process_frame

	if player == null:
		print("Warning: PlayerController not found!")
		return

	# Connect to terrain raycast signals for terrain modification
	if terrain_raycast != null:
		if terrain_raycast.has_signal("block_add_requested"):
			terrain_raycast.block_add_requested.connect(_on_block_add_requested)
		if terrain_raycast.has_signal("block_delete_requested"):
			terrain_raycast.block_delete_requested.connect(_on_block_delete_requested)
		print("Connected to TerrainRayCast signals")
	else:
		print("Warning: TerrainRayCast not assigned!")

	_update_chunks()

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):  # Escape key
		get_tree().quit()

	if player == null:
		return

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

func _on_block_add_requested(global_pos: Vector3, normal: Vector3):
	"""Handle block placement with area effect"""
	print("Block add requested at: ", global_pos, " normal: ", normal)

	var offset_pos = global_pos + normal * 0.5

	var center_pos = Vector3i(
		int(floor(offset_pos.x)),
		int(floor(offset_pos.y)),
		int(floor(offset_pos.z))
	)

	var effect_radius = 3  # Affect voxels within this radius
	var center_strength = -3.0  # Strong solid value at center

	var affected_chunks_set = {}
	var modified_voxels = []  # Track all modified voxel positions

	for dx in range(-effect_radius, effect_radius + 1):
		for dy in range(-effect_radius, effect_radius + 1):
			for dz in range(-effect_radius, effect_radius + 1):
				var x = center_pos.x + dx
				var y = center_pos.y + dy
				var z = center_pos.z + dz

				var dist = Vector3(dx, dy, dz).length()

				if dist <= effect_radius:
					var falloff = 1.0 - (dist / float(effect_radius))
					falloff = clamp(falloff, 0.0, 1.0)

					# Apply modification with falloff
					var value = center_strength * falloff
					terrain_data.set_voxel(x, y, z, value)
					modified_voxels.append(Vector3i(x, y, z))

	for voxel_pos in modified_voxels:
		_add_affected_chunks(voxel_pos, affected_chunks_set)

	# Remesh all affected chunks
	for chunk_coord in affected_chunks_set.keys():
		_remesh_chunk_at(chunk_coord)

func _on_block_delete_requested(global_pos: Vector3, normal: Vector3):
	"""Handle block deletion with area effect"""
	print("Block delete requested at: ", global_pos, " normal: ", normal)

	var center_pos = Vector3i(
		int(floor(global_pos.x)),
		int(floor(global_pos.y)),
		int(floor(global_pos.z))
	)

	var effect_radius = 3  # Affect voxels within this radius
	var center_strength = 3.0  # Strong air value at center

	var affected_chunks_set = {}
	var modified_voxels = []  # Track all modified voxel positions

	for dx in range(-effect_radius, effect_radius + 1):
		for dy in range(-effect_radius, effect_radius + 1):
			for dz in range(-effect_radius, effect_radius + 1):
				var x = center_pos.x + dx
				var y = center_pos.y + dy
				var z = center_pos.z + dz

				# Calculate distance from center
				var dist = Vector3(dx, dy, dz).length()

				if dist <= effect_radius:
					# Calculate falloff
					var falloff = 1.0 - (dist / float(effect_radius))
					falloff = clamp(falloff, 0.0, 1.0)

					# Apply modification with falloff
					var value = center_strength * falloff
					terrain_data.set_voxel(x, y, z, value)
					modified_voxels.append(Vector3i(x, y, z))

	# Find all chunks affected by modifications (including neighbors for boundaries)
	for voxel_pos in modified_voxels:
		_add_affected_chunks(voxel_pos, affected_chunks_set)

	# Remesh all affected chunks
	for chunk_coord in affected_chunks_set.keys():
		_remesh_chunk_at(chunk_coord)

func _remesh_affected_chunks(voxel_pos: Vector3i):
	"""Remesh chunks affected by a voxel modification"""
	var chunk_coord = Vector3i(
		int(floor(float(voxel_pos.x) / chunk_size)),
		int(floor(float(voxel_pos.y) / chunk_size)),
		int(floor(float(voxel_pos.z) / chunk_size))
	)

	var chunks_to_remesh = {}
	chunks_to_remesh[chunk_coord] = true

	# Check if on chunk boundaries
	var local_x = voxel_pos.x - (chunk_coord.x * chunk_size)
	var local_y = voxel_pos.y - (chunk_coord.y * chunk_size)
	var local_z = voxel_pos.z - (chunk_coord.z * chunk_size)

	# If on boundary, add neighboring chunks
	if local_x == 0:
		chunks_to_remesh[chunk_coord + Vector3i(-1, 0, 0)] = true
	elif local_x == chunk_size - 1:
		chunks_to_remesh[chunk_coord + Vector3i(1, 0, 0)] = true

	if local_y == 0:
		chunks_to_remesh[chunk_coord + Vector3i(0, -1, 0)] = true
	elif local_y == chunk_size - 1:
		chunks_to_remesh[chunk_coord + Vector3i(0, 1, 0)] = true

	if local_z == 0:
		chunks_to_remesh[chunk_coord + Vector3i(0, 0, -1)] = true
	elif local_z == chunk_size - 1:
		chunks_to_remesh[chunk_coord + Vector3i(0, 0, 1)] = true

	# Trigger remesh for all affected chunks
	for coord in chunks_to_remesh.keys():
		_remesh_chunk_at(coord)

func _add_affected_chunks(voxel_pos: Vector3i, chunks_set: Dictionary):
	"""Add chunk containing voxel and neighbors if on boundary"""
	var chunk_coord = Vector3i(
		int(floor(float(voxel_pos.x) / chunk_size)),
		int(floor(float(voxel_pos.y) / chunk_size)),
		int(floor(float(voxel_pos.z) / chunk_size))
	)

	chunks_set[chunk_coord] = true

	# Check if voxel is on chunk boundaries and add neighboring chunks
	var local_x = voxel_pos.x - (chunk_coord.x * chunk_size)
	var local_y = voxel_pos.y - (chunk_coord.y * chunk_size)
	var local_z = voxel_pos.z - (chunk_coord.z * chunk_size)

	# Add neighboring chunks if on or near boundaries (within 1 voxel)
	if local_x <= 1:
		chunks_set[chunk_coord + Vector3i(-1, 0, 0)] = true
	if local_x >= chunk_size - 1:
		chunks_set[chunk_coord + Vector3i(1, 0, 0)] = true

	if local_y <= 1:
		chunks_set[chunk_coord + Vector3i(0, -1, 0)] = true
	if local_y >= chunk_size - 1:
		chunks_set[chunk_coord + Vector3i(0, 1, 0)] = true

	if local_z <= 1:
		chunks_set[chunk_coord + Vector3i(0, 0, -1)] = true
	if local_z >= chunk_size - 1:
		chunks_set[chunk_coord + Vector3i(0, 0, 1)] = true

func _remesh_chunk_at(coord: Vector3i):
	"""Remesh a single chunk by its coordinate"""
	var chunk = get_chunk_at(coord)
	if chunk != null:
		print("Remeshing chunk at: ", coord)
		var world_pos = Vector3i(
			coord.x * chunk_size,
			coord.y * chunk_size,
			coord.z * chunk_size
		)

		var voxel_data := []
		for k in range(chunk_size + 1):
			var slice := []
			for j in range(chunk_size + 1):
				var row := []
				for i in range(chunk_size + 1):
					var wx = world_pos.x + i
					var wy = world_pos.y + j
					var wz = world_pos.z + k
					row.append(terrain_data.get_voxel(wx, wy, wz))
				slice.append(row)
			voxel_data.append(slice)

		# Setting voxelData triggers automatic remesh
		chunk.voxelData = voxel_data

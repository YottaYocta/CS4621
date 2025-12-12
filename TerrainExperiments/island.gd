@tool
extends Node3D
class_name IslandData

@export var resolution: int = 32:
	set(value):
		resolution = value
		_regenerate()

@export var chunk_size: int = 8:
	set(value):
		chunk_size = value
		_regenerate()

@export var automata_iterations: int = 3:
	set(value):
		automata_iterations = value
		_regenerate()

@export var alive_threshold: int = 4:
	set(value):
		alive_threshold = value
		_regenerate()

@export var debug: bool = false:
	set(value):
		debug = value
		_regenerate()

@export var sphere_radius: float = 0.1

@export var chunk_gen_speed: float = 0.05

@export var regenerate: bool = false:
	set(value):
		if value:
			_regenerate()
			regenerate = false

var mat := []

func _clear_chunks():
	for c in get_children():
		if c is Chunk:
			c.queue_free()

func _generate_voxels():
	mat.clear()
	# Generate random voxel data [z][y][x]
	for k in range(resolution):
		var slice := []
		for j in range(resolution):
			var row := []
			for i in range(resolution):
				# Set edge voxels to empty (-1) to ensure closed mesh
				if i == 0 or i == resolution - 1 or j == 0 or j == resolution - 1 or k == 0 or k == resolution - 1:
					row.append(-1)
				else:
					row.append(randi_range(-1, 1))
			slice.append(row)
		mat.append(slice)

func _cellular_automata():
	# Create a copy to read from while writing to mat
	var old_mat = []
	for k in range(resolution):
		var slice := []
		for j in range(resolution):
			var row := []
			for i in range(resolution):
				row.append(mat[k][j][i])
			slice.append(row)
		old_mat.append(slice)

	# Apply cellular automata rule
	for k in range(resolution):
		for j in range(resolution):
			for i in range(resolution):
				# Keep edge voxels empty to ensure closed mesh
				if i == 0 or i == resolution - 1 or j == 0 or j == resolution - 1 or k == 0 or k == resolution - 1:
					mat[k][j][i] = -1
				else:
					var alive_neighbors = _count_alive_neighbors(old_mat, i, j, k)
					# Rule: if > alive_threshold neighbors alive, solid (1), else empty (-1)
					if alive_neighbors > alive_threshold:
						mat[k][j][i] = 1
					else:
						mat[k][j][i] = -1

func _count_alive_neighbors(grid: Array, x: int, y: int, z: int) -> int:
	var count = 0
	# Check all 26 neighbors (3x3x3 cube minus center)
	for dz in range(-1, 2):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0 and dz == 0:
					continue

				var nx = x + dx
				var ny = y + dy
				var nz = z + dz

				# Bounds check
				if nx >= 0 and nx < resolution and ny >= 0 and ny < resolution and nz >= 0 and nz < resolution:
					if grid[nz][ny][nx] > 0:
						count += 1
	return count

func get_voxel(x: int, y: int, z: int) -> float:
	if x >= 0 and x < resolution and y >= 0 and y < resolution and z >= 0 and z < resolution:
		return float(mat[z][y][x])
	return -1.0

func _spawn_chunks():
	var num_chunks = int(ceil(float(resolution) / float(chunk_size)))

	for cz in range(num_chunks):
		for cy in range(num_chunks):
			for cx in range(num_chunks):
				var chunk_scene = preload("res://TerrainExperiments/chunk.tscn")
				var chunk_instance = chunk_scene.instantiate()

				var start_x = cx * chunk_size
				var start_y = cy * chunk_size
				var start_z = cz * chunk_size

				# Position chunk at its world location
				chunk_instance.position = Vector3(start_x, start_y, start_z)

				# Set chunk properties
				chunk_instance.debug = debug
				chunk_instance.sphere_radius = sphere_radius
				chunk_instance.gen_speed = chunk_gen_speed

				add_child(chunk_instance)

				# Call render on the chunk
				if chunk_instance.has_method("render"):
					chunk_instance.render(self, start_x, start_y, start_z, chunk_size)

func _regenerate():
	if not is_inside_tree():
		return

	_clear_chunks()
	_generate_voxels()

	# Run cellular automata multiple times
	for i in range(automata_iterations):
		_cellular_automata()

	_spawn_chunks()

func _ready():
	_regenerate()

	# Connect to player voxel editing signals
	_connect_player_signals()

func _connect_player_signals():
	# Find the player controller in the scene
	var player = get_node_or_null("PlayerController")
	if player and player.has_signal("voxel_add_requested"):
		player.voxel_add_requested.connect(_on_voxel_add_requested)
		player.voxel_delete_requested.connect(_on_voxel_delete_requested)
		print("Connected to player voxel editing signals")

func _on_voxel_add_requested(global_pos: Vector3):
	print("Island received add request at: ", global_pos)
	_modify_voxels_at_position(global_pos, 1)

func _on_voxel_delete_requested(global_pos: Vector3):
	print("Island received delete request at: ", global_pos)
	_modify_voxels_at_position(global_pos, -1)

func _modify_voxels_at_position(global_pos: Vector3, value: int):
	# Convert global position to voxel coordinates
	var voxel_x = int(round(global_pos.x))
	var voxel_y = int(round(global_pos.y))
	var voxel_z = int(round(global_pos.z))

	print("Modifying voxel at: [", voxel_x, ", ", voxel_y, ", ", voxel_z, "] to value: ", value)

	# Track which chunks need remeshing
	var affected_chunks = {}

	# Modify the voxel and neighboring voxels for a brush-like effect
	var brush_radius = 1
	for dz in range(-brush_radius, brush_radius + 1):
		for dy in range(-brush_radius, brush_radius + 1):
			for dx in range(-brush_radius, brush_radius + 1):
				var x = voxel_x + dx
				var y = voxel_y + dy
				var z = voxel_z + dz

				# Check if within bounds
				if x >= 0 and x < resolution and y >= 0 and y < resolution and z >= 0 and z < resolution:
					# Don't modify edge voxels
					if x > 0 and x < resolution - 1 and y > 0 and y < resolution - 1 and z > 0 and z < resolution - 1:
						mat[z][y][x] = value

						# Calculate which chunk this voxel belongs to
						var chunk_x = int(x / chunk_size)
						var chunk_y = int(y / chunk_size)
						var chunk_z = int(z / chunk_size)
						var chunk_key = Vector3i(chunk_x, chunk_y, chunk_z)
						affected_chunks[chunk_key] = true

	# Expand to include neighboring chunks of affected chunks
	var chunks_to_remesh = {}
	for chunk_key in affected_chunks.keys():
		# Add the directly affected chunk
		chunks_to_remesh[chunk_key] = true

		# Add all 26 neighboring chunks
		for dz in range(-1, 2):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var neighbor_chunk = Vector3i(chunk_key.x + dx, chunk_key.y + dy, chunk_key.z + dz)
					# Check if neighboring chunk is within valid range
					var num_chunks = int(ceil(float(resolution) / float(chunk_size)))
					if neighbor_chunk.x >= 0 and neighbor_chunk.x < num_chunks and \
					   neighbor_chunk.y >= 0 and neighbor_chunk.y < num_chunks and \
					   neighbor_chunk.z >= 0 and neighbor_chunk.z < num_chunks:
						chunks_to_remesh[neighbor_chunk] = true

	# Remesh all affected chunks and their neighbors
	print("Remeshing ", chunks_to_remesh.size(), " chunks (", affected_chunks.size(), " directly affected + neighbors)")
	for chunk_key in chunks_to_remesh.keys():
		_remesh_chunk(chunk_key.x, chunk_key.y, chunk_key.z)

func _remesh_chunk(chunk_x: int, chunk_y: int, chunk_z: int):
	# Find and remesh the specific chunk
	for child in get_children():
		if child is Chunk:
			var expected_pos = Vector3(chunk_x * chunk_size, chunk_y * chunk_size, chunk_z * chunk_size)
			if child.position == expected_pos:
				print("Remeshing chunk at: ", expected_pos)
				# Clear the chunk's children and re-render
				for c in child.get_children():
					c.queue_free()
				# Re-render the chunk
				child.render(self, chunk_x * chunk_size, chunk_y * chunk_size, chunk_z * chunk_size, chunk_size)
				break

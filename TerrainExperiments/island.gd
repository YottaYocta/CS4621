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

func get_voxel(x: int, y: int, z: int) -> int:
	if x >= 0 and x < resolution and y >= 0 and y < resolution and z >= 0 and z < resolution:
		return mat[z][y][x]
	return -1

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

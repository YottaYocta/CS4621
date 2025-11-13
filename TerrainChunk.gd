extends MeshInstance3D
class_name TerrainChunk

## Individual terrain chunk that generates its mesh using marching cubes

var chunk_position: Vector3i
var chunk_size: int
var voxel_size: float
var terrain_params: Dictionary

func initialize(pos: Vector3i, size: int, voxel_sz: float, params: Dictionary):
	"""Initialize the chunk with its parameters"""
	chunk_position = pos
	chunk_size = size
	voxel_size = voxel_sz
	terrain_params = params

func generate():
	"""Generate the chunk's mesh using marching cubes"""
	var voxels = _generate_voxel_data()
	var mesh_data = CubeMarcher.march_cubes(voxels, chunk_size, voxel_size)

	if mesh_data["vertices"].size() > 0:
		_create_mesh(mesh_data)
	else:
		# Chunk is completely empty or full
		queue_free()

func _generate_voxel_data() -> PackedInt32Array:
	"""Generate voxel data based on noise and terrain parameters"""
	var voxels = PackedInt32Array()
	var total_voxels = chunk_size * chunk_size * chunk_size
	voxels.resize(total_voxels)

	var world_offset = chunk_position * chunk_size

	# Get terrain parameters
	var terrain_type = terrain_params.get("terrain_type", "hills")
	var noise_scale = terrain_params.get("noise_scale", 50.0)
	var height_multiplier = terrain_params.get("height_multiplier", 30.0)
	var seed_value = terrain_params.get("seed", 0)
	var surface_level = terrain_params.get("surface_level", 0.5)

	match terrain_type:
		"flat":
			_generate_flat_terrain(voxels, world_offset, surface_level)
		"hills":
			_generate_hills(voxels, world_offset, noise_scale, height_multiplier, seed_value, surface_level)
		"mountains":
			_generate_mountains(voxels, world_offset, noise_scale, height_multiplier, seed_value, surface_level)
		"caves":
			_generate_caves(voxels, world_offset, noise_scale, height_multiplier, seed_value, surface_level)
		"islands":
			_generate_islands(voxels, world_offset, noise_scale, height_multiplier, seed_value, surface_level)

	return voxels

func _generate_flat_terrain(voxels: PackedInt32Array, world_offset: Vector3i, surface_level: float):
	"""Generate simple flat terrain"""
	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var index = x + chunk_size * y + chunk_size * chunk_size * z
				var world_y = world_offset.y + y

				# Simple height threshold
				voxels[index] = 1 if world_y < (chunk_size * surface_level) else 0

func _generate_hills(voxels: PackedInt32Array, world_offset: Vector3i,
					 noise_scale: float, height_mult: float, seed_val: int, surface_level: float):
	"""Generate rolling hills terrain"""
	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var index = x + chunk_size * y + chunk_size * chunk_size * z

				var world_x = world_offset.x + x
				var world_y = world_offset.y + y
				var world_z = world_offset.z + z

				# Get height from 2D noise
				var height = NoiseGenerator.generate_height_map(
					world_x, world_z,
					4, 0.5, 2.0,
					noise_scale, seed_val,
					height_mult, height_mult * surface_level
				)

				# Voxel is solid if below the height
				voxels[index] = 1 if world_y < height else 0

func _generate_mountains(voxels: PackedInt32Array, world_offset: Vector3i,
						 noise_scale: float, height_mult: float, seed_val: int, surface_level: float):
	"""Generate mountainous terrain with steeper features"""
	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var index = x + chunk_size * y + chunk_size * chunk_size * z

				var world_x = world_offset.x + x
				var world_y = world_offset.y + y
				var world_z = world_offset.z + z

				# Use more octaves and exponential scaling for mountains
				var height = NoiseGenerator.generate_height_map(
					world_x, world_z,
					6, 0.6, 2.0,
					noise_scale, seed_val,
					height_mult * 1.5, height_mult * surface_level
				)

				# Apply exponential curve for steeper peaks
				var height_factor = NoiseGenerator.generate_noise_3d(
					world_x, 0, world_z, 2, 0.5, 2.0, noise_scale * 2.0, seed_val + 100
				)
				height = height + (height_factor * height_factor * height_mult * 0.5)

				voxels[index] = 1 if world_y < height else 0

func _generate_caves(voxels: PackedInt32Array, world_offset: Vector3i,
					 noise_scale: float, height_mult: float, seed_val: int, surface_level: float):
	"""Generate terrain with cave systems"""
	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var index = x + chunk_size * y + chunk_size * chunk_size * z

				var world_x = world_offset.x + x
				var world_y = world_offset.y + y
				var world_z = world_offset.z + z

				# Get density using 3D noise
				var density = NoiseGenerator.get_density(
					world_x, world_y, world_z,
					noise_scale, height_mult,
					noise_scale * 0.5, seed_val
				)

				voxels[index] = 1 if density > surface_level else 0

func _generate_islands(voxels: PackedInt32Array, world_offset: Vector3i,
					   noise_scale: float, height_mult: float, seed_val: int, surface_level: float):
	"""Generate floating islands terrain"""
	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var index = x + chunk_size * y + chunk_size * chunk_size * z

				var world_x = world_offset.x + x
				var world_y = world_offset.y + y
				var world_z = world_offset.z + z

				# Multiple layers of 3D noise for floating effect
				var density1 = NoiseGenerator.generate_noise_3d(
					world_x, world_y, world_z,
					3, 0.5, 2.0, noise_scale * 0.8, seed_val
				)

				var density2 = NoiseGenerator.generate_noise_3d(
					world_x, world_y * 0.5, world_z,
					2, 0.5, 2.0, noise_scale * 1.5, seed_val + 500
				)

				# Combine for floating island effect
				var final_density = (density1 + density2 * 0.5) / 1.5

				voxels[index] = 1 if final_density > surface_level else 0

func _create_mesh(mesh_data: Dictionary):
	"""Create the actual mesh from marching cubes data"""
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices = mesh_data["vertices"]
	var triangles = mesh_data["triangles"]

	# Offset vertices by chunk position
	var offset = Vector3(chunk_position) * chunk_size * voxel_size
	for i in range(vertices.size()):
		vertices[i] += offset

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = triangles

	# Calculate normals for proper lighting
	var normals = _calculate_normals(vertices, triangles)
	arrays[Mesh.ARRAY_NORMAL] = normals

	# Add mesh surface
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Assign mesh to this MeshInstance3D
	mesh = arr_mesh

	# Apply material
	_apply_material()

func _calculate_normals(vertices: PackedVector3Array, triangles: PackedInt32Array) -> PackedVector3Array:
	"""Calculate smooth vertex normals"""
	var normals = PackedVector3Array()
	normals.resize(vertices.size())

	# Calculate face normals and accumulate
	for i in range(0, triangles.size(), 3):
		var idx0 = triangles[i]
		var idx1 = triangles[i + 1]
		var idx2 = triangles[i + 2]

		var v0 = vertices[idx0]
		var v1 = vertices[idx1]
		var v2 = vertices[idx2]

		var edge1 = v1 - v0
		var edge2 = v2 - v0
		var normal = edge1.cross(edge2).normalized()

		normals[idx0] += normal
		normals[idx1] += normal
		normals[idx2] += normal

	# Normalize all vertex normals
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	return normals

func _apply_material():
	"""Apply material to the mesh"""
	var material = StandardMaterial3D.new()

	# Terrain-like colors
	material.albedo_color = Color(0.3, 0.5, 0.2)  # Grassy green
	material.metallic = 0.0
	material.roughness = 0.9

	# Enable double-sided rendering for visibility from both sides
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Enable ambient occlusion for better depth perception
	material.ao_enabled = true

	set_surface_override_material(0, material)

@tool
extends Node3D
class_name Chunk

@export var gen_speed: float = 0.05
@export var debug: bool = false
@export var sphere_radius: float = 0.1

var island_data: IslandData = null
var chunk_start_x: int = 0
var chunk_start_y: int = 0
var chunk_start_z: int = 0
var chunk_size: int = 8
var mat := []

func render(island: IslandData, x: int, y: int, z: int, size: int):
	island_data = island
	chunk_start_x = x
	chunk_start_y = y
	chunk_start_z = z
	chunk_size = size

	# Extract chunk's portion of the voxel data
	_extract_chunk_data()

	# Render debug spheres if enabled
	if debug:
		_spawn_debug_spheres()

	# Start marching cubes rendering
	_cpu_cube_march()

func _extract_chunk_data():
	mat.clear()

	# Extract voxel data for this chunk from the island
	# +1 to include boundary voxels needed for marching cubes
	for k in range(chunk_size + 1):
		var slice := []
		for j in range(chunk_size + 1):
			var row := []
			for i in range(chunk_size + 1):
				var world_x = chunk_start_x + i
				var world_y = chunk_start_y + j
				var world_z = chunk_start_z + k
				# get_voxel returns -1 for out-of-bounds, which is fine
				row.append(island_data.get_voxel(world_x, world_y, world_z))
			slice.append(row)
		mat.append(slice)

func _spawn_debug_spheres():
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = sphere_radius
	sphere_mesh.height = sphere_radius * 2

	for k in range(chunk_size + 1):
		for j in range(chunk_size + 1):
			for i in range(chunk_size + 1):
				var value = mat[k][j][i]
				var inst := MeshInstance3D.new()
				inst.mesh = sphere_mesh

				var grayscale := float(value + 1) / 2.0
				var material := StandardMaterial3D.new()
				material.albedo_color = Color(grayscale, grayscale, grayscale)
				inst.material_override = material

				# Position relative to chunk (local coordinates)
				inst.position = Vector3(i, j, k)
				add_child(inst)

func _calculate_normal_at_position(x: float, y: float, z: float) -> Vector3:
	# Calculate normal using gradient of the density field from island data
	# Convert local chunk coordinates to world coordinates
	var world_x = x + chunk_start_x
	var world_y = y + chunk_start_y
	var world_z = z + chunk_start_z

	var dx = _sample_field_world(world_x + 0.1, world_y, world_z) - _sample_field_world(world_x - 0.1, world_y, world_z)
	var dy = _sample_field_world(world_x, world_y + 0.1, world_z) - _sample_field_world(world_x, world_y - 0.1, world_z)
	var dz = _sample_field_world(world_x, world_y, world_z + 0.1) - _sample_field_world(world_x, world_y, world_z - 0.1)

	var gradient = Vector3(dx, dy, dz)
	if gradient.length() > 0.0001:
		return -gradient.normalized()
	return Vector3.UP

func _sample_field_world(x: float, y: float, z: float) -> float:
	# Sample directly from island data using world coordinates
	var xi = int(floor(x))
	var yi = int(floor(y))
	var zi = int(floor(z))

	# Get the 8 surrounding voxel values from island
	var fx = x - xi
	var fy = y - yi
	var fz = z - zi

	var c000 = float(island_data.get_voxel(xi, yi, zi))
	var c100 = float(island_data.get_voxel(xi + 1, yi, zi))
	var c010 = float(island_data.get_voxel(xi, yi + 1, zi))
	var c110 = float(island_data.get_voxel(xi + 1, yi + 1, zi))
	var c001 = float(island_data.get_voxel(xi, yi, zi + 1))
	var c101 = float(island_data.get_voxel(xi + 1, yi, zi + 1))
	var c011 = float(island_data.get_voxel(xi, yi + 1, zi + 1))
	var c111 = float(island_data.get_voxel(xi + 1, yi + 1, zi + 1))

	# Trilinear interpolation
	var c00 = c000 * (1 - fx) + c100 * fx
	var c01 = c001 * (1 - fx) + c101 * fx
	var c10 = c010 * (1 - fx) + c110 * fx
	var c11 = c011 * (1 - fx) + c111 * fx

	var c0 = c00 * (1 - fy) + c10 * fy
	var c1 = c01 * (1 - fy) + c11 * fy

	return c0 * (1 - fz) + c1 * fz

func _process_single_cube(mesh_instance: MeshInstance3D, i: int, j: int, k: int):
	# Get the 8 corner values of the cube
	var cube_values = []
	cube_values.append(mat[k][j][i])
	cube_values.append(mat[k][j][i + 1])
	cube_values.append(mat[k][j + 1][i + 1])
	cube_values.append(mat[k][j + 1][i])
	cube_values.append(mat[k + 1][j][i])
	cube_values.append(mat[k + 1][j][i + 1])
	cube_values.append(mat[k + 1][j + 1][i + 1])
	cube_values.append(mat[k + 1][j + 1][i])

	# Calculate the cube index (0-255) based on which corners are solid
	var cube_index = 0
	for idx in range(8):
		if cube_values[idx] > 0:
			cube_index |= (1 << idx)

	# Skip if cube is completely inside or outside
	if cube_index == 0 or cube_index == 255:
		return

	# Get the edge configuration
	var edge_flags = CubeMarcher.EDGE_TABLE[cube_index]

	# Calculate vertex positions on edges
	var edge_vertices = []
	for idx in range(12):
		edge_vertices.append(Vector3.ZERO)

	var voxel_size = 1.0

	if edge_flags & 1:
		edge_vertices[0] = _interpolate_vertex(i, j, k, i + 1, j, k, cube_values[0], cube_values[1], voxel_size)
	if edge_flags & 2:
		edge_vertices[1] = _interpolate_vertex(i + 1, j, k, i + 1, j + 1, k, cube_values[1], cube_values[2], voxel_size)
	if edge_flags & 4:
		edge_vertices[2] = _interpolate_vertex(i + 1, j + 1, k, i, j + 1, k, cube_values[2], cube_values[3], voxel_size)
	if edge_flags & 8:
		edge_vertices[3] = _interpolate_vertex(i, j, k, i, j + 1, k, cube_values[0], cube_values[3], voxel_size)
	if edge_flags & 16:
		edge_vertices[4] = _interpolate_vertex(i, j, k + 1, i + 1, j, k + 1, cube_values[4], cube_values[5], voxel_size)
	if edge_flags & 32:
		edge_vertices[5] = _interpolate_vertex(i + 1, j, k + 1, i + 1, j + 1, k + 1, cube_values[5], cube_values[6], voxel_size)
	if edge_flags & 64:
		edge_vertices[6] = _interpolate_vertex(i + 1, j + 1, k + 1, i, j + 1, k + 1, cube_values[6], cube_values[7], voxel_size)
	if edge_flags & 128:
		edge_vertices[7] = _interpolate_vertex(i, j, k + 1, i, j + 1, k + 1, cube_values[4], cube_values[7], voxel_size)
	if edge_flags & 256:
		edge_vertices[8] = _interpolate_vertex(i, j, k, i, j, k + 1, cube_values[0], cube_values[4], voxel_size)
	if edge_flags & 512:
		edge_vertices[9] = _interpolate_vertex(i + 1, j, k, i + 1, j, k + 1, cube_values[1], cube_values[5], voxel_size)
	if edge_flags & 1024:
		edge_vertices[10] = _interpolate_vertex(i + 1, j + 1, k, i + 1, j + 1, k + 1, cube_values[2], cube_values[6], voxel_size)
	if edge_flags & 2048:
		edge_vertices[11] = _interpolate_vertex(i, j + 1, k, i, j + 1, k + 1, cube_values[3], cube_values[7], voxel_size)

	var tri_list = CubeMarcher.TRI_TABLE[cube_index]

	var array_mesh: ArrayMesh
	if mesh_instance.mesh == null:
		array_mesh = ArrayMesh.new()
		mesh_instance.mesh = array_mesh
	else:
		array_mesh = mesh_instance.mesh as ArrayMesh

	var vertices = []
	var triangles = []
	var normals = []

	if array_mesh.get_surface_count() > 0:
		var existing_arrays = array_mesh.surface_get_arrays(0)
		vertices = Array(existing_arrays[Mesh.ARRAY_VERTEX])
		triangles = Array(existing_arrays[Mesh.ARRAY_INDEX])
		if existing_arrays[Mesh.ARRAY_NORMAL] != null:
			normals = Array(existing_arrays[Mesh.ARRAY_NORMAL])
		array_mesh.clear_surfaces()

	for idx in range(0, tri_list.size(), 3):
		if idx + 2 < tri_list.size():
			var v1 = edge_vertices[tri_list[idx]]
			var v2 = edge_vertices[tri_list[idx + 1]]
			var v3 = edge_vertices[tri_list[idx + 2]]

			# Calculate smooth normals using gradient at each vertex position
			var n1 = _calculate_normal_at_position(v1.x, v1.y, v1.z)
			var n2 = _calculate_normal_at_position(v2.x, v2.y, v2.z)
			var n3 = _calculate_normal_at_position(v3.x, v3.y, v3.z)

			var base_idx = vertices.size()
			vertices.append(v1)
			vertices.append(v2)
			vertices.append(v3)
			normals.append(n1)
			normals.append(n2)
			normals.append(n3)
			triangles.append(base_idx)
			triangles.append(base_idx + 1)
			triangles.append(base_idx + 2)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(triangles)
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _interpolate_vertex(x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, val1: int, val2: int, voxel_size: float) -> Vector3:
	# Simple interpolation between two vertices
	var p1 = Vector3(x1, y1, z1) * voxel_size
	var p2 = Vector3(x2, y2, z2) * voxel_size

	# If values are the same or one is zero, return midpoint
	if abs(val1 - val2) < 0.00001:
		return (p1 + p2) * 0.5

	# Linear interpolation at the isosurface (threshold of 0.5)
	var threshold = 0.5
	var t = (threshold - val1) / float(val2 - val1)
	t = clamp(t, 0.0, 1.0)

	return p1.lerp(p2, t)

func _cpu_cube_march():
	var newMeshInstance := MeshInstance3D.new()

	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.5, 0.7, 0.9)
	newMeshInstance.material_override = material

	add_child(newMeshInstance)

	for k in range(chunk_size):
		for j in range(chunk_size):
			for i in range(chunk_size):
				_process_single_cube(newMeshInstance, i, j, k)
				var tree := get_tree()
				if tree != null && gen_speed > 0:
					await get_tree().create_timer(gen_speed).timeout

	# Create collision mesh after rendering is complete
	_create_collision_mesh(newMeshInstance)

func _create_collision_mesh(mesh_instance: MeshInstance3D):
	if mesh_instance.mesh == null:
		return

	# Create StaticBody3D for collision
	var static_body := StaticBody3D.new()
	static_body.name = "CollisionBody"
	add_child(static_body)

	# Create CollisionShape3D
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	static_body.add_child(collision_shape)

	# Create ConcavePolygonShape3D from the mesh
	var shape := ConcavePolygonShape3D.new()
	var mesh_arrays = mesh_instance.mesh.surface_get_arrays(0)
	var vertices = mesh_arrays[Mesh.ARRAY_VERTEX]
	var indices = mesh_arrays[Mesh.ARRAY_INDEX]

	# Build faces array for ConcavePolygonShape3D
	var faces := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		if i + 2 < indices.size():
			faces.append(vertices[indices[i]])
			faces.append(vertices[indices[i + 1]])
			faces.append(vertices[indices[i + 2]])

	shape.set_faces(faces)
	collision_shape.shape = shape

	# Connect to body_entered signal to detect collisions
	if static_body.has_signal("body_entered"):
		static_body.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	# Log collision when something enters the chunk collision
	print("Collision detected in chunk at position ", position)
	print("  Body: ", body.name)
	print("  Body position: ", body.global_position)

	# If the body is a CharacterBody3D or RigidBody3D, we can get more info
	if body is CharacterBody3D:
		print("  CharacterBody velocity: ", body.velocity)
	elif body is RigidBody3D:
		print("  RigidBody linear velocity: ", body.linear_velocity)

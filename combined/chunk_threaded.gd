extends Node3D
class_name ChunkThreaded

@export var gen_speed: float = 0.0  # For threaded, we ignore this
@export var debug: bool = false
@export var sphere_radius: float = 0.1

var island_data: IslandData = null
var chunk_start_x: int = 0
var chunk_start_y: int = 0
var chunk_start_z: int = 0
var chunk_size: int = 8
var mat := []

var is_generating := false
var generation_thread: Thread = null
var mesh_data: Dictionary = {}
var mesh_ready := false

func render(island: IslandData, x: int, y: int, z: int, size: int):
	island_data = island
	chunk_start_x = x
	chunk_start_y = y
	chunk_start_z = z
	chunk_size = size

	# Start generation in a thread
	is_generating = true
	generation_thread = Thread.new()
	generation_thread.start(_threaded_generate)

func _threaded_generate():
	_extract_chunk_data()

	var vertices = []
	var normals = []
	var indices = []

	for k in range(chunk_size):
		for j in range(chunk_size):
			for i in range(chunk_size):
				_process_single_cube(vertices, normals, indices, i, j, k)

	mesh_data = {
		"vertices": PackedVector3Array(vertices),
		"normals": PackedVector3Array(normals),
		"indices": PackedInt32Array(indices)
	}

	mesh_ready = true

func _process(delta):
	if mesh_ready and generation_thread != null:
		# Join the thread
		generation_thread.wait_to_finish()
		generation_thread = null

		# Create the mesh on the main thread
		_create_mesh_from_data()

		mesh_ready = false
		is_generating = false

func _create_mesh_from_data():
	if mesh_data.is_empty():
		return

	var mesh_instance := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()

	if mesh_data.vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = mesh_data.vertices
		arrays[Mesh.ARRAY_NORMAL] = mesh_data.normals
		arrays[Mesh.ARRAY_INDEX] = mesh_data.indices

		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var material := StandardMaterial3D.new()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.5, 0.7, 0.9)
		mesh_instance.material_override = material
		mesh_instance.mesh = array_mesh

		add_child(mesh_instance)

		# Create collision
		_create_collision_mesh(mesh_instance)

	mesh_data.clear()

func _extract_chunk_data():
	mat.clear()

	# Extract voxel data for this chunk from the island
	for k in range(chunk_size + 1):
		var slice := []
		for j in range(chunk_size + 1):
			var row := []
			for i in range(chunk_size + 1):
				var world_x = chunk_start_x + i
				var world_y = chunk_start_y + j
				var world_z = chunk_start_z + k
				row.append(island_data.get_voxel(world_x, world_y, world_z))
			slice.append(row)
		mat.append(slice)

func _calculate_normal_at_position(x: float, y: float, z: float) -> Vector3:
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
	var xi = int(floor(x))
	var yi = int(floor(y))
	var zi = int(floor(z))

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

func _process_single_cube(vertices: Array, normals: Array, indices: Array, i: int, j: int, k: int):
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

	# Calculate the cube index
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

	for idx in range(0, tri_list.size(), 3):
		if idx + 2 < tri_list.size():
			var v1 = edge_vertices[tri_list[idx]]
			var v2 = edge_vertices[tri_list[idx + 1]]
			var v3 = edge_vertices[tri_list[idx + 2]]

			# Calculate smooth normals
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
			indices.append(base_idx)
			indices.append(base_idx + 1)
			indices.append(base_idx + 2)

func _interpolate_vertex(x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, val1: int, val2: int, voxel_size: float) -> Vector3:
	var p1 = Vector3(x1, y1, z1) * voxel_size
	var p2 = Vector3(x2, y2, z2) * voxel_size

	if abs(val1 - val2) < 0.00001:
		return (p1 + p2) * 0.5

	var threshold = 0.5
	var t = (threshold - val1) / float(val2 - val1)
	t = clamp(t, 0.0, 1.0)

	return p1.lerp(p2, t)

func _create_collision_mesh(mesh_instance: MeshInstance3D):
	if mesh_instance.mesh == null:
		return

	var static_body := StaticBody3D.new()
	static_body.name = "CollisionBody"
	add_child(static_body)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	static_body.add_child(collision_shape)

	var shape := ConcavePolygonShape3D.new()
	var mesh_arrays = mesh_instance.mesh.surface_get_arrays(0)
	var vertices_arr = mesh_arrays[Mesh.ARRAY_VERTEX]
	var indices_arr = mesh_arrays[Mesh.ARRAY_INDEX]

	var faces := PackedVector3Array()
	for idx in range(0, indices_arr.size(), 3):
		if idx + 2 < indices_arr.size():
			faces.append(vertices_arr[indices_arr[idx]])
			faces.append(vertices_arr[indices_arr[idx + 1]])
			faces.append(vertices_arr[indices_arr[idx + 2]])

	shape.set_faces(faces)
	collision_shape.shape = shape

func _exit_tree():
	# Clean up thread if still running
	if generation_thread != null and generation_thread.is_alive():
		generation_thread.wait_to_finish()

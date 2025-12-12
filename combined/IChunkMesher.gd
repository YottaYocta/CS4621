extends Node
class_name IChunkMesher

## Static/Global mesher that converts voxel data to mesh geometry

static var active_jobs := {}
static var job_id_counter := 0

class MeshJob:
	var id: int
	var voxel_data: Array
	var chunk_size: int
	var chunk_start: Vector3i
	var island_data: IslandData
	var thread: Thread
	var complete := false
	var result: Dictionary = {}

# CPU async mesh gen
static func request_mesh_async(voxel_data: Array, chunk_size: int, chunk_start: Vector3i, island_data: IslandData, callback: Callable) -> int:
	var job = MeshJob.new()
	job.id = job_id_counter
	job_id_counter += 1
	job.voxel_data = voxel_data
	job.chunk_size = chunk_size
	job.chunk_start = chunk_start
	job.island_data = island_data
	job.thread = Thread.new()

	active_jobs[job.id] = job

	job.thread.start(func(): _generate_mesh_threaded(job, callback))

	return job.id

static func _generate_mesh_threaded(job: MeshJob, callback: Callable):
	var vertices := []
	var normals := []
	var indices := []

	for k in range(job.chunk_size):
		for j in range(job.chunk_size):
			for i in range(job.chunk_size):
				_process_cube(vertices, normals, indices, i, j, k, job.voxel_data, job.chunk_start, job.island_data)

	job.result = {
		"vertices": PackedVector3Array(vertices),
		"normals": PackedVector3Array(normals),
		"indices": PackedInt32Array(indices)
	}
	job.complete = true

	callback.call_deferred(job.result)

static func _process_cube(vertices: Array, normals: Array, indices: Array, i: int, j: int, k: int, voxel_data: Array, chunk_start: Vector3i, island_data: IslandData):
	# Get 8 corner values
	var cube_values = []
	cube_values.append(voxel_data[k][j][i])
	cube_values.append(voxel_data[k][j][i + 1])
	cube_values.append(voxel_data[k][j + 1][i + 1])
	cube_values.append(voxel_data[k][j + 1][i])
	cube_values.append(voxel_data[k + 1][j][i])
	cube_values.append(voxel_data[k + 1][j][i + 1])
	cube_values.append(voxel_data[k + 1][j + 1][i + 1])
	cube_values.append(voxel_data[k + 1][j + 1][i])

	# Calculate cube index using 0 as threshold (negative = solid, positive = air)
	var cube_index = 0
	for idx in range(8):
		if cube_values[idx] < 0:  
			# keep track of index; 
			cube_index |= (1 << idx) 

	# kip empty/full cubes
	if cube_index == 0 or cube_index == 255:
		return

	var edge_flags = CubeMarcher.EDGE_TABLE[cube_index]

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

			# Calculate face normal from triangle geometry
			var edge1 = v2 - v1
			var edge2 = v3 - v1
			var face_normal = -edge1.cross(edge2).normalized()  # Negated to flip

			# Use face normal for all vertices (flat shading)
			# This gives consistent lighting without artifacts
			var n1 = face_normal
			var n2 = face_normal
			var n3 = face_normal

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

static func _interpolate_vertex(x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, val1: float, val2: float, voxel_size: float) -> Vector3:
	var p1 = Vector3(x1, y1, z1) * voxel_size
	var p2 = Vector3(x2, y2, z2) * voxel_size

	#linear interpolation to find zero crossing 
	if abs(val1 - val2) < 0.00001:
		return (p1 + p2) * 0.5

	var t = -val1 / (val2 - val1)
	t = clamp(t, 0.0, 1.0)

	return p1.lerp(p2, t)

static func _calculate_normal_at_position(pos: Vector3, chunk_start: Vector3i, island_data: IslandData) -> Vector3:
	var world_pos = pos + Vector3(chunk_start)

	var dx = _sample_field(world_pos + Vector3(0.1, 0, 0), island_data) - _sample_field(world_pos - Vector3(0.1, 0, 0), island_data)
	var dy = _sample_field(world_pos + Vector3(0, 0.1, 0), island_data) - _sample_field(world_pos - Vector3(0, 0.1, 0), island_data)
	var dz = _sample_field(world_pos + Vector3(0, 0, 0.1), island_data) - _sample_field(world_pos - Vector3(0, 0, 0.1), island_data)

	var gradient = Vector3(dx, dy, dz)
	if gradient.length() > 0.0001:
		return -gradient.normalized()
	return Vector3.UP

static func _sample_field(pos: Vector3, island_data: IslandData) -> float:
	var xi = int(floor(pos.x))
	var yi = int(floor(pos.y))
	var zi = int(floor(pos.z))

	var fx = pos.x - xi
	var fy = pos.y - yi
	var fz = pos.z - zi

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

static func cleanup_job(job_id: int):
	if active_jobs.has(job_id):
		var job = active_jobs[job_id]
		if job.thread != null and job.thread.is_alive():
			job.thread.wait_to_finish()
		active_jobs.erase(job_id)

extends Node3D
class_name IChunk

## Chunk class that stores voxel data and mesh data
## Setting voxelData triggers remeshing, setting meshData renders the mesh

var _voxel_data: Array = []
var _mesh_data: Dictionary = {}
var _chunk_size: int = 16
var _chunk_position: Vector3i = Vector3i.ZERO
var _terrain_data: IslandData = null

var _mesh_instance: MeshInstance3D = null
var _collision_body: StaticBody3D = null
var _is_meshing := false
var _mesh_job_id := -1

## Voxel data property - setting this triggers remeshing
var voxelData: Array:
	get:
		return _voxel_data
	set(value):
		_voxel_data = value
		if not _voxel_data.is_empty():
			request_remesh()

## Mesh data property - setting this renders the mesh
var meshData: Dictionary:
	get:
		return _mesh_data
	set(value):
		_mesh_data = value
		if not _mesh_data.is_empty():
			_render_mesh()

## Initialize chunk with position and size
func initialize(chunk_pos: Vector3i, chunk_size: int, terrain_data: IslandData):
	_chunk_position = chunk_pos
	_chunk_size = chunk_size
	_terrain_data = terrain_data
	position = Vector3(chunk_pos)

## Request mesh generation from voxel data
func request_remesh():
	if _voxel_data.is_empty() or _is_meshing:
		return

	_is_meshing = true

	# Call global mesher
	_mesh_job_id = IChunkMesher.request_mesh_async(
		_voxel_data,
		_chunk_size,
		_chunk_position,
		_terrain_data,
		_on_mesh_generated
	)

## Callback when mesh generation completes
func _on_mesh_generated(result: Dictionary):
	_is_meshing = false
	meshData = result

## Render the mesh from mesh data
func _render_mesh():
	if _mesh_data.is_empty():
		return

	# Clean up existing mesh
	if _mesh_instance != null:
		_mesh_instance.queue_free()
		_mesh_instance = null

	# Create new mesh instance
	_mesh_instance = MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()

	if _mesh_data.vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _mesh_data.vertices
		arrays[Mesh.ARRAY_NORMAL] = _mesh_data.normals
		arrays[Mesh.ARRAY_INDEX] = _mesh_data.indices

		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Set material
		var material := StandardMaterial3D.new()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.6, 0.75, 0.5)  # Green terrain color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		material.roughness = 0.8
		_mesh_instance.material_override = material
		_mesh_instance.mesh = array_mesh

		add_child(_mesh_instance)

		# Create collision
		_create_collision()

func _create_collision():
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return

	# Clean up existing collision
	if _collision_body != null:
		_collision_body.queue_free()
		_collision_body = null

	# Create collision body
	_collision_body = StaticBody3D.new()
	_collision_body.name = "CollisionBody"
	add_child(_collision_body)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	_collision_body.add_child(collision_shape)

	# Create shape from mesh
	var shape := ConcavePolygonShape3D.new()
	var mesh_arrays = _mesh_instance.mesh.surface_get_arrays(0)
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
	# Clean up any active meshing jobs
	if _mesh_job_id >= 0:
		IChunkMesher.cleanup_job(_mesh_job_id)

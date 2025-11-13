@tool
extends MeshInstance3D

@export var chunk_size: int = 16
@export var voxel_size: float = 1.0
@export var wave_frequency: float = 0.3
@export var wave_amplitude: float = 8.0

func _ready():
	generate_chunk()

func generate_chunk():
	# Create voxel data for a 16x16x16 chunk
	var voxels = PackedInt32Array()
	var total_voxels = chunk_size * chunk_size * chunk_size
	voxels.resize(total_voxels)

	# Fill voxel array with sine wave data
	for z in range(chunk_size):
		for y in range(chunk_size):
			for x in range(chunk_size):
				var index = x + chunk_size * y + chunk_size * chunk_size * z

				# Calculate sine wave height based on x and z coordinates
				var wave_height = wave_amplitude + wave_amplitude * sin(x * wave_frequency) * cos(z * wave_frequency)

				# If the current y position is below the wave height, mark as solid (1), otherwise empty (0)
				if y < wave_height:
					voxels[index] = 1
				else:
					voxels[index] = 0

	# Generate mesh using marching cubes
	var mesh_data = CubeMarcher.march_cubes(voxels, chunk_size, voxel_size)

	# Create the mesh
	if mesh_data["vertices"].size() > 0:
		var arr_mesh = ArrayMesh.new()
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = mesh_data["vertices"]
		arrays[Mesh.ARRAY_INDEX] = mesh_data["triangles"]

		# Calculate normals for lighting
		var vertices = mesh_data["vertices"]
		var triangles = mesh_data["triangles"]
		var normals = PackedVector3Array()
		normals.resize(vertices.size())

		# Calculate face normals and accumulate them for each vertex
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

		arrays[Mesh.ARRAY_NORMAL] = normals

		# Add mesh surface
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Assign mesh to this MeshInstance3D
		mesh = arr_mesh

		# Create a simple material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.6, 0.8)
		material.metallic = 0.3
		material.roughness = 0.7
		set_surface_override_material(0, material)

		print("Mesh generated successfully!")
		print("Vertices: ", vertices.size())
		print("Triangles: ", triangles.size() / 3)
	else:
		push_warning("No mesh data generated - all voxels might be empty or full")

func regenerate():
	generate_chunk()

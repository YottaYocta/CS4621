@tool
extends Node3D

@export var resolution: int = 8:
    set(value):
        resolution = value
        _generate()
        _clear_children()
        _spawn_visuals()

@export var debug: bool = true:
    set(value):
        debug = value
        if debug:
            _clear_children()
            _spawn_visuals()
        else:
            _clear_children()

@export var sphere_radius := 0.1
@export var gen_speed := 0.05


var mat := []

func _clear_children():
    for c in get_children():
        if c is MeshInstance3D:
            c.queue_free()

func _generate():
    mat.clear()
    for k in range(resolution):
        var slice := []
        for j in range(resolution):
            var row := []
            for i in range(resolution):
                row.append(randi_range(-1, 1))
            slice.append(row)
        mat.append(slice) 


func _spawn_visuals():
    if debug:
        var sphere_mesh := SphereMesh.new()
        sphere_mesh.radius=sphere_radius
        sphere_mesh.height=sphere_radius * 2


        for k in range(resolution):
            for j in range(resolution):
                for i in range(resolution):
                    var value = mat[k][j][i]
                    var inst := MeshInstance3D.new()
                    inst.mesh = sphere_mesh

                    var grayscale:= float(value + 1)/2.0
                    var material := StandardMaterial3D.new()
                    material.albedo_color = Color(grayscale, grayscale, grayscale)
                    inst.material_override = material

                    inst.position = Vector3(i,j,k)
                    add_child(inst)
    _cpu_cube_march()


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

    # Build triangles from the lookup table
    var tri_list = CubeMarcher.TRI_TABLE[cube_index]

    # Get current mesh or create new one
    var array_mesh: ArrayMesh
    if mesh_instance.mesh == null:
        array_mesh = ArrayMesh.new()
        mesh_instance.mesh = array_mesh
    else:
        array_mesh = mesh_instance.mesh as ArrayMesh

    # Get existing vertices and triangles if any
    var vertices = []
    var triangles = []

    if array_mesh.get_surface_count() > 0:
        var existing_arrays = array_mesh.surface_get_arrays(0)
        vertices = Array(existing_arrays[Mesh.ARRAY_VERTEX])
        triangles = Array(existing_arrays[Mesh.ARRAY_INDEX])
        array_mesh.clear_surfaces()

    # Add new triangles
    for idx in range(0, tri_list.size(), 3):
        if idx + 2 < tri_list.size():
            var v1 = edge_vertices[tri_list[idx]]
            var v2 = edge_vertices[tri_list[idx + 1]]
            var v3 = edge_vertices[tri_list[idx + 2]]

            var base_idx = vertices.size()
            vertices.append(v1)
            vertices.append(v2)
            vertices.append(v3)
            triangles.append(base_idx)
            triangles.append(base_idx + 1)
            triangles.append(base_idx + 2)

    # Recreate mesh with updated data
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
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

    # Add a material so it's visible
    var material := StandardMaterial3D.new()
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    material.albedo_color = Color(0.5, 0.7, 0.9)
    newMeshInstance.material_override = material

    add_child(newMeshInstance)

    for k in range(resolution - 1):
        for j in range(resolution - 1):
            for i in range(resolution - 1):
                # processes cube starting with bounds [k k+1], [j, j+1], [i, i+1]; use lookup table in CubeMarcher.gd to get faces for THIS CUBE ONLY; append to meshinstance
                _process_single_cube(newMeshInstance, i, j, k)
                await get_tree().create_timer(gen_speed).timeout
 



func _ready():
    _generate()
    _clear_children()
    _spawn_visuals()

# tool script; runs on load in editor
# generates resolution x resolution x resolution array of ints, distributed between [-1, 1]

# onready, spawns a sphere at position xi,yj,zk for the mat[k][j][i] with color = mapping of -1, 1 to grayscale
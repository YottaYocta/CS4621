extends Node
class_name IChunkGenerator

## chunk generator that creates voxel data based on position

var noise: FastNoiseLite
var noise_scale: float = 0.05
var noise_amplitude: float = 8.0
var base_height: int = 16

func _init():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale

## generate voxel data for a chunk at the given world position
## returns a 3D array [z][y][x] of voxel values (-1 = empty, 1 = solid)
func generate_chunk_data(chunk_pos: Vector3i, chunk_size: int) -> Array:
	var voxel_data := []

	# Generate chunk_size + 1 in each dimension for marching cubes boundaries
	for k in range(chunk_size + 1):
		var slice := []
		for j in range(chunk_size + 1):
			var row := []
			for i in range(chunk_size + 1):
				var world_x = chunk_pos.x + i
				var world_y = chunk_pos.y + j
				var world_z = chunk_pos.z + k

				var voxel_value = _get_voxel_at(world_x, world_y, world_z)
				row.append(voxel_value)
			slice.append(row)
		voxel_data.append(slice)

	return voxel_data

## Get voxel value at world position using noise-based terrain generation
## Returns signed distance: negative = solid, positive = air
func _get_voxel_at(x: int, y: int, z: int) -> float:
	# Sample noise to get terrain height at this x,z position
	var height = _get_terrain_height(x, z)

	# Return signed distance to surface
	return float(y) - height

func _get_terrain_height(x: int, z: int) -> float:
	var noise_value = noise.get_noise_2d(float(x), float(z))
	var height = base_height + (noise_value * noise_amplitude)
	return height

func set_noise_params(scale: float, amplitude: float, base: int):
	noise_scale = scale
	noise_amplitude = amplitude
	base_height = base
	noise.frequency = noise_scale

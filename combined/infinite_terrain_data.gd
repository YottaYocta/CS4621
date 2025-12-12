extends IslandData
class_name InfiniteTerrainData

## Infinite terrain data source that uses noise for terrain generation
## Extends IslandData to be compatible with existing chunk rendering code

var noise: FastNoiseLite
var noise_scale: float = 0.05
var noise_amplitude: float = 8.0
var base_height: int = 16

var modified_voxels := {}  # Dictionary[Vector3i, float]

func _init():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale

func _ready():
	if noise == null:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = noise_scale

func _regenerate():
	pass

func get_voxel(x: int, y: int, z: int) -> float:
	var key = Vector3i(x, y, z)
	if modified_voxels.has(key):
		return modified_voxels[key]

	var height = _get_terrain_height(x, z)
	return float(y) - height

func _get_terrain_height(x: int, z: int) -> float:
	var noise_value = noise.get_noise_2d(float(x), float(z))

	var height = base_height + (noise_value * noise_amplitude)

	return height

func set_voxel(x: int, y: int, z: int, value: float):
	var key = Vector3i(x, y, z)
	modified_voxels[key] = value
	print("Set voxel at ", key, " to ", value)

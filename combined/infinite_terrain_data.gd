extends IslandData
class_name InfiniteTerrainData

## Infinite terrain data source that uses noise for terrain generation
## Extends IslandData to be compatible with existing chunk rendering code

var noise: FastNoiseLite
var noise_scale: float = 0.05
var noise_amplitude: float = 8.0
var base_height: int = 16

func _init():
	# Initialize noise generator
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale

func _ready():
	# Don't call super._ready() to avoid cellular automata generation
	if noise == null:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = noise_scale

func _regenerate():
	# Override parent's regenerate to do nothing
	# Infinite terrain doesn't need pre-generation
	pass

func get_voxel(x: int, y: int, z: int) -> float:
	# Return signed distance: negative = solid (below surface), positive = air (above surface)
	var height = _get_terrain_height(x, z)

	# Distance to surface: positive when above, negative when below
	return float(y) - height

func _get_terrain_height(x: int, z: int) -> float:
	# Sample noise at x, z to get height variation
	var noise_value = noise.get_noise_2d(float(x), float(z))

	# Noise returns values between -1 and 1, scale it to our amplitude
	var height = base_height + (noise_value * noise_amplitude)

	return height

func set_voxel(x: int, y: int, z: int, value: int):
	# For infinite terrain, we don't store voxel modifications
	# This could be implemented with a sparse data structure if needed
	pass

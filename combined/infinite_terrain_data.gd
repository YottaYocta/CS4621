extends IslandData
class_name InfiniteTerrainData

# Noise parameters for terrain generation
@export var noise_scale: float = 0.05
@export var noise_amplitude: float = 8.0
@export var base_height: int = 16  # Half of the typical chunk height for "bottom half filled"

var noise: FastNoiseLite

func _init():
	# Initialize noise generator
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale

func _ready():
	# Don't call super._ready() to avoid cellular automata generation
	# Re-initialize noise in case we need it
	if noise == null:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = noise_scale

func _regenerate():
	# Override parent's regenerate to do nothing
	# Infinite terrain doesn't need pre-generation
	pass

func get_voxel(x: int, y: int, z: int) -> int:
	# Generate terrain: bottom half is land with noise-based height variation
	# Use noise to determine the height at this x,z position
	var height = _get_terrain_height(x, z)

	# If we're below the terrain height, it's solid (1), otherwise empty (-1)
	if y <= height:
		return 1
	else:
		return -1

func _get_terrain_height(x: int, z: int) -> float:
	# Sample noise at x, z to get height variation
	var noise_value = noise.get_noise_2d(float(x), float(z))

	# Noise returns values between -1 and 1, scale it to our amplitude
	# and add to base height
	var height = base_height + (noise_value * noise_amplitude)

	return height

func set_voxel(x: int, y: int, z: int, value: int):
	# For infinite terrain, we don't store voxel modifications yet
	# This could be implemented with a sparse data structure (dictionary) if needed
	pass

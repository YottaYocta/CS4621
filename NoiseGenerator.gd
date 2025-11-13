extends Node
class_name NoiseGenerator

## Noise generation utility for procedural terrain
## Implements Perlin-like noise with multiple octaves for natural-looking terrain

static func generate_noise_3d(x: float, y: float, z: float,
							  octaves: int = 4,
							  persistence: float = 0.5,
							  lacunarity: float = 2.0,
							  scale: float = 1.0,
							  seed_value: int = 0) -> float:
	"""
	Generate 3D Perlin-like noise with multiple octaves
	- octaves: Number of noise layers to combine
	- persistence: How much each octave contributes (amplitude multiplier)
	- lacunarity: Frequency multiplier for each octave
	- scale: Overall scale of the noise
	- seed_value: Seed for deterministic generation
	"""
	var total = 0.0
	var frequency = 1.0 / scale
	var amplitude = 1.0
	var max_value = 0.0

	for i in range(octaves):
		total += _perlin_3d(x * frequency, y * frequency, z * frequency, seed_value + i) * amplitude
		max_value += amplitude
		amplitude *= persistence
		frequency *= lacunarity

	# Normalize to 0-1 range
	return total / max_value

static func generate_height_map(x: float, z: float,
								octaves: int = 4,
								persistence: float = 0.5,
								lacunarity: float = 2.0,
								scale: float = 1.0,
								seed_value: int = 0,
								height_multiplier: float = 1.0,
								height_offset: float = 0.0) -> float:
	"""
	Generate 2D height map value (optimized for terrain)
	Returns height value that can be used for voxel threshold
	"""
	var noise_value = generate_noise_3d(x, 0.0, z, octaves, persistence, lacunarity, scale, seed_value)
	return (noise_value * height_multiplier) + height_offset

static func _perlin_3d(x: float, y: float, z: float, seed_offset: int) -> float:
	"""
	Simple Perlin-like noise implementation using gradient noise
	"""
	# Get integer coordinates
	var xi = int(floor(x)) & 255
	var yi = int(floor(y)) & 255
	var zi = int(floor(z)) & 255

	# Get fractional coordinates
	var xf = x - floor(x)
	var yf = y - floor(y)
	var zf = z - floor(z)

	# Smooth the coordinates
	var u = _fade(xf)
	var v = _fade(yf)
	var w = _fade(zf)

	# Hash coordinates of the 8 cube corners
	var aaa = _hash(xi, yi, zi, seed_offset)
	var aba = _hash(xi, yi + 1, zi, seed_offset)
	var aab = _hash(xi, yi, zi + 1, seed_offset)
	var abb = _hash(xi, yi + 1, zi + 1, seed_offset)
	var baa = _hash(xi + 1, yi, zi, seed_offset)
	var bba = _hash(xi + 1, yi + 1, zi, seed_offset)
	var bab = _hash(xi + 1, yi, zi + 1, seed_offset)
	var bbb = _hash(xi + 1, yi + 1, zi + 1, seed_offset)

	# Interpolate along x for each corner
	var x1 = lerp(_grad(aaa, xf, yf, zf), _grad(baa, xf - 1, yf, zf), u)
	var x2 = lerp(_grad(aba, xf, yf - 1, zf), _grad(bba, xf - 1, yf - 1, zf), u)
	var x3 = lerp(_grad(aab, xf, yf, zf - 1), _grad(bab, xf - 1, yf, zf - 1), u)
	var x4 = lerp(_grad(abb, xf, yf - 1, zf - 1), _grad(bbb, xf - 1, yf - 1, zf - 1), u)

	# Interpolate along y
	var y1 = lerp(x1, x2, v)
	var y2 = lerp(x3, x4, v)

	# Interpolate along z
	return (lerp(y1, y2, w) + 1.0) * 0.5

static func _fade(t: float) -> float:
	"""Smooth interpolation curve (6t^5 - 15t^4 + 10t^3)"""
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

static func _hash(x: int, y: int, z: int, seed_offset: int) -> int:
	"""Simple hash function for coordinates"""
	var h = seed_offset
	h = (h * 374761393 + x) & 0x7FFFFFFF
	h = (h * 668265263 + y) & 0x7FFFFFFF
	h = (h * 1274126177 + z) & 0x7FFFFFFF
	return h & 255

static func _grad(hash: int, x: float, y: float, z: float) -> float:
	"""Compute gradient dot product"""
	var h = hash & 15
	var u = x if h < 8 else y
	var v = y if h < 4 else (x if h == 12 or h == 14 else z)
	return (u if (h & 1) == 0 else -u) + (v if (h & 2) == 0 else -v)

# Terrain-specific helper functions

static func get_cave_noise(x: float, y: float, z: float,
							scale: float = 0.1,
							threshold: float = 0.5,
							seed_value: int = 1000) -> bool:
	"""
	Generate cave systems using 3D noise
	Returns true if the voxel should be carved out (cave)
	"""
	var noise = generate_noise_3d(x, y, z, 3, 0.5, 2.0, scale, seed_value)
	return noise > threshold

static func get_density(x: float, y: float, z: float,
						base_scale: float = 50.0,
						height_scale: float = 30.0,
						cave_scale: float = 20.0,
						seed_value: int = 0) -> float:
	"""
	Calculate voxel density for more complex terrain
	Returns value where > 0.5 is solid, < 0.5 is air
	"""
	# Base terrain height
	var height = generate_height_map(x, z, 4, 0.5, 2.0, base_scale, seed_value, height_scale, height_scale * 0.5)

	# Basic height-based density
	var density = 1.0 - ((y - height) / 10.0)

	# Add 3D cave noise
	var cave_noise = generate_noise_3d(x, y, z, 2, 0.5, 2.0, cave_scale, seed_value + 1000)

	# Carve caves below surface
	if y < height - 2:
		density -= (cave_noise - 0.5) * 0.8

	return clamp(density, 0.0, 1.0)

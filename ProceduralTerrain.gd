@tool
extends Node3D
class_name ProceduralTerrain

## Main procedural terrain generator with chunk management
## Generates terrain using voxel-based marching cubes

@export_group("Chunk Settings")
@export var chunk_size: int = 16:
	set(value):
		chunk_size = max(8, value)
		if Engine.is_editor_hint():
			_mark_dirty()

@export var voxel_size: float = 1.0:
	set(value):
		voxel_size = max(0.1, value)
		if Engine.is_editor_hint():
			_mark_dirty()

@export var render_distance: int = 2:
	set(value):
		render_distance = max(1, value)
		if Engine.is_editor_hint():
			_mark_dirty()

@export_group("Terrain Type")
@export_enum("Flat", "Hills", "Mountains", "Caves", "Islands") var terrain_type: String = "Hills":
	set(value):
		terrain_type = value
		if Engine.is_editor_hint():
			_mark_dirty()

@export_group("Terrain Parameters")
@export var noise_scale: float = 50.0:
	set(value):
		noise_scale = max(1.0, value)
		if Engine.is_editor_hint():
			_mark_dirty()

@export var height_multiplier: float = 30.0:
	set(value):
		height_multiplier = max(1.0, value)
		if Engine.is_editor_hint():
			_mark_dirty()

@export var surface_level: float = 0.5:
	set(value):
		surface_level = clamp(value, 0.0, 1.0)
		if Engine.is_editor_hint():
			_mark_dirty()

@export var terrain_seed: int = 0:
	set(value):
		terrain_seed = value
		if Engine.is_editor_hint():
			_mark_dirty()

@export_group("Material")
@export var terrain_color: Color = Color(0.3, 0.5, 0.2):
	set(value):
		terrain_color = value
		_update_chunk_materials()

@export var metallic: float = 0.0:
	set(value):
		metallic = clamp(value, 0.0, 1.0)
		_update_chunk_materials()

@export var roughness: float = 0.9:
	set(value):
		roughness = clamp(value, 0.0, 1.0)
		_update_chunk_materials()

@export_group("Actions")
@export var auto_generate: bool = true
@export var regenerate_button: bool = false:
	set(value):
		if value:
			regenerate()
			regenerate_button = false

# Internal variables
var chunks: Dictionary = {}  # Vector3i -> TerrainChunk
var is_dirty: bool = true
var generation_center: Vector3i = Vector3i.ZERO

func _ready():
	if not Engine.is_editor_hint():
		if auto_generate:
			call_deferred("generate_terrain")

func _process(_delta):
	if Engine.is_editor_hint() and is_dirty:
		call_deferred("regenerate")
		is_dirty = false

func generate_terrain(center: Vector3i = Vector3i.ZERO):
	"""Generate terrain chunks around a center position"""
	generation_center = center

	# Calculate chunk coordinates for the center
	var center_chunk = Vector3i(
		int(floor(float(center.x) / chunk_size)),
		int(floor(float(center.y) / chunk_size)),
		int(floor(float(center.z) / chunk_size))
	)

	# Generate chunks in a cube around the center
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			for z in range(-render_distance, render_distance + 1):
				var chunk_pos = center_chunk + Vector3i(x, y, z)
				_generate_chunk(chunk_pos)

func regenerate():
	"""Clear and regenerate all terrain"""
	clear_terrain()
	generate_terrain(generation_center)

func clear_terrain():
	"""Remove all existing chunks"""
	for chunk in chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	chunks.clear()

func _generate_chunk(chunk_pos: Vector3i):
	"""Generate a single chunk at the given position"""
	# Check if chunk already exists
	if chunks.has(chunk_pos):
		return

	# Create terrain parameters dictionary
	var params = {
		"terrain_type": terrain_type.to_lower(),
		"noise_scale": noise_scale,
		"height_multiplier": height_multiplier,
		"surface_level": surface_level,
		"seed": terrain_seed
	}

	# Create and initialize the chunk
	var chunk = TerrainChunk.new()
	chunk.initialize(chunk_pos, chunk_size, voxel_size, params)
	add_child(chunk)

	# Generate the chunk mesh
	chunk.generate()

	# Store the chunk
	chunks[chunk_pos] = chunk

	# Apply material settings
	if is_instance_valid(chunk) and chunk.get_surface_override_material_count() > 0:
		var mat = chunk.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color = terrain_color
			mat.metallic = metallic
			mat.roughness = roughness

func _update_chunk_materials():
	"""Update materials on all existing chunks"""
	for chunk in chunks.values():
		if is_instance_valid(chunk) and chunk.get_surface_override_material_count() > 0:
			var mat = chunk.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				mat.albedo_color = terrain_color
				mat.metallic = metallic
				mat.roughness = roughness

func _mark_dirty():
	"""Mark terrain as needing regeneration"""
	is_dirty = true

func get_chunk_at_position(world_pos: Vector3) -> TerrainChunk:
	"""Get the chunk at a world position"""
	var chunk_pos = Vector3i(
		int(floor(world_pos.x / (chunk_size * voxel_size))),
		int(floor(world_pos.y / (chunk_size * voxel_size))),
		int(floor(world_pos.z / (chunk_size * voxel_size)))
	)
	return chunks.get(chunk_pos)

func get_terrain_info() -> Dictionary:
	"""Get information about the current terrain"""
	return {
		"chunk_count": chunks.size(),
		"chunk_size": chunk_size,
		"voxel_size": voxel_size,
		"terrain_type": terrain_type,
		"noise_scale": noise_scale,
		"height_multiplier": height_multiplier,
		"total_voxels": chunks.size() * chunk_size * chunk_size * chunk_size
	}

func print_terrain_info():
	"""Print terrain information to console"""
	var info = get_terrain_info()
	print("=== Terrain Info ===")
	print("Chunks: ", info.chunk_count)
	print("Chunk Size: ", info.chunk_size)
	print("Voxel Size: ", info.voxel_size)
	print("Terrain Type: ", info.terrain_type)
	print("Total Voxels: ", info.total_voxels)
	print("==================")

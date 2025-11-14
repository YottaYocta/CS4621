extends MeshInstance3D

@export var light_node: OmniLight3D

var shader_mat: ShaderMaterial = null

func _ready() -> void:
	# ensure _process runs for MeshInstance3D
	set_process(true)

	if not light_node:
		push_error("No light_node assigned!")
		return

	# Try several places to find the active ShaderMaterial
	# 1) material_override (whole mesh)
	if material_override and material_override is ShaderMaterial:
		print("Using material_override (whole mesh).")
		shader_mat = material_override.duplicate() as ShaderMaterial
		material_override = shader_mat
		_print_material_id(shader_mat)
		return

	# 2) surface override(s)
	var surface_count = mesh.get_surface_count() if mesh else 0
	var loop_arr = range(surface_count) if surface_count > 0 else []
	for i in loop_arr:
		var surf_mat = get_surface_override_material(i)
		if surf_mat and surf_mat is ShaderMaterial:
			print("Using surface_override material on surface %d." % i)
			shader_mat = surf_mat.duplicate() as ShaderMaterial
			set_surface_override_material(i, shader_mat)
			_print_material_id(shader_mat)
			return

	# 3) mesh's internal surface materials (the Mesh resource stores materials)
	# Note: mesh.surface_get_material(i) returns a Material for that surface
	if mesh:
		for i in range(surface_count):
			var surf_mat2 = mesh.surface_get_material(i)
			if surf_mat2 and surf_mat2 is ShaderMaterial:
				print("Found ShaderMaterial inside Mesh resource on surface %d." % i)
				# make a per-surface override with a duplicate so we don't modify shared resource
				shader_mat = surf_mat2.duplicate() as ShaderMaterial
				set_surface_override_material(i, shader_mat)
				_print_material_id(shader_mat)
				return

	# If we got here, we couldn't find a ShaderMaterial
	if not shader_mat:
		push_warning("Could not find a ShaderMaterial on this MeshInstance3D. Create one or attach a ShaderMaterial to material_override or a surface override.")
		print("Available: material_override=%s, surface_count=%d" % [str(material_override), surface_count])

func _process(_delta: float) -> void:
	# Print a simple heartbeat to confirm this runs (comment out if spammy)
	# print("Process tick.")

	if not shader_mat:
		return

	# Get light world pos and convert to mesh local space (so shader uses local coords)
	var world_pos: Vector3 = light_node.global_transform.origin
	var local_pos: Vector3 = to_local(world_pos)

	# Update shader uniforms
	shader_mat.set_shader_parameter("light_pos", local_pos)
	shader_mat.set_shader_parameter("light_color", light_node.light_color)
	# debug output to verify values (uncomment to inspect)
	# print("Set shader_parameter/light_pos -> ", local_pos)
	# print("Set shader_parameter/light_color -> ", light_node.light_color)

func _print_material_id(mat: ShaderMaterial) -> void:
	if not mat:
		return
	print("Material assigned and duplicated. GUID-like id: %s" % str(mat.get_instance_id()))

extends Node
## Model pipeline (6.3): a figure runs on graybox primitives until a model file exists
## at its fixed path; then the model is mounted under `Model`, the graybox hidden, and
## an animator attached. Nothing breaks when the file is missing.

## Returns the ModelAnimator or null if no model was mounted.
func mount(model_root: Node3D, path: String, graybox: Node3D, scale: float, yaw_offset_deg: float, tint: Color = Color.WHITE) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed = load(path)
	if not (packed is PackedScene):
		return null
	var inst: Node3D = packed.instantiate()
	inst.name = "Visual"
	inst.scale = Vector3.ONE * scale
	inst.rotation_degrees.y = yaw_offset_deg
	model_root.add_child(inst)
	if graybox != null:
		graybox.visible = false
	_fix_materials(inst, tint)
	var player := _find_animation_player(inst)
	if player == null:
		return null
	var animator = load("res://game/entities/model_animator.gd").new()
	animator.name = "Animator"
	model_root.add_child(animator)
	animator.setup(player)
	return animator

## Many low-poly models keep colour in vertex colours (8.D.1). Godot ignores those by
## default, and without the sRGB flag they wash out. Matte, so the sky does not tint
## bright surfaces blue.
func _fix_materials(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				var fixed: StandardMaterial3D
				if mat is StandardMaterial3D:
					fixed = mat.duplicate()
				else:
					fixed = StandardMaterial3D.new()
				fixed.vertex_color_use_as_albedo = true
				fixed.vertex_color_is_srgb = true
				fixed.metallic = 0.0
				fixed.roughness = 1.0
				fixed.albedo_color = fixed.albedo_color * tint
				mi.set_surface_override_material(s, fixed)
	for c in node.get_children():
		_fix_materials(c, tint)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var p := _find_animation_player(c)
		if p != null:
			return p
	return null

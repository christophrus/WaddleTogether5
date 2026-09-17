extends Node
## Prints the merged AABB, mesh materials and animation clips of the two duck models.
##   godot --headless --path . res://tools/inspect_model.tscn
## "Understand the clip before touching it" (8.C.2) starts with knowing what is there.

func _ready() -> void:
	for path in ["res://assets/models/duck_mother.glb", "res://assets/models/duckling.glb"]:
		print("=== ", path)
		if not ResourceLoader.exists(path):
			print("  missing")
			continue
		var inst: Node3D = load(path).instantiate()
		add_child(inst)
		var aabb := _merged_aabb(inst, inst)
		print("  aabb: pos=%s size=%s  (height %.3f, length z %.3f, width x %.3f)" % [aabb.position, aabb.size, aabb.size.y, aabb.size.z, aabb.size.x])
		_dump(inst, inst, 1)
		inst.queue_free()
	get_tree().quit()

func _merged_aabb(node: Node, root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			var xf: Transform3D = root.global_transform.affine_inverse() * n.global_transform
			var a: AABB = xf * n.mesh.get_aabb()
			if first:
				result = a
				first = false
			else:
				result = result.merge(a)
		for c in n.get_children():
			stack.append(c)
	return result

func _dump(node: Node, root: Node3D, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var info := "%s%s (%s)" % [pad, node.name, node.get_class()]
	if node is MeshInstance3D and node.mesh != null:
		info += " surfaces=%d" % node.mesh.get_surface_count()
		for s in node.mesh.get_surface_count():
			var m: Material = node.get_active_material(s)
			if m is StandardMaterial3D:
				info += " [mat%d albedo=%s tex=%s vcol=%s]" % [s, m.albedo_color, m.albedo_texture != null, m.vertex_color_use_as_albedo]
			else:
				info += " [mat%d %s]" % [s, m]
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var colors = arrays[Mesh.ARRAY_COLOR]
		info += " has_vertex_colors=%s" % (colors != null and colors.size() > 0)
	if node is AnimationPlayer:
		for clip in node.get_animation_list():
			var a: Animation = node.get_animation(clip)
			info += "\n%s  clip '%s' length=%.2f loop=%d" % [pad, clip, a.length, a.loop_mode]
	print(info)
	for c in node.get_children():
		_dump(c, root, depth + 1)

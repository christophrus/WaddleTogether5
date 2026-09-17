extends Node
## Debug helper: boots the park and lists decoration props inside an XZ box with the
## world-space AABB of their meshes. Usage (headless is fine):
##   WADDLE_BOX="20,40,-10,20" godot --headless --path . res://tools/dump_props.tscn

func _ready() -> void:
	GameState.reset()
	var main = load("res://game/main/game.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var box := OS.get_environment("WADDLE_BOX").split(",")
	var x0 := float(box[0]) if box.size() == 4 else -40.0
	var x1 := float(box[1]) if box.size() == 4 else 40.0
	var z0 := float(box[2]) if box.size() == 4 else -40.0
	var z1 := float(box[3]) if box.size() == 4 else 40.0
	var deco: Node3D = main.park.get_node("Decoration")
	for e in deco.placed:
		var p: Vector2 = e["pos"]
		if p.x < x0 or p.x > x1 or p.y < z0 or p.y > z1:
			continue
		var node: Node3D = null
		for c in deco.get_children():
			if c is Node3D and Vector2(c.position.x, c.position.z).distance_to(p) < 0.01:
				node = c
				break
		var aabb := AABB()
		var first := true
		if node != null:
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				var a: AABB = mi.global_transform * mi.mesh.get_aabb()
				aabb = a if first else aabb.merge(a)
				first = false
		print("%-10s at %s  aabb pos=%s size=%s" % [e["kind"], p, aabb.position, aabb.size])
	get_tree().quit()

extends WaddleTest
## Decoration (5.9): deterministic placement, keep-out zones read from groups (plus the
## explicit brook zone, 8.G.5), hand-placed benches go through the same check (8.G.4),
## and only trees/benches are solid.

func _init() -> void:
	test_name = "DECORATION"

func run(main: Node) -> void:
	var p := park(main)
	var deco: Node3D = p.get_node("Decoration")
	var n := nest(main)
	check(deco.placed.size() > 100, "plenty of props placed", deco.placed.size())
	var kinds := {}
	for e in deco.placed:
		kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
	for k in ["tree_round", "tree_pine", "bush", "rock", "reed", "lily", "bench"]:
		check(kinds.get(k, 0) > 0, "has at least one %s" % k, kinds.get(k, 0))
	check_eq(kinds.get("bench", 0), 2, "both benches found a spot")

	# Determinism: a second build from the same seed yields identical positions.
	var second := Node3D.new()
	second.set_script(load("res://game/world/decoration.gd"))
	p.add_child(second)
	second.build()
	var same: bool = second.placed.size() == deco.placed.size()
	if same:
		for i in deco.placed.size():
			if deco.placed[i]["kind"] != second.placed[i]["kind"] or deco.placed[i]["pos"] != second.placed[i]["pos"]:
				same = false
				break
	check(same, "placement is deterministic across builds")
	second.queue_free()

	# Keep-out: nest, spawn, pond (except reeds/lilies), brook, pickups, gates.
	var nest2 := Vector2(n.global_position.x, n.global_position.z)
	var spawn: Vector3 = p.get_node("Spawn").position
	var spawn2 := Vector2(spawn.x, spawn.z)
	var pond2 := Vector2(p.POND_CENTER.x, p.POND_CENTER.z)
	var violations: Array = []
	for e in deco.placed:
		var pos: Vector2 = e["pos"]
		var kind: String = e["kind"]
		if kind in ["reed", "lily"]:
			continue
		if pos.distance_to(nest2) < 5.0: violations.append([kind, "nest", pos])
		if pos.distance_to(spawn2) < 4.0: violations.append([kind, "spawn", pos])
		if pos.distance_to(pond2) < p.POND_RADIUS + 1.0: violations.append([kind, "pond", pos])
		if _near_brook(deco, pos): violations.append([kind, "brook", pos])
		for pk in get_tree().get_nodes_in_group("pickup"):
			if pos.distance_to(Vector2(pk.global_position.x, pk.global_position.z)) < 1.2:
				violations.append([kind, "pickup", pos])
				break
	check(violations.is_empty(), "no prop inside a keep-out zone", violations.slice(0, 5))
	for e in deco.placed:
		if e["kind"] == "lily":
			check(p.is_water(Vector3(e["pos"].x, 0, e["pos"].y)), "lilies float on the pond", e["pos"])
			break

	# Solidity: trees and benches carry a StaticBody, bushes and rocks do not.
	var solid := {"tree_round": false, "bench": false, "bush": false, "rock": false}
	var seen := {}
	for e in deco.placed:
		if not solid.has(e["kind"]) or seen.has(e["kind"]):
			continue
		var node: Node3D = _node_for(deco, e)
		if node != null:
			seen[e["kind"]] = true
			solid[e["kind"]] = _has_static_body(node)
	check(solid["tree_round"], "round trees are solid")
	check(solid["bench"], "benches are solid")
	check(not solid["bush"], "bushes are not solid (no slalom)")
	check(not solid["rock"], "rocks are not solid")
	finish()

func _near_brook(deco: Node3D, pos: Vector2) -> bool:
	for i in deco.BROOK_POINTS.size() - 1:
		var a: Vector2 = deco.BROOK_POINTS[i]
		var b: Vector2 = deco.BROOK_POINTS[i + 1]
		var t := clampf((pos - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if pos.distance_to(a.lerp(b, t)) < deco.BROOK_WIDTH * 0.5 + 0.5:
			return true
	return false

func _node_for(deco: Node3D, entry: Dictionary) -> Node3D:
	for c in deco.get_children():
		if c is Node3D and Vector2(c.position.x, c.position.z).distance_to(entry["pos"]) < 0.01:
			return c
	return null

func _has_static_body(node: Node) -> bool:
	if node is StaticBody3D:
		return true
	for c in node.get_children():
		if _has_static_body(c):
			return true
	return false

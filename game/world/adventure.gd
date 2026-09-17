extends Node3D
## One scripted outing: walk the brood from a start marker to a goal. Distance checks
## instead of Areas so it is deterministic headless and needs no physics layers.

var adventure_id := "forest_edge_walk"
var start_point := Vector3.ZERO
var goal_point := Vector3.ZERO
var trigger_radius := 3.0
var started := false

var _park: Node3D

func _ready() -> void:
	add_to_group("adventure_zone")
	add_to_group("keep_out")
	_park = get_tree().get_first_node_in_group("park")
	for p in [start_point, goal_point]:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = trigger_radius * 0.6
		cm.bottom_radius = trigger_radius * 0.6
		cm.height = 0.05
		m.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.5, 0.3, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.position = p + Vector3(0, 0.03, 0)
		add_child(m)

func _physics_process(_delta: float) -> void:
	if _park == null or _park.mother == null or adventure_id in GameState.adventures_done:
		return
	var m: Vector3 = _park.mother.global_position
	var brood = _park.ducklings().filter(func(d): return not d.data["nest_bound"])
	if brood.is_empty():
		return
	if not started:
		if _flat_dist(m, start_point) < trigger_radius:
			started = true
			EventBus.adventure_started.emit(adventure_id)
	else:
		if _flat_dist(m, goal_point) < trigger_radius:
			var near = brood.filter(func(d): return _flat_dist(d.global_position, goal_point) < 6.0)
			if not near.is_empty():
				GameState.adventures_done.append(adventure_id)
				EventBus.adventure_completed.emit(adventure_id)

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func keep_out_circle() -> Array:
	return [Vector2(goal_point.x, goal_point.z), trigger_radius + 2.0]

func keep_out_rect() -> Array:
	var mid := (start_point + goal_point) * 0.5
	return [Vector2(mid.x, mid.z), Vector2(absf(start_point.x - goal_point.x), absf(start_point.z - goal_point.z)) * 0.5 + Vector2(3, 3)]

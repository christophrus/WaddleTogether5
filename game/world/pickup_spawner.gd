extends Node3D
## Scatters 20 food + 19 nest material with a fixed seed so the park looks the same
## every session and tests can rely on positions. Rejects water, the nest and spawn.

const FOOD_COUNT := 20
const MATERIAL_COUNT := 19
const SEED := 4242

func _ready() -> void:
	var park := get_tree().get_first_node_in_group("park")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var placed: Array[Vector2] = []
	var nest_pos: Vector3 = park.nest.global_position
	var spawn_pos: Vector3 = park.get_node("Spawn").position
	var script := load("res://game/world/pickup.gd")
	var kinds: Array[String] = []
	for i in FOOD_COUNT: kinds.append("food")
	for i in MATERIAL_COUNT: kinds.append("material")
	for kind in kinds:
		for attempt in 200:
			var p := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-20.0, 18.0))
			# Food near the water and meadow side, material more towards the grass edge.
			if kind == "food" and attempt < 50:
				var a := rng.randf() * TAU
				var r := rng.randf_range(park.POND_RADIUS + 1.5, park.POND_RADIUS + 9.0)
				p = Vector2(park.POND_CENTER.x + cos(a) * r, park.POND_CENTER.z + sin(a) * r)
			if absf(p.x) > 19.0 or p.y < -21.0 or p.y > 19.0:
				continue
			var pos3 := Vector3(p.x, 0.0, p.y)
			if park.is_water(pos3):
				continue
			if pos3.distance_to(Vector3(nest_pos.x, 0, nest_pos.z)) < 3.0:
				continue
			if pos3.distance_to(Vector3(spawn_pos.x, 0, spawn_pos.z)) < 2.5:
				continue
			var too_close := false
			for q in placed:
				if q.distance_to(p) < 2.0:
					too_close = true
					break
			if too_close:
				continue
			placed.append(p)
			var pk: Area3D = script.new()
			pk.kind = kind
			add_child(pk)
			pk.global_position = Vector3(p.x, park.ground_height(p.x, p.y), p.y)
			break

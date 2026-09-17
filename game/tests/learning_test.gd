extends WaddleTest
## Learning by imitation (5.3): proximity, attention falloff, thresholds, and — most
## important — that the only display is behaviour: an untaught duckling ignores food,
## an untaught one stops at the shore.

func _init() -> void:
	test_name = "LEARNING"

func run(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var brood := await bootstrap_brood(main, 2)
	var a = brood[0]
	var b = brood[1]
	for d in brood:
		d.data["nest_bound"] = false
		d.data["stage"] = 1
		d.state = d.State.FOLLOW
		d.learning.learn_mult = {}   # neutral multipliers so the maths is checkable
	var learned := spy(EventBus.duckling_learned)

	# Proximity + attention falloff
	var origin := Vector3(0, 0.4, 6)
	m.teleport(origin)
	a.teleport(origin + Vector3(2, 0, 0))
	b.teleport(origin + Vector3(20, 0, 0))
	await frames(2)
	EventBus.mother_demonstrated.emit("foraging", origin, 0.2)
	var expected_a := 0.2 * lerpf(1.0, 0.35, 2.0 / 7.0)
	check_near(a.learning.level("foraging"), expected_a, 0.002, "duckling 2 m away learns with distance-weighted attention")
	check_eq(b.learning.level("foraging"), 0.0, "duckling 20 m away learns nothing")
	a.teleport(origin + Vector3(7, 0, 0))
	await frames(2)
	var before: float = a.learning.level("foraging")
	EventBus.mother_demonstrated.emit("foraging", origin, 0.2)
	check_near(a.learning.level("foraging") - before, 0.2 * 0.35, 0.003, "attention at the sight edge is 35 %, never zero")
	a.teleport(origin + Vector3(7.2, 0, 0))
	await frames(2)
	before = a.learning.level("foraging")
	EventBus.mother_demonstrated.emit("foraging", origin, 0.2)
	check_eq(a.learning.level("foraging"), before, "beyond sight radius nothing is learned")

	# Threshold signal
	a.data["skills"]["foraging"] = 0.29
	a.teleport(origin)
	await frames(2)
	EventBus.mother_demonstrated.emit("foraging", origin, 0.05)
	check_eq(learned[0], 1, "duckling_learned emitted at threshold 1")
	check(a.learning.has("foraging", 1), "has foraging 1")
	check(not a.learning.has("foraging", 2), "not yet foraging 2")

	# Behaviour is the display: untaught duckling walks past food.
	var food := _place_food(p, Vector3(-14, 0, 12))
	b.data["skills"]["foraging"] = 0.0
	b.data["hunger"] = 1.0
	m.teleport(Vector3(-14, 0.5, 13.5))
	b.teleport(Vector3(-14, 0.4, 14.5))
	await frames(150)
	check(food.active, "untaught duckling ignores food right next to it")
	# Taught duckling eats it.
	a.data["hunger"] = 1.0
	a.data["skills"]["foraging"] = 0.5
	a.teleport(Vector3(-14, 0.4, 14.5))
	await frames(200)
	check(not food.active, "taught duckling picks the food itself")
	check(a.needs.hunger() < 1.0, "eating reduced hunger", a.needs.hunger())

	# Swimming gate: untaught stops at the shore and peeps; taught follows into water.
	var peeps_before := AudioManager.peep_count
	var centre: Vector3 = p.POND_CENTER + Vector3(0, 0.3, 0)
	m.teleport(centre)
	b.data["skills"]["swimming"] = 0.0
	b.data["hunger"] = 0.0
	b.teleport(p.POND_CENTER + Vector3(0, 0.4, p.POND_RADIUS + 1.5))
	a.data["skills"]["swimming"] = 0.5
	a.data["hunger"] = 0.0
	a.teleport(p.POND_CENTER + Vector3(2, 0.4, p.POND_RADIUS + 1.5))
	await frames(360)
	check(not p.is_water(b.global_position), "untaught duckling stays out of the water", b.global_position)
	check(AudioManager.peep_count > peeps_before, "it peeps after the swimming mother", AudioManager.peep_count - peeps_before)
	check(p.is_water(a.global_position), "taught duckling swims after the mother", a.global_position)
	finish()

func _place_food(p: Node3D, pos: Vector3) -> Node:
	var pk = load("res://game/world/pickup.gd").new()
	pk.kind = "food"
	p.get_node("Pickups").add_child(pk)
	pk.global_position = pos
	return pk

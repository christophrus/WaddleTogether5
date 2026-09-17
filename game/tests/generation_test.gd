extends WaddleTest
## The generations cycle (5.10): once the brood has fledged, a dawn brings new eggs and
## the old brood becomes helpers who teach with the mother's own signal.

func _init() -> void:
	test_name = "GENERATION"

func run(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var n := nest(main)
	var brood := await bootstrap_brood(main, 2)
	var new_gen := spy(EventBus.new_generation)
	var promoted := spy(EventBus.helper_promoted)

	# Not yet: still nest-bound hatchlings.
	Daytime.set_time(0.99)
	Daytime.advance(0.02)
	check_eq(new_gen[0], 0, "no new generation while the brood is small")

	for d in brood:
		d.data["nest_bound"] = false
		d.data["stage"] = 2
		d.state = d.State.FOLLOW
	Daytime.set_time(0.99)
	Daytime.advance(0.02)
	check_eq(new_gen[0], 1, "new generation at dawn once everyone fledged")
	check_eq(promoted[0], 2, "both fledglings promoted to helpers")
	check_eq(GameState.eggs.size(), 3, "three new eggs in the nest", GameState.eggs.size())
	check_eq(GameState.generation, 2, "generation counter advanced")
	for d in brood:
		check(bool(d.data["is_helper"]), "duckling record flagged as helper")
		check_eq(d.state, d.State.HELPER, "duckling runs the helper behaviour")
	Daytime.set_time(0.99)
	Daytime.advance(0.02)
	check_eq(new_gen[0], 1, "no second clutch while eggs are incubating")

	# Helpers teach: collecting food emits the very same demonstration signal.
	var demos := spy(EventBus.mother_demonstrated)
	var helper = brood[0]
	var food = load("res://game/world/pickup.gd").new()
	food.kind = "food"
	p.get_node("Pickups").add_child(food)
	food.global_position = Vector3(-15, 0, 15)
	m.teleport(Vector3(-15, 0.5, 17))
	helper.teleport(Vector3(-15, 0.4, 14))
	helper._helper_teach_t = 10.0
	await frames(120)
	check(not food.active, "helper collected the food")
	check(demos[0] >= 1, "helper emitted mother_demonstrated", demos[0])
	finish()

extends WaddleTest
## Feeding at the nest must always do something visible: a full brood still takes the
## bite (hunger only orders who eats first), each bite grows the duckling a little,
## three bites per hatchling get the whole clutch out of the nest. Hatchlings also
## answer calls from the nest instead of ignoring them.

func _init() -> void:
	test_name = "FEEDING"

func run(main: Node) -> void:
	var m := mother(main)
	var n := nest(main)
	var brood := await bootstrap_brood(main, 4)
	check_eq(brood.size(), 4, "four hatchlings")
	for d in brood:
		d.data["hunger"] = 0.0   # everyone full: the case the player actually hits
	m.teleport(n.global_position + Vector3(1.0, 0.5, 0))
	GameState.mother["carried_food"] = 20
	await frames(3)
	check(m.current_prompt.begins_with("Küken füttern (0/3)"), "prompt offers feeding a full brood, with counter", m.current_prompt)
	var fed := spy(EventBus.duckling_fed)
	var scale_before: float = brood[0].model.scale.x
	for i in 4:
		m.interact()
	check_eq(fed[0], 4, "four feedings all landed")
	var counts := brood.map(func(d): return int(d.data["feedings"]))
	check_eq(counts, [1, 1, 1, 1], "each hatchling fed exactly once (least-fed first)")
	check(brood[0].model.scale.x > scale_before, "a fed hatchling is visibly bigger", [scale_before, brood[0].model.scale.x])
	await frames(3)
	check(m.current_prompt.begins_with("Küken füttern (1/3)"), "counter advanced", m.current_prompt)
	var left := spy(EventBus.duckling_left_nest)
	for i in 8:
		m.interact()
	check_eq(left[0], 4, "twelve feedings: the whole clutch left the nest")
	check_eq(GameState.egg_slots_free(), 4, "all egg slots free again")
	check_eq(int(GameState.mother["carried_food"]), 8, "twelve food consumed")

	# Hatchlings answer a call: peep and scurry to the rim facing the mother.
	var brood2 := await bootstrap_brood(main, 2)
	for d in brood2:
		d.teleport(n.global_position + Vector3(-0.8, 0.4, 0))
	m.teleport(n.global_position + Vector3(6, 0.5, 0))
	await frames(5)
	var peeps := AudioManager.peep_count
	m.make_call("gather")
	await frames(90)
	check(AudioManager.peep_count >= peeps + 2, "both hatchlings peeped back", AudioManager.peep_count - peeps)
	for d in brood2:
		check(bool(d.data["nest_bound"]), "hatchling still nest-bound after the call")
		check(d.global_position.x > n.global_position.x + 0.3, "hatchling moved to the rim facing the mother", d.global_position.x - n.global_position.x)
		check(d.global_position.distance_to(n.global_position) < 1.6, "…but stayed at the nest", d.global_position.distance_to(n.global_position))
	finish()

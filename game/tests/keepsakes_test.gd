extends WaddleTest
## Keepsakes (5.7): a roaming duckling carries its find home and the nest keeps it;
## the mother drops a dabbling find at the nest; everything ends up in GameState.

func _init() -> void:
	test_name = "KEEPSAKES"

func run(main: Node) -> void:
	var m := mother(main)
	var n := nest(main)
	var placed: Array = []
	EventBus.keepsake_placed.connect(func(k, f): placed.append([k, f]))
	var brood := await bootstrap_brood(main, 1)
	var d = brood[0]
	d.data["nest_bound"] = false
	d.data["stage"] = 1
	d.set_duck_name("Rikki")
	d.state = d.State.FOLLOW
	m.teleport(n.global_position + Vector3(6, 0.5, 0))
	d.teleport(n.global_position + Vector3(5, 0.4, 0))
	d.carried_keepsake = "marble"
	d.state = d.State.CARRY_HOME
	await frames(60 * 5)
	check_eq(placed.size(), 1, "duckling placed its find at the nest", placed)
	check(placed.size() > 0 and placed[0][1] == "Rikki", "finder is the duckling's name", placed)
	check_eq(d.carried_keepsake, "", "duckling no longer carries it")
	check_eq(d.state, d.State.FOLLOW, "back to following afterwards")
	check_eq(GameState.keepsakes.size(), 1, "keepsake recorded in GameState")
	check_eq(n.get_node("Keepsakes").get_child_count(), 1, "keepsake rendered at the nest")

	# Mother: a dabbling find is dropped at the nest through the same prompt system.
	GameState.mother["carried_keepsake"] = "bottle_cap"
	m.teleport(n.global_position + Vector3(1.0, 0.5, 0))
	await frames(3)
	check_eq(m.current_prompt, "Fundstück ablegen", "nest offers to place the mother's find")
	m.interact()
	check_eq(placed.size(), 2, "mother placed her find")
	check_eq(GameState.mother["carried_keepsake"], "", "mother's hands are free again")
	check_eq(GameState.keepsakes.size(), 2, "two keepsakes ring the nest")
	for k in GameState.keepsakes:
		check(float(k["radius"]) > 0.8 and float(k["radius"]) < 1.5, "keepsake lies in the ring around the nest", k["radius"])
	finish()

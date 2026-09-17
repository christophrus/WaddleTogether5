extends WaddleTest
## Zones and the scripted outing: gates are solid until progression opens them, and
## the adventure completes only when at least one duckling reaches the goal too.

func _init() -> void:
	test_name = "ADVENTURE"

func run(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var gates := get_tree().get_nodes_in_group("zone_gate")
	check_eq(gates.size(), 2, "two zone gates")
	var forest: Node3D = null
	for g in gates:
		if g.zone_id == "forest_edge":
			forest = g
	check(forest != null and forest.visible, "forest gate closed at the start")
	check(not forest._shape.disabled, "forest gate collides while closed")

	# Walking into the closed gate stops the duck.
	m.teleport(Vector3(0, 0.6, -19.5))
	await frames(10)
	InputRouter.sim_move(Vector2(0, 1))   # -Z, into the fence at z=-22
	await frames(90)
	InputRouter.sim_move(Vector2.ZERO)
	check(m.global_position.z > -22.0, "closed gate blocks the mother", m.global_position.z)

	var started := spy(EventBus.adventure_started)
	var completed := spy(EventBus.adventure_completed)
	Progression.unlock("forest_edge")
	await frames(2)
	check(not forest.visible, "gate hidden once unlocked")
	check(forest._shape.disabled, "gate collision off once unlocked")

	var adv: Node3D = get_tree().get_first_node_in_group("adventure_zone")
	# Without a brood nothing starts: the outing is *with* the ducklings.
	m.teleport(adv.start_point + Vector3(0, 0.6, 0))
	await frames(5)
	check_eq(started[0], 0, "no adventure without a brood")
	var brood := await bootstrap_brood(main, 1)
	var d = brood[0]
	d.data["nest_bound"] = false
	d.data["stage"] = 1
	d.state = d.State.FOLLOW
	d.teleport(adv.start_point + Vector3(1, 0.4, 0))
	await frames(5)
	check_eq(started[0], 1, "adventure starts with the brood at the start marker")
	m.teleport(adv.goal_point + Vector3(0, 0.6, 0))
	d.teleport(adv.goal_point + Vector3(20, 0.4, 0))
	await frames(5)
	check_eq(completed[0], 0, "no completion while the duckling is far behind")
	d.teleport(adv.goal_point + Vector3(2, 0.4, 0))
	await frames(5)
	check_eq(completed[0], 1, "adventure completes with the duckling at the goal")
	check("forest_edge_walk" in GameState.adventures_done, "completion recorded in GameState")
	await frames(30)
	check_eq(completed[0], 1, "does not complete twice")
	finish()

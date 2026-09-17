extends WaddleTest
## Quack grammar (5.2): gesture recognition in the input layer, place-based
## resolution (far call vs. lullaby) in the duck, and the lullaby's silent exit (8.G.3).

func _init() -> void:
	test_name = "CALLS"

func run(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var n := nest(main)
	var gestures: Array = []
	InputRouter.call_gesture.connect(func(_pid, g): gestures.append(g))
	var calls: Array = []
	EventBus.call_made.connect(func(k): calls.append(k))

	# Gesture recognition (physics frames at 60 Hz drive the router's own clock).
	InputRouter.sim_call_down(); InputRouter.sim_call_up()
	await frames(10)
	check_eq(gestures.size(), 0, "single tap waits for the double-tap window")
	await frames(20)
	check_eq(gestures, ["tap"], "tap resolves after the window")
	InputRouter.sim_call_down(); InputRouter.sim_call_up()
	await frames(5)
	InputRouter.sim_call_down(); InputRouter.sim_call_up()
	await frames(25)
	check_eq(gestures, ["tap", "double"], "two taps inside the window make a double")
	InputRouter.sim_call_down()
	await frames(35)
	check_eq(gestures, ["tap", "double", "hold"], "holding 450 ms makes a hold")
	InputRouter.sim_call_up()
	await frames(25)
	check_eq(gestures.size(), 3, "release after hold does not add a tap")

	# Resolution: same hold means different things by place.
	m.teleport(n.global_position + Vector3(12, 0.5, 0))
	await frames(2)
	check_eq(calls, ["gather", "look", "far"], "hold away from the nest is a far call", calls)
	m.teleport(n.global_position + Vector3(1.0, 0.5, 0))
	await frames(2)
	InputRouter.sim_call_down()
	await frames(35)
	InputRouter.sim_call_up()
	check_eq(calls.back(), "lullaby", "hold at the nest is a lullaby")

	# Lullaby puts the brood down; they get up when the mother leaves.
	var brood := await bootstrap_brood(main, 2)
	m.make_call("lullaby")
	await frames(2)
	for d in brood:
		check_eq(d.state, d.State.SLEEP, "hatchling sleeps after the lullaby")
	await frames(60)
	check_eq(brood[0].state, brood[0].State.SLEEP, "still asleep while the mother stays")
	m.teleport(n.global_position + Vector3(9, 0.5, 0))
	await frames(5)
	check_eq(brood[0].state, brood[0].State.NEST, "wakes up when the mother walks away")

	# Gather: only within earshot. Far call: everyone.
	var d0 = brood[0]
	var d1 = brood[1]
	for d in brood:
		d.data["nest_bound"] = false
		d.data["stage"] = 1
	d0.state = d0.State.ROAM
	d1.state = d1.State.ROAM
	d0._roam_timer = 999.0
	d1._roam_timer = 999.0
	d0.teleport(m.global_position + Vector3(8, 0, 0))
	d1.teleport(m.global_position + Vector3(20, 0, 0))
	d0._roam_target = d0.global_position
	d1._roam_target = d1.global_position
	m.make_call("gather")
	check_eq(d0.state, d0.State.FOLLOW, "gather reaches a duckling 8 m away")
	check_eq(d1.state, d1.State.ROAM, "gather does not reach a duckling 20 m away")
	m.make_call("far")
	check_eq(d1.state, d1.State.FOLLOW, "far call reaches everyone")

	# Look: run towards the mother's facing direction.
	m.facing = Vector3(0, 0, -1)
	m.make_call("look")
	check_eq(d0.state, d0.State.LOOK, "look sends ducklings looking")
	check_near(d0._target.z, m.global_position.z - 4.0, 0.01, "look target lies 4 m ahead of the mother")
	finish()

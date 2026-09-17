extends WaddleTest
## Water physics: buoyancy settles at the surface, dabbling is a target depth (8.B.2),
## the duck gets out of the pond again (8.B.1), and the step assist works on a ledge.

func _init() -> void:
	test_name = "WATER"

func run(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var surface: float = p.WATER_SURFACE_Y
	var finished := []
	EventBus.dabble_finished.connect(func(r): finished.append(r))

	m.teleport(p.POND_CENTER + Vector3(0, 0.6, 0))
	await frames(120)
	check(m.is_in_water, "duck is in water at the pond centre")
	check_near(m.global_position.y, surface + m.FLOAT_OFFSET, 0.08, "floats at the surface")

	# Dabble: sinks to a target depth, never further, resurfaces with a result.
	InputRouter.sim_dive(true)
	await frames(60)
	check(m.is_dabbling, "dabbling while dive is held in water")
	check(AudioManager.muffled, "audio muffled under water")
	var min_y := 10.0
	for i in 200:
		await frames(1)
		min_y = minf(min_y, m.global_position.y)
	check(min_y > surface - m.DABBLE_DEPTH - 0.25, "never sinks past the target depth", min_y)
	check(min_y < surface - m.DABBLE_DEPTH + 0.25, "actually reaches the target depth", min_y)
	check_eq(finished.size(), 1, "dabble finished once after ~3 s", finished)
	check(finished.size() > 0 and finished[0] in ["food", "keepsake"], "dabble yields food or a keepsake", finished)
	var food := int(GameState.mother["carried_food"])
	var keep: String = GameState.mother["carried_keepsake"]
	check(food == 1 or keep != "", "result reached the inventory", [food, keep])
	InputRouter.sim_dive(false)
	await frames(30)
	check(not m.is_dabbling, "stops dabbling on release")
	check(not AudioManager.muffled, "audio restored")

	# Get out of the water: walk straight to the shore and past it.
	InputRouter.sim_move(Vector2(0, -1))   # camera-relative "forward" == +Z with the default rig (camera behind a +Z-facing duck)
	await frames(60 * 6)
	InputRouter.sim_move(Vector2.ZERO)
	check(not m.is_in_water, "walked out of the pond", m.global_position)
	check(m.global_position.z > p.POND_CENTER.z + p.POND_RADIUS, "well past the shore", m.global_position.z)
	check(m.global_position.y > -0.2, "back on land height", m.global_position.y)

	# Step assist: a 0.3 m ledge across the path must not stop the duck.
	var ledge := StaticBody3D.new()
	ledge.collision_layer = 1
	ledge.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.3, 1.0)
	cs.shape = box
	ledge.add_child(cs)
	p.add_child(ledge)
	ledge.global_position = Vector3(-20, 0.15, 20)
	m.teleport(Vector3(-20, 0.6, 23))
	await frames(20)
	InputRouter.sim_move(Vector2(0, 1))   # "back" == -Z: towards the ledge at z=20
	await frames(60 * 3)
	InputRouter.sim_move(Vector2.ZERO)
	check(m.global_position.z < 18.5, "climbed the ledge instead of sticking to it", m.global_position.z)
	finish()

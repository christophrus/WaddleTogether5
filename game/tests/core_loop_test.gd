extends WaddleTest
## The core loop from section 4: build nest -> lay eggs -> hatch -> feed at the nest
## -> grow -> follow -> fledge. Uses the real interaction path, not debug shortcuts.

func _init() -> void:
	test_name = "CORE_LOOP"

func run(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var n := nest(main)
	var completed := spy(EventBus.nest_completed)
	var hatched := spy(EventBus.egg_hatched)
	var left := spy(EventBus.duckling_left_nest)
	var fledged := spy(EventBus.duckling_fledged)

	# 1. Nest material
	m.teleport(n.global_position + Vector3(1.2, 0.5, 0))
	await frames(5)
	check(not n.is_built(), "nest starts unbuilt")
	check_eq(m.current_prompt, "", "no prompt without material")
	GameState.mother["carried_material"] = 4
	await frames(2)
	check(m.current_prompt.begins_with("Nistmaterial"), "prompt offers material delivery", m.current_prompt)
	m.interact()
	check_eq(int(GameState.nest["material"]), 4, "4 material delivered")
	check_eq(int(GameState.nest["stage"]), 1, "stage 1 after 4 material")
	check(not n.is_built(), "not built yet")
	GameState.mother["carried_material"] = 20
	m.interact()
	check(n.is_built(), "nest built after enough material")
	check_eq(int(GameState.nest["material"]), n.material_needed(), "material capped at needed")
	check_eq(completed[0], 1, "nest_completed emitted once")
	check(Progression.is_unlocked("meadow"), "meadow unlocked by nest completion")

	# 2. Eggs, max 4
	await frames(2)
	check_eq(m.current_prompt, "Ei legen", "prompt offers laying")
	for i in 5:
		m.interact()
	check_eq(GameState.eggs.size(), 4, "egg count capped at 4")
	check_eq(GameState.egg_slots_free(), 0, "no free slots")
	await frames(2)
	check_eq(m.current_prompt, "", "no prompt when nest is full")

	# 3. Brooding only while the mother is close (ritual, 3.3)
	n.incubation_seconds = 0.5
	m.teleport(n.global_position + Vector3(8, 0.5, 0))
	await frames(40)
	check_eq(hatched[0], 0, "eggs do not progress while the mother is away")
	m.teleport(n.global_position + Vector3(1.0, 0.5, 0))
	await frames(60)
	check_eq(hatched[0], 4, "all four eggs hatched with the mother brooding")
	var brood := ducklings(main)
	check_eq(brood.size(), 4, "four ducklings spawned")
	for d in brood:
		check(bool(d.data["nest_bound"]), "hatchling is nest-bound")
	var temps := brood.map(func(d): return d.data["temperament"])
	var unique := {}
	for t in temps:
		unique[t] = true
	check_eq(unique.size(), 4, "temperaments distinct within the clutch", temps)

	# 4. Feeding at the nest until one leaves it
	var d0 = brood[0]
	GameState.mother["carried_food"] = 10
	var fed_before := int(d0.data["feedings"])
	for i in 3:
		# Reset hunger between feedings: a full duckling is a no-op target (8.F.2).
		for d in brood:
			d.data["hunger"] = 0.0
		d0.data["hunger"] = 1.0
		await frames(2)
		check_eq(m.current_prompt, "Küken füttern", "prompt offers feeding hungry hatchling (%d)" % i)
		m.interact()
	check_eq(int(d0.data["stage"]), 1, "duckling grew to stage 1 after 3 feedings")
	check(not bool(d0.data["nest_bound"]), "grown duckling left the nest")
	check_eq(left[0], 1, "duckling_left_nest emitted once")
	check_eq(GameState.egg_slots_free(), 1, "a slot frees up when a duckling leaves")
	check_eq(int(GameState.mother["carried_food"]), 7, "three food consumed")

	# 5. Following
	m.teleport(n.global_position + Vector3(7, 0.5, 4))
	await frames(240)
	var dist: float = d0.global_position.distance_to(m.global_position)
	check(dist < 3.5, "grown duckling follows the mother", dist)
	var stayed = brood[1]
	var nest_dist: float = stayed.global_position.distance_to(n.global_position)
	check(nest_dist < 2.5, "hatchling stays at the nest", nest_dist)

	# 6. Fledging via direct feeding
	for i in 5:
		d0.data["hunger"] = 1.0
		GameState.mother["carried_food"] = 1
		d0.interact(m)
	check(d0.growth.is_fledged(), "fledged after 5 more feedings", d0.data["stage"])
	check_eq(fledged[0], 1, "duckling_fledged emitted")
	check(Progression.is_unlocked("forest_edge"), "forest edge unlocked by fledging")
	check(GameState.journal.size() >= 5, "journal wrote memories", GameState.journal.size())
	finish()

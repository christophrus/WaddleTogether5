extends WaddleTest
## 8.D.2: the brood-progress parameter must be read back from the material that is
## actually rendered, not from a duplicate nobody displays.

func _init() -> void:
	test_name = "MATERIAL"

func run(main: Node) -> void:
	var m := mother(main)
	var n := nest(main)
	n.debug_complete()
	var id_a: int = n.lay_egg()
	var id_b: int = n.lay_egg()
	check(id_a > 0 and id_b > id_a, "two eggs laid", [id_a, id_b])
	var mat_a: Material = n.rendered_egg_material(id_a)
	var mat_b: Material = n.rendered_egg_material(id_b)
	check(mat_a != null and mat_b != null, "rendered materials exist")
	check(mat_a != mat_b, "each egg renders its own material instance")
	n.incubation_seconds = 4.0
	m.teleport(n.global_position + Vector3(1.0, 0.5, 0))
	await frames(90)
	var shown: float = mat_a.get_shader_parameter("progress")
	var state: float = GameState.eggs[0]["progress"]
	check(shown > 0.15, "rendered progress advanced", shown)
	check_near(shown, state, 0.03, "rendered progress matches the game state")
	finish()

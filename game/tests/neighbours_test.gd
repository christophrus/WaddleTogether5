extends WaddleTest
## Shy neighbours (5.8): comfort shrinks while the family is calm nearby, a fright
## costs progress but never exceeds day one, a far call startles, the heron stalks
## away, the turtle never moves, and befriending is permanent.

func _init() -> void:
	test_name = "NEIGHBOURS"

func run(main: Node) -> void:
	var m := mother(main)
	var frog: Node3D = _find("frog")
	var heron: Node3D = _find("heron")
	var turtle: Node3D = _find("turtle")
	check(frog != null and heron != null and turtle != null, "three neighbours exist")
	var befriended: Array = []
	EventBus.neighbour_befriended.connect(func(id): befriended.append(id))

	# Startle never exceeds the start value.
	frog.comfort = frog.start_comfort
	frog.startle()
	check_eq(frog.comfort, frog.start_comfort, "startle at day one changes nothing")
	frog.comfort = frog.start_comfort - 2.0
	frog.startle()
	check(frog.comfort < frog.start_comfort and frog.comfort > frog.start_comfort - 2.0, "startle costs progress but stays below day one", frog.comfort)
	var before: float = frog.comfort
	EventBus.call_made.emit("far")
	check(frog.comfort > before, "far call startles the frog", frog.comfort)
	var t_before: float = turtle.comfort
	turtle.startle()
	check_eq(turtle.comfort, t_before, "turtle is unimpressable")

	# Calm proximity shrinks comfort; fast approach does not.
	frog.comfort = frog.start_comfort
	frog.calm_rate = 4.0   # time-lapse
	m.teleport(frog.home + Vector3(frog.start_comfort + 3.0, 0.5, 0))
	m.velocity = Vector3.ZERO
	await frames(30)
	check(frog.comfort < frog.start_comfort, "comfort shrinks while the mother idles nearby", frog.comfort)
	await frames(90)
	check("frog" in befriended, "frog befriended after calm time", befriended)
	check(frog.befriended, "frog flag set")
	check(bool(GameState.neighbours["frog"]["befriended"]), "friendship written to GameState")
	frog.comfort = 5.0
	m.teleport(frog.home + Vector3(0.8, 0.5, 0))
	var fpos: Vector3 = frog.global_position
	await frames(60)
	check(frog.global_position.distance_to(fpos) < 0.5, "befriended frog no longer flees", frog.global_position.distance_to(fpos))

	# Heron stalks away continuously; turtle never moves.
	m.teleport(heron.home + Vector3(1.0, 0.5, 0))
	var hpos: Vector3 = heron.global_position
	await frames(90)
	var moved: float = heron.global_position.distance_to(hpos)
	check(moved > 0.8, "heron walks away from a close mother", moved)
	check(heron.global_position.distance_to(heron.home) <= heron.wander_radius + 0.05, "heron stays inside its wander radius")
	m.teleport(turtle.home + Vector3(0.7, 0.5, 0))
	var tpos: Vector3 = turtle.global_position
	await frames(90)
	check(turtle.global_position.distance_to(tpos) < 0.01, "turtle never flees")
	turtle.calm_rate = 4.0
	await frames(60)
	check("turtle" in befriended, "turtle is the easiest to befriend", befriended)
	finish()

func _find(id: String) -> Node3D:
	for n in get_tree().get_nodes_in_group("neighbour"):
		if n.neighbour_id == id:
			return n
	return null

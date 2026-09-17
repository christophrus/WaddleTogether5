extends WaddleTest
## Day/night clock and warmth (5.6): the night peep ramps while alone and stops the
## moment the mother arrives; passive sleep needs warm AND at the nest (8.G.1).

func _init() -> void:
	test_name = "DAYTIME_WARMTH"

func run(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var n := nest(main)
	var dawns := spy(EventBus.dawn_broke)
	var nights := spy(EventBus.night_fell)

	Daytime.set_time(0.5)
	check(not Daytime.is_night(), "midday is not night")
	var noon_sky := Daytime.sky_color()
	Daytime.set_time(0.9)
	check(Daytime.is_night(), "0.9 is night")
	check(Daytime.sky_color().v < noon_sky.v, "night sky darker than noon", [Daytime.sky_color().v, noon_sky.v])
	Daytime.set_time(0.75)
	Daytime.advance(0.1)
	check_eq(nights[0], 1, "night_fell emitted when crossing into night")
	var day_before := GameState.day_index
	Daytime.advance(0.2)
	check_eq(dawns[0], 1, "dawn_broke emitted when the day wraps")
	check_eq(GameState.day_index, day_before + 1, "day index advanced")
	check(GameState.day_time < 0.1, "time wrapped around", GameState.day_time)
	check(p.sun.light_energy < 0.2, "sun is dim right after midnight", p.sun.light_energy)

	# Warmth: a follower stuck far away peeps at night; silent once the mother is near.
	var brood := await bootstrap_brood(main, 1)
	var d = brood[0]
	d.data["nest_bound"] = false
	d.data["stage"] = 1
	d.state = d.State.FOLLOW
	d.follow.speed = 0.0   # pin it in place so distance stays constant
	Daytime.set_time(0.9)
	m.teleport(Vector3(0, 0.5, 6))
	d.teleport(Vector3(14, 0.4, 6))
	var before := AudioManager.peep_count
	await frames(60 * 7)
	var peeps_alone := AudioManager.peep_count - before
	check(peeps_alone >= 1, "alone at night: at least one peep in 7 s", peeps_alone)
	await frames(60 * 20)
	var peeps_20 := AudioManager.peep_count - before - peeps_alone
	check(peeps_20 >= 4, "interval ramps up the longer it stays alone", peeps_20)
	m.teleport(d.global_position + Vector3(1.5, 0.1, 0))
	await frames(2)
	before = AudioManager.peep_count
	await frames(60 * 8)
	check_eq(AudioManager.peep_count - before, 0, "silent the moment the mother is close")

	# Day: no peeps even when alone.
	Daytime.set_time(0.5)
	m.teleport(Vector3(0, 0.5, 6))
	before = AudioManager.peep_count
	await frames(60 * 8)
	check_eq(AudioManager.peep_count - before, 0, "no warmth peeps by day")

	# Sleep needs warm AND at the nest.
	Daytime.set_time(0.9)
	d.follow.speed = 3.2
	m.teleport(Vector3(-10, 0.5, 14))
	d.teleport(Vector3(-9, 0.4, 14))
	await frames(90)
	check(d.state != d.State.SLEEP, "warm but away from the nest: stays awake", d.state)
	m.teleport(n.global_position + Vector3(1.0, 0.5, 0))
	d.teleport(n.global_position + Vector3(-1.0, 0.4, 0))
	await frames(30)
	check_eq(d.state, d.State.SLEEP, "warm and at the nest: falls asleep")
	m.teleport(n.global_position + Vector3(9, 0.5, 0))
	await frames(5)
	check_eq(d.state, d.State.FOLLOW, "wakes when the mother leaves")
	finish()

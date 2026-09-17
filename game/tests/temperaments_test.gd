extends WaddleTest
## Personalities (5.4): six distinct temperaments handed out without duplicates, each
## fast at something and slow at something, each with its own voice and look.

func _init() -> void:
	test_name = "TEMPERAMENTS"

func run(main: Node) -> void:
	var reg = load("res://game/data/temperaments.gd")
	var all: Array = reg.all()
	check_eq(all.size(), 6, "six temperaments")
	var pitches := {}
	var names := {}
	for t in all:
		check(t.display_name != "" and t.id != "", "temperament has id and name: %s" % t.id)
		var fast := false
		var slow := false
		for skill in ["foraging", "swimming", "dabbling", "courage"]:
			var v := float(t.learn_mult.get(skill, 1.0))
			if v > 1.0: fast = true
			if v < 1.0: slow = true
		check(fast and slow, "%s is fast at something and slow at something" % t.id, t.learn_mult)
		pitches[t.pitch] = true
		names[t.display_name] = true
		check(t.name_suggestions.size() >= 2, "%s has name suggestions" % t.id)
	check_eq(pitches.size(), 6, "six distinct peep pitches")
	check_eq(names.size(), 6, "six distinct display names")
	var greedy = reg.get_by_id("greedy")
	var anxious = reg.get_by_id("anxious")
	check_near(float(greedy.learn_mult["foraging"]), 2.0, 0.001, "the greedy one learns foraging twice as fast")
	check(float(greedy.learn_mult["courage"]) < 1.0, "…but courage slower")
	check(float(anxious.learn_mult["swimming"]) < 0.6, "the anxious one barely dares the water")
	check(float(anxious.learn_mult["foraging"]) > 1.0, "…but learns attentively at food")

	# Distribution without duplicates while supply lasts.
	GameState.used_temperaments.clear()
	var picked := {}
	for i in 6:
		picked[reg.pick_unused().id] = true
	check_eq(picked.size(), 6, "six picks yield six different temperaments")
	var seventh = reg.pick_unused()
	check(seventh != null and seventh.id in reg.IDS, "seventh pick recycles the pool")
	check_eq(GameState.used_temperaments.size(), 1, "pool reset after exhaustion")

	# Visible in the duckling: tint, scale, pitch, follow distance.
	var brood := await bootstrap_brood(main, 2)
	var a = brood[0]
	var b = brood[1]
	check(a.temperament != null and b.temperament != null, "ducklings carry temperaments")
	check(a.peep_pitch != b.peep_pitch, "sibling voices differ", [a.peep_pitch, b.peep_pitch])
	check(a.follow.follow_distance != b.follow.follow_distance, "sibling follow distances differ")
	finish()

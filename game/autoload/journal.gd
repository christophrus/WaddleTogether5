extends Node
## Listens to the world and writes diary lines. No system knows the journal exists;
## it only ever reads signals, so adding a memory never touches gameplay code.

func _ready() -> void:
	EventBus.nest_completed.connect(func(): _add("Das Nest ist fertig. Es riecht nach Gras und Sonne."))
	EventBus.egg_laid.connect(func(_id): _add("Ein neues Ei liegt im Nest. Ich bleibe heute in der Nähe."))
	EventBus.egg_hatched.connect(func(_id): _add("Ein Küken ist geschlüpft! Es piepst schon nach mir."))
	EventBus.duckling_named.connect(func(_id, n): _add("Heute habe ich beim Kuscheln einen Namen gefunden: %s." % n))
	EventBus.duckling_left_nest.connect(func(id): _add("%s hat das Nest verlassen und watschelt mir hinterher." % _name(id)))
	EventBus.duckling_fledged.connect(func(id): _add("%s ist heute zum ersten Mal geflogen. Nur ein paar Meter. Ich war so stolz." % _name(id)))
	EventBus.duckling_learned.connect(_on_learned)
	EventBus.zone_unlocked.connect(func(z): _add(_zone_line(z)))
	EventBus.adventure_completed.connect(func(_a): _add("Wir waren am Waldrand. Die Kleinen haben zum ersten Mal Moos gesehen."))
	EventBus.neighbour_befriended.connect(func(n): _add(_neighbour_line(n)))
	EventBus.keepsake_placed.connect(func(k, f): _add("%s hat %s ans Nest gelegt. Es glänzt." % [f, _keepsake(k)]))
	EventBus.dawn_broke.connect(func(d): _add("Tag %d. Die Sonne geht auf über dem Teich." % d))
	EventBus.new_generation.connect(func(n): _add("Eines Morgens lagen wieder Eier im Nest: %d. Die Großen schauen neugierig herüber." % n))
	EventBus.helper_promoted.connect(func(id): _add("%s hilft mir jetzt mit den Kleinen. Ich werde langsam überflüssig – und das ist gut so." % _name(id)))

func entries() -> Array:
	return GameState.journal

func _add(text: String) -> void:
	GameState.journal.append({"day": GameState.day_index, "text": text})
	EventBus.journal_entry_added.emit(text)

func _name(id: int) -> String:
	var d := GameState.get_duckling(id)
	if d.is_empty() or d["name"] == "":
		return "Ein Küken"
	return d["name"]

func _on_learned(id: int, skill: String, threshold: int) -> void:
	# Behaviour, never numbers: the diary describes what changed, not what was gained.
	var n := _name(id)
	var key := "%s_%d" % [skill, threshold]
	match key:
		"foraging_1": _add("%s hat heute allein gepickt. Ganz nebenbei, als wäre es nichts." % n)
		"foraging_2": _add("%s hat mir ein Stück Futter gebracht. Mir!" % n)
		"swimming_1": _add("%s hat sich ins Wasser getraut. Erst einen Fuß, dann alles." % n)
		"dabbling_1": _add("%s hat gegründelt. Popo in der Luft, wie ich." % n)
		"courage_1": _add("%s streift jetzt allein umher und kommt mit Fundstücken zurück." % n)
		"courage_2": _add("%s hat ein Geschwisterchen zurückgeholt, das sich verlaufen hatte." % n)

func _zone_line(z: String) -> String:
	match z:
		"meadow": return "Der Weg zur Wiese ist frei. Da wächst Löwenzahn."
		"forest_edge": return "Wir trauen uns jetzt bis zum Waldrand."
	return "Ein neuer Ort ist offen."

func _neighbour_line(n: String) -> String:
	match n:
		"frog": return "Der Frosch springt nicht mehr weg. Er sitzt einfach da und quakt zurück."
		"heron": return "Der Reiher hat sich verneigt. Wenigstens glaube ich das."
		"turtle": return "Die Schildkröte war nie scheu. Ich habe es nur erst heute gemerkt."
	return "Ein Nachbar mag uns jetzt."

func _keepsake(k: String) -> String:
	match k:
		"bottle_cap": return "einen Kronkorken"
		"marble": return "eine Murmel"
		"button": return "einen Knopf"
		"blue_glass": return "eine blaue Glasscherbe"
		"pebble": return "einen glatten Kiesel"
	return "etwas Glänzendes"

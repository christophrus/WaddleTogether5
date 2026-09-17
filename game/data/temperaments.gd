extends Object
## Registry for the six temperaments. Per clutch they are handed out without
## duplicates while the supply lasts; the used list lives in GameState.

const IDS := ["curious", "anxious", "greedy", "dreamy", "brave", "clingy"]
static var _cache: Dictionary = {}

static func get_by_id(id: String) -> Temperament:
	if _cache.has(id):
		return _cache[id]
	var path := "res://game/data/temperaments/%s.tres" % id
	var t: Temperament = load(path) if ResourceLoader.exists(path) else null
	if t == null:
		t = Temperament.new()
		t.id = id
	_cache[id] = t
	return t

static func all() -> Array:
	var out: Array = []
	for id in IDS:
		out.append(get_by_id(id))
	return out

static func pick_unused() -> Temperament:
	var free: Array = IDS.filter(func(id): return not (id in GameState.used_temperaments))
	if free.is_empty():
		GameState.used_temperaments.clear()
		free = IDS.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var id: String = free[rng.randi_range(0, free.size() - 1)]
	GameState.used_temperaments.append(id)
	return get_by_id(id)

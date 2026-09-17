extends Node
## Serialisable world state. Entities reference each other by id, never by node
## path, so a save file (and one day a network peer) can rebuild the world from
## this dictionary alone. Everything that counts as progress lives here (see 8.G.6).

const MAX_EGGS := 4
const SKILLS := ["foraging", "swimming", "dabbling", "courage"]

var day_index: int = 1
var day_time: float = 0.3          # 0..1, saved so a night save loads at night
var next_id: int = 1

var mother := {}
var nest := {}
var eggs: Array = []        # {id, progress}
var ducklings: Array = []   # see new_duckling()
var keepsakes: Array = []   # {kind, angle, radius, finder}
var neighbours: Dictionary = {}  # id -> {comfort, befriended}
var unlocked_zones: Array = ["pond"]
var adventures_done: Array = []
var journal: Array = []     # {day, text}
var generation: int = 1
var used_temperaments: Array = []

func _init() -> void:
	reset()

func reset() -> void:
	day_index = 1
	day_time = 0.3
	next_id = 1
	mother = {"position": [0.0, 0.0, 6.0], "carried_food": 0, "carried_material": 0, "carried_keepsake": ""}
	nest = {"material": 0, "stage": 0, "built": false}
	eggs = []
	ducklings = []
	keepsakes = []
	neighbours = {}
	unlocked_zones = ["pond"]
	adventures_done = []
	journal = []
	generation = 1
	used_temperaments = []

func allocate_id() -> int:
	var id := next_id
	next_id += 1
	return id

func new_duckling(temperament: String) -> Dictionary:
	var d := {
		"id": allocate_id(),
		"name": "",
		"temperament": temperament,
		"stage": 0,
		"feedings": 0,
		"hunger": 0.4,
		"affection": 0.0,
		"skills": {"foraging": 0.0, "swimming": 0.0, "dabbling": 0.0, "courage": 0.0},
		"position": [0.0, 0.0, 0.0],
		"nest_bound": true,
		"is_helper": false,
		"generation": generation,
	}
	ducklings.append(d)
	return d

func get_duckling(id: int) -> Dictionary:
	for d in ducklings:
		if int(d["id"]) == id:
			return d
	return {}

func egg_slots_free() -> int:
	# A slot frees up the moment a duckling leaves the nest, not when it fledges:
	# the nest is a place for eggs and hatchlings, not a family register.
	var occupied := eggs.size()
	for d in ducklings:
		if d["nest_bound"]:
			occupied += 1
	return maxi(0, MAX_EGGS - occupied)

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"day_index": day_index,
		"day_time": day_time,
		"next_id": next_id,
		"mother": mother.duplicate(true),
		"nest": nest.duplicate(true),
		"eggs": eggs.duplicate(true),
		"ducklings": ducklings.duplicate(true),
		"keepsakes": keepsakes.duplicate(true),
		"neighbours": neighbours.duplicate(true),
		"unlocked_zones": unlocked_zones.duplicate(),
		"adventures_done": adventures_done.duplicate(),
		"journal": journal.duplicate(true),
		"generation": generation,
		"used_temperaments": used_temperaments.duplicate(),
	}

func from_dict(data: Dictionary) -> void:
	reset()
	day_index = int(data.get("day_index", 1))
	day_time = float(data.get("day_time", 0.3))
	next_id = int(data.get("next_id", 1))
	mother.merge(data.get("mother", {}), true)
	nest.merge(data.get("nest", {}), true)
	eggs = data.get("eggs", [])
	ducklings = data.get("ducklings", [])
	keepsakes = data.get("keepsakes", [])
	neighbours = data.get("neighbours", {})
	unlocked_zones = data.get("unlocked_zones", ["pond"])
	adventures_done = data.get("adventures_done", [])
	journal = data.get("journal", [])
	generation = int(data.get("generation", 1))
	used_temperaments = data.get("used_temperaments", [])
	# JSON turns every int into a float; normalise the ids and counters we compare with ==.
	for d in ducklings:
		d["id"] = int(d["id"])
		d["stage"] = int(d["stage"])
		d["feedings"] = int(d["feedings"])
	for e in eggs:
		e["id"] = int(e["id"])
	nest["material"] = int(nest["material"])
	nest["stage"] = int(nest["stage"])
	mother["carried_food"] = int(mother["carried_food"])
	mother["carried_material"] = int(mother["carried_material"])

static func v3_to_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func arr_to_v3(a) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(a[0], a[1], a[2])
	return Vector3.ZERO

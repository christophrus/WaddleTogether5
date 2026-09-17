extends Node
## The generations cycle (5.10), the finale: once the whole brood has fledged, one
## morning there are eggs in the nest again. The old brood does not vanish — they
## become helpers who teach with the very same signal the mother uses. "Success is
## becoming unnecessary."

const NEW_CLUTCH := 3

var _park: Node3D

func _ready() -> void:
	_park = get_tree().get_first_node_in_group("park")
	EventBus.dawn_broke.connect(_on_dawn)

func _on_dawn(_day: int) -> void:
	if not _ready_for_next_generation():
		return
	start_next_generation()

func _ready_for_next_generation() -> bool:
	if _park == null or _park.nest == null or not _park.nest.is_built():
		return false
	if not GameState.eggs.is_empty():
		return false
	var brood: Array = _park.ducklings()
	if brood.is_empty():
		return false
	for d in brood:
		if bool(d.data["nest_bound"]) or not d.growth.is_fledged():
			return false
	return true

func start_next_generation() -> void:
	for d in _park.ducklings():
		if not bool(d.data.get("is_helper", false)):
			d.promote_to_helper()
	GameState.generation += 1
	var laid := 0
	for i in mini(NEW_CLUTCH, GameState.egg_slots_free()):
		if _park.nest.lay_egg() >= 0:
			laid += 1
	EventBus.new_generation.emit(laid)

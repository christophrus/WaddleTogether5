extends Node
## Translates milestones into unlocked zones. All rules in one place so nothing else
## has to know why a gate opened.

const RULES := {
	"nest_completed": "meadow",
	"duckling_fledged": "forest_edge",
}

func _ready() -> void:
	EventBus.nest_completed.connect(func(): unlock(RULES["nest_completed"]))
	EventBus.duckling_fledged.connect(func(_id): unlock(RULES["duckling_fledged"]))

func is_unlocked(zone_id: String) -> bool:
	return zone_id in GameState.unlocked_zones

func unlock(zone_id: String) -> void:
	if is_unlocked(zone_id):
		return
	GameState.unlocked_zones.append(zone_id)
	EventBus.zone_unlocked.emit(zone_id)

extends Node
## Data-driven growth: stages come from a .tres so tuning never touches code. The
## last stage triggers the first flight; leaving stage 0 ends the nest-bound phase.

var stages_resource: Resource
var data: Dictionary

func _ready() -> void:
	if stages_resource == null:
		stages_resource = load("res://game/data/growth_stages.tres")

func bind(record: Dictionary) -> void:
	data = record

func stage_index() -> int:
	return int(data.get("stage", 0))

func stage() -> Resource:
	var s: Array = stages_resource.stages
	return s[clampi(stage_index(), 0, s.size() - 1)]

func is_fledged() -> bool:
	return stage_index() >= stages_resource.stages.size() - 1

func is_nest_bound() -> bool:
	return bool(data.get("nest_bound", true))

## One feeding. Returns true when it caused a growth step.
func feed() -> bool:
	data["feedings"] = int(data["feedings"]) + 1
	if is_fledged():
		return false
	if int(data["feedings"]) >= stage().feedings_to_grow:
		data["feedings"] = 0
		data["stage"] = stage_index() + 1
		EventBus.duckling_grew.emit(int(data["id"]), stage_index())
		if stage_index() == 1 and is_nest_bound():
			data["nest_bound"] = false
			EventBus.duckling_left_nest.emit(int(data["id"]))
		if is_fledged():
			EventBus.duckling_fledged.emit(int(data["id"]))
			AudioManager.play_sfx("fledge")
		return true
	return false

func apply_visuals(model: Node3D, tint_mult: float = 1.0) -> void:
	var s: Resource = stage()
	model.scale = Vector3.ONE * s.scale * tint_mult

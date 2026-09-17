extends Node
## Learning by imitation, the heart of the game (5.3). Four silent values grow *only*
## when someone demonstrates something within sight. Proximity-based on purpose: the
## mother has to do the thing where the brood can watch, which quietly turns ordinary
## movement into teaching without ever adding a fail state.
##
## Nothing here may ever reach a UI bar (rule 3.1). Thresholds unlock behaviours and
## the behaviours are the only display.

const SIGHT_RADIUS := 7.0
const EDGE_ATTENTION := 0.35   # attention at the edge of sight, never zero
const THRESHOLDS := {
	"foraging": [0.3, 0.7],   # picks alone | brings you food
	"swimming": [0.4],        # dares the water
	"dabbling": [0.5],        # dabbles alone
	"courage": [0.4, 0.8],    # roams, finds keepsakes | fetches strays
}

var data: Dictionary
var learn_mult: Dictionary = {}
var owner_body: Node3D

func _ready() -> void:
	EventBus.mother_demonstrated.connect(_on_demonstrated)

func bind(record: Dictionary, body: Node3D, temperament: Resource) -> void:
	data = record
	owner_body = body
	learn_mult = temperament.learn_mult if temperament != null else {}

func level(skill: String) -> float:
	return float(data["skills"].get(skill, 0.0))

## Threshold index is 1-based: has("foraging", 2) means "brings food".
func has(skill: String, threshold: int) -> bool:
	var t: Array = THRESHOLDS.get(skill, [])
	if threshold < 1 or threshold > t.size():
		return false
	return level(skill) >= t[threshold - 1]

func _on_demonstrated(skill: String, position: Vector3, amount: float) -> void:
	if data.is_empty() or owner_body == null or not is_instance_valid(owner_body):
		return
	if bool(data.get("is_helper", false)):
		return  # helpers teach, they no longer learn
	var d := owner_body.global_position.distance_to(position)
	if d > SIGHT_RADIUS:
		return
	var attention := lerpf(1.0, EDGE_ATTENTION, d / SIGHT_RADIUS)
	var mult := float(learn_mult.get(skill, 1.0))
	var before := level(skill)
	var after := minf(1.0, before + amount * attention * mult)
	data["skills"][skill] = after
	var thresholds: Array = THRESHOLDS.get(skill, [])
	for i in thresholds.size():
		if before < thresholds[i] and after >= thresholds[i]:
			EventBus.duckling_learned.emit(int(data["id"]), skill, i + 1)

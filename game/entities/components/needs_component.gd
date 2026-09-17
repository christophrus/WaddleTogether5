extends Node
## Soft needs. Hunger drifts 0 (full) -> 1 (hungry) and nudges behaviour and sounds;
## it never takes anything away (rule 3.2). Values live in the duckling's GameState
## record so they save for free.

const HUNGRY_THRESHOLD := 0.35

var hunger_rate := 1.0 / 360.0   # ~6 minutes from full to hungry; tests override
var data: Dictionary

func bind(record: Dictionary) -> void:
	data = record

func tick(delta: float) -> void:
	if data.is_empty():
		return
	data["hunger"] = minf(1.0, float(data["hunger"]) + hunger_rate * delta)

func hunger() -> float:
	return float(data.get("hunger", 0.0))

func is_hungry() -> bool:
	return hunger() > HUNGRY_THRESHOLD

func feed(amount := 0.5) -> void:
	data["hunger"] = maxf(0.0, hunger() - amount)
	data["affection"] = minf(1.0, float(data.get("affection", 0.0)) + 0.05)

func cuddle() -> void:
	data["affection"] = minf(1.0, float(data.get("affection", 0.0)) + 0.1)

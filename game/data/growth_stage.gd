extends Resource
class_name GrowthStage
## One growth stage. Tuned in growth_stages.tres, never in code.

@export var stage_name := "Küken"
@export var scale := 0.5
@export var color := Color(0.98, 0.88, 0.35)
@export var feedings_to_grow := 3

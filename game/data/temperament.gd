extends Resource
class_name Temperament
## A duckling personality. Shows three ways: eye (tint + size), ear (peep pitch) and
## behaviour (learning speeds, follow distance). Balance rule: every temperament is
## fast at something and slow at something. None is better.

@export var id := "curious"
@export var display_name := "die Neugierige"
@export var color_tint := Color(1, 1, 1)
@export var scale_mult := 1.0
@export var pitch := 1.0
@export var learn_mult := {"foraging": 1.0, "swimming": 1.0, "dabbling": 1.0, "courage": 1.0}
@export var follow_distance := 1.6
@export var roam_chance := 0.05   # per second, once courage allows roaming
@export var name_suggestions: Array[String] = ["Piep"]

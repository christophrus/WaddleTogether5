extends "res://game/entities/neighbours/neighbour.gd"
## Skittish: flees in short hops. Befriended, it sits and croaks back.

var _hop_t := 0.0
var _hop_dir := Vector3.ZERO
var _croak_t := 0.0

func _init() -> void:
	neighbour_id = "frog"
	start_comfort = 5.0
	friend_threshold = 1.8
	calm_rate = 0.12
	startle_penalty = 1.2

func build_model(root: Node3D) -> void:
	var body := SphereMesh.new()
	body.radius = 0.22
	body.height = 0.3
	var b := make_part(root, body, Color(0.35, 0.6, 0.25), Vector3(0, 0.15, 0))
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.22
	var h := make_part(root, head, Color(0.4, 0.66, 0.28), Vector3(0, 0.28, 0.14))
	add_eyes(h, 0.035, 0.1)

func flee_step(delta: float, away: Vector3) -> void:
	if _hop_t <= 0.0:
		_hop_dir = Vector3(away.x, 0, away.z).normalized()
		_hop_t = 0.45
	_hop_t -= delta
	if _hop_t > 0.0:
		var p := global_position + _hop_dir * 4.0 * delta
		p = _settle(p)
		p.y += sin(_hop_t / 0.45 * PI) * 0.25
		global_position = p
		model.rotation.y = atan2(_hop_dir.x, _hop_dir.z)

func signature_behaviour(delta: float, mother: Node3D) -> void:
	_croak_t -= delta
	if _croak_t <= 0.0 and _flat(mother.global_position).distance_to(_flat(global_position)) < 3.0:
		_croak_t = 4.0
		AudioManager.peep(global_position, 0.45)
		model.scale = Vector3(1.15, 0.85, 1.15)

func idle_animate(delta: float) -> void:
	model.scale = model.scale.lerp(Vector3.ONE, delta * 4.0)

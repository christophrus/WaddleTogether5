extends Node
## Boids-flavoured following: seek the mother, cohere with siblings, keep a little
## personal space. Returns a planar velocity; the duckling owns gravity and water.

var speed := 3.2
var follow_distance := 1.6
var cohesion_weight := 0.25
var separation_weight := 1.2
var separation_radius := 0.7
var arrive_radius := 0.35

func compute(self_pos: Vector3, target: Vector3, siblings: Array, delta: float) -> Vector3:
	var to_target := Vector3(target.x - self_pos.x, 0, target.z - self_pos.z)
	var dist := to_target.length()
	var desired := Vector3.ZERO
	if dist > follow_distance:
		var arrive := clampf((dist - follow_distance) / 2.0, 0.25, 1.0)
		desired = to_target.normalized() * speed * arrive
	elif dist < follow_distance * 0.5 and dist > 0.01:
		# Too close to the mother: ease back without ever stopping dead.
		desired = -to_target.normalized() * speed * 0.3
	var cohesion := Vector3.ZERO
	var separation := Vector3.ZERO
	var n := 0
	for s in siblings:
		var d: Vector3 = s.global_position - self_pos
		d.y = 0.0
		var l := d.length()
		if l < 0.01:
			continue
		n += 1
		cohesion += d
		if l < separation_radius:
			separation -= d.normalized() * (separation_radius - l) / separation_radius
	if n > 0:
		cohesion = (cohesion / n).limit_length(1.0) * cohesion_weight
	desired += cohesion * speed + separation * speed * separation_weight
	if desired.length() < 0.05:
		return Vector3.ZERO
	return desired.limit_length(speed)

extends Area3D
## Food or nest material. Collected by walking over it; respawns so the map never
## runs dry. `active` is the source of truth (8.E.3): `monitoring` cannot be changed
## inside its own signal callback, so we flip it deferred and trust our own flag.

var kind := "food"   # food | material
var active := true
var respawn_seconds := 45.0
var respawn_jitter := 0.2

var _mesh: MeshInstance3D
var _timer := 0.0
var _respawn_in := 0.0
var _bob := 0.0

func _ready() -> void:
	add_to_group("pickup")
	add_to_group("keep_out")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 | 8  # mother and ducklings
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.6
	cs.shape = s
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	if kind == "food":
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		_mesh.mesh = sm
		mat.albedo_color = Color(0.85, 0.55, 0.2)
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.08, 0.12)
		_mesh.mesh = bm
		mat.albedo_color = Color(0.7, 0.6, 0.35)
		_mesh.rotation_degrees.y = randf() * 180.0
	_mesh.material_override = mat
	_mesh.position.y = 0.2
	add_child(_mesh)
	body_entered.connect(_on_body_entered)
	_bob = randf() * TAU

func _process(delta: float) -> void:
	if active:
		_bob += delta * 2.0
		_mesh.position.y = 0.2 + sin(_bob) * 0.04
		return
	_timer += delta
	if _timer >= _respawn_in:
		_set_active(true)

func _on_body_entered(body: Node3D) -> void:
	if not active:
		return
	if body.has_method("try_collect_pickup") and body.try_collect_pickup(self):
		collect()

## Consume this pickup and schedule its return (~45 s ±20 %).
func collect() -> void:
	if not active:
		return
	_set_active(false)
	_timer = 0.0
	_respawn_in = respawn_seconds * (1.0 + randf_range(-respawn_jitter, respawn_jitter))

func _set_active(v: bool) -> void:
	active = v
	_mesh.visible = v
	set_deferred("monitoring", v)

func keep_out_circle() -> Array:
	return [Vector2(global_position.x, global_position.z), 1.2]

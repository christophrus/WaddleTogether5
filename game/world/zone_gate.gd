extends StaticBody3D
## A fence that exists until Progression unlocks its zone. Solid on layer 1 like every
## other fixed thing, so the ducks need no special handling for it.

var zone_id := ""
var size := Vector3(1, 2, 10)

var _shape: CollisionShape3D
var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("zone_gate")
	add_to_group("keep_out")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.9, size.z)
	_mesh.mesh = bm
	_mesh.position.y = -0.55
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.28)
	mat.roughness = 1.0
	_mesh.material_override = mat
	add_child(_mesh)
	# Fence posts so the barrier reads as a garden fence, not a floating plank.
	var length := maxf(size.x, size.z)
	var along := Vector3(1, 0, 0) if size.x > size.z else Vector3(0, 0, 1)
	var i := -length / 2.0
	while i <= length / 2.0:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.1
		cm.height = 1.4
		post.mesh = cm
		post.material_override = mat
		post.position = along * i + Vector3(0, -0.3, 0)
		add_child(post)
		i += 2.5
	EventBus.zone_unlocked.connect(_on_zone_unlocked)
	_apply()

func _on_zone_unlocked(id: String) -> void:
	if id == zone_id:
		_apply()

func _apply() -> void:
	var open := Progression.is_unlocked(zone_id)
	_shape.set_deferred("disabled", open)
	visible = not open
	if open:
		remove_from_group("keep_out")

func keep_out_rect() -> Array:
	# A fence is long and thin; a circle around it would wall off half the park.
	return [Vector2(global_position.x, global_position.z), Vector2(size.x, size.z) / 2.0 + Vector2(1.5, 1.5)]

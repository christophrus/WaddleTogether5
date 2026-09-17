extends Node3D
## The pond: a disc of water over the terrain bowl. Group "water" is how the ducks
## ask "am I swimming?" — a point test, no physics areas, so it works headless.

var center := Vector3.ZERO
var radius := 9.0
var surface_y := -0.25

func _ready() -> void:
	add_to_group("water")
	add_to_group("keep_out")
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/world/shaders/water.gdshader")
	mi.material_override = mat
	mi.position = Vector3(center.x, surface_y, center.z)
	# Circular water disc: clip the plane by scaling a cylinder-shaped mesh instead.
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.94
	cyl.bottom_radius = radius * 0.94
	cyl.height = 0.02
	cyl.radial_segments = 48
	cyl.rings = 6
	mi.mesh = cyl
	add_child(mi)

func contains(pos: Vector3) -> bool:
	var d := Vector2(pos.x - center.x, pos.z - center.z).length()
	# Shore is where the bowl crosses the water line; slightly inside that ring the
	# duck is already floating.
	return d < shore_radius()

func shore_radius() -> float:
	# Solve bowl(r) = surface_y for r (see Park.ground_height).
	var depth := 1.6
	return radius * sqrt(1.0 - (-surface_y) / depth)

## Closest point on dry land to pos, for ducklings that cannot swim yet.
func nearest_shore(pos: Vector3, margin := 0.4) -> Vector3:
	var flat := Vector3(pos.x - center.x, 0.0, pos.z - center.z)
	if flat.length() < 0.01:
		flat = Vector3(1, 0, 0)
	var p := center + flat.normalized() * (shore_radius() + margin)
	p.y = pos.y
	return p

## Keep-out disc for decoration.
func keep_out_circle() -> Array:
	return [Vector2(center.x, center.z), radius + 1.0]

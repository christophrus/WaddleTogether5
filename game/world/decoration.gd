extends Node3D
## Park dressing: trees, bushes, reeds, lilies, rocks, benches, a gravel path and a
## brook. Placement is deterministic (fixed seed) and rejection-sampled against
## keep-out zones read *from groups at runtime* — a maintained list would drift.
## The brook has no scene node, so it gets an explicit keep-out (8.G.5).
## Only trees and benches are solid; bushes, rocks and reeds are not, otherwise
## "walk to the pond" becomes a slalom.

const SEED := 1337
const FOLIAGE_SHADER := "res://game/world/shaders/foliage.gdshader"

var placed: Array = []   # [{kind, pos}] for tests
var _rng := RandomNumberGenerator.new()
var _park: Node3D
var _keep_circles: Array = []   # [Vector2 center, float radius]
var _keep_rects: Array = []     # [Vector2 center, Vector2 half]
var _foliage_shader: Shader

# The brook: a bent strip from the north-west corner into the pond.
const BROOK_POINTS := [Vector2(-34.0, -34.0), Vector2(-26.0, -28.0), Vector2(-20.0, -20.0), Vector2(-13.0, -14.0)]
const BROOK_WIDTH := 2.2

func build() -> void:
	_park = get_tree().get_first_node_in_group("park")
	_rng.seed = SEED
	_foliage_shader = load(FOLIAGE_SHADER)
	_collect_keep_out()
	_build_brook()
	_build_path()
	_scatter("tree_round", 26, 36.0)
	_scatter("tree_pine", 14, 36.0)
	_scatter("bush", 40, 36.0)
	_scatter("rock", 24, 36.0)
	_scatter_reeds(34)
	_scatter_lilies(9)
	_scatter_meadow_flowers(60)
	_place_anchored("bench", Vector2(-4.0, 14.0))
	_place_anchored("bench", Vector2(14.0, -4.0))
	_build_horizon_ring()

## A belt of trees beyond the invisible walls so the world does not end in a hard
## line against the sky. Decoration only: no collision, no keep-out, not in `placed`.
func _build_horizon_ring() -> void:
	var half: float = _park.WORLD_HALF
	for i in 120:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(half + 3.0, half + 26.0)
		var p := Vector2(cos(a) * r, sin(a) * r)
		var root: Node3D = _tree_pine() if _rng.randf() < 0.4 else _tree_round()
		for body in root.get_children():
			if body is StaticBody3D:
				body.queue_free()
		root.position = Vector3(p.x, 0.0, p.y)
		root.rotation.y = _rng.randf() * TAU
		root.scale = Vector3.ONE * _rng.randf_range(1.1, 1.6)
		add_child(root)

# --- Keep-out ------------------------------------------------------------------

func _collect_keep_out() -> void:
	_keep_circles.clear()
	_keep_rects.clear()
	for n in get_tree().get_nodes_in_group("keep_out"):
		if n.has_method("keep_out_circle"):
			_keep_circles.append(n.keep_out_circle())
		if n.has_method("keep_out_rect"):
			_keep_rects.append(n.keep_out_rect())
	# Nest, spawn and the mother are game-critical; read them from their groups too.
	for n in get_tree().get_nodes_in_group("nest_site"):
		_keep_circles.append([Vector2(n.global_position.x, n.global_position.z), 5.0])
	var spawn: Node3D = _park.get_node("Spawn")
	_keep_circles.append([Vector2(spawn.position.x, spawn.position.z), 4.0])
	# Explicit zone for the purely decorative brook (no node, no group).
	for i in BROOK_POINTS.size() - 1:
		var a: Vector2 = BROOK_POINTS[i]
		var b: Vector2 = BROOK_POINTS[i + 1]
		var steps := int(a.distance_to(b) / 1.5) + 1
		for s in steps + 1:
			_keep_circles.append([a.lerp(b, float(s) / steps), BROOK_WIDTH * 0.5 + 1.2])

func is_free(p: Vector2, own_radius: float) -> bool:
	if absf(p.x) > 38.5 or absf(p.y) > 38.5:
		return false
	for c in _keep_circles:
		if p.distance_to(c[0]) < c[1] + own_radius:
			return false
	for r in _keep_rects:
		var d: Vector2 = (p - r[0]).abs() - r[1]
		if d.x < own_radius and d.y < own_radius:
			return false
	for e in placed:
		if p.distance_to(e["pos"]) < e["radius"] + own_radius:
			return false
	return true

# --- Scatter -------------------------------------------------------------------

func _scatter(kind: String, count: int, half: float) -> void:
	var radius := _footprint(kind)
	for i in count:
		for attempt in 60:
			var p := Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
			if _park.is_water(Vector3(p.x, 0, p.y)) or not is_free(p, radius):
				continue
			_spawn(kind, p)
			break

func _scatter_reeds(count: int) -> void:
	# Reeds hug the pond rim: just outside the shore line.
	var shore: float = _park.pond.shore_radius()
	for i in count:
		for attempt in 30:
			var a := _rng.randf() * TAU
			var r := shore + _rng.randf_range(0.2, 1.4)
			var p := Vector2(_park.POND_CENTER.x + cos(a) * r, _park.POND_CENTER.z + sin(a) * r)
			if not _free_except_water(p, 0.3):
				continue
			_spawn("reed", p)
			break

## The meadow east of the gate is where the dandelions grow (5.10 seed for later).
func _scatter_meadow_flowers(count: int) -> void:
	for i in count:
		for attempt in 30:
			var p := Vector2(_rng.randf_range(22.0, 38.0), _rng.randf_range(-20.0, 30.0))
			if not is_free(p, 0.5):
				continue
			_spawn("flower", p)
			break

func _scatter_lilies(count: int) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(2.0, _park.pond.shore_radius() - 1.5)
		var p := Vector2(_park.POND_CENTER.x + cos(a) * r, _park.POND_CENTER.z + sin(a) * r)
		_spawn("lily", p)

## Hand-placed props go through the same check (8.G.4): the wish position is an anchor
## and we search nearby if it collides.
func _place_anchored(kind: String, anchor: Vector2) -> void:
	var radius := _footprint(kind)
	for attempt in 80:
		var p := anchor + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * (attempt * 0.15)
		if not _park.is_water(Vector3(p.x, 0, p.y)) and is_free(p, radius):
			_spawn(kind, p)
			return
	push_warning("Decoration: no free spot near %s for %s" % [anchor, kind])

func _free_except_water(p: Vector2, own_radius: float) -> bool:
	# Reeds are allowed inside the pond keep-out ring but nowhere else that matters.
	var saved := _keep_circles
	_keep_circles = _keep_circles.filter(func(c): return c[0] != Vector2(_park.POND_CENTER.x, _park.POND_CENTER.z))
	var ok := is_free(p, own_radius)
	_keep_circles = saved
	return ok

func _footprint(kind: String) -> float:
	match kind:
		"tree_round", "tree_pine": return 1.6
		"bush": return 0.9
		"rock": return 0.6
		"bench": return 1.4
		"reed": return 0.25
		"flower": return 0.5
	return 0.5

# --- Builders ------------------------------------------------------------------

func _spawn(kind: String, p: Vector2) -> void:
	var y: float = _park.ground_height(p.x, p.y)
	var root: Node3D
	match kind:
		"tree_round": root = _tree_round()
		"tree_pine": root = _tree_pine()
		"bush": root = _bush()
		"rock": root = _rock()
		"bench": root = _bench()
		"reed": root = _reed()
		"flower": root = _flower()
		"lily": root = _lily(); y = _park.WATER_SURFACE_Y + 0.09  # above the ripple amplitude
		_: return
	root.position = Vector3(p.x, y, p.y)
	root.rotation.y = _rng.randf() * TAU
	add_child(root)
	placed.append({"kind": kind, "pos": p, "radius": _footprint(kind)})

## HSV jitter, never RGB: hue + value at constant saturation reads natural; independent
## channel noise shifts the hue unpredictably and looks dirty (8.D.3).
func _jitter(c: Color, hue_amt := 0.03, val_amt := 0.12) -> Color:
	var h := fposmod(c.h + _rng.randf_range(-hue_amt, hue_amt), 1.0)
	var v := clampf(c.v + _rng.randf_range(-val_amt, val_amt), 0.05, 1.0)
	return Color.from_hsv(h, c.s, v)

func _foliage_material(bottom: Color, top: Color, half_height: float, sway := 0.06) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _foliage_shader
	m.set_shader_parameter("color_bottom", _jitter(bottom))
	m.set_shader_parameter("color_top", _jitter(top))
	m.set_shader_parameter("half_height", half_height)
	m.set_shader_parameter("sway_strength", sway)
	return m

func _plain_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _solid(root: Node3D, shape: Shape3D, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	root.add_child(body)

func _tree_round() -> Node3D:
	# Short, thick, overlapping crowns read "storybook"; botanically correct is bleak.
	var root := Node3D.new()
	var s := _rng.randf_range(0.85, 1.25)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22 * s
	trunk.bottom_radius = 0.32 * s
	trunk.height = 1.6 * s
	_mesh(root, trunk, _plain_material(_jitter(Color(0.42, 0.29, 0.18))), Vector3(0, 0.8 * s, 0))
	var crown_mat := _foliage_material(Color(0.16, 0.36, 0.14), Color(0.42, 0.7, 0.28), 1.3 * s)
	for off in [Vector3(0, 2.3, 0), Vector3(0.7, 2.0, 0.3), Vector3(-0.6, 2.1, -0.4), Vector3(0.1, 2.9, 0.5), Vector3(-0.2, 2.6, -0.7)]:
		var sph := SphereMesh.new()
		var r := _rng.randf_range(1.0, 1.35) * s
		sph.radius = r
		sph.height = r * 2.0
		_mesh(root, sph, crown_mat, off * s)
	var col := CylinderShape3D.new()
	col.radius = 0.35 * s
	col.height = 2.0 * s
	_solid(root, col, Vector3(0, 1.0 * s, 0))
	return root

func _tree_pine() -> Node3D:
	var root := Node3D.new()
	var s := _rng.randf_range(0.9, 1.3)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18 * s
	trunk.bottom_radius = 0.28 * s
	trunk.height = 1.2 * s
	_mesh(root, trunk, _plain_material(_jitter(Color(0.38, 0.25, 0.15))), Vector3(0, 0.6 * s, 0))
	var mat := _foliage_material(Color(0.1, 0.3, 0.16), Color(0.28, 0.55, 0.3), 1.0 * s, 0.03)
	var y := 1.0 * s
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = (1.5 - i * 0.35) * s
		cone.height = 1.7 * s
		_mesh(root, cone, mat, Vector3(0, y + 0.85 * s, 0))
		y += 0.9 * s
	var col := CylinderShape3D.new()
	col.radius = 0.3 * s
	col.height = 2.0 * s
	_solid(root, col, Vector3(0, 1.0 * s, 0))
	return root

func _bush() -> Node3D:
	var root := Node3D.new()
	var mat := _foliage_material(Color(0.14, 0.32, 0.12), Color(0.36, 0.62, 0.24), 0.55)
	for off in [Vector3(0, 0.45, 0), Vector3(0.4, 0.35, 0.2), Vector3(-0.35, 0.4, -0.25)]:
		var sph := SphereMesh.new()
		var r := _rng.randf_range(0.45, 0.65)
		sph.radius = r
		sph.height = r * 2.0
		_mesh(root, sph, mat, off)
	return root

func _rock() -> Node3D:
	# A boulder sits half-buried but must still read as a lump, not a disc: keep the
	# sphere nearly round and sink only a third of it.
	var root := Node3D.new()
	var r := _rng.randf_range(0.3, 0.6)
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 1.7
	var mi := _mesh(root, sph, _plain_material(_jitter(Color(0.52, 0.51, 0.48), 0.01, 0.12)), Vector3(0, r * 0.45, 0))
	mi.scale = Vector3(1.0, 0.85, _rng.randf_range(0.8, 1.3))
	mi.rotation.y = _rng.randf() * TAU
	if _rng.randf() < 0.5:
		var small := SphereMesh.new()
		small.radius = r * 0.45
		small.height = r * 0.8
		_mesh(root, small, _plain_material(_jitter(Color(0.5, 0.5, 0.47), 0.01, 0.12)), Vector3(r * 0.9, r * 0.2, r * 0.3))
	return root

func _flower() -> Node3D:
	var root := Node3D.new()
	var stalk_mat := _foliage_material(Color(0.25, 0.45, 0.15), Color(0.45, 0.65, 0.25), 0.2, 0.1)
	var petal_col: Color = [Color(0.98, 0.85, 0.2), Color(0.98, 0.98, 0.95), Color(0.9, 0.55, 0.75)][_rng.randi_range(0, 2)]
	for i in _rng.randi_range(3, 6):
		var off := Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.35, 0.35))
		var h := _rng.randf_range(0.25, 0.45)
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.012
		stalk.bottom_radius = 0.018
		stalk.height = h
		_mesh(root, stalk, stalk_mat, off + Vector3(0, h / 2.0, 0))
		var head := SphereMesh.new()
		head.radius = 0.05
		head.height = 0.08
		_mesh(root, head, _plain_material(_jitter(petal_col, 0.02, 0.1)), off + Vector3(0, h + 0.03, 0))
	return root

func _bench() -> Node3D:
	var root := Node3D.new()
	var wood := _plain_material(Color(0.5, 0.36, 0.22))
	var iron := _plain_material(Color(0.2, 0.2, 0.22))
	var seat := BoxMesh.new()
	seat.size = Vector3(1.8, 0.08, 0.5)
	_mesh(root, seat, wood, Vector3(0, 0.45, 0))
	var back := BoxMesh.new()
	back.size = Vector3(1.8, 0.4, 0.06)
	_mesh(root, back, wood, Vector3(0, 0.75, -0.22))
	for x in [-0.75, 0.75]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.08, 0.45, 0.45)
		_mesh(root, leg, iron, Vector3(x, 0.22, 0))
	var col := BoxShape3D.new()
	col.size = Vector3(1.8, 0.9, 0.55)
	_solid(root, col, Vector3(0, 0.45, 0))
	return root

func _reed() -> Node3D:
	var root := Node3D.new()
	var mat := _foliage_material(Color(0.25, 0.45, 0.15), Color(0.6, 0.72, 0.3), 0.7, 0.12)
	for i in 4:
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.015
		stalk.bottom_radius = 0.03
		stalk.height = _rng.randf_range(1.0, 1.5)
		var off := Vector3(_rng.randf_range(-0.15, 0.15), stalk.height / 2.0, _rng.randf_range(-0.15, 0.15))
		_mesh(root, stalk, mat, off)
	return root

func _lily() -> Node3D:
	var root := Node3D.new()
	var pad := CylinderMesh.new()
	pad.top_radius = _rng.randf_range(0.3, 0.5)
	pad.bottom_radius = pad.top_radius
	pad.height = 0.03
	_mesh(root, pad, _plain_material(_jitter(Color(0.25, 0.5, 0.25))), Vector3.ZERO)
	if _rng.randf() < 0.5:
		var flower := SphereMesh.new()
		flower.radius = 0.1
		flower.height = 0.14
		_mesh(root, flower, _plain_material(Color(0.95, 0.75, 0.85)), Vector3(0.1, 0.07, 0.05))
	return root

func _build_brook() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/world/shaders/water.gdshader")
	for i in BROOK_POINTS.size() - 1:
		var a: Vector2 = BROOK_POINTS[i]
		var b: Vector2 = BROOK_POINTS[i + 1]
		var mid := (a + b) * 0.5
		var seg := PlaneMesh.new()
		seg.size = Vector2(BROOK_WIDTH, a.distance_to(b) + 0.6)
		seg.subdivide_depth = 6
		var mi := _mesh(self, seg, mat, Vector3(mid.x, 0.03, mid.y))
		mi.rotation.y = -atan2(b.y - a.y, b.x - a.x) + PI / 2.0
		# Pebbly bank on each side so the strip does not float on the grass.
		for side in [-1.0, 1.0]:
			var bank := PlaneMesh.new()
			bank.size = Vector2(0.5, a.distance_to(b) + 0.6)
			var bm := _mesh(self, bank, _plain_material(Color(0.6, 0.58, 0.5)), Vector3(mid.x, 0.02, mid.y))
			bm.rotation.y = mi.rotation.y
			bm.position += Vector3(cos(mi.rotation.y), 0, -sin(mi.rotation.y)) * side * (BROOK_WIDTH * 0.5 + 0.2)

func _build_path() -> void:
	# Gravel path from the spawn east towards the meadow gate.
	var pts := [Vector2(0.0, 12.0), Vector2(8.0, 14.0), Vector2(16.0, 11.0), Vector2(24.0, 6.0)]
	var mat := _plain_material(Color(0.72, 0.68, 0.58))
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mid := (a + b) * 0.5
		var seg := PlaneMesh.new()
		seg.size = Vector2(1.8, a.distance_to(b) + 0.4)
		var mi := _mesh(self, seg, mat, Vector3(mid.x, 0.015, mid.y))
		mi.rotation.y = -atan2(b.y - a.y, b.x - a.x) + PI / 2.0
		var steps := int(a.distance_to(b) / 1.5) + 1
		for s in steps + 1:
			_keep_circles.append([a.lerp(b, float(s) / steps), 1.4])

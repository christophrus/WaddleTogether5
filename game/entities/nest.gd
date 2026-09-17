extends Node3D
## The nest. One interaction key does the right thing for the moment: deliver
## material while building, feed a hungry hatchling, or lay an egg. Eggs only
## incubate while the mother sits close by — brooding is a thing you *do* (3.3).
## Keepsakes ring the nest permanently, so over many sessions it stops being a
## progress bar and becomes a place (5.7).

const MATERIAL_PER_STAGE := 3
const STAGES := 3
const NEST_RADIUS := 3.0
const BROOD_RADIUS := 2.6

var incubation_seconds := 120.0   # overridable for time-lapse tests
var brood_progress_material: ShaderMaterial

@onready var _visual: Node3D = $Visual
@onready var _eggs_root: Node3D = $Eggs
@onready var _keepsakes_root: Node3D = $Keepsakes

var _park: Node3D
var _egg_nodes: Dictionary = {}   # egg id -> MeshInstance3D
var _progress_mats: Dictionary = {}  # egg id -> ShaderMaterial (the one really rendered)
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("nest_site")
	add_to_group("interactable")
	add_to_group("saveable")
	add_to_group("keep_out")
	_park = get_tree().get_first_node_in_group("park")
	_rng.seed = 99
	_build_visual()
	_refresh_visual()
	for e in GameState.eggs:
		_add_egg_visual(int(e["id"]))
	_rebuild_keepsakes()

# --- Queries -------------------------------------------------------------------

func is_built() -> bool:
	return bool(GameState.nest["built"])

func material_needed() -> int:
	return STAGES * MATERIAL_PER_STAGE

func is_near(pos: Vector3) -> bool:
	return global_position.distance_to(pos) <= NEST_RADIUS

func hatchlings() -> Array:
	return get_tree().get_nodes_in_group("duckling").filter(func(d): return bool(d.data["nest_bound"]))

func _hungry_hatchling() -> Node:
	var best: Node = null
	for d in hatchlings():
		if d.needs.is_hungry() and (best == null or d.needs.hunger() > best.needs.hunger()):
			best = d
	return best

# --- Interaction (duck typing: prompt + interact) --------------------------------

func get_interaction_prompt(duck: Node) -> String:
	if not is_built():
		if GameState.mother["carried_material"] > 0:
			return "Nistmaterial ablegen (%d/%d)" % [GameState.nest["material"], material_needed()]
		return ""
	if GameState.mother["carried_food"] > 0 and _hungry_hatchling() != null:
		return "Küken füttern"
	if GameState.mother["carried_keepsake"] != "":
		return "Fundstück ablegen"
	if GameState.egg_slots_free() > 0:
		return "Ei legen"
	return ""

func interact(duck: Node) -> void:
	if not is_built():
		if GameState.mother["carried_material"] > 0:
			deliver_material(GameState.mother["carried_material"])
			GameState.mother["carried_material"] = 0
		return
	if GameState.mother["carried_food"] > 0:
		var h := _hungry_hatchling()
		if h != null:
			GameState.mother["carried_food"] -= 1
			h.receive_feeding()
			return
	if GameState.mother["carried_keepsake"] != "":
		place_keepsake(GameState.mother["carried_keepsake"], "Mama")
		GameState.mother["carried_keepsake"] = ""
		return
	if GameState.egg_slots_free() > 0:
		lay_egg()

# --- Building ------------------------------------------------------------------

func deliver_material(count: int) -> void:
	var needed := material_needed()
	GameState.nest["material"] = mini(needed, int(GameState.nest["material"]) + count)
	GameState.nest["stage"] = int(GameState.nest["material"]) / MATERIAL_PER_STAGE
	AudioManager.play_sfx("nest_build")
	EventBus.nest_material_delivered.emit(GameState.nest["material"], needed)
	if GameState.nest["material"] >= needed and not is_built():
		GameState.nest["built"] = true
		EventBus.nest_completed.emit()
	_refresh_visual()

func debug_complete() -> void:
	deliver_material(material_needed())

# --- Eggs ----------------------------------------------------------------------

func lay_egg() -> int:
	if not is_built() or GameState.egg_slots_free() <= 0:
		return -1
	var id := GameState.allocate_id()
	GameState.eggs.append({"id": id, "progress": 0.0})
	_add_egg_visual(id)
	EventBus.egg_laid.emit(id)
	return id

func _process(delta: float) -> void:
	if GameState.eggs.is_empty() or _park == null or _park.mother == null:
		return
	# Only while the mother broods. Progress is an object counter, allowed in UI.
	if global_position.distance_to(_park.mother.global_position) > BROOD_RADIUS:
		return
	var hatched: Array = []
	for e in GameState.eggs:
		e["progress"] = minf(1.0, float(e["progress"]) + delta / incubation_seconds)
		var m: ShaderMaterial = _progress_mats.get(int(e["id"]))
		if m != null:
			m.set_shader_parameter("progress", e["progress"])
		if e["progress"] >= 1.0:
			hatched.append(e)
	for e in hatched:
		_hatch(e)

func brood_progress() -> float:
	if GameState.eggs.is_empty():
		return 0.0
	var best := 0.0
	for e in GameState.eggs:
		best = maxf(best, float(e["progress"]))
	return best

func _hatch(egg: Dictionary) -> void:
	GameState.eggs.erase(egg)
	var id := int(egg["id"])
	if _egg_nodes.has(id):
		_egg_nodes[id].queue_free()
		_egg_nodes.erase(id)
		_progress_mats.erase(id)
	var temperaments = load("res://game/data/temperaments.gd")
	var record := GameState.new_duckling(temperaments.pick_unused().id)
	var angle := _rng.randf() * TAU
	record["position"] = GameState.v3_to_arr(global_position + Vector3(cos(angle), 0.4, sin(angle)) * 0.8)
	_park.spawn_duckling(record)
	AudioManager.play_sfx("hatch")
	EventBus.egg_hatched.emit(int(record["id"]))

func debug_hatch_all() -> void:
	for e in GameState.eggs.duplicate():
		_hatch(e)

# --- Keepsakes -----------------------------------------------------------------

func place_keepsake(kind: String, finder: String) -> void:
	var entry := {"kind": kind, "angle": _rng.randf() * TAU, "radius": _rng.randf_range(0.95, 1.4), "finder": finder}
	GameState.keepsakes.append(entry)
	_add_keepsake_visual(entry)
	EventBus.keepsake_placed.emit(kind, finder)

func _rebuild_keepsakes() -> void:
	for c in _keepsakes_root.get_children():
		c.queue_free()
	for k in GameState.keepsakes:
		_add_keepsake_visual(k)

func _add_keepsake_visual(k: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.4
	match k["kind"]:
		"bottle_cap":
			var c := CylinderMesh.new(); c.top_radius = 0.08; c.bottom_radius = 0.08; c.height = 0.03
			mi.mesh = c; mat.albedo_color = Color(0.85, 0.2, 0.2); mat.metallic = 0.6
		"marble":
			var s := SphereMesh.new(); s.radius = 0.06; s.height = 0.12
			mi.mesh = s; mat.albedo_color = Color(0.3, 0.6, 0.9); mat.roughness = 0.1
		"button":
			var c := CylinderMesh.new(); c.top_radius = 0.07; c.bottom_radius = 0.07; c.height = 0.02
			mi.mesh = c; mat.albedo_color = Color(0.95, 0.9, 0.8)
		"blue_glass":
			var b := BoxMesh.new(); b.size = Vector3(0.12, 0.02, 0.09)
			mi.mesh = b; mat.albedo_color = Color(0.2, 0.5, 0.8, 0.8); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_:
			var s := SphereMesh.new(); s.radius = 0.07; s.height = 0.09
			mi.mesh = s; mat.albedo_color = Color(0.6, 0.6, 0.62)
	mi.material_override = mat
	var a: float = k["angle"]
	var r: float = k["radius"]
	mi.position = Vector3(cos(a) * r, 0.05, sin(a) * r)
	_keepsakes_root.add_child(mi)

# --- Visual --------------------------------------------------------------------

## Sized to a 0.73 m duck: a real nest is about one duck across. Built in three
## visible stages: a trampled patch with loose twigs, a woven ring, a lined bowl.
func _build_visual() -> void:
	var patch := CylinderMesh.new()
	patch.top_radius = 0.62
	patch.bottom_radius = 0.62
	patch.height = 0.03
	_part(_visual, patch, Color(0.40, 0.33, 0.20), Vector3(0, 0.015, 0), 1.0)
	var stage_roots: Array[Node3D] = []
	for i in STAGES:
		var root := Node3D.new()
		root.visible = false
		_visual.add_child(root)
		stage_roots.append(root)
	# Stage 1: loose twigs dropped on the patch.
	for i in 10:
		_twig(stage_roots[0], _rng.randf_range(0.1, 0.55), 0.02, false, 0.0)
	# Stage 2: a woven ring.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.34
	ring.outer_radius = 0.58
	var r1 := _part(stage_roots[1], ring, Color(0.66, 0.53, 0.30), Vector3(0, 0.07, 0), 1.0)
	r1.scale = Vector3(1.0, 0.45, 1.0)
	for i in 16:
		_twig(stage_roots[1], 0.47, 0.11, true, _rng.randf_range(-0.25, 0.25))
	# Stage 3: raised rim and a soft down lining inside.
	var rim := TorusMesh.new()
	rim.inner_radius = 0.3
	rim.outer_radius = 0.52
	var r2 := _part(stage_roots[2], rim, Color(0.6, 0.47, 0.27), Vector3(0, 0.15, 0), 1.0)
	r2.scale = Vector3(1.0, 0.45, 1.0)
	for i in 14:
		_twig(stage_roots[2], 0.42, 0.2, true, _rng.randf_range(-0.3, 0.3))
	var lining := CylinderMesh.new()
	lining.top_radius = 0.32
	lining.bottom_radius = 0.28
	lining.height = 0.06
	_part(stage_roots[2], lining, Color(0.86, 0.8, 0.66), Vector3(0, 0.09, 0), 1.0)
	_stage_roots = stage_roots

var _stage_roots: Array[Node3D] = []

## A twig at a random angle `a` around the centre. `tangential` lays it along the
## rim (woven look); otherwise it lies at a random yaw (dropped look).
func _twig(parent: Node3D, radius: float, y: float, tangential: bool, tilt: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(_rng.randf_range(0.25, 0.42), 0.025, 0.03)
	var a := _rng.randf() * TAU
	var mi := _part(parent, box, Color(0.55, 0.42, 0.24).lightened(_rng.randf_range(-0.1, 0.2)), Vector3(cos(a) * radius, y, sin(a) * radius), 1.0)
	var yaw := (-a + PI / 2.0 + _rng.randf_range(-0.35, 0.35)) if tangential else _rng.randf() * TAU
	mi.rotation = Vector3(tilt, yaw, 0.0)

func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, roughness: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _refresh_visual() -> void:
	var stage := int(GameState.nest["stage"])
	for i in _stage_roots.size():
		_stage_roots[i].visible = i < stage

func _add_egg_visual(id: int) -> void:
	var idx := _egg_nodes.size()
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.22
	mi.mesh = s
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/entities/egg.gdshader")
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("half_height", 0.11)
	# Duplicate goes onto the *same* property the renderer reads (8.D.2).
	mi.material_override = mat
	var a := idx * TAU / 4.0
	mi.position = Vector3(cos(a) * 0.18, 0.3, sin(a) * 0.18)
	_eggs_root.add_child(mi)
	_egg_nodes[id] = mi
	_progress_mats[id] = mat

## For tests: the material that is actually rendered for an egg.
func rendered_egg_material(id: int) -> Material:
	if not _egg_nodes.has(id):
		return null
	return _egg_nodes[id].material_override

func write_state() -> void:
	pass

func keep_out_circle() -> Array:
	return [Vector2(global_position.x, global_position.z), 5.0]

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
var _ring_meshes: Array[MeshInstance3D] = []
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

func _build_visual() -> void:
	# Sized to a 0.73 m duck: a real nest is about one duck across.
	var base := CylinderMesh.new()
	base.top_radius = 0.7
	base.bottom_radius = 0.78
	base.height = 0.1
	var b := MeshInstance3D.new()
	b.mesh = base
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.45, 0.36, 0.22)
	bm.roughness = 1.0
	b.material_override = bm
	b.position.y = 0.06
	_visual.add_child(b)
	for i in STAGES:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.42 - i * 0.05
		ring.outer_radius = 0.66 - i * 0.03
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.6, 0.35).darkened(i * 0.08)
		m.roughness = 1.0
		mi.material_override = m
		mi.position.y = 0.12 + i * 0.1
		mi.visible = false
		_visual.add_child(mi)
		_ring_meshes.append(mi)

func _refresh_visual() -> void:
	var stage := int(GameState.nest["stage"])
	for i in _ring_meshes.size():
		_ring_meshes[i].visible = i < stage

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

extends Node3D
## The world root. Terrain, pond and lighting are built in code from a handful of
## marker nodes so the scene file stays tiny and feature work never touches it.
## Wildlife and decoration each hang off one empty node and build themselves.

const MotherScene := preload("res://game/entities/duck_mother.tscn")
const DucklingScene := preload("res://game/entities/duckling.tscn")
const NestScene := preload("res://game/entities/nest.tscn")

const WORLD_HALF := 40.0
const POND_CENTER := Vector3(0.0, 0.0, -8.0)
const POND_RADIUS := 9.0
const POND_DEPTH := 1.6
const WATER_SURFACE_Y := -0.25

var mother: CharacterBody3D
var nest: Node3D
var pond: Node3D
var terrain: Node3D
var sun: DirectionalLight3D
var environment: Environment

@onready var _ducklings_root: Node3D = $Ducklings

func _ready() -> void:
	add_to_group("park")
	sun = $Sun
	_build_environment()
	_build_terrain()
	_build_pond()
	_build_nest()
	_build_mother()
	_build_gates()
	_build_adventure()
	_build_pickups()
	_build_wildlife()
	_build_decoration()
	_restore_ducklings()
	var generations := Node.new()
	generations.name = "Generations"
	generations.set_script(load("res://game/world/generations.gd"))
	add_child(generations)
	Daytime.register_world(sun, environment)
	Daytime.running = true

# --- Terrain -------------------------------------------------------------------

## Height of the ground at a world xz. A smooth bowl under the pond; flat elsewhere.
static func ground_height(x: float, z: float) -> float:
	var r := Vector2(x - POND_CENTER.x, z - POND_CENTER.z).length()
	if r >= POND_RADIUS:
		return 0.0
	var t := r / POND_RADIUS
	return -POND_DEPTH * (1.0 - t * t)

func is_water(pos: Vector3) -> bool:
	return pond != null and pond.contains(pos)

func _build_environment() -> void:
	var we: WorldEnvironment = $WorldEnvironment
	environment = Environment.new()
	# Procedural sky: Daytime drives its colours, so the sky *is* the clock (5.6).
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.6, 0.9)
	sky_mat.sky_horizon_color = Color(0.7, 0.82, 0.95)
	sky_mat.ground_bottom_color = Color(0.3, 0.45, 0.25)
	sky_mat.ground_horizon_color = Color(0.7, 0.82, 0.95)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.15
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color(0.55, 0.75, 0.95)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.8, 0.9)
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_density = 0.0012
	environment.fog_light_color = Color(0.75, 0.85, 0.95)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = environment

func _build_terrain() -> void:
	terrain = $Terrain
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("ground")
	terrain.add_child(body)

	var cells := int(WORLD_HALF * 2.0) + 1  # 1 m resolution
	var heights := PackedFloat32Array()
	heights.resize(cells * cells)
	for zi in cells:
		for xi in cells:
			heights[zi * cells + xi] = ground_height(xi - WORLD_HALF, zi - WORLD_HALF)
	var shape := HeightMapShape3D.new()
	shape.map_width = cells
	shape.map_depth = cells
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

	var mesh := _build_terrain_mesh(cells)
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/world/shaders/ground.gdshader")
	mi.material_override = mat
	body.add_child(mi)

	# Visual apron past the walls (four strips, so nothing covers the pond bowl), same
	# shader, so the horizon is grass rather than void.
	var reach := WORLD_HALF * 3.0
	var strips := [
		[Vector2(WORLD_HALF * 2.0 + reach * 2.0, reach), Vector3(0, 0, -WORLD_HALF - reach / 2.0)],
		[Vector2(WORLD_HALF * 2.0 + reach * 2.0, reach), Vector3(0, 0, WORLD_HALF + reach / 2.0)],
		[Vector2(reach, WORLD_HALF * 2.0), Vector3(-WORLD_HALF - reach / 2.0, 0, 0)],
		[Vector2(reach, WORLD_HALF * 2.0), Vector3(WORLD_HALF + reach / 2.0, 0, 0)],
	]
	for s in strips:
		var apron := MeshInstance3D.new()
		var apron_mesh := PlaneMesh.new()
		apron_mesh.size = s[0]
		apron.mesh = apron_mesh
		apron.material_override = mat
		apron.position = s[1] + Vector3(0, -0.02, 0)
		terrain.add_child(apron)

	# Invisible walls at the world rim so nobody waddles into the void.
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		var ws := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 6.0, WORLD_HALF * 2.0 + 2.0) if side.x != 0.0 else Vector3(WORLD_HALF * 2.0 + 2.0, 6.0, 1.0)
		ws.shape = box
		wall.add_child(ws)
		wall.position = side * (WORLD_HALF + 0.5) + Vector3(0, 2, 0)
		terrain.add_child(wall)

func _build_terrain_mesh(cells: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in cells - 1:
		for xi in cells - 1:
			var x0 := xi - WORLD_HALF
			var z0 := zi - WORLD_HALF
			var p00 := Vector3(x0, ground_height(x0, z0), z0)
			var p10 := Vector3(x0 + 1, ground_height(x0 + 1, z0), z0)
			var p01 := Vector3(x0, ground_height(x0, z0 + 1), z0 + 1)
			var p11 := Vector3(x0 + 1, ground_height(x0 + 1, z0 + 1), z0 + 1)
			# Godot front faces are wound *clockwise*; CCW here renders the ground invisible
			# from above (back-face culled). Normal is computed from the CCW edge order.
			for tri in [[p00, p10, p01], [p10, p11, p01]]:
				var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
				if n.y < 0.0:
					n = -n
				for v in tri:
					st.set_normal(n)
					st.add_vertex(v)
	st.index()
	return st.commit()

func _build_pond() -> void:
	pond = load("res://game/world/pond.gd").new()
	pond.name = "Pond"
	pond.center = POND_CENTER
	pond.radius = POND_RADIUS
	pond.surface_y = WATER_SURFACE_Y
	terrain.add_child(pond)

# --- Entities ------------------------------------------------------------------

func _build_nest() -> void:
	nest = NestScene.instantiate()
	nest.position = $NestSite.position
	add_child(nest)

func _build_mother() -> void:
	mother = MotherScene.instantiate()
	add_child(mother)
	var saved := GameState.arr_to_v3(GameState.mother.get("position", null))
	mother.global_position = saved if saved != Vector3.ZERO else $Spawn.position
	if mother.global_position.y < 0.05:
		mother.global_position.y = 0.6

func _build_gates() -> void:
	var gate_script := load("res://game/world/zone_gate.gd")
	# Meadow to the east, forest edge to the north. Barriers open on progression.
	var meadow = gate_script.new()
	meadow.zone_id = "meadow"
	meadow.size = Vector3(0.6, 2.0, 60.0)
	meadow.position = Vector3(20.0, 1.0, 0.0)
	$Gates.add_child(meadow)
	var forest = gate_script.new()
	forest.zone_id = "forest_edge"
	forest.size = Vector3(80.0, 2.0, 0.6)
	forest.position = Vector3(0.0, 1.0, -22.0)
	$Gates.add_child(forest)

func _build_adventure() -> void:
	var adv = load("res://game/world/adventure.gd").new()
	adv.adventure_id = "forest_edge_walk"
	adv.start_point = Vector3(0.0, 0.0, -26.0)
	adv.goal_point = Vector3(-6.0, 0.0, -36.0)
	$Adventure.add_child(adv)

func _build_pickups() -> void:
	var spawner = load("res://game/world/pickup_spawner.gd").new()
	$Pickups.add_child(spawner)

func _build_wildlife() -> void:
	$Wildlife.set_script(load("res://game/entities/neighbours/wildlife.gd"))
	$Wildlife.build()

func _build_decoration() -> void:
	$Decoration.set_script(load("res://game/world/decoration.gd"))
	$Decoration.build()

func _restore_ducklings() -> void:
	for data in GameState.ducklings:
		spawn_duckling(data)

## Spawn a live duckling for a GameState record (fresh hatch or restored from save).
func spawn_duckling(data: Dictionary) -> CharacterBody3D:
	var d := DucklingScene.instantiate()
	d.data = data
	_ducklings_root.add_child(d)
	var pos := GameState.arr_to_v3(data.get("position", null))
	if pos == Vector3.ZERO:
		var angle := randf() * TAU
		pos = nest.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.9
	pos.y = maxf(pos.y, ground_height(pos.x, pos.z) + 0.4)
	d.global_position = pos
	return d

func ducklings() -> Array:
	return get_tree().get_nodes_in_group("duckling")

func duckling_by_id(id: int) -> Node:
	for d in ducklings():
		if d.data["id"] == id:
			return d
	return null

func write_state() -> void:
	pass

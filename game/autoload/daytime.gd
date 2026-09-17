extends Node
## Day/night clock plus world lighting. Time is a float 0..1; there is no clock in
## the UI, so the sky *is* the clock. Saved with the game so a night save loads at night.

var day_length_seconds := 14.0 * 60.0   # overridable for tests / time-lapse
var running := false                    # the park switches it on; menus keep time still
const NIGHT_START := 0.82
const NIGHT_END := 0.2

var _light: DirectionalLight3D
var _env: Environment
var _was_night := false

# Keyframes (time -> value). Curves/gradients keep the transitions smooth for free.
var _sun_angle := Curve.new()
var _light_energy := Curve.new()
var _light_color := Gradient.new()
var _sky_color := Gradient.new()
var _ambient_color := Gradient.new()

func _ready() -> void:
	_add_points(_sun_angle, [[0.0, -30.0], [0.25, 10.0], [0.5, 60.0], [0.78, 8.0], [1.0, -30.0]])
	_add_points(_light_energy, [[0.0, 0.08], [0.22, 0.6], [0.5, 1.2], [0.78, 0.6], [0.86, 0.08], [1.0, 0.08]])
	_set_gradient(_light_color, [[0.0, Color(0.35, 0.4, 0.7)], [0.22, Color(1.0, 0.75, 0.55)], [0.5, Color(1.0, 0.97, 0.9)], [0.78, Color(1.0, 0.6, 0.4)], [0.88, Color(0.35, 0.4, 0.7)], [1.0, Color(0.35, 0.4, 0.7)]])
	_set_gradient(_sky_color, [[0.0, Color(0.06, 0.07, 0.16)], [0.22, Color(0.85, 0.6, 0.5)], [0.5, Color(0.55, 0.75, 0.95)], [0.78, Color(0.9, 0.5, 0.35)], [0.88, Color(0.06, 0.07, 0.16)], [1.0, Color(0.06, 0.07, 0.16)]])
	_set_gradient(_ambient_color, [[0.0, Color(0.12, 0.14, 0.3)], [0.22, Color(0.6, 0.5, 0.5)], [0.5, Color(0.7, 0.8, 0.9)], [0.78, Color(0.6, 0.45, 0.4)], [0.88, Color(0.12, 0.14, 0.3)], [1.0, Color(0.12, 0.14, 0.3)]])
	_was_night = is_night()

func _add_points(c: Curve, points: Array) -> void:
	for p in points:
		c.add_point(Vector2(p[0], p[1]))

func _set_gradient(g: Gradient, points: Array) -> void:
	# A fresh Gradient ships with two default points; replace them instead of appending.
	g.offsets = PackedFloat32Array([points[0][0], points[-1][0]])
	g.colors = PackedColorArray([points[0][1], points[-1][1]])
	for i in range(1, points.size() - 1):
		g.add_point(points[i][0], points[i][1])

func register_world(light: DirectionalLight3D, env: Environment) -> void:
	_light = light
	_env = env
	_was_night = is_night()
	apply_lighting()

func _process(delta: float) -> void:
	if not running:
		return
	advance(delta / day_length_seconds)

func advance(fraction: float) -> void:
	var t := GameState.day_time + fraction
	while t >= 1.0:
		t -= 1.0
		GameState.day_index += 1
		EventBus.dawn_broke.emit(GameState.day_index)
	GameState.day_time = t
	var night := is_night()
	if night and not _was_night:
		EventBus.night_fell.emit()
	_was_night = night
	apply_lighting()

func set_time(t: float) -> void:
	GameState.day_time = fposmod(t, 1.0)
	_was_night = is_night()
	apply_lighting()

func is_night() -> bool:
	return GameState.day_time >= NIGHT_START or GameState.day_time < NIGHT_END

func sky_color() -> Color:
	return _sky_color.sample(GameState.day_time)

func apply_lighting() -> void:
	var t := GameState.day_time
	if _light != null and is_instance_valid(_light):
		# rotation_degrees on purpose: hand-written basis matrices bit us once (8.A.1).
		_light.rotation_degrees = Vector3(-_sun_angle.sample(t), -35.0 + 180.0 * t, 0.0)
		_light.light_color = _light_color.sample(t)
		_light.light_energy = _light_energy.sample(t)
	if _env != null:
		var sky := _sky_color.sample(t)
		_env.background_color = sky
		_env.ambient_light_color = _ambient_color.sample(t)
		_env.fog_light_color = sky.lerp(Color.WHITE, 0.3) if not is_night() else sky.darkened(0.2)
		if _env.sky != null and _env.sky.sky_material is ProceduralSkyMaterial:
			var m: ProceduralSkyMaterial = _env.sky.sky_material
			m.sky_top_color = sky.darkened(0.25)
			m.sky_horizon_color = sky.lerp(Color.WHITE, 0.35)
			m.ground_horizon_color = sky.lerp(Color.WHITE, 0.35)
			m.ground_bottom_color = sky.darkened(0.6)

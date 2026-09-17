extends Node
## Raw input -> intent, per player_id. Nothing downstream reads Input directly, so a
## second local player or a network peer later only needs another router feed.
##
## Gesture recognition for the quack grammar lives here because it is purely an
## input concern (tap vs. hold vs. double tap). What a hold *means* (far call or
## lullaby) depends on where the duck stands, so that resolution lives in the duck.

signal interact_pressed(player_id: int)
signal call_gesture(player_id: int, gesture: String) # tap | double | hold
signal journal_toggled(player_id: int)
signal pause_toggled(player_id: int)

const HOLD_SECONDS := 0.45
const DOUBLE_TAP_WINDOW := 0.3
## Generous on purpose: 150 ms was not enough against key ghosting (8.C.1), and in an
## unhurried game half a second of latency on the *release* is invisible.
const DIVE_DEBOUNCE := 0.5

var locked := false  # naming dialog etc. freeze gameplay input

var _call_down_at := -1.0
var _call_held_fired := false
var _pending_tap_at := -1.0
var _dive_raw := false
var _dive_stable := false
var _dive_changed_at := -10.0
var _sim_move := Vector2.ZERO
var _sim_camera := 0.0
var _clock := 0.0

func _process(delta: float) -> void:
	# Own clock instead of wall time so tests can advance it deterministically.
	_clock += delta
	if _call_down_at >= 0.0 and not _call_held_fired and _clock - _call_down_at >= HOLD_SECONDS:
		_call_held_fired = true
		_pending_tap_at = -1.0
		call_gesture.emit(0, "hold")
	if _pending_tap_at >= 0.0 and _clock - _pending_tap_at >= DOUBLE_TAP_WINDOW:
		_pending_tap_at = -1.0
		call_gesture.emit(0, "tap")
	# Pressing applies at once; only the release is debounced. That keeps the dive
	# responsive while a flickering key cannot restart the animation.
	if not _dive_raw and _dive_stable and _clock - _dive_changed_at >= DIVE_DEBOUNCE:
		_dive_stable = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_toggled.emit(0)
		return
	if locked:
		return
	if event.is_action_pressed("interact"):
		interact_pressed.emit(0)
	elif event.is_action_pressed("journal"):
		journal_toggled.emit(0)
	elif event.is_action_pressed("call"):
		_on_call_down()
	elif event.is_action_released("call"):
		_on_call_up()
	elif event.is_action_pressed("dive"):
		_set_dive_raw(true)
	elif event.is_action_released("dive"):
		_set_dive_raw(false)

func get_move_vector(_player_id: int = 0) -> Vector2:
	if locked:
		return Vector2.ZERO
	if _sim_move != Vector2.ZERO:
		return _sim_move
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func get_camera_turn(_player_id: int = 0) -> float:
	if _sim_camera != 0.0:
		return _sim_camera
	return Input.get_axis("camera_left", "camera_right")

func is_dive_held(_player_id: int = 0) -> bool:
	return _dive_stable and not locked

# --- Simulation hooks for tests (no InputEvent synthesis needed) ---------------
func sim_move(v: Vector2) -> void:
	_sim_move = v

func sim_dive(held: bool) -> void:
	_set_dive_raw(held)
	if not held:
		_dive_stable = false

func sim_call_down() -> void:
	_on_call_down()

func sim_call_up() -> void:
	_on_call_up()

func sim_interact() -> void:
	interact_pressed.emit(0)

# --- Internals -----------------------------------------------------------------
func _on_call_down() -> void:
	_call_down_at = _clock
	_call_held_fired = false

func _on_call_up() -> void:
	if _call_down_at < 0.0:
		return
	_call_down_at = -1.0
	if _call_held_fired:
		return
	if _pending_tap_at >= 0.0:
		_pending_tap_at = -1.0
		call_gesture.emit(0, "double")
	else:
		# A single tap only resolves once the double-tap window has passed.
		_pending_tap_at = _clock

func _set_dive_raw(v: bool) -> void:
	if v == _dive_raw:
		return
	_dive_raw = v
	_dive_changed_at = _clock
	if v:
		_dive_stable = true

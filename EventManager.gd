extends Node2D
# Hazard director, driven by power-ups (no more autonomous timer). Players
# call trigger_boulder(caster) / trigger_rain(caster); the hazard targets the
# caster's opponent. One hazard runs at a time — extra triggers queue up.
#
# Boulder: WARNING (danger arrow at the top tracks the TARGET player) ->
# FALLING (boulder drops on them) -> done.
#
# Bottle rain: SIDE WARNING (danger arrow on the target's side of the screen)
# -> RAINING (3-8 bottles hurled in from that edge, staggered over 2 s) -> done.

const WARNING_TIME := 2.5
const WALL_CENTER_X := 576.0

# Bottle rain tuning.
const RAIN_MIN_BOTTLES := 12
const RAIN_MAX_BOTTLES := 32
const RAIN_SPREAD_TIME := 2.0          # bottles staggered across this window
const RAIN_EDGE_MARGIN := 0.2          # spawn band skips 20% top and bottom
const RAIN_SPEED_MIN := 560.0
const RAIN_SPEED_MAX := 760.0
# Base course tilts upward: fired flat they'd arc down and die early — with
# lift they scrape across the whole screen before gravity wins.
const RAIN_ANGLE_UP := deg_to_rad(14.0)
const RAIN_ANGLE_JITTER := deg_to_rad(12.0)  # per-bottle deviation from the base course

const DangerArrowScript := preload("res://DangerArrow.gd")
const BoulderScript := preload("res://Boulder.gd")
const BottleScene := preload("res://Bottle.tscn")

enum State { IDLE, WARNING, FALLING, RAIN_WARNING, RAINING }

var players: Array = []  # set by Game._ready
var _state: State = State.IDLE
var _state_t := 0.0
var _arrow: Node2D = null
var _boulder: RigidBody2D = null
# The player a running hazard is aimed at.
var _target: Node2D = null
# Pending hazards: array of {"kind": "boulder"/"rain", "target": Node2D}.
var _queue: Array = []

# Bottle rain state: which side ("left"/"right") and the pre-rolled spawn
# timestamps (seconds into the RAINING state), sorted ascending.
var _rain_side := "left"
var _rain_times: Array[float] = []
var _rain_next := 0


func setup(p: Array) -> void:
	players = p


# --- Power-up API -----------------------------------------------------------

func trigger_boulder(caster: Node2D) -> void:
	_queue.append({"kind": "boulder", "target": caster.opponent})


func trigger_rain(caster: Node2D) -> void:
	_queue.append({"kind": "rain", "target": caster.opponent})


# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			if _queue.is_empty():
				return
			var next: Dictionary = _queue.pop_front()
			_target = next["target"]
			if _target == null or not is_instance_valid(_target):
				return
			if next["kind"] == "boulder":
				_start_boulder_warning()
			else:
				_start_rain_warning()
		State.WARNING:
			_state_t += delta
			# Arrow shadows the target until the drop commits.
			if _arrow != null and is_instance_valid(_target):
				_arrow.global_position.x = _target.global_position.x
			if _state_t >= WARNING_TIME:
				_drop_boulder()
		State.FALLING:
			if _boulder == null or not is_instance_valid(_boulder):
				_state = State.IDLE
		State.RAIN_WARNING:
			_state_t += delta
			if _state_t >= WARNING_TIME:
				_start_rain()
		State.RAINING:
			_state_t += delta
			while _rain_next < _rain_times.size() and _state_t >= _rain_times[_rain_next]:
				_spawn_rain_bottle()
				_rain_next += 1
			if _rain_next >= _rain_times.size():
				_state = State.IDLE


func _start_boulder_warning() -> void:
	_state = State.WARNING
	_state_t = 0.0
	_arrow = Node2D.new()
	_arrow.set_script(DangerArrowScript)
	_arrow.global_position.x = _target.global_position.x
	add_child(_arrow)


func _drop_boulder() -> void:
	var x := _arrow.global_position.x
	_arrow.queue_free()
	_arrow = null
	_state = State.FALLING
	_boulder = RigidBody2D.new()
	_boulder.set_script(BoulderScript)
	var cam := get_viewport().get_camera_2d()
	var top_y := -400.0
	if cam != null:
		top_y = cam.global_position.y - get_viewport_rect().size.y * 0.5 / cam.zoom.y - 60.0
	_boulder.global_position = Vector2(x, top_y)
	add_child(_boulder)


func _start_rain_warning() -> void:
	_state = State.RAIN_WARNING
	_state_t = 0.0
	# Rain comes from the side of the wall the target is on.
	_rain_side = "left" if _target.global_position.x < WALL_CENTER_X else "right"
	_arrow = Node2D.new()
	_arrow.set_script(DangerArrowScript)
	_arrow.edge = _rain_side
	add_child(_arrow)


func _start_rain() -> void:
	_arrow.queue_free()
	_arrow = null
	_state = State.RAINING
	_state_t = 0.0
	# Roll the volley: 3-8 bottles, each at a random moment in the 2 s window.
	_rain_times.clear()
	_rain_next = 0
	for _i in randi_range(RAIN_MIN_BOTTLES, RAIN_MAX_BOTTLES):
		_rain_times.append(randf() * RAIN_SPREAD_TIME)
	_rain_times.sort()


# One rain bottle: spawns just off the chosen edge, inside the middle 60% of
# the screen height, flying inward at a random angle. Armed like a player
# throw (it stuns) but with no home_target -> no homing.
func _spawn_rain_bottle() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var half_h := get_viewport_rect().size.y * 0.5 / cam.zoom.y
	var half_w := get_viewport_rect().size.x * 0.5 / cam.zoom.x
	var y_span := half_h * 2.0 * (1.0 - 2.0 * RAIN_EDGE_MARGIN)
	var y := cam.global_position.y - half_h + half_h * 2.0 * RAIN_EDGE_MARGIN + randf() * y_span
	var s := 1.0 if _rain_side == "left" else -1.0  # inward x direction
	var x := cam.global_position.x - s * (half_w + 40.0)
	# Tilt up (screen up = -y, so rotate against the inward x direction).
	var dir := Vector2(s, 0.0).rotated(
		-s * RAIN_ANGLE_UP + randf_range(-RAIN_ANGLE_JITTER, RAIN_ANGLE_JITTER))
	var bottle := BottleScene.instantiate()
	add_child(bottle)
	bottle.throw(Vector2(x, y), dir * randf_range(RAIN_SPEED_MIN, RAIN_SPEED_MAX))

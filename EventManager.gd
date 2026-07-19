extends Node2D
# Rolls for a random event every EVENT_INTERVAL seconds. Each event runs as a
# small state machine; only one event at a time.
#
# Boulder event: WARNING (danger arrow at the top of the screen tracks the
# highest climber) -> FALLING (boulder drops from that x) -> done.
#
# Bottle rain event: SIDE WARNING (danger arrow on a random screen edge) ->
# RAINING (3-8 bottles hurled in from that edge, staggered over 2 s) -> done.

# Events stay dormant until any player climbs this high, then one fires
# every EVENT_DELAY_MIN..MAX seconds (re-rolled after each event), guaranteed.
const EVENT_START_HEIGHT_M := 15.0
const EVENT_DELAY_MIN := 5.0
const EVENT_DELAY_MAX := 15.0
const PIXELS_PER_METER := 100.0  # same scale as HeightHud
const WARNING_TIME := 2.5

# Bottle rain tuning.
const RAIN_MIN_BOTTLES := 3
const RAIN_MAX_BOTTLES := 8
const RAIN_SPREAD_TIME := 2.0          # bottles staggered across this window
const RAIN_EDGE_MARGIN := 0.2          # spawn band skips 20% top and bottom
const RAIN_SPEED_MIN := 380.0
const RAIN_SPEED_MAX := 560.0
const RAIN_ANGLE_JITTER := deg_to_rad(22.0)  # per-bottle deviation from straight-in

const DangerArrowScript := preload("res://DangerArrow.gd")
const BoulderScript := preload("res://Boulder.gd")
const BottleScene := preload("res://Bottle.tscn")

enum State { IDLE, WARNING, FALLING, RAIN_WARNING, RAINING }

var players: Array = []  # set by Game._ready
var _timer := 0.0
var _armed := false      # true once someone has passed EVENT_START_HEIGHT_M
var _next_in := 0.0      # current rolled delay until the next event
var _start_y := 0.0      # spawn height baseline for the meter calc
var _state: State = State.IDLE
var _state_t := 0.0
var _arrow: Node2D = null
var _boulder: RigidBody2D = null

# Bottle rain state: which side ("left"/"right") and the pre-rolled spawn
# timestamps (seconds into the RAINING state), sorted ascending.
var _rain_side := "left"
var _rain_times: Array[float] = []
var _rain_next := 0


func setup(p: Array) -> void:
	players = p
	_start_y = p[0].global_position.y


func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			if not _armed:
				if _highest_height_m() >= EVENT_START_HEIGHT_M:
					_armed = true
					_next_in = randf_range(EVENT_DELAY_MIN, EVENT_DELAY_MAX)
				return
			# _timer only runs in IDLE, so the rolled delay is measured from
			# the end of the previous event. Always fires — no chance roll.
			_timer += delta
			if _timer >= _next_in:
				_timer = 0.0
				_next_in = randf_range(EVENT_DELAY_MIN, EVENT_DELAY_MAX)
				if randf() < 0.5:
					_start_boulder_warning()
				else:
					_start_rain_warning()
		State.WARNING:
			_state_t += delta
			# Arrow shadows the highest climber until the drop commits.
			if _arrow != null:
				_arrow.global_position.x = _highest_player_x()
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
	_arrow.global_position.x = _highest_player_x()
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
	_rain_side = "left" if randf() < 0.5 else "right"
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
	var dir := Vector2(s, 0.0).rotated(randf_range(-RAIN_ANGLE_JITTER, RAIN_ANGLE_JITTER))
	var bottle := BottleScene.instantiate()
	add_child(bottle)
	bottle.throw(Vector2(x, y), dir * randf_range(RAIN_SPEED_MIN, RAIN_SPEED_MAX))


# Best height above spawn across both players, in meters (HeightHud scale).
func _highest_height_m() -> float:
	var best := 0.0
	for p: Node2D in players:
		if is_instance_valid(p):
			best = maxf(best, (_start_y - p.global_position.y) / PIXELS_PER_METER)
	return best


func _highest_player_x() -> float:
	var best_x := 576.0
	var best_y := INF
	for p: Node2D in players:
		if is_instance_valid(p) and p.global_position.y < best_y:
			best_y = p.global_position.y
			best_x = p.global_position.x
	return best_x

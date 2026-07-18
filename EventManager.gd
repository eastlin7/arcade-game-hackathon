extends Node2D
# Rolls for a random event every EVENT_INTERVAL seconds. Each event runs as a
# small state machine; only one event at a time.
#
# Boulder event: WARNING (danger arrow at the top of the screen tracks the
# highest climber) -> FALLING (boulder drops from that x) -> done.

const EVENT_INTERVAL := 30.0
const EVENT_CHANCE := 0.5
const WARNING_TIME := 2.5

const DangerArrowScript := preload("res://DangerArrow.gd")
const BoulderScript := preload("res://Boulder.gd")

enum State { IDLE, WARNING, FALLING }

var players: Array = []  # set by Game._ready
var _timer := 0.0
var _state: State = State.IDLE
var _state_t := 0.0
var _arrow: Node2D = null
var _boulder: RigidBody2D = null


func setup(p: Array) -> void:
	players = p


func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			_timer += delta
			if _timer >= EVENT_INTERVAL:
				_timer = 0.0
				if randf() < EVENT_CHANCE:
					_start_boulder_warning()
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


func _highest_player_x() -> float:
	var best_x := 576.0
	var best_y := INF
	for p: Node2D in players:
		if is_instance_valid(p) and p.global_position.y < best_y:
			best_y = p.global_position.y
			best_x = p.global_position.x
	return best_x

extends Node2D
# Sagging, swaying safety rope between a player and their tether anchor.
# Cheap verlet chain (SEGMENTS points, a couple of relaxation passes) drawn
# with a single draw_polyline — fine on old GPUs.
#
# Owned by the player, lives in world space (top_level). When the player
# attaches to a new point the rope "shoots out": the far endpoint travels
# from the player to the anchor over SHOOT_TIME before settling.

const SEGMENTS := 12               # point count (11 rope segments)
const GRAVITY := Vector2(0.0, 520.0)
const DAMPING := 0.985
const RELAX_ITERATIONS := 2
const SLACK := 1.12                # rest length = distance * slack -> visible sag
# Distance at which the rope reads as fully taut (player hanging 1 m below the
# anchor = the tether limit). Slack fades out as the line approaches this.
const TAUT_DIST := 100.0
const FLOOR_Y := 596.0             # ground top is 600; rope never sinks below
const MIN_REST_LEN := 3.0
const SHOOT_TIME := 0.18
const ROPE_COLOR := Color(0.85, 0.62, 0.30)
const ROPE_COLOR_DARK := Color(0.55, 0.38, 0.18)

var player: Node2D = null          # near endpoint (pinned to body)
var anchor := Vector2.ZERO         # far endpoint (tether point)

var _pos: PackedVector2Array = []
var _prev: PackedVector2Array = []
var _shoot_t := 1.0                # 0..1, <1 while the shoot-out plays
var _active := false


func _ready() -> void:
	top_level = true  # world-space drawing, ignore player transform
	global_position = Vector2.ZERO
	# z 0: above the wall background (also z 0, but earlier in the tree).
	# Drawing before the player's sprites (child index 0) keeps it behind the
	# climber without dropping below the background.


func shoot_to(target: Vector2) -> void:
	anchor = target
	_active = true
	_shoot_t = 0.0
	# Reset the chain bunched at the player; it uncoils as the tip flies out.
	var start := player.global_position if player != null else target
	_pos.resize(SEGMENTS)
	_prev.resize(SEGMENTS)
	for i in SEGMENTS:
		_pos[i] = start
		_prev[i] = start


func deactivate() -> void:
	_active = false
	queue_redraw()


func _process(delta: float) -> void:
	if not _active or player == null:
		return
	var head := player.global_position
	var tip := anchor
	if _shoot_t < 1.0:
		_shoot_t = minf(_shoot_t + delta / SHOOT_TIME, 1.0)
		# Ease-out flight of the rope tip toward the ring.
		var t := 1.0 - (1.0 - _shoot_t) * (1.0 - _shoot_t)
		tip = head.lerp(anchor, t)

	# Verlet integrate the free points (endpoints pinned below).
	var dt2 := delta * delta
	for i in range(1, SEGMENTS - 1):
		var p := _pos[i]
		var vel := (p - _prev[i]) * DAMPING
		_prev[i] = p
		_pos[i] = p + vel + GRAVITY * dt2
		if _pos[i].y > FLOOR_Y:
			_pos[i].y = FLOOR_Y

	# Pin endpoints, then relax segment lengths.
	_pos[0] = head
	_pos[SEGMENTS - 1] = tip
	# Slack fades to zero as the line stretches toward the tether limit — a
	# player hanging at the 1 m floor sees a straight, taut rope.
	var dist := head.distance_to(tip)
	var taut := clampf((dist / TAUT_DIST - 0.6) / 0.4, 0.0, 1.0)
	var slack := lerpf(SLACK, 1.0, taut)
	var rest := maxf(dist * slack / float(SEGMENTS - 1), MIN_REST_LEN)
	for _it in RELAX_ITERATIONS:
		_pos[0] = head
		_pos[SEGMENTS - 1] = tip
		for i in range(0, SEGMENTS - 1):
			var a := _pos[i]
			var b := _pos[i + 1]
			var d := a.distance_to(b)
			if d < 0.001:
				continue
			var diff := (d - rest) / d * 0.5
			var offset := (b - a) * diff
			if i > 0:
				_pos[i] = a + offset
			if i + 1 < SEGMENTS - 1:
				_pos[i + 1] = b - offset
		_pos[0] = head
		_pos[SEGMENTS - 1] = tip
	queue_redraw()


func _draw() -> void:
	if not _active or _pos.size() < 2:
		return
	draw_polyline(_pos, ROPE_COLOR_DARK, 4.0, true)
	draw_polyline(_pos, ROPE_COLOR, 2.2, true)

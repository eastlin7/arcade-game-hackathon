extends Node2D
# Root game controller: camera follow + arcade exit contract.

@onready var player: RigidBody2D = $Player
@onready var player2: RigidBody2D = $Player2
@onready var camera: Camera2D = $Camera
@onready var height_hud: Control = $HudLayer/HeightHud
@onready var height_hud2: Control = $HudLayer/HeightHud2


func _ready() -> void:
	height_hud.setup(player)
	height_hud2.setup(player2)
	$EventManager.setup([player, player2])
	player.opponent = player2
	player2.opponent = player
	player.event_manager = $EventManager
	player2.event_manager = $EventManager
	_win_screen = CanvasLayer.new()
	_win_screen.set_script(WinScreenScript)
	add_child(_win_screen)


# Camera zoom: 1.0 when players are close, eases out to ZOOM_FAR as their
# separation grows from SEP_NEAR to SEP_FAR pixels. ZOOM_FAR is capped so the
# zoomed-out view is never wider than the 1152 px wall (1080 / 1152).
const ZOOM_NEAR := 1.0
const ZOOM_FAR := 0.9375
const SEP_NEAR := 350.0
const SEP_FAR := 850.0
const ZOOM_SPEED := 3.0

# Screen shake: decaying random camera offset, in real time so the hitstop
# slow-mo doesn't stretch it.
const SHAKE_DECAY := 22.0

var _shake := 0.0

# Race: first player to WIN_HEIGHT_M meters wins.
const WIN_HEIGHT_M := 100
const WinScreenScript := preload("res://WinScreen.gd")
const P1_COLOR := Color(1.0, 0.85, 0.3)
const P2_COLOR := Color(1.0, 0.35, 0.3)
var _win_screen: CanvasLayer = null
var _won := false

# Competitive scoring: +1 pt/sec to whichever player is strictly higher
# (rounded to the meter, same calc as the HUD). Tie -> nobody scores.
var _score_accum := 0.0


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	# Camera centers on the midpoint between the two players; the camera's
	# limit_* bounds clamp it inside the wall / above the floor.
	var a := player.global_position
	var b := player2.global_position
	camera.global_position = (a + b) * 0.5

	var t := clampf(((a - b).length() - SEP_NEAR) / (SEP_FAR - SEP_NEAR), 0.0, 1.0)
	var target_zoom := lerpf(ZOOM_NEAR, ZOOM_FAR, t)
	var z := lerpf(camera.zoom.x, target_zoom, minf(ZOOM_SPEED * delta, 1.0))
	camera.zoom = Vector2(z, z)

	# Shake rides on the camera offset so position/limits stay untouched.
	if _shake > 0.01:
		var real_delta := delta / maxf(Engine.time_scale, 0.001)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = maxf(0.0, _shake - SHAKE_DECAY * real_delta * maxf(_shake / 6.0, 0.5))
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

	# Competitive scoring tick.
	var h1: int = height_hud.height_m()
	var h2: int = height_hud2.height_m()

	# Race finish: first to WIN_HEIGHT_M takes it. Simultaneous -> higher wins;
	# exact tie -> P1 by pixel (nearly impossible).
	if not _won and (h1 >= WIN_HEIGHT_M or h2 >= WIN_HEIGHT_M):
		_won = true
		var p1_wins := h1 >= WIN_HEIGHT_M and (h2 < WIN_HEIGHT_M
			or player.global_position.y <= player2.global_position.y)
		_win_screen.show_win(1 if p1_wins else 2, P1_COLOR if p1_wins else P2_COLOR)
		return
	height_hud.set_leading(h1 > h2)
	height_hud2.set_leading(h2 > h1)
	if h1 == h2:
		_score_accum = 0.0
	else:
		_score_accum += delta
		while _score_accum >= 1.0:
			_score_accum -= 1.0
			if h1 > h2:
				height_hud.add_point()
			else:
				height_hud2.add_point()


func _unhandled_input(event: InputEvent) -> void:
	# Arcade cabinet contract: exit action quits the game.
	if event.is_action_pressed("ui_exit"):
		get_tree().quit()

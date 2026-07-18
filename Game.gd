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


# Camera zoom: 1.0 when players are close, eases out to ZOOM_FAR (shows ~50%
# more world) as their separation grows from SEP_NEAR to SEP_FAR pixels.
const ZOOM_NEAR := 1.0
const ZOOM_FAR := 0.67
const SEP_NEAR := 350.0
const SEP_FAR := 850.0
const ZOOM_SPEED := 3.0


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


func _unhandled_input(event: InputEvent) -> void:
	# Arcade cabinet contract: exit action quits the game.
	if event.is_action_pressed("ui_exit"):
		get_tree().quit()

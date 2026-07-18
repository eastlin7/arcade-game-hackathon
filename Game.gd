extends Node2D
# Root game controller: camera follow + arcade exit contract.

@onready var player: RigidBody2D = $Player
@onready var camera: Camera2D = $Camera


func _process(_delta: float) -> void:
	# Camera tracks the player vertically only; horizontally centered.
	# limit_bottom on the camera prevents showing below the floor.
	camera.global_position = Vector2(576, player.global_position.y)


func _unhandled_input(event: InputEvent) -> void:
	# Arcade cabinet contract: exit action quits the game.
	if event.is_action_pressed("ui_exit"):
		get_tree().quit()

extends Control

# Main menu for Aggro Bouldering (c-base arcade cabinet).
# Navigation: joystick/arrows move focus, Button 1 (ui_accept) activates.
# ui_exit (Esc) always quits back to the launcher.

@onready var start_button: Button = $Menu/StartButton
@onready var high_score_button: Button = $Menu/HighScoreButton
@onready var exit_button: Button = $Menu/ExitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	high_score_button.pressed.connect(_on_high_score_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	start_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_exit"):
		get_tree().quit()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_high_score_pressed() -> void:
	# TODO: show high score screen (reads /arcade/scores/arcade-game.json).
	print("High Score — screen not implemented yet")

func _on_exit_pressed() -> void:
	get_tree().quit()

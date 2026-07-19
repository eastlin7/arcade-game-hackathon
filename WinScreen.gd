extends CanvasLayer
# Full-screen win overlay: dark banner swipes in, "PLAYER X WINS!" slams in
# with a bounce, and after 5 seconds a blinking "PRESS ANY KEY TO RESTART"
# arms — early so players mid-climb don't insta-skip the screen they caused.
# The tree is paused the whole time; this layer runs in ALWAYS mode.

const RESTART_ARM_DELAY := 5.0

var _can_restart := false
var _shown := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_win(winner: int, col: Color) -> void:
	if _shown:
		return
	_shown = true
	get_tree().paused = true
	var vp := get_viewport().get_visible_rect().size

	# Swiping banner: full-screen dark sheet sliding in from the winner's side.
	var sheet := ColorRect.new()
	sheet.color = Color(0.06, 0.07, 0.12, 0.92)
	sheet.size = vp
	sheet.position = Vector2(-vp.x if winner == 1 else vp.x, 0.0)
	add_child(sheet)
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(sheet, "position:x", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Accent stripe behind the text, in the winner's color.
	var stripe := ColorRect.new()
	stripe.color = Color(col.r, col.g, col.b, 0.25)
	stripe.size = Vector2(vp.x, 220.0)
	stripe.position = Vector2(vp.x if winner == 1 else -vp.x, vp.y * 0.5 - 110.0)
	add_child(stripe)
	var ts := create_tween()
	ts.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ts.tween_interval(0.15)
	ts.tween_property(stripe, "position:x", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Big win text: drops in from above with an overshoot bounce.
	var label := Label.new()
	label.text = "PLAYER %d WINS!" % winner
	label.add_theme_font_size_override("font_size", 120)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1))
	label.add_theme_constant_override("outline_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(vp.x, 220.0)
	label.position = Vector2(0.0, -260.0)
	add_child(label)
	var tl := create_tween()
	tl.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tl.tween_interval(0.3)
	tl.tween_property(label, "position:y", vp.y * 0.5 - 110.0, 0.55)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Endless soft pulse once landed.
	tl.tween_callback(func() -> void:
		var tp := create_tween()
		tp.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tp.set_loops()
		tp.tween_property(label, "modulate:a", 0.75, 0.6)
		tp.tween_property(label, "modulate:a", 1.0, 0.6))

	# Restart prompt: hidden until armed, then blinks.
	var prompt := Label.new()
	prompt.text = "PRESS ANY KEY TO RESTART"
	prompt.add_theme_font_size_override("font_size", 44)
	prompt.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	prompt.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1))
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(vp.x, 60.0)
	prompt.position = Vector2(0.0, vp.y * 0.5 + 160.0)
	prompt.visible = false
	add_child(prompt)

	await get_tree().create_timer(RESTART_ARM_DELAY, true).timeout
	_can_restart = true
	prompt.visible = true
	var tb := create_tween()
	tb.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tb.set_loops()
	tb.tween_property(prompt, "modulate:a", 0.25, 0.45)
	tb.tween_property(prompt, "modulate:a", 1.0, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	# ui_exit must keep working even on the win screen (arcade contract).
	if event.is_action_pressed("ui_exit"):
		get_tree().quit()
		return
	if not _can_restart:
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		get_tree().paused = false
		get_tree().reload_current_scene()

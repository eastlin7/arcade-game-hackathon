extends CanvasLayer
# Cartoony race intro so the match doesn't just drop players in cold:
# dim sheet + tilted "REACH 100 METERS FIRST!" swipes in, then a huge tilted
# "CLIMB!" slams down — the tree unpauses on the slam (that IS the go signal)
# and the overlay pops away.

const INTRO_HOLD := 1.7   # how long the goal line sits before CLIMB!

var _sheet: ColorRect
var _goal: Label
var _climb: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_start() -> void:
	get_tree().paused = true
	var vp := get_viewport().get_visible_rect().size

	_sheet = ColorRect.new()
	_sheet.color = Color(0.06, 0.07, 0.12, 0.75)
	_sheet.size = vp
	add_child(_sheet)

	# Goal line: tilted, drops in with overshoot.
	_goal = _make_label("REACH 100 METERS FIRST!", 72, Color(0.85, 0.87, 0.9), vp)
	_goal.rotation = deg_to_rad(-4.0)
	_goal.position = Vector2(0.0, -220.0)
	var tg := create_tween()
	tg.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tg.tween_property(_goal, "position:y", vp.y * 0.42 - 80.0, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Cartoony idle wobble while it holds.
	tg.tween_callback(func() -> void:
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_loops()
		tw.tween_property(_goal, "rotation", deg_to_rad(3.0), 0.45)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_goal, "rotation", deg_to_rad(-4.0), 0.45)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))

	# CLIMB!: giant, tilted the other way, scale-slams in — and unlocks play.
	_climb = _make_label("CLIMB!", 170, Color(1.0, 0.85, 0.3), vp)
	_climb.rotation = deg_to_rad(5.0)
	_climb.position = Vector2(0.0, vp.y * 0.5 - 120.0)
	_climb.pivot_offset = _climb.size * 0.5
	_climb.scale = Vector2.ZERO
	var tc := create_tween()
	tc.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tc.tween_interval(INTRO_HOLD)
	tc.tween_callback(func() -> void: get_tree().paused = false)  # GO!
	tc.tween_property(_climb, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tc.parallel().tween_property(_sheet, "modulate:a", 0.0, 0.4)
	tc.parallel().tween_property(_goal, "modulate:a", 0.0, 0.25)
	# Let CLIMB! linger a beat, then pop it away.
	tc.tween_interval(0.7)
	tc.tween_property(_climb, "scale", Vector2(1.4, 1.4), 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tc.parallel().tween_property(_climb, "modulate:a", 0.0, 0.2)
	tc.tween_callback(queue_free)


func _make_label(text: String, size_px: int, col: Color, vp: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1))
	l.add_theme_constant_override("outline_size", 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(vp.x, 240.0)
	l.pivot_offset = l.size * 0.5
	add_child(l)
	return l

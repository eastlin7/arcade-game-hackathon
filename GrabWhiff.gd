extends Node2D
# One-shot missed-grab feedback: a quick gray swipe of arc strokes that
# expands slightly and fades. Frees itself when done.

const LIFETIME := 0.18

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / LIFETIME, 0.0, 1.0)
	var alpha := (1.0 - p) * 0.7
	var r := lerpf(6.0, 12.0, p)
	var col := Color(0.75, 0.75, 0.8, alpha)
	# Three short arc strokes swiping downward around the hand.
	for i in 3:
		var start := PI * 0.25 + float(i) * PI * 0.25
		draw_arc(Vector2.ZERO, r, start, start + PI * 0.14, 6, col, 2.0)

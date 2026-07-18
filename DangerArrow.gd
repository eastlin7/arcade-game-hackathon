extends Node2D
# Warning marker for incoming events: a blinking downward arrow with "DANGER"
# above it, pinned to the top edge of the visible screen. EventManager moves
# it horizontally (it tracks the highest climber) and frees it.

const PX := 4
const STROKE := Color(0.08, 0.06, 0.1)
const FILL := Color(1.0, 0.25, 0.2)

const GLYPHS := {
	"D": ["##.", "#.#", "#.#", "#.#", "##."],
	"A": ["###", "#.#", "###", "#.#", "#.#"],
	"N": ["#.#", "###", "#.#", "#.#", "#.#"],
	"G": ["###", "#..", "#.#", "#.#", "###"],
	"E": ["###", "#..", "##.", "#..", "###"],
	"R": ["##.", "#.#", "##.", "#.#", "#.#"],
}

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	# Pin to the top of the current camera view, keep constant screen size.
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var half_h := get_viewport_rect().size.y * 0.5 / cam.zoom.y
		global_position.y = cam.global_position.y - half_h + 30.0 / cam.zoom.y
		scale = Vector2.ONE / cam.zoom.y
	queue_redraw()


func _draw() -> void:
	# Blink ~4x per second.
	if fmod(_t, 0.25) > 0.17:
		return
	# "DANGER" text centered above the arrow.
	_draw_text("DANGER", Vector2(0.0, 0.0))
	# Downward triangle arrow under the text, bobbing slightly.
	var bob := sin(_t * 10.0) * 3.0
	var top_y := 5.0 * PX + 8.0 + bob
	var pts := PackedVector2Array([
		Vector2(-14.0, top_y), Vector2(14.0, top_y), Vector2(0.0, top_y + 20.0),
	])
	var outline := PackedVector2Array([
		Vector2(-17.0, top_y - 3.0), Vector2(17.0, top_y - 3.0), Vector2(0.0, top_y + 25.0),
	])
	draw_colored_polygon(outline, STROKE)
	draw_colored_polygon(pts, FILL)


func _draw_text(text: String, center: Vector2) -> void:
	var w := text.length() * 4.0 * PX - PX
	var origin := center + Vector2(-w / 2.0, 0.0)
	var stroke_w := maxf(2.0, PX * 0.34)
	for pass_i in 2:
		var cursor := origin
		for ch in text:
			var glyph: Array = GLYPHS.get(ch, GLYPHS["D"])
			for row in 5:
				var line: String = glyph[row]
				for col in 3:
					if line[col] != "#":
						continue
					var p := cursor + Vector2(col * PX, row * PX)
					if pass_i == 0:
						draw_rect(Rect2(p - Vector2(stroke_w, stroke_w),
							Vector2(PX + 2.0 * stroke_w, PX + 2.0 * stroke_w)), STROKE)
					else:
						draw_rect(Rect2(p, Vector2(PX, PX)), FILL)
			cursor.x += 4.0 * PX

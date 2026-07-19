extends Node2D
# Floating badge above a player's head showing the held power-up.
# Reads `player.power` every frame; hidden when empty.

var player: Node2D = null
var _t := 0.0

const COLORS := {
	"homing": Color(0.45, 0.65, 1.0),   # blue shell
	"rain": Color(0.35, 0.75, 0.4),     # bottle green
	"boulder": Color(0.6, 0.57, 0.55),  # rock grey
}


func _process(delta: float) -> void:
	_t += delta
	var held: String = player.power if player != null else ""
	visible = held != ""
	if visible:
		position = Vector2(0.0, -110.0 + sin(_t * 3.0) * 4.0)
		queue_redraw()


func _draw() -> void:
	var kind: String = player.power if player != null else ""
	if kind == "":
		return
	var col: Color = COLORS.get(kind, Color.WHITE)
	draw_circle(Vector2.ZERO, 18.0, Color(0.08, 0.06, 0.1))
	draw_circle(Vector2.ZERO, 15.0, col)
	match kind:
		"homing":
			# Bottle silhouette.
			draw_rect(Rect2(-3, -2, 6, 10), Color.WHITE)
			draw_rect(Rect2(-1.5, -8, 3, 6), Color.WHITE)
		"rain":
			# Three falling drops/bottles.
			for i in 3:
				draw_rect(Rect2(-8 + i * 6, -6 + (i % 2) * 4, 3, 8), Color.WHITE)
		"boulder":
			draw_circle(Vector2(0, 0), 8.0, Color.WHITE)
			draw_circle(Vector2(2, 2), 5.0, col.darkened(0.2))

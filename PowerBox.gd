extends Node2D
# Shiny gold mystery box ("?") parked on the wall. A player collects it by
# simply getting close — no grab needed. Pops with a burst effect and grants
# a random power (rolled by the collector).

const SIZE := 56.0
const GOLD := Color(1.0, 0.78, 0.15)
const GOLD_DARK := Color(0.72, 0.5, 0.05)
const GOLD_LIGHT := Color(1.0, 0.95, 0.55)
const STROKE := Color(0.08, 0.06, 0.1)

# 5x7 question mark glyph.
const QMARK := [
	".###.",
	"#...#",
	"....#",
	"...#.",
	"..#..",
	".....",
	"..#..",
]

const GrabSplashScript := preload("res://GrabSplash.gd")
const GrabWhiffScript := preload("res://GrabWhiff.gd")

var _t := randf() * TAU
var _base_y := 0.0


func _ready() -> void:
	add_to_group("powerups")
	_base_y = position.y


func _process(delta: float) -> void:
	_t += delta
	# Gentle bob + a slow wobble; shine sweep drives redraw.
	position.y = _base_y + sin(_t * 2.2) * 5.0
	rotation = sin(_t * 1.4) * 0.08
	queue_redraw()


func _draw() -> void:
	var h := SIZE * 0.5
	# Pulsing glow halo -> reads as "shiny, come get me" from far away.
	var pulse := 0.55 + 0.45 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, h * 1.55, Color(GOLD.r, GOLD.g, GOLD.b, 0.10 + 0.08 * pulse))
	draw_circle(Vector2.ZERO, h * 1.25, Color(GOLD.r, GOLD.g, GOLD.b, 0.14 + 0.10 * pulse))
	# Box: outline, body, bevel.
	draw_rect(Rect2(-h - 3, -h - 3, SIZE + 6, SIZE + 6), STROKE)
	draw_rect(Rect2(-h, -h, SIZE, SIZE), GOLD)
	draw_rect(Rect2(-h, -h, SIZE, 8), GOLD_LIGHT)
	draw_rect(Rect2(-h, h - 8, SIZE, 8), GOLD_DARK)
	draw_rect(Rect2(-h, -h, 8, SIZE), GOLD_LIGHT.darkened(0.1))
	draw_rect(Rect2(h - 8, -h, 8, SIZE), GOLD_DARK)
	# Rivets.
	for corner: Vector2 in [Vector2(-h + 10, -h + 10), Vector2(h - 10, -h + 10),
			Vector2(-h + 10, h - 10), Vector2(h - 10, h - 10)]:
		draw_circle(corner, 3.0, GOLD_DARK)
	# Question mark, dark with light offset for depth.
	var px := 5.0
	var org := Vector2(-2.5 * px, -3.5 * px)
	for row in QMARK.size():
		for col in QMARK[row].length():
			if QMARK[row][col] == "#":
				var p := org + Vector2(col * px, row * px)
				draw_rect(Rect2(p + Vector2(1.5, 1.5), Vector2(px, px)), GOLD_DARK.darkened(0.3))
				draw_rect(Rect2(p, Vector2(px, px)), Color(1, 1, 1, 0.95))
	# Diagonal shine sweep across the face.
	var sweep := fmod(_t * 0.7, 2.0) * SIZE * 2.0 - SIZE * 1.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var shine := PackedVector2Array([
		Vector2(sweep - h, -h), Vector2(sweep - h + 12, -h),
		Vector2(sweep - h - SIZE + 12, h), Vector2(sweep - h - SIZE, h),
	])
	# Clip by hand: only draw while the band overlaps the box.
	if sweep > -SIZE * 0.2 and sweep < SIZE * 1.8:
		draw_colored_polygon(shine, Color(1, 1, 1, 0.30))


# Pop: dust burst + expanding ring, then gone.
func collect() -> void:
	var dust: CPUParticles2D = GrabSplashScript.new()
	dust.global_position = global_position
	get_parent().add_child(dust)
	var ring := Node2D.new()
	ring.set_script(GrabWhiffScript)
	ring.global_position = global_position
	ring.scale = Vector2(2.5, 2.5)
	get_parent().add_child(ring)
	queue_free()

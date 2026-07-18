extends Node2D
# Cartoony fight-scene hit text ("POW!" etc), drawn with the same 3x5 pixel
# bitmap font style as HeightHud. Pops in with an overshoot, holds a beat,
# fades out over 0.2s, then frees itself.

const WORDS := ["POW!", "BOINK!", "KABAAM!", "PLOP!"]

const PX := 4  # screen pixels per glyph pixel (smaller than the HUD digits)
const STROKE := Color(0.08, 0.06, 0.1)
const COLORS := [
	Color(1.0, 0.85, 0.3),   # yellow
	Color(1.0, 0.55, 0.15),  # orange
	Color(1.0, 0.4, 0.35),   # red
]

const POP_TIME := 0.12
const HOLD_TIME := 0.25
const FADE_TIME := 0.2

const GLYPHS := {
	"P": ["###", "#.#", "###", "#..", "#.."],
	"O": ["###", "#.#", "#.#", "#.#", "###"],
	"W": ["#.#", "#.#", "#.#", "###", "#.#"],
	"B": ["##.", "#.#", "##.", "#.#", "##."],
	"I": ["###", ".#.", ".#.", ".#.", "###"],
	"N": ["#.#", "###", "#.#", "#.#", "#.#"],
	"K": ["#.#", "##.", "#..", "##.", "#.#"],
	"A": ["###", "#.#", "###", "#.#", "#.#"],
	"M": ["#.#", "###", "#.#", "#.#", "#.#"],
	"L": ["#..", "#..", "#..", "#..", "###"],
	"!": [".#.", ".#.", ".#.", "...", ".#."],
	" ": ["...", "...", "...", "...", "..."],
}

var text: String = WORDS[0]
var fill: Color = COLORS[0]
var _t := 0.0


func _ready() -> void:
	text = WORDS[randi() % WORDS.size()]
	fill = COLORS[randi() % COLORS.size()]
	rotation = randf_range(-0.15, 0.15)
	scale = Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	if _t < POP_TIME:
		# Overshoot pop: 0 -> 1.35 -> settles at 1.
		var p := _t / POP_TIME
		var s := 1.35 * (1.0 - (1.0 - p) * (1.0 - p))
		scale = Vector2.ONE * s
	elif _t < POP_TIME + HOLD_TIME:
		scale = scale.lerp(Vector2.ONE, 12.0 * delta)
	elif _t < POP_TIME + HOLD_TIME + FADE_TIME:
		var p := (_t - POP_TIME - HOLD_TIME) / FADE_TIME
		modulate.a = 1.0 - p
		scale = Vector2.ONE * (1.0 + 0.3 * p)  # drifts bigger as it fades
	else:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var w := text.length() * 4.0 * PX - PX
	var origin := Vector2(-w / 2.0, -2.5 * PX)  # centered on the node
	var stroke_w := maxf(2.0, PX * 0.34)
	for pass_i in 2:
		var cursor := origin
		for ch in text:
			var glyph: Array = GLYPHS.get(ch, GLYPHS[" "])
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
						draw_rect(Rect2(p, Vector2(PX, PX)), fill)
			cursor.x += 4.0 * PX

extends Control
# Top-left height counter drawn with a built-in 3x5 pixel bitmap font.
# Each glyph pixel renders as a scaled square with a dark stroke pass under it,
# giving crisp pixel-art text with an outline — no font asset needed.

const PX := 6           # screen pixels per glyph pixel (number line)
const PX_SMALL := 3     # scale for the "HEIGHT" caption
const MARGIN := Vector2(18.0, 14.0)
const PIXELS_PER_METER := 100.0

const FILL_CAPTION := Color(0.85, 0.87, 0.9)
const STROKE := Color(0.08, 0.06, 0.1)

# Anchor to the top-right corner instead of top-left (player 2).
@export var right_side := false
@export var fill := Color(1.0, 0.85, 0.3)  # digit color (P1 yellow, P2 red)

# 3x5 pixel glyphs. '#' = filled.
const GLYPHS := {
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", ".##", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
	"M": ["#.#", "###", "#.#", "#.#", "#.#"],
	"H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"E": ["###", "#..", "##.", "#..", "###"],
	"I": ["###", ".#.", ".#.", ".#.", "###"],
	"G": ["###", "#..", "#.#", "#.#", "###"],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	" ": ["...", "...", "...", "...", "..."],
}

var player: Node2D = null
var _start_y := 0.0
var _height_m := -1  # last drawn value; redraw only on change


func setup(p: Node2D) -> void:
	player = p
	_start_y = p.global_position.y


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var m := maxi(0, int((_start_y - player.global_position.y) / PIXELS_PER_METER))
	if m != _height_m:
		_height_m = m
		queue_redraw()


func _draw() -> void:
	var num := "%dM" % maxi(_height_m, 0)
	var pos := MARGIN
	if right_side:
		# Right-align both lines against the right margin.
		var w_cap := _text_width("HEIGHT", PX_SMALL)
		var w_num := _text_width(num, PX)
		pos = Vector2(size.x - MARGIN.x - w_cap, MARGIN.y)
		_draw_text("HEIGHT", pos, PX_SMALL, FILL_CAPTION)
		pos = Vector2(size.x - MARGIN.x - w_num, MARGIN.y + 5.0 * PX_SMALL + 8.0)
		_draw_text(num, pos, PX, fill)
	else:
		_draw_text("HEIGHT", pos, PX_SMALL, FILL_CAPTION)
		pos.y += 5.0 * PX_SMALL + 8.0
		_draw_text(num, pos, PX, fill)


func _text_width(text: String, s: float) -> float:
	return text.length() * 4.0 * s - s  # glyphs 3 wide + 1 gap, minus last gap


# Two passes: stroke squares (expanded 1 glyph-pixel-unit... actually 2 screen
# px) underneath, fill squares on top -> clean outline around the whole text.
func _draw_text(text: String, origin: Vector2, s: float, fill: Color) -> void:
	var stroke_w := maxf(2.0, s * 0.34)
	for pass_i in 2:
		var cursor := origin
		for ch in text:
			var glyph: Array = GLYPHS.get(ch, GLYPHS[" "])
			for row in 5:
				var line: String = glyph[row]
				for col in 3:
					if line[col] != "#":
						continue
					var p := cursor + Vector2(col * s, row * s)
					if pass_i == 0:
						draw_rect(Rect2(p - Vector2(stroke_w, stroke_w),
							Vector2(s + 2.0 * stroke_w, s + 2.0 * stroke_w)), STROKE)
					else:
						draw_rect(Rect2(p, Vector2(s, s)), fill)
			cursor.x += 4.0 * s  # 3 wide + 1 gap

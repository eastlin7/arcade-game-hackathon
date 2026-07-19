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
	"P": ["###", "#.#", "###", "#..", "#.."],
	"S": ["###", "#..", "###", "..#", "###"],
	" ": ["...", "...", "...", "...", "..."],
}

var player: Node2D = null
var _start_y := 0.0
var _height_m := -1  # last drawn value; redraw only on change

# Competitive score (driven by Game.gd).
var _score := 0
var _leading := false  # strictly higher than the other player -> pulse effect
var _flash := 0.0      # 1.0 -> 0.0 pop each time a point lands
var _time := 0.0       # drives the leader pulse


func setup(p: Node2D) -> void:
	player = p
	_start_y = p.global_position.y


func height_m() -> int:
	if player == null or not is_instance_valid(player):
		return 0
	return maxi(0, int((_start_y - player.global_position.y) / PIXELS_PER_METER))


func add_point() -> void:
	_score += 1
	_flash = 1.0
	queue_redraw()


func set_leading(l: bool) -> void:
	if l != _leading:
		_leading = l
		queue_redraw()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var m := height_m()
	if m != _height_m:
		_height_m = m
		queue_redraw()
	# Animate only while the effect is live (cheap: static HUD redraws on change).
	if _leading or _flash > 0.0:
		_time += delta
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	var num := "%dM" % maxi(_height_m, 0)
	var score_txt := "%d PTS" % _score

	# Leader effect: pulsing brighter color + a size pop when a point lands.
	var score_col := fill
	var score_s := float(PX)
	if _leading:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		score_col = fill.lerp(Color(1.0, 1.0, 1.0), 0.35 + 0.4 * pulse)
		score_s = PX * (1.0 + 0.06 * pulse + 0.25 * _flash)

	var y_num := MARGIN.y + 5.0 * PX_SMALL + 8.0
	var y_score := y_num + 5.0 * PX + 10.0
	if right_side:
		# Right-align all lines against the right margin.
		var w_cap := _text_width("HEIGHT", PX_SMALL)
		var w_num := _text_width(num, PX)
		var w_sc := _text_width(score_txt, score_s)
		_draw_text("HEIGHT", Vector2(size.x - MARGIN.x - w_cap, MARGIN.y), PX_SMALL, FILL_CAPTION)
		_draw_text(num, Vector2(size.x - MARGIN.x - w_num, y_num), PX, fill)
		_draw_text(score_txt, Vector2(size.x - MARGIN.x - w_sc, y_score), score_s, score_col)
	else:
		_draw_text("HEIGHT", MARGIN, PX_SMALL, FILL_CAPTION)
		_draw_text(num, Vector2(MARGIN.x, y_num), PX, fill)
		_draw_text(score_txt, Vector2(MARGIN.x, y_score), score_s, score_col)


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

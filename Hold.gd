extends Node2D
# Visual-only bouldering hold. Becomes grabbable later.

# Palette of climbing-hold colors: orange, teal, magenta, lime.
const HOLD_COLORS := [
	Color(0.85, 0.45, 0.2),  # orange
	Color(0.2, 0.7, 0.68),   # teal
	Color(0.82, 0.25, 0.6),  # magenta
	Color(0.55, 0.75, 0.25), # lime
]

# Per-hand highlight colors: left hand (J) cyan, right hand (K) amber.
const HL_LEFT_COLOR := Color(0.35, 0.85, 1.0)
const HL_RIGHT_COLOR := Color(1.0, 0.78, 0.3)
const HL_BOTH_COLOR := Color(1.0, 1.0, 1.0)

var _base_color: Color = HOLD_COLORS[0]
var _hl_left := false
var _hl_right := false


# Reachability highlight, set by the player each frame.
func set_highlight(is_left: bool, on: bool) -> void:
	if is_left:
		if _hl_left == on:
			return
		_hl_left = on
	else:
		if _hl_right == on:
			return
		_hl_right = on
	queue_redraw()


func _ready() -> void:
	add_to_group("holds")
	# Pick a color and jitter its hue slightly so each hold looks unique.
	_base_color = HOLD_COLORS[randi() % HOLD_COLORS.size()]
	var h := _base_color.h + randf_range(-0.03, 0.03)
	_base_color = Color.from_hsv(wrapf(h, 0.0, 1.0), _base_color.s, _base_color.v)
	queue_redraw()


func _draw() -> void:
	var r := 14.0
	# Main filled knob.
	draw_circle(Vector2.ZERO, r, _base_color)
	# Darker outline arc around the knob.
	var outline := _base_color.darkened(0.4)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, outline, 2.5, true)
	# Small highlight circle offset up-left.
	var highlight := _base_color.lightened(0.4)
	draw_circle(Vector2(-r * 0.35, -r * 0.35), r * 0.28, highlight)
	# Small darker bolt dot in the center.
	draw_circle(Vector2.ZERO, r * 0.18, _base_color.darkened(0.55))
	# Reachability glow: which hand(s) can grab this hold right now.
	if _hl_left or _hl_right:
		var hl := HL_BOTH_COLOR if (_hl_left and _hl_right) else (HL_LEFT_COLOR if _hl_left else HL_RIGHT_COLOR)
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color(hl, 0.9), 2.5, true)
		draw_arc(Vector2.ZERO, r + 7.5, 0.0, TAU, 24, Color(hl, 0.25), 3.0, true)

extends Node2D
# One plywood wall panel of the bouldering wall background, drawn procedurally.
# Deterministic per-cell: WallBackground seeds `rng_seed` before adding to tree.

const PANEL_W := 192.0
const PANEL_H := 216.0
const TNUT_SPACING := 48.0

# Muted plywood panel palette (weighted toward neutrals).
const PANEL_COLORS := [
	Color(0.16, 0.17, 0.21),  # slate
	Color(0.18, 0.19, 0.23),  # lighter slate
	Color(0.15, 0.16, 0.20),  # darker slate
	Color(0.17, 0.18, 0.22),  # mid slate
]
# Rare accent panels (real gyms mix in colored boards).
const ACCENT_COLORS := [
	Color(0.30, 0.17, 0.14),  # brick red
	Color(0.14, 0.22, 0.24),  # deep teal
	Color(0.25, 0.21, 0.13),  # ochre
]

var rng_seed: int = 0


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# Base panel color: ~12% accent, else neutral, with slight value jitter.
	var base: Color
	if rng.randf() < 0.12:
		base = ACCENT_COLORS[rng.randi() % ACCENT_COLORS.size()]
	else:
		base = PANEL_COLORS[rng.randi() % PANEL_COLORS.size()]
	base = base.lightened(rng.randf_range(-0.03, 0.03))

	draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_W, PANEL_H)), base)

	# Subtle top-edge highlight + bottom shadow -> panels read as slabs.
	draw_rect(Rect2(0, 0, PANEL_W, 3), base.lightened(0.08))
	draw_rect(Rect2(0, PANEL_H - 3, PANEL_W, 3), base.darkened(0.25))

	# Seam lines between panels.
	var seam := base.darkened(0.45)
	draw_line(Vector2(0, 0), Vector2(0, PANEL_H), seam, 2.0)
	draw_line(Vector2(0, 0), Vector2(PANEL_W, 0), seam, 2.0)

	# Occasional angled "volume" (big plywood wedge bolted on).
	if rng.randf() < 0.10:
		_draw_volume(rng, base)

	# T-nut hole grid with slight jitter; a few holes skipped.
	var hole := base.darkened(0.55)
	var y := TNUT_SPACING * 0.5
	while y < PANEL_H:
		var x := TNUT_SPACING * 0.5
		while x < PANEL_W:
			if rng.randf() > 0.08:
				var p := Vector2(
					x + rng.randf_range(-1.5, 1.5),
					y + rng.randf_range(-1.5, 1.5))
				draw_circle(p, 2.2, hole)
				draw_circle(p + Vector2(-0.6, -0.6), 0.9, base.lightened(0.10))
			x += TNUT_SPACING
		y += TNUT_SPACING

	# Faint scuff marks (chalk / rubber smears) for lived-in look.
	for i in rng.randi_range(0, 3):
		var c := Vector2(rng.randf_range(10, PANEL_W - 10), rng.randf_range(10, PANEL_H - 10))
		var scuff := Color(1, 1, 1, rng.randf_range(0.015, 0.04))
		draw_circle(c, rng.randf_range(8, 22), scuff)


func _draw_volume(rng: RandomNumberGenerator, base: Color) -> void:
	var cx := rng.randf_range(40.0, PANEL_W - 40.0)
	var cy := rng.randf_range(50.0, PANEL_H - 50.0)
	var s := rng.randf_range(30.0, 55.0)
	var rot := rng.randf_range(0.0, TAU)
	var pts := PackedVector2Array()
	for i in 3:
		var a := rot + TAU * i / 3.0
		pts.append(Vector2(cx, cy) + Vector2.from_angle(a) * s)
	var vcol := base.lightened(0.10) if rng.randf() < 0.5 else base.darkened(0.18)
	draw_colored_polygon(pts, vcol)
	# Edge shading so the wedge pops.
	pts.append(pts[0])
	draw_polyline(pts, base.darkened(0.5), 2.0)
	# One t-nut on the volume face.
	draw_circle(Vector2(cx, cy), 2.2, vcol.darkened(0.55))

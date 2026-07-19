extends Node2D
# Infinite deterministic hold generation, streaming upward.
#
# Two "guide lines" — one per player — each random-walking horizontally as
# they climb. Every row gets one guaranteed hold per line (an always-climbable
# route), plus a few ad-hoc extras dropped randomly left/right of each line.
# Lines may drift together (overlap) or apart (spread) freely within the wall.

const ROW_H := 70.0
const JITTER_X := 18.0
const JITTER_Y := 22.0
const FIRST_ROW_Y := 540.0  # just above the floor top (600)
# Wall is 1152 px wide; the 1080-wide portrait view pans slightly within it.
const X_MIN := 70.0
const X_MAX := 1082.0
const PATH_STEP_MAX := 85.0    # max lateral shift of a guide line per row
const EXTRA_SPREAD := 160.0    # how far off a line ad-hoc extras may drop
const EXTRA_MAX_PER_LINE := 2  # extras rolled per line per row
const EXTRA_CHANCE := 0.55     # chance per extra roll
const MIN_HOLD_GAP := 55.0     # reject extras landing on existing holds
const LEVEL_SEED := 20260718

# Starting x and per-line seed salt for the two player lines.
# Well apart: left/right wall thirds so players don't start on top of each other.
const LINE_STARTS: Array[float] = [300.0, 850.0]
const LINE_SALTS: Array[int] = [0x5EED, 0xCAFE]

const HoldScene := preload("res://Hold.tscn")
const BottleScene := preload("res://Bottle.tscn")
const TetherPointScript := preload("res://TetherPoint.gd")
const BOTTLE_CHANCE := 0.18  # chance per row a bottle sits on the wall
# Tether points: one per guide line every TETHER_INTERVAL rows (phase-shifted
# per line so both players' points don't land on the same row).
const TETHER_INTERVAL := 7
const TETHER_PHASES: Array[int] = [3, 6]

# row_index -> container Node2D holding that row's holds.
var _rows: Dictionary = {}
# Per line: guide-line x per row, grown deterministically (never freed).
var _line_x: Array = [[], []]


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var cam_y := cam.global_position.y
	var view_h := 1920.0

	# 2x margin: still covers the whole view when the camera zooms out to 0.67.
	var spawn_above := cam_y - 2.0 * view_h
	var free_below := cam_y + 1.0 * view_h

	var top_r := int(ceil((FIRST_ROW_Y - spawn_above) / ROW_H))
	for r in range(0, top_r + 1):
		var row_y := FIRST_ROW_Y - r * ROW_H
		if row_y >= spawn_above and not _rows.has(r):
			_spawn_row(r)

	for r: int in _rows.keys():
		var row_y := FIRST_ROW_Y - r * ROW_H
		if row_y > free_below:
			_rows[r].queue_free()
			_rows.erase(r)


# Deterministic random-walk x for guide line `line` at row `r`,
# computed incrementally.
func _get_line_x(line: int, r: int) -> float:
	var xs: Array = _line_x[line]
	while xs.size() <= r:
		var i := xs.size()
		if i == 0:
			xs.append(LINE_STARTS[line])
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(i) ^ LEVEL_SEED ^ LINE_SALTS[line]
			var next: float = xs[i - 1] + rng.randf_range(-PATH_STEP_MAX, PATH_STEP_MAX)
			xs.append(clampf(next, X_MIN, X_MAX))
	return xs[r]


func _spawn_row(r: int) -> void:
	if r < 0:
		return
	var row_y := FIRST_ROW_Y - r * ROW_H
	var container := Node2D.new()
	container.name = "Row_%d" % r
	add_child(container)
	_rows[r] = container

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(r) ^ LEVEL_SEED

	var placed: Array[float] = []  # x positions already used this row

	# 1. Guaranteed hold on each guide line — one climbable route per player.
	for line in LINE_STARTS.size():
		var lx := _get_line_x(line, r)
		var hx := lx + rng.randf_range(-JITTER_X, JITTER_X)
		# When lines overlap, one shared hold is enough.
		if _clear_of(placed, hx):
			_add_hold(container, Vector2(hx, row_y + rng.randf_range(-JITTER_Y, JITTER_Y)))
			placed.append(hx)

	# 2. Ad-hoc extras dropped left/right of each line.
	for line in LINE_STARTS.size():
		var lx := _get_line_x(line, r)
		for _i in EXTRA_MAX_PER_LINE:
			if rng.randf() >= EXTRA_CHANCE:
				continue
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var hx := clampf(lx + side * rng.randf_range(MIN_HOLD_GAP, EXTRA_SPREAD), X_MIN, X_MAX)
			if _clear_of(placed, hx):
				_add_hold(container, Vector2(hx, row_y + rng.randf_range(-JITTER_Y, JITTER_Y)))
				placed.append(hx)


	# 3. Deterministic tether point on a guide line every TETHER_INTERVAL rows
	# (alongside the row's normal holds, nudged to the side of the line).
	for line in LINE_STARTS.size():
		if r > 0 and (r + TETHER_PHASES[line]) % TETHER_INTERVAL == 0:
			var lx := _get_line_x(line, r)
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var tx := clampf(lx + side * rng.randf_range(30.0, 55.0), X_MIN, X_MAX)
			var tp := Node2D.new()
			tp.set_script(TetherPointScript)
			tp.position = Vector2(tx, row_y + rng.randf_range(-JITTER_Y, JITTER_Y))
			container.add_child(tp)

	# 4. Occasional throwable bottle, parked clear of this row's holds.
	if rng.randf() < BOTTLE_CHANCE:
		var bx := rng.randf_range(X_MIN, X_MAX)
		if _clear_of(placed, bx):
			var bottle := BottleScene.instantiate()
			bottle.position = Vector2(bx, row_y + rng.randf_range(-JITTER_Y, JITTER_Y))
			container.add_child(bottle)


func _clear_of(placed: Array[float], x: float) -> bool:
	for px in placed:
		if absf(x - px) < MIN_HOLD_GAP:
			return false
	return true


func _add_hold(container: Node2D, pos: Vector2) -> void:
	var hold := HoldScene.instantiate()
	hold.position = pos
	container.add_child(hold)

extends Node2D
# Infinite bouldering-wall background: streams WallPanel rows with the camera,
# same pattern as HoldSpawner. Deterministic per-cell seeds -> stable on revisit.

const PANEL_W := 192.0
const PANEL_H := 216.0
const COLS := 6  # 6 * 192 = 1152 = full level width
const WALL_SEED := 0x5EED_CAFE

const WallPanelScene := preload("res://WallPanel.tscn")

# row_index -> container Node2D of that row's panels.
var _rows: Dictionary = {}


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var cam_y := cam.global_position.y
	var view_h := 648.0

	var top_edge := cam_y - 1.2 * view_h
	var bottom_edge := cam_y + 1.2 * view_h

	# Row 0 bottom sits at the floor top (y=600); rows go up (negative y).
	var first := int(floor((600.0 - bottom_edge) / PANEL_H))
	var last := int(ceil((600.0 - top_edge) / PANEL_H))
	for r in range(maxi(first, 0), last + 1):
		if not _rows.has(r):
			_spawn_row(r)

	for r: int in _rows.keys():
		var row_bottom := 600.0 - r * PANEL_H
		if row_bottom - PANEL_H > bottom_edge or row_bottom < top_edge:
			_rows[r].queue_free()
			_rows.erase(r)


func _spawn_row(r: int) -> void:
	var container := Node2D.new()
	container.name = "WallRow_%d" % r
	add_child(container)
	_rows[r] = container

	var row_top := 600.0 - (r + 1) * PANEL_H
	for c in COLS:
		var panel := WallPanelScene.instantiate()
		panel.rng_seed = hash(Vector2i(c, r)) ^ WALL_SEED
		panel.position = Vector2(c * PANEL_W, row_top)
		container.add_child(panel)

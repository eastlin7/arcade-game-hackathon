extends Node2D
# Safety tether point: a metal piton/ring bolted to the wall. Players auto-
# attach by proximity (see Player.gd). When a player moves on to a newer
# point, the old one is ripped from the wall and falls away.
#
# Code-drawn like Hold.gd — no textures.

const RING_COLOR := Color(0.72, 0.74, 0.78)   # steel
const RING_DARK := Color(0.38, 0.40, 0.45)
const PLATE_COLOR := Color(0.50, 0.52, 0.58)
const BOLT_COLOR := Color(0.30, 0.31, 0.35)
const FALL_GRAVITY := 980.0
const FALL_FREE_DIST := 500.0  # free after falling 5 m below origin

var _falling := false
var _fall_velocity := Vector2.ZERO
var _fall_origin_y := 0.0
var _spin := 0.0


func _ready() -> void:
	add_to_group("tether_points")
	queue_redraw()


# Rip the point off the wall: no longer attachable, falls with simple gravity
# and is freed once it has dropped 5 meters below where it was mounted.
func detach_and_fall() -> void:
	if _falling:
		return
	_falling = true
	remove_from_group("tether_points")
	_fall_origin_y = global_position.y
	_fall_velocity = Vector2(randf_range(-40.0, 40.0), -60.0)  # small pop off the wall
	_spin = randf_range(-6.0, 6.0)
	# Escape the spawner's row container so scroll-out cleanup can't free the
	# row (and this node with it) before the fall finishes.
	var world := get_tree().current_scene
	if world != null and get_parent() != world:
		call_deferred("reparent", world)


func _process(delta: float) -> void:
	if not _falling:
		return
	_fall_velocity.y += FALL_GRAVITY * delta
	global_position += _fall_velocity * delta
	rotation += _spin * delta
	if global_position.y > _fall_origin_y + FALL_FREE_DIST:
		queue_free()


func _draw() -> void:
	# Wall plate with two bolt heads.
	draw_rect(Rect2(-12.0, -6.0, 24.0, 12.0), PLATE_COLOR)
	draw_rect(Rect2(-12.0, -6.0, 24.0, 12.0), RING_DARK, false, 2.0)
	draw_circle(Vector2(-8.0, 0.0), 2.2, BOLT_COLOR)
	draw_circle(Vector2(8.0, 0.0), 2.2, BOLT_COLOR)
	# Hanging steel ring below the plate.
	draw_arc(Vector2(0.0, 12.0), 8.0, 0.0, TAU, 20, RING_DARK, 5.0, true)
	draw_arc(Vector2(0.0, 12.0), 8.0, 0.0, TAU, 20, RING_COLOR, 2.5, true)
	# Highlight glint on the ring.
	draw_arc(Vector2(0.0, 12.0), 8.0, -2.4, -1.2, 6, Color(0.95, 0.96, 1.0), 2.0, true)

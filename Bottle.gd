extends RigidBody2D
# Throwable glass bottle. Sits frozen on the wall until a player grabs it,
# rides the hand while carried, then flies as a free rigid body when thrown.

const BOTTLE_COLORS := [
	Color(0.25, 0.55, 0.3),   # green glass
	Color(0.45, 0.3, 0.15),   # brown glass
	Color(0.35, 0.5, 0.65),   # blue glass
]

var carried := false
var _glass: Color = BOTTLE_COLORS[0]


@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("bottles")
	freeze = true  # pinned to the wall until picked up
	# No collision while on the wall or in a hand — solid only in flight,
	# so a pinned bottle never body-blocks a climbing player.
	_shape.set_deferred("disabled", true)
	_glass = BOTTLE_COLORS[randi() % BOTTLE_COLORS.size()]
	queue_redraw()


func pick_up() -> void:
	carried = true
	freeze = true
	remove_from_group("bottles")  # no double-grab while in a hand


func throw(from: Vector2, velocity: Vector2) -> void:
	carried = false
	global_position = from
	freeze = false
	_shape.set_deferred("disabled", false)
	linear_velocity = velocity
	angular_velocity = randf_range(-12.0, 12.0)


func _process(_delta: float) -> void:
	# Despawn once far below the camera (thrown or missed).
	var cam := get_viewport().get_camera_2d()
	if cam != null and not carried and global_position.y > cam.global_position.y + 700.0:
		queue_free()


func _draw() -> void:
	# Simple longneck bottle, drawn pointing up. ~14 wide, ~44 tall.
	var body := _glass
	var dark := body.darkened(0.35)
	# Body.
	draw_rect(Rect2(-7, -10, 14, 30), body)
	# Shoulder taper.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -10), Vector2(7, -10), Vector2(2.5, -18), Vector2(-2.5, -18),
	]), body)
	# Neck.
	draw_rect(Rect2(-2.5, -26, 5, 8), body)
	# Lip.
	draw_rect(Rect2(-3.5, -28, 7, 2.5), dark)
	# Label band.
	draw_rect(Rect2(-7, 2, 14, 9), Color(0.92, 0.88, 0.8))
	# Highlight streak.
	draw_rect(Rect2(-5, -8, 2, 26), body.lightened(0.45))
	# Base shadow.
	draw_rect(Rect2(-7, 17, 14, 3), dark)

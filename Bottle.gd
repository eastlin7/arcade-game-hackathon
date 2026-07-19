extends RigidBody2D
# Throwable glass bottle. Sits frozen on the wall until a player grabs it,
# rides the hand while carried, then flies as a free rigid body when thrown.

const BOTTLE_COLORS := [
	Color(0.25, 0.55, 0.3),   # green glass
	Color(0.45, 0.3, 0.15),   # brown glass
	Color(0.35, 0.5, 0.65),   # blue glass
]

const STUN_DURATION := 2.0

# In-flight homing: when the target player is near, the course bends slightly
# toward them. Weak on purpose — assisted, not a guided missile.
const HOMING_RADIUS := 260.0             # only homes inside this range
const HOMING_TURN := deg_to_rad(140.0)   # max course change per second at full strength

var carried := false
var _armed := false  # true while in flight after a throw — only then it stuns
# Player to home toward (set by the thrower; null = no homing).
var home_target: Node2D = null
# Blue-shell mode: no gravity, constant speed, relentless full homing onto
# home_target — there is no dodging it.
var super_homing := false
const SUPER_SPEED := 520.0
const SUPER_TURN := deg_to_rad(720.0)  # course correction per second
var _glass: Color = BOTTLE_COLORS[0]

const GrabSplashScript := preload("res://GrabSplash.gd")


@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("bottles")
	freeze = true  # pinned to the wall until picked up
	# No collision while on the wall or in a hand — solid only in flight,
	# so a pinned bottle never body-blocks a climbing player.
	_shape.set_deferred("disabled", true)
	_glass = BOTTLE_COLORS[randi() % BOTTLE_COLORS.size()]
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not _armed:
		return
	if body.has_method("stun"):
		body.stun(STUN_DURATION)
		_shatter()


func _shatter() -> void:
	var dust: CPUParticles2D = GrabSplashScript.new()
	dust.global_position = global_position
	get_parent().add_child(dust)
	queue_free()


func pick_up() -> void:
	carried = true
	freeze = true
	remove_from_group("bottles")  # no double-grab while in a hand


func throw(from: Vector2, velocity: Vector2) -> void:
	carried = false
	_armed = true
	global_position = from
	freeze = false
	_shape.set_deferred("disabled", false)
	linear_velocity = velocity
	angular_velocity = randf_range(-12.0, 12.0)
	if super_homing:
		gravity_scale = 0.0
		_glass = BOTTLE_COLORS[2]  # always blue — it's a blue shell
		queue_redraw()


func _physics_process(delta: float) -> void:
	# Slight homing while flying: bend the velocity toward a nearby target,
	# stronger the closer they are. Speed is preserved; gravity still applies.
	if not _armed or home_target == null or not is_instance_valid(home_target):
		return
	if super_homing:
		# Full pursuit: constant speed, hard steer straight at the target.
		var want := (home_target.global_position - global_position).angle()
		var have := linear_velocity.angle()
		var turned := have + clampf(wrapf(want - have, -PI, PI),
			-SUPER_TURN * delta, SUPER_TURN * delta)
		linear_velocity = Vector2.from_angle(turned) * SUPER_SPEED
		return
	var to_target := home_target.global_position - global_position
	var dist := to_target.length()
	if dist > HOMING_RADIUS or linear_velocity.length_squared() < 1.0:
		return
	var strength := 1.0 - dist / HOMING_RADIUS  # 0 at edge -> 1 point blank
	var off := linear_velocity.angle_to(to_target)
	var max_turn := HOMING_TURN * strength * delta
	linear_velocity = linear_velocity.rotated(clampf(off, -max_turn, max_turn))


func _process(_delta: float) -> void:
	# Despawn once far below the camera (thrown or missed).
	var cam := get_viewport().get_camera_2d()
	if super_homing and home_target != null and is_instance_valid(home_target):
		return  # a blue shell never gives up
	if cam != null and not carried and global_position.y > cam.global_position.y + 700.0:
		queue_free()


func _draw() -> void:
	# Blue-shell aura so the victim sees doom coming.
	if super_homing:
		draw_circle(Vector2.ZERO, 34.0, Color(0.35, 0.55, 1.0, 0.18))
		draw_circle(Vector2.ZERO, 24.0, Color(0.45, 0.65, 1.0, 0.25))
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

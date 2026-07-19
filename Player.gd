extends RigidBody2D

# Local distance from shoulder pivot to the hand's CENTER (not the sprite tip —
# grabbing/pivoting happens mid-palm), world reach = local * 3x scale.
const ARM_LEN := 17.0
const ARM_REACH := 51.0
const CLIMB_SPEED := 140.0  # steering speed while gripping (px/s)
const CLIMB_ACCEL := 6.0    # how snappily velocity follows input while gripping
const HANG_GRAVITY := 0.25  # partial gravity while gripping -> natural sag/swing
const REGRIP_COOLDOWN := 0.3  # per-hand delay between release and next grab
const LUNGE_SPEED := 380.0  # impulse when releasing the last grip while aiming
const ARM_TURN_SPEED := 12.0

# Ground walking (only way to move without gripping).
const WALK_SPEED := 160.0
# Snap-assist range around the hand tip — deliberately larger than the hand
# itself, so holds a bit beyond actual reach still catch; the arm constraint
# then pulls the body toward the hold.
const GRAB_RADIUS := 55.0

# Shoulder offsets in body-local space (rotation is locked, so no rotation math).
const LEFT_SHOULDER := Vector2(-16.5, -28.5)
const RIGHT_SHOULDER := Vector2(22.5, -28.5)

const THROW_SPEED := 620.0

# Coyote grab buffer: a missed press keeps retrying this long while held.
const GRAB_BUFFER := 0.12

# Per-side lock state.
var left_locked := false
var right_locked := false
var left_anchor := Vector2.ZERO
var right_anchor := Vector2.ZERO

# Per-side carried bottle (null when hand is empty).
var left_bottle: RigidBody2D = null
var right_bottle: RigidBody2D = null

# Cached input read on the main thread for _integrate_forces.
var aim_dir := Vector2.ZERO

# Remaining coyote-buffer time per hand.
var left_grab_buffer := 0.0
var right_grab_buffer := 0.0

# Remaining stun time (bottle hit): hands forced open, no gripping allowed.
var stun_time := 0.0

# Per-hand regrip cooldown (anti button-mash: alternate hands to climb fast).
var left_regrip := 0.0
var right_regrip := 0.0

# Currently highlighted (reachable) hold per hand.
var _hl_left_hold: Node2D = null
var _hl_right_hold: Node2D = null

# Tether: auto-attach when the body gets within this range of a tether point.
const TETHER_ATTACH_RADIUS := 60.0
# While tethered, the body can never fall more than 1 m below the anchor.
const TETHER_FLOOR_DROP := 100.0

# Current tether point (null when untethered) and its frozen anchor position.
var tether_point: Node2D = null
var tether_anchor := Vector2.ZERO
# Anchor constraint survives even if the point node is streamed out below.
var tether_active := false
var _tether_rope: Node2D = null

const GrabSplashScript := preload("res://GrabSplash.gd")
const TetherRopeScript := preload("res://TetherRope.gd")
const GrabWhiffScript := preload("res://GrabWhiff.gd")
const HitTextScript := preload("res://HitText.gd")
const RedTintShader := preload("res://red_tint.gdshader")

# Hit effect: sprite flashes white and game slows for this many REAL seconds
# (~2 frames' worth of impact at normal speed).
const HIT_FREEZE := 0.09
const HIT_TIME_SCALE := 0.1

var _mat: ShaderMaterial

# "p1" or "p2" — selects this player's InputMap action set (p1_move_up etc).
@export var input_prefix := "p1"
# Recolor the sprite red (player 2 identity).
@export var red_tint := false

# Cached action names, built from input_prefix in _ready.
var _a_ml: String
var _a_mr: String
var _a_mu: String
var _a_md: String
var _a_gl: String
var _a_gr: String

@onready var left_arm: Node2D = $LeftArm
@onready var right_arm: Node2D = $RightArm


func _ready() -> void:
	_a_ml = input_prefix + "_move_left"
	_a_mr = input_prefix + "_move_right"
	_a_mu = input_prefix + "_move_up"
	_a_md = input_prefix + "_move_down"
	_a_gl = input_prefix + "_grab_left"
	_a_gr = input_prefix + "_grab_right"
	# Every player gets the shader (for the hit flash); only p2 gets the red mix.
	_mat = ShaderMaterial.new()
	_mat.shader = RedTintShader
	_mat.set_shader_parameter("mix_amount", 0.8 if red_tint else 0.0)
	for sprite: CanvasItem in [$BodySprite, $LeftArm/ArmSprite, $RightArm/ArmSprite]:
		sprite.material = _mat
	# Needed so _integrate_forces can read floor contacts for ground walking.
	contact_monitor = true
	max_contacts_reported = 6
	# Rope visual: child node drawing in world space (top_level in its _ready).
	_tether_rope = Node2D.new()
	_tether_rope.set_script(TetherRopeScript)
	_tether_rope.player = self
	add_child(_tether_rope)


func _physics_process(delta: float) -> void:
	aim_dir = Input.get_vector(_a_ml, _a_mr, _a_mu, _a_md)

	# Hold-to-lock: locked exactly while the key is held.
	# A bottle in range wins over a hold; releasing a bottle-hand throws it.
	# A missed press whiffs visibly and keeps retrying for GRAB_BUFFER seconds
	# (coyote grab) while the key stays held. Stunned -> grabs blocked entirely.
	stun_time = maxf(0.0, stun_time - delta)
	left_regrip = maxf(0.0, left_regrip - delta)
	right_regrip = maxf(0.0, right_regrip - delta)

	if Input.is_action_just_pressed(_a_gl) and stun_time <= 0.0 and left_regrip <= 0.0:
		if _attempt_grab(true):
			left_grab_buffer = 0.0
		else:
			left_grab_buffer = GRAB_BUFFER
			_spawn_grab_whiff(left_arm.to_global(Vector2(0, ARM_LEN)))
	elif left_grab_buffer > 0.0 and Input.is_action_pressed(_a_gl) and stun_time <= 0.0 and left_regrip <= 0.0:
		if _attempt_grab(true):
			left_grab_buffer = 0.0
	if Input.is_action_just_released(_a_gl):
		left_grab_buffer = 0.0
		if left_locked:
			left_locked = false
			left_regrip = REGRIP_COOLDOWN
			_maybe_lunge()
		if left_bottle != null:
			_throw_bottle(left_bottle, left_arm)
			left_bottle = null

	if Input.is_action_just_pressed(_a_gr) and stun_time <= 0.0 and right_regrip <= 0.0:
		if _attempt_grab(false):
			right_grab_buffer = 0.0
		else:
			right_grab_buffer = GRAB_BUFFER
			_spawn_grab_whiff(right_arm.to_global(Vector2(0, ARM_LEN)))
	elif right_grab_buffer > 0.0 and Input.is_action_pressed(_a_gr) and stun_time <= 0.0 and right_regrip <= 0.0:
		if _attempt_grab(false):
			right_grab_buffer = 0.0
	if Input.is_action_just_released(_a_gr):
		right_grab_buffer = 0.0
		if right_locked:
			right_locked = false
			right_regrip = REGRIP_COOLDOWN
			_maybe_lunge()
		if right_bottle != null:
			_throw_bottle(right_bottle, right_arm)
			right_bottle = null

	left_grab_buffer = maxf(0.0, left_grab_buffer - delta)
	right_grab_buffer = maxf(0.0, right_grab_buffer - delta)

	# While gripping, partial gravity: the body sags under the anchor and
	# swings naturally instead of hovering.
	gravity_scale = HANG_GRAVITY if (left_locked or right_locked) else 1.0


# Deadpoint leap: releasing the LAST grip while steering throws the body in
# the aim direction. Release timing becomes the climbing skill.
func _maybe_lunge() -> void:
	if left_locked or right_locked:
		return
	if aim_dir != Vector2.ZERO:
		linear_velocity += aim_dir * LUNGE_SPEED

	_update_tether()


# Auto-attach to a nearby tether point; on a new attachment the old point is
# ripped off the wall and falls away (a climber only ever has one safety line).
func _update_tether() -> void:
	if tether_point != null and not is_instance_valid(tether_point):
		tether_point = null  # node streamed out; anchor + rope stay live
	var best: Node2D = null
	var best_d := TETHER_ATTACH_RADIUS
	for tp: Node2D in get_tree().get_nodes_in_group("tether_points"):
		if tp == tether_point:
			continue
		var d := tp.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = tp
	if best == null:
		return
	if tether_point != null and is_instance_valid(tether_point):
		tether_point.detach_and_fall()
	tether_point = best
	tether_anchor = best.global_position
	tether_active = true
	# Rope shoots out from the body to the ring (constraint is live immediately;
	# only the visual animates — keeps it snappy).
	_tether_rope.shoot_to(tether_anchor)
	_spawn_grab_splash(tether_anchor)


# Bottle hit: hands fly open and can't grip for `duration`. Carried bottles drop.
func stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)
	left_locked = false
	right_locked = false
	left_grab_buffer = 0.0
	right_grab_buffer = 0.0
	if left_bottle != null:
		_drop_bottle(left_bottle, left_arm)
		left_bottle = null
	if right_bottle != null:
		_drop_bottle(right_bottle, right_arm)
		right_bottle = null
	_hit_effect()
	if get_parent().has_method("add_shake"):
		get_parent().add_shake(6.0)
	# Cartoony hit text above the head.
	var hit_text := Node2D.new()
	hit_text.set_script(HitTextScript)
	hit_text.global_position = global_position + Vector2(randf_range(-12.0, 12.0), -95.0)
	get_parent().add_child(hit_text)


# White flash + brief global slow-mo on impact. Timer runs on real time, so
# the restore isn't itself slowed by the reduced time scale.
func _hit_effect() -> void:
	_mat.set_shader_parameter("flash", 1.0)
	Engine.time_scale = HIT_TIME_SCALE
	await get_tree().create_timer(HIT_FREEZE, true, false, true).timeout
	Engine.time_scale = 1.0
	_mat.set_shader_parameter("flash", 0.0)


func _drop_bottle(bottle: RigidBody2D, arm: Node2D) -> void:
	bottle.add_collision_exception_with(self)
	bottle.throw(arm.to_global(Vector2(0, ARM_LEN)), linear_velocity)


# Try to grab with one hand: bottle wins over hold. Returns success.
func _attempt_grab(is_left: bool) -> bool:
	var arm := left_arm if is_left else right_arm
	var hand := arm.to_global(Vector2(0, ARM_LEN))
	var bottle := _find_bottle_near(hand)
	if bottle != null:
		if is_left:
			left_bottle = bottle
		else:
			right_bottle = bottle
		bottle.pick_up()
		_spawn_grab_splash(bottle.global_position)
		return true
	var hold := _find_hold_near(hand)
	if hold != null:
		if is_left:
			left_locked = true
			left_anchor = hold.global_position
		else:
			right_locked = true
			right_anchor = hold.global_position
		_spawn_grab_splash(hold.global_position)
		return true
	return false


# Nearest climbing hold within grab range of the hand tip, or null.
func _find_hold_near(hand_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := GRAB_RADIUS
	for hold: Node2D in get_tree().get_nodes_in_group("holds"):
		var d := hold.global_position.distance_to(hand_pos)
		if d < best_d:
			best_d = d
			best = hold
	return best


# Nearest wall bottle within grab range of the hand tip, or null.
func _find_bottle_near(hand_pos: Vector2) -> RigidBody2D:
	var best: RigidBody2D = null
	var best_d := GRAB_RADIUS
	for bottle: RigidBody2D in get_tree().get_nodes_in_group("bottles"):
		var d := bottle.global_position.distance_to(hand_pos)
		if d < best_d:
			best_d = d
			best = bottle
	# Reparent out of its spawner row so scrolling can't free it mid-carry.
	if best != null and best.get_parent() != get_parent():
		best.call_deferred("reparent", get_parent())
	return best


func _throw_bottle(bottle: RigidBody2D, arm: Node2D) -> void:
	var hand := arm.to_global(Vector2(0, ARM_LEN))
	# Throw along the aim stick; no aim -> lob up-and-away from the body.
	var dir := aim_dir
	if dir == Vector2.ZERO:
		dir = Vector2(0.4 if arm == right_arm else -0.4, -1.0).normalized()
	bottle.add_collision_exception_with(self)
	bottle.throw(hand, dir * THROW_SPEED + linear_velocity)


func _spawn_grab_splash(pos: Vector2) -> void:
	var splash: CPUParticles2D = GrabSplashScript.new()
	# Originate just under the hand's pivot point.
	splash.global_position = pos + Vector2(0.0, 5.0)
	# Sibling of the player so it stays put in the world, not on the moving body.
	get_parent().add_child(splash)


func _spawn_grab_whiff(pos: Vector2) -> void:
	var whiff := Node2D.new()
	whiff.set_script(GrabWhiffScript)
	whiff.global_position = pos
	get_parent().add_child(whiff)


func _process(delta: float) -> void:
	_update_arm(left_arm, left_locked, left_anchor, LEFT_SHOULDER, true, delta)
	_update_arm(right_arm, right_locked, right_anchor, RIGHT_SHOULDER, false, delta)
	_carry_bottle(left_bottle, left_arm)
	_carry_bottle(right_bottle, right_arm)
	_hl_left_hold = _update_highlight(_hl_left_hold, left_arm, left_locked or left_bottle != null or stun_time > 0.0, true)
	_hl_right_hold = _update_highlight(_hl_right_hold, right_arm, right_locked or right_bottle != null or stun_time > 0.0, false)
	# Stun feedback: fast red blink until control returns.
	if stun_time > 0.0:
		modulate = Color(1.0, 0.45, 0.45) if fmod(stun_time, 0.2) < 0.1 else Color.WHITE
	elif modulate != Color.WHITE:
		modulate = Color.WHITE


# Highlight the hold this hand would grab right now; clear the previous one.
func _update_highlight(prev: Node2D, arm: Node2D, hand_busy: bool, is_left: bool) -> Node2D:
	var next: Node2D = null
	if not hand_busy:
		next = _find_hold_near(arm.to_global(Vector2(0, ARM_LEN)))
	if next == prev:
		return prev
	if prev != null and is_instance_valid(prev):
		prev.set_highlight(is_left, false)
	if next != null:
		next.set_highlight(is_left, true)
	return next


func _carry_bottle(bottle: RigidBody2D, arm: Node2D) -> void:
	if bottle == null or not is_instance_valid(bottle):
		return
	bottle.global_position = arm.to_global(Vector2(0, ARM_LEN))
	# Neck points away from the arm.
	bottle.rotation = arm.rotation


func _update_arm(arm: Node2D, locked: bool, anchor: Vector2, shoulder: Vector2, is_left: bool, delta: float) -> void:
	# rotation 0 == pointing down (+Y), so target = dir.angle() - PI/2.
	var target: float
	if locked:
		# Point from shoulder toward the frozen anchor.
		var shoulder_world := global_position + shoulder
		target = (anchor - shoulder_world).angle() - PI / 2.0
		arm.rotation = _clamp_arm_angle(target, is_left)
	else:
		var dir := aim_dir
		if dir == Vector2.ZERO:
			target = 0.0  # hang straight down
		else:
			target = _clamp_arm_angle(dir.angle() - PI / 2.0, is_left)
		# Plain lerp inside the arm's clamped domain (never through the wrong
		# half, unlike lerp_angle which takes the shortest path around).
		var current := _clamp_arm_angle(arm.rotation, is_left)
		arm.rotation = _clamp_arm_angle(
			lerpf(current, target, minf(ARM_TURN_SPEED * delta, 1.0)), is_left)


func _clamp_arm_angle(angle: float, is_left: bool) -> float:
	# Each arm sweeps only its own half-circle: left arm down->left->up ([0, PI]),
	# right arm down->right->up ([-PI, 0]). Straight down/up shared by both.
	# Wrap into a window centered on the allowed range, then clamp — the arm can
	# never pass through the forbidden half.
	if is_left:
		return clampf(wrapf(angle, -PI / 2.0, 3.0 * PI / 2.0), 0.0, PI)
	return clampf(wrapf(angle, -3.0 * PI / 2.0, PI / 2.0), -PI, 0.0)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_apply_arm_constraint(state, left_locked, left_anchor, LEFT_SHOULDER, true)
	_apply_arm_constraint(state, right_locked, right_anchor, RIGHT_SHOULDER, false)

	# Tether floor: free to climb up/sideways, but never drop more than 1 m
	# below the anchor. Y-only clamp, downward velocity killed.
	if tether_active:
		var floor_y := tether_anchor.y + TETHER_FLOOR_DROP
		if state.transform.origin.y > floor_y:
			state.transform.origin.y = floor_y
			if state.linear_velocity.y > 0.0:
				state.linear_velocity.y = 0.0

	# Rigid grip: velocity is steered, not force-pushed. No input -> hold still.
	if left_locked or right_locked:
		var desired := aim_dir * CLIMB_SPEED
		state.linear_velocity = state.linear_velocity.lerp(
			desired, minf(CLIMB_ACCEL * state.step, 1.0))
	elif _on_ground(state):
		# Standing on something: left/right walks. Vertical stays physics-owned.
		state.linear_velocity.x = lerpf(state.linear_velocity.x,
			aim_dir.x * WALK_SPEED, minf(CLIMB_ACCEL * state.step, 1.0))


# Grounded when any contact pushes us upward (floor or other flat top).
func _on_ground(state: PhysicsDirectBodyState2D) -> bool:
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y < -0.5:
			return true
	return false


func _apply_arm_constraint(state: PhysicsDirectBodyState2D, locked: bool, anchor: Vector2, shoulder: Vector2, is_left: bool) -> void:
	if not locked:
		return
	# The arm only sweeps its own half-circle, so the anchor must stay on that
	# side of the shoulder: left hand never right of the left shoulder, right
	# hand never left of the right shoulder. Half-plane constraint on the body.
	if is_left:
		var min_x := anchor.x - shoulder.x
		if state.transform.origin.x < min_x:
			state.transform.origin.x = min_x
			if state.linear_velocity.x < 0.0:
				state.linear_velocity.x = 0.0
	else:
		var max_x := anchor.x - shoulder.x
		if state.transform.origin.x > max_x:
			state.transform.origin.x = max_x
			if state.linear_velocity.x > 0.0:
				state.linear_velocity.x = 0.0

	var shoulder_world := state.transform.origin + shoulder
	var v := shoulder_world - anchor
	var d := v.length()
	if d > ARM_REACH:
		var n := v / d
		# Pull body back within reach.
		state.transform.origin -= n * (d - ARM_REACH)
		# Kill outward radial velocity -> pendulum swing.
		var rad := state.linear_velocity.dot(n)
		if rad > 0.0:
			state.linear_velocity -= n * rad

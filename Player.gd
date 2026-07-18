extends RigidBody2D

# Local distance from shoulder pivot to the hand's CENTER (not the sprite tip —
# grabbing/pivoting happens mid-palm), world reach = local * 3x scale.
const ARM_LEN := 17.0
const ARM_REACH := 51.0
const CLIMB_SPEED := 200.0  # steering speed while gripping (px/s)
const CLIMB_ACCEL := 10.0   # how snappily velocity follows input while gripping
const ARM_TURN_SPEED := 12.0
# Snap-assist range around the hand tip — deliberately larger than the hand
# itself, so holds a bit beyond actual reach still catch; the arm constraint
# then pulls the body toward the hold.
const GRAB_RADIUS := 55.0

# Shoulder offsets in body-local space (rotation is locked, so no rotation math).
const LEFT_SHOULDER := Vector2(-16.5, -28.5)
const RIGHT_SHOULDER := Vector2(22.5, -28.5)

const THROW_SPEED := 620.0

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

const GrabSplashScript := preload("res://GrabSplash.gd")

@onready var left_arm: Node2D = $LeftArm
@onready var right_arm: Node2D = $RightArm


func _physics_process(_delta: float) -> void:
	aim_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Hold-to-lock: locked exactly while the key is held.
	# A bottle in range wins over a hold; releasing a bottle-hand throws it.
	if Input.is_action_just_pressed("grab_left"):
		var hand := left_arm.to_global(Vector2(0, ARM_LEN))
		var bottle := _find_bottle_near(hand)
		if bottle != null:
			left_bottle = bottle
			bottle.pick_up()
			_spawn_grab_splash(bottle.global_position)
		else:
			var hold := _find_hold_near(hand)
			if hold != null:
				left_locked = true
				left_anchor = hold.global_position
				_spawn_grab_splash(left_anchor)
	if Input.is_action_just_released("grab_left"):
		left_locked = false
		if left_bottle != null:
			_throw_bottle(left_bottle, left_arm)
			left_bottle = null

	if Input.is_action_just_pressed("grab_right"):
		var hand := right_arm.to_global(Vector2(0, ARM_LEN))
		var bottle := _find_bottle_near(hand)
		if bottle != null:
			right_bottle = bottle
			bottle.pick_up()
			_spawn_grab_splash(bottle.global_position)
		else:
			var hold := _find_hold_near(hand)
			if hold != null:
				right_locked = true
				right_anchor = hold.global_position
				_spawn_grab_splash(right_anchor)
	if Input.is_action_just_released("grab_right"):
		right_locked = false
		if right_bottle != null:
			_throw_bottle(right_bottle, right_arm)
			right_bottle = null

	# While gripping, the climber holds on: no gravity sag, movement is steered.
	gravity_scale = 0.0 if (left_locked or right_locked) else 1.0


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


func _process(delta: float) -> void:
	_update_arm(left_arm, left_locked, left_anchor, LEFT_SHOULDER, true, delta)
	_update_arm(right_arm, right_locked, right_anchor, RIGHT_SHOULDER, false, delta)
	_carry_bottle(left_bottle, left_arm)
	_carry_bottle(right_bottle, right_arm)


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

	# Rigid grip: velocity is steered, not force-pushed. No input -> hold still.
	if left_locked or right_locked:
		var desired := aim_dir * CLIMB_SPEED
		state.linear_velocity = state.linear_velocity.lerp(
			desired, minf(CLIMB_ACCEL * state.step, 1.0))


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

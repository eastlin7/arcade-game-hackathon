extends CPUParticles2D
# One-shot dust puff on grab: bursts from under the hand, spreads out
# circularly, fades. Frees itself when done.

const LIFETIME := 0.45


func _ready() -> void:
	one_shot = true
	emitting = true
	explosiveness = 1.0
	amount = 14
	lifetime = LIFETIME
	lifetime_randomness = 0.3

	# Burst radially in all directions.
	direction = Vector2.ZERO
	spread = 180.0
	initial_velocity_min = 35.0
	initial_velocity_max = 80.0
	# Dust settles: slows down fast, sinks slightly.
	linear_accel_min = -120.0
	linear_accel_max = -80.0
	gravity = Vector2(0.0, 60.0)

	# Chunky pixel-dust squares that shrink.
	scale_amount_min = 1.5
	scale_amount_max = 3.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.2))
	scale_amount_curve = sc

	# Dusty beige, fading out.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.82, 0.76, 0.62, 0.9))
	grad.set_color(1, Color(0.82, 0.76, 0.62, 0.0))
	color_ramp = grad

	get_tree().create_timer(LIFETIME * 1.5).timeout.connect(queue_free)

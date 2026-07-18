extends RigidBody2D
# Falling boulder event hazard. Drops from above the screen, stuns any player
# it lands on (same impact package as a bottle hit), despawns below the camera.

const STUN_DURATION := 2.0
const RADIUS := 22.0

const GrabSplashScript := preload("res://GrabSplash.gd")

var _hit_players := {}  # player -> true; one stun per player per boulder


func _ready() -> void:
	mass = 6.0
	gravity_scale = 1.4
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.3
	angular_velocity = randf_range(-4.0, 4.0)


func _on_body_entered(body: Node) -> void:
	if body.has_method("stun") and not _hit_players.has(body):
		_hit_players[body] = true
		body.stun(STUN_DURATION)
		# Same impact dust as a bottle shattering on a player.
		var dust: CPUParticles2D = GrabSplashScript.new()
		dust.global_position = global_position
		get_parent().add_child(dust)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and global_position.y > cam.global_position.y + 800.0:
		queue_free()


func _draw() -> void:
	# Chunky rock: irregular polygon, base + shadow + highlight facets.
	var base := Color(0.45, 0.42, 0.4)
	var dark := base.darkened(0.35)
	var light := base.lightened(0.25)
	var pts := PackedVector2Array()
	for i in 9:
		var ang := TAU * float(i) / 9.0
		var r := RADIUS * (0.85 + 0.15 * sin(float(i) * 12.9898))
		pts.append(Vector2.from_angle(ang) * r)
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(p * 1.12)
	draw_colored_polygon(outline, Color(0.08, 0.06, 0.1))
	draw_colored_polygon(pts, base)
	draw_circle(Vector2(6.0, 6.0), RADIUS * 0.45, dark)
	draw_circle(Vector2(-6.0, -7.0), RADIUS * 0.35, light)

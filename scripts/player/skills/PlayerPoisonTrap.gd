class_name PlayerPoisonTrap
extends Area3D

@export var arm_time: float = 0.25
@export var cloud_duration: float = 4.0
@export var damage_per_sec: float = 24.0
@export var slow_percent: float = 0.40

var is_armed: bool = false
var is_triggered: bool = false
var shooter: Node3D = null
var tick_timer: float = 0.0

@onready var trap_mesh: MeshInstance3D = $TrapMesh
@onready var cloud_mesh: MeshInstance3D = $CloudMesh
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 4 # Enemies
	if cloud_mesh:
		cloud_mesh.visible = false
	if light:
		light.visible = false

	# Arming delay
	var arm_tween := create_tween()
	arm_tween.tween_interval(arm_time)
	arm_tween.tween_callback(func():
		is_armed = true
		_check_immediate_trigger()
	)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(from_shooter: Node3D, dmg: float = 24.0) -> void:
	shooter = from_shooter
	damage_per_sec = dmg

func _check_immediate_trigger() -> void:
	if has_overlapping_bodies() or has_overlapping_areas():
		_trigger_trap()

func _on_body_entered(body: Node3D) -> void:
	if not is_armed or is_triggered:
		return
	if body == shooter or (body is PlayerController):
		return
	if body.has_method("take_damage") or body.is_in_group("enemies"):
		_trigger_trap()

func _on_area_entered(area: Area3D) -> void:
	if not is_armed or is_triggered:
		return
	if area.get_parent() == shooter or (area.get_parent() is PlayerController):
		return
	_trigger_trap()

func _trigger_trap() -> void:
	if is_triggered:
		return
	is_triggered = true

	AudioManager.play_toxic_burst()
	if trap_mesh:
		trap_mesh.visible = false
	if cloud_mesh:
		cloud_mesh.visible = true
		cloud_mesh.scale = Vector3(0.2, 0.2, 0.2)
		var t := create_tween()
		t.tween_property(cloud_mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if light:
		light.visible = true

	var cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.15, 0.1)

	# Fade out after cloud duration
	var tween := create_tween()
	tween.tween_interval(cloud_duration)
	tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if not is_triggered:
		return

	tick_timer += delta
	if tick_timer >= 0.4:
		tick_timer = 0.0
		_damage_enemies_in_cloud()

func _damage_enemies_in_cloud() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.6
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = (1 << 2) | (1 << 3)

	var results := space.intersect_shape(query, 24)
	var tick_dmg := damage_per_sec * 0.4
	var hit_enemies: Array[Node] = []

	for r in results:
		var col = r.collider
		var enemy: Node = null
		if col.has_method("take_damage"):
			enemy = col
		elif col.get_parent() and col.get_parent().has_method("take_damage"):
			enemy = col.get_parent()

		if enemy and enemy != shooter and not (enemy is PlayerController) and not (enemy in hit_enemies):
			hit_enemies.append(enemy)
			enemy.take_damage(tick_dmg, false, shooter, Vector3.ZERO)
			# Apply temporary slow if enemy has speed modifier
			if "speed" in enemy and not enemy.has_meta("is_slowed"):
				var orig_speed: float = enemy.speed
				enemy.set_meta("is_slowed", true)
				enemy.speed = orig_speed * (1.0 - slow_percent)
				var reset_t := get_tree().create_timer(1.2)
				reset_t.timeout.connect(func():
					if is_instance_valid(enemy):
						enemy.speed = orig_speed
						enemy.remove_meta("is_slowed")
				)

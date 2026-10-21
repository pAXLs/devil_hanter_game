class_name ArcaneBolt
extends Area3D

@export var speed: float = 18.0
@export var damage: float = 38.0
@export var splash_radius: float = 2.5
@export var crit_chance: float = 0.15
@export var crit_mult: float = 1.75
@export var knockback_force: float = 10.0
@export var max_distance: float = 22.0

var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var has_exploded: bool = false
var distance_traveled: float = 0.0

@onready var orb_mesh: MeshInstance3D = $OrbMesh
@onready var burst_mesh: MeshInstance3D = $BurstMesh
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if burst_mesh:
		burst_mesh.visible = false

func setup(dir: Vector3, from_shooter: Node3D, base_dmg: float = 38.0, crit_rate: float = 0.15, crit_multiplier: float = 1.75, knockback: float = 10.0) -> void:
	shooter = from_shooter
	damage = base_dmg
	crit_chance = crit_rate
	crit_mult = crit_multiplier
	knockback_force = knockback
	direction = dir.normalized()
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	var step := speed * delta
	global_position += direction * step
	distance_traveled += step

	# Pulsing glowing orb effect while flying
	if orb_mesh:
		var pulse := 1.0 + sin(distance_traveled * 8.0) * 0.12
		orb_mesh.scale = Vector3(pulse, pulse, pulse)

	if distance_traveled >= max_distance:
		_explode()

func _on_body_entered(body: Node3D) -> void:
	if body == shooter or (body is PlayerController):
		return
	_explode()

func _on_area_entered(area: Area3D) -> void:
	if area.get_parent() == shooter or (area.get_parent() is PlayerController):
		return
	_explode()

func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	set_physics_process(false)

	# Sound
	if AudioManager.has_method("play_arcane_impact"):
		AudioManager.play_arcane_impact()
	else:
		AudioManager.play_hit()

	# AoE splash damage to layer 4 (Enemies)
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = splash_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = (1 << 2) | (1 << 3) # Enemies layer 3 (val 4) & layer 4 (val 8)

	var results := space.intersect_shape(query, 32)
	var hit_enemies: Array[Node] = []
	var any_crit: bool = false

	for r in results:
		var col = r.collider
		var enemy: Node = null
		if col.has_method("take_damage"):
			enemy = col
		elif col.get_parent() and col.get_parent().has_method("take_damage"):
			enemy = col.get_parent()

		if enemy and enemy != shooter and not (enemy is PlayerController) and not (enemy in hit_enemies):
			hit_enemies.append(enemy)
			var is_crit: bool = randf() < crit_chance
			if is_crit:
				any_crit = true
			var final_dmg: float = damage * (crit_mult if is_crit else 1.0)
			var to_enemy: Vector3 = enemy.global_position - global_position
			var knock_dir: Vector3 = to_enemy.normalized() if to_enemy.length_squared() > 0.01 else direction
			knock_dir.y = 0.25

			enemy.take_damage(final_dmg, is_crit, shooter, knock_dir.normalized() * knockback_force)

			if SkillManager.lifesteal_percent > 0.0 and shooter and shooter.has_method("heal"):
				shooter.heal(final_dmg * SkillManager.lifesteal_percent)

	if any_crit:
		AudioManager.play_crit()

	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.2, 0.15)

	# Visual Burst Animation
	if orb_mesh:
		orb_mesh.visible = false

	if burst_mesh:
		burst_mesh.visible = true
		burst_mesh.scale = Vector3(0.4, 0.4, 0.4)
		var mat: StandardMaterial3D = burst_mesh.material_override
		if mat:
			mat = mat.duplicate()
			burst_mesh.material_override = mat

		var tween := create_tween()
		tween.parallel().tween_property(burst_mesh, "scale", Vector3(splash_radius, splash_radius, splash_radius), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if mat:
			tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
		if light:
			tween.parallel().tween_property(light, "light_energy", 0.0, 0.22)
		tween.tween_callback(queue_free)
	else:
		queue_free()

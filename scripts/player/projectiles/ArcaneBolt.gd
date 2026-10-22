class_name ArcaneBolt
extends Area3D

@export var speed: float = 22.0
@export var damage: float = 42.0
@export var splash_radius: float = 2.8
@export var crit_chance: float = 0.15
@export var crit_mult: float = 1.75
@export var knockback_force: float = 12.0
@export var max_distance: float = 24.0

var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var has_exploded: bool = false
var distance_traveled: float = 0.0

@onready var orb_mesh: MeshInstance3D = $OrbMesh
@onready var burst_mesh: MeshInstance3D = $BurstMesh
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 4 # Detect enemy hurtboxes and colliders only
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if burst_mesh:
		burst_mesh.visible = false

func setup(dir: Vector3, from_shooter: Node3D, base_dmg: float = 42.0, crit_rate: float = 0.15, crit_multiplier: float = 1.75, knockback: float = 12.0) -> void:
	shooter = from_shooter
	damage = base_dmg
	crit_chance = crit_rate
	crit_mult = crit_multiplier
	knockback_force = knockback

	# Keep direction strictly on the horizontal plane
	direction = Vector3(dir.x, 0.0, dir.z).normalized()
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	var step := speed * delta
	global_position += direction * step
	distance_traveled += step

	if orb_mesh:
		var pulse := 1.0 + sin(distance_traveled * 10.0) * 0.15
		orb_mesh.scale = Vector3(pulse, pulse, pulse)

	if distance_traveled >= max_distance:
		_explode()

func _on_body_entered(body: Node3D) -> void:
	if body == shooter or (body is PlayerController):
		return
	if body.has_method("take_damage") or body.is_in_group("enemies"):
		_explode(body)

func _on_area_entered(area: Area3D) -> void:
	if area == self or area.get_parent() == shooter or (area.get_parent() is PlayerController):
		return
	var target: Node = area
	if not target.has_method("take_damage") and area.get_parent() and area.get_parent().has_method("take_damage"):
		target = area.get_parent()
	if target.has_method("take_damage") or area.is_in_group("enemies") or (area.get_parent() and area.get_parent().is_in_group("enemies")):
		_explode(target)

func _explode(direct_target: Node = null) -> void:
	if has_exploded:
		return
	has_exploded = true
	set_physics_process(false)

	if AudioManager.has_method("play_arcane_impact"):
		AudioManager.play_arcane_impact()
	else:
		AudioManager.play_hit()

	# AoE splash damage to layer 3 & 4 (Enemies)
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = splash_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = (1 << 2) | (1 << 3)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var results := space.intersect_shape(query, 32)
	var hit_enemies: Array[Node] = []
	var any_crit: bool = false

	# Ensure directly hit target is included
	if direct_target and direct_target != shooter and not (direct_target is PlayerController):
		var main_enemy: Node = direct_target
		if not main_enemy.has_method("take_damage") and main_enemy.get_parent() and main_enemy.get_parent().has_method("take_damage"):
			main_enemy = main_enemy.get_parent()
		hit_enemies.append(main_enemy)

	for r in results:
		var col = r.collider
		var enemy: Node = null
		if col.has_method("take_damage"):
			enemy = col
		elif col.get_parent() and col.get_parent().has_method("take_damage"):
			enemy = col.get_parent()

		if enemy and enemy != shooter and not (enemy is PlayerController) and not (enemy in hit_enemies):
			hit_enemies.append(enemy)

	for enemy in hit_enemies:
		if enemy.has_method("take_damage"):
			var is_crit: bool = randf() < crit_chance
			if is_crit:
				any_crit = true
			var final_dmg: float = damage * (crit_mult if is_crit else 1.0)
			var enemy_pos: Vector3 = enemy.global_position if (enemy is Node3D) else global_position
			var diff: Vector3 = enemy_pos - global_position
			var knock_dir: Vector3 = diff.normalized() if diff.length_squared() > 0.001 else direction
			enemy.take_damage(final_dmg, is_crit, shooter, knock_dir * knockback_force)

	if hit_enemies.size() > 0 and shooter and (shooter is PlayerController):
		var pc := shooter as PlayerController
		if Global.current_class == Global.CLASS_MAGE:
			pc.resource = minf(pc.max_resource, pc.resource + 4.0)
			Global.player_resource_changed.emit(pc.resource, pc.max_resource)

	if any_crit:
		AudioManager.play_crit()

	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("shake") and hit_enemies.size() > 0:
		cam.shake(0.12, 0.1)

	# Visual explosion burst
	if orb_mesh:
		orb_mesh.visible = false
	if burst_mesh:
		burst_mesh.visible = true
		burst_mesh.scale = Vector3(0.2, 0.2, 0.2)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(burst_mesh, "scale", Vector3(1.4, 1.4, 1.4), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if light:
			tw.tween_property(light, "light_energy", 0.0, 0.18)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()

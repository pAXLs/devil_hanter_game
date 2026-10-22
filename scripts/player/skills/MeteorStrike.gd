class_name MeteorStrike
extends Node3D

@export var damage: float = 85.0
@export var splash_radius: float = 4.8
@export var crit_chance: float = 0.25
@export var crit_mult: float = 2.2

var target_pos: Vector3 = Vector3.ZERO
var shooter: Node3D = null

@onready var meteor_mesh: MeshInstance3D = $MeteorMesh
@onready var ground_decal: MeshInstance3D = $GroundDecal
@onready var explosion_mesh: MeshInstance3D = $ExplosionMesh
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	if explosion_mesh:
		explosion_mesh.visible = false

func setup(pos: Vector3, from_shooter: Node3D, base_dmg: float = 85.0, crit_rate: float = 0.25, crit_multiplier: float = 2.2) -> void:
	target_pos = pos
	shooter = from_shooter
	damage = base_dmg
	crit_chance = crit_rate
	crit_mult = crit_multiplier

	global_position = pos
	if ground_decal:
		ground_decal.global_position = pos + Vector3(0, 0.05, 0)

	if meteor_mesh:
		var start_meteor_pos := pos + Vector3(2.5, 12.0, -2.5)
		meteor_mesh.global_position = start_meteor_pos
		var fall_tween := create_tween()
		fall_tween.tween_property(meteor_mesh, "global_position", pos, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_tween.tween_callback(_impact)

func _impact() -> void:
	AudioManager.play_slam()
	if meteor_mesh:
		meteor_mesh.visible = false

	if explosion_mesh:
		explosion_mesh.visible = true
		explosion_mesh.scale = Vector3(0.5, 0.5, 0.5)
		var exp_tween := create_tween()
		exp_tween.tween_property(explosion_mesh, "scale", Vector3(3.2, 3.2, 3.2), 0.25)
		if light:
			exp_tween.parallel().tween_property(light, "light_energy", 0.0, 0.25)
		exp_tween.tween_callback(queue_free)

	var cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.45, 0.25)

	# Damage enemies in impact zone
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = splash_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), target_pos)
	query.collision_mask = (1 << 2) | (1 << 3)

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
			var is_crit := randf() < crit_chance
			if is_crit:
				any_crit = true
			var final_dmg := damage * (crit_mult if is_crit else 1.0)
			var enemy_pos: Vector3 = enemy.global_position if (enemy is Node3D) else target_pos
			var diff: Vector3 = enemy_pos - target_pos
			var knock_dir: Vector3 = diff.normalized() if diff.length_squared() > 0.001 else Vector3.UP
			knock_dir.y = 0.35
			enemy.take_damage(final_dmg, is_crit, shooter, knock_dir.normalized() * 22.0)

	if any_crit:
		AudioManager.play_crit()

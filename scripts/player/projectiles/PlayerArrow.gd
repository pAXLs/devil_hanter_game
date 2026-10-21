class_name PlayerArrow
extends Area3D

@export var speed: float = 24.0
@export var damage: float = 32.0
@export var crit_chance: float = 0.20
@export var crit_mult: float = 1.75
@export var knockback_force: float = 12.0
@export var lifetime: float = 1.8

var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var has_hit: bool = false
var time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(dir: Vector3, from_shooter: Node3D, base_dmg: float = 32.0, crit_rate: float = 0.20, crit_multiplier: float = 1.75, knockback: float = 12.0) -> void:
	shooter = from_shooter
	damage = base_dmg
	crit_chance = crit_rate
	crit_mult = crit_multiplier
	knockback_force = knockback
	direction = dir.normalized()
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)

func _on_area_entered(area: Area3D) -> void:
	_handle_hit(area)

func _handle_hit(target: Node) -> void:
	if has_hit:
		return

	var enemy: Node = null
	if target.has_method("take_damage"):
		enemy = target
	elif target.get_parent() and target.get_parent().has_method("take_damage"):
		enemy = target.get_parent()

	if enemy and enemy != shooter and not (enemy is PlayerController):
		has_hit = true
		set_physics_process(false)

		var is_crit: bool = randf() < crit_chance
		var final_dmg: float = damage * (crit_mult if is_crit else 1.0)
		var knock_dir: Vector3 = (direction + Vector3.UP * 0.15).normalized() * knockback_force

		enemy.take_damage(final_dmg, is_crit, shooter, knock_dir)

		if is_crit:
			AudioManager.play_crit()
		else:
			AudioManager.play_hit()

		if SkillManager.lifesteal_percent > 0.0 and shooter and shooter.has_method("heal"):
			shooter.heal(final_dmg * SkillManager.lifesteal_percent)

		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.12, 0.1)

		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.05)
		tween.tween_callback(queue_free)
	elif target is StaticBody3D or (target is CollisionObject3D and target.get_collision_layer_value(1)):
		has_hit = true
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.05)
		tween.tween_callback(queue_free)

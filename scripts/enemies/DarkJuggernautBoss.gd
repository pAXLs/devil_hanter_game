class_name DarkJuggernautBoss
extends CharacterBody3D

@export var max_health: float = 1600.0
@export var health: float = 1600.0
@export var move_speed: float = 3.5
@export var enraged_speed: float = 5.2
@export var attack_damage: float = 55.0

var is_dead: bool = false
var is_whirlwinding: bool = false
var is_acting: bool = false
var whirlwind_timer: float = 4.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var sword_pivot: Node3D = $Visuals/SwordPivot
var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")

	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

	Global.boss_spawned.emit("ТЁМНЫЙ ДЖАГГЕРНАУТ — ПОВЕЛИТЕЛЬ ЦИТАДЕЛИ", max_health)
	Global.boss_health_changed.emit(health, max_health)
	AudioManager.play_explosion()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var player = Global.current_player
	if player and is_instance_valid(player) and not is_acting:
		var dir = (player.global_position - global_position)
		dir.y = 0.0
		var dist = dir.length()

		if dist > 0.1 and not is_whirlwinding:
			var target_rot = atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 4.0 * delta)

		whirlwind_timer -= delta
		if dist <= 4.0 and whirlwind_timer <= 0.0:
			whirlwind_timer = 5.5
			_perform_whirlwind(player)
		elif not is_whirlwinding:
			if dist > 2.6:
				velocity.x = dir.normalized().x * move_speed
				velocity.z = dir.normalized().z * move_speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_blade_slash(player)

	move_and_slide()

func _perform_whirlwind(target: Node3D) -> void:
	is_whirlwinding = true
	is_acting = true
	AudioManager.play_sword_swing()

	var tw = create_tween()
	tw.tween_property(visuals, "rotation_degrees:y", 1080.0, 1.2).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func():
		visuals.rotation_degrees.y = 0.0
		is_whirlwinding = false
		is_acting = false
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= 5.0:
			var knock = (target.global_position - global_position).normalized() * 16.0
			if target.has_method("take_damage"):
				target.take_damage(attack_damage * 1.3, true, self, knock)
	)

func _blade_slash(target: Node3D) -> void:
	is_acting = true
	var tw = create_tween()
	tw.tween_property(sword_pivot, "rotation_degrees:x", -60.0, 0.3)
	tw.tween_property(sword_pivot, "rotation_degrees:x", 70.0, 0.15)
	tw.tween_callback(func():
		AudioManager.play_sword_hit()
		Global.boss_attacked.emit()
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= 3.8:
			var knock = (target.global_position - global_position).normalized() * 10.0
			if target.has_method("take_damage"):
				target.take_damage(attack_damage, false, self, knock)
	)
	tw.tween_property(sword_pivot, "rotation_degrees:x", 0.0, 0.25)
	tw.tween_interval(0.4)
	tw.tween_callback(func(): is_acting = false)

func _on_received_damage(amount: float, _is_crit: bool, _source: Node3D, _knockback: float) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	Global.boss_health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	Global.boss_defeated.emit()
	AudioManager.play_explosion()

	var root = get_tree().current_scene
	for i in range(20):
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(30, 60)
		root.add_child(coin)
		coin.global_position = global_position + Vector3(randf_range(-2.2, 2.2), 0.5, randf_range(-2.2, 2.2))

	var drop_wpn = loot_scene.instantiate()
	drop_wpn.item_type = 2
	drop_wpn.rarity = 3 # Legendary
	drop_wpn.item_name = "★ Цвайхендер Джаггернаута Цитадели"
	root.add_child(drop_wpn)
	drop_wpn.global_position = global_position + Vector3.UP * 0.5

	queue_free()

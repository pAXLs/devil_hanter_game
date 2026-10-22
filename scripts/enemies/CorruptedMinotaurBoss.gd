class_name CorruptedMinotaurBoss
extends CharacterBody3D

@export var max_health: float = 1350.0
@export var health: float = 1350.0
@export var move_speed: float = 3.6
@export var charge_speed: float = 8.5
@export var attack_damage: float = 48.0

var is_dead: bool = false
var is_charging: bool = false
var is_acting: bool = false
var charge_cooldown: float = 5.0
var charge_timer: float = 3.0
var charge_target: Vector3 = Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")

	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

	Global.boss_spawned.emit("ОСКВЕРНЁННЫЙ МИНОТАВР — ЯРОСТЬ ПЕПЛА", max_health)
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

		if dist > 0.1 and not is_charging:
			var target_rot = atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 4.0 * delta)

		charge_timer -= delta
		if dist >= 5.0 and charge_timer <= 0.0 and not is_charging:
			charge_timer = charge_cooldown
			_initiate_charge(player.global_position)
		elif not is_charging:
			if dist > 2.8:
				velocity.x = dir.normalized().x * move_speed
				velocity.z = dir.normalized().z * move_speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_horn_thrust(player)

	move_and_slide()

func _initiate_charge(target_pos: Vector3) -> void:
	is_charging = true
	is_acting = true
	var dir = (target_pos - global_position).normalized()
	dir.y = 0.0
	velocity = dir * charge_speed
	AudioManager.play_dash()

	var tw = create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func():
		velocity = Vector3.ZERO
		is_charging = false
		is_acting = false
	)

func _horn_thrust(target: Node3D) -> void:
	is_acting = true
	var tw = create_tween()
	tw.tween_property(visuals, "rotation_degrees:x", 35.0, 0.2)
	tw.tween_callback(func():
		AudioManager.play_sword_hit()
		Global.boss_attacked.emit()
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= 3.5:
			var knock = (target.global_position - global_position).normalized() * 14.0
			if target.has_method("take_damage"):
				target.take_damage(attack_damage, true, self, knock)
	)
	tw.tween_property(visuals, "rotation_degrees:x", 0.0, 0.3)
	tw.tween_interval(0.5)
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
	for i in range(16):
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(25, 45)
		root.add_child(coin)
		coin.global_position = global_position + Vector3(randf_range(-2.0, 2.0), 0.5, randf_range(-2.0, 2.0))

	var drop_wpn = loot_scene.instantiate()
	drop_wpn.item_type = 2
	drop_wpn.rarity = 3 # Legendary
	drop_wpn.item_name = "★ Рогатый Крушитель Минотавра"
	root.add_child(drop_wpn)
	drop_wpn.global_position = global_position + Vector3.UP * 0.5

	queue_free()

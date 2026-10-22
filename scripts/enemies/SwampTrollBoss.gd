class_name SwampTrollBoss
extends CharacterBody3D

@export var max_health: float = 950.0
@export var health: float = 950.0
@export var move_speed: float = 2.8
@export var enraged_speed: float = 4.2
@export var attack_damage: float = 42.0
@export var slam_range: float = 4.5

var is_dead: bool = false
var is_enraged: bool = false
var is_acting: bool = false
var action_timer: float = 2.2
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var club_pivot: Node3D = $Visuals/ClubPivot
var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")

	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

	Global.boss_spawned.emit("БОЛОТНЫЙ ТРОЛЛЬ — ХРАНИТЕЛЬ ЧАЩИ", max_health)
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

		if dist > 0.1:
			var target_rot = atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 4.0 * delta)

		action_timer -= delta
		if dist <= slam_range and action_timer <= 0.0:
			action_timer = 2.5
			_perform_ground_slam(player)
		elif dist > slam_range * 0.8:
			var spd = enraged_speed if is_enraged else move_speed
			velocity.x = dir.normalized().x * spd
			velocity.z = dir.normalized().z * spd
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()

func _perform_ground_slam(target: Node3D) -> void:
	is_acting = true
	velocity = Vector3.ZERO

	if club_pivot:
		var tw = create_tween()
		tw.tween_property(club_pivot, "rotation_degrees:x", -65.0, 0.4)
		tw.tween_property(club_pivot, "rotation_degrees:x", 75.0, 0.18)
		tw.tween_callback(func():
			AudioManager.play_explosion()
			Global.boss_attacked.emit()
			if is_instance_valid(target):
				var d = global_position.distance_to(target.global_position)
				if d <= slam_range * 1.2:
					var knock = (target.global_position - global_position).normalized() * 12.0
					if target.has_method("take_damage"):
						target.take_damage(attack_damage, true, self, knock)
		)
		tw.tween_interval(0.3)
		tw.tween_property(club_pivot, "rotation_degrees:x", 0.0, 0.3)
		tw.tween_callback(func(): is_acting = false)
	else:
		is_acting = false

func _on_received_damage(amount: float, is_crit: bool, _source: Node3D, _knockback: float) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	Global.boss_health_changed.emit(health, max_health)

	if health <= max_health * 0.4 and not is_enraged:
		is_enraged = true

	if health <= 0.0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	Global.boss_defeated.emit()
	AudioManager.play_explosion()

	var root = get_tree().current_scene
	for i in range(12):
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(15, 30)
		root.add_child(coin)
		coin.global_position = global_position + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5))

	var drop_wpn = loot_scene.instantiate()
	drop_wpn.item_type = 2
	drop_wpn.rarity = 2
	drop_wpn.item_name = "★ Дубина Болотного Великана"
	root.add_child(drop_wpn)
	drop_wpn.global_position = global_position + Vector3.UP * 0.5

	queue_free()

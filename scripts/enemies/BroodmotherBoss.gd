class_name BroodmotherBoss
extends CharacterBody3D

@export var max_health: float = 1100.0
@export var health: float = 1100.0
@export var move_speed: float = 3.2
@export var attack_damage: float = 36.0

var is_dead: bool = false
var is_acting: bool = false
var spawn_cooldown: float = 6.0
var spawn_timer: float = 2.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
var spider_scene: PackedScene = preload("res://scenes/enemies/CaveSpider.tscn")
var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")

	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

	Global.boss_spawned.emit("ПАУЧЬЯ МАТКА — АРАХНА ТЬМЫ", max_health)
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
			rotation.y = lerp_angle(rotation.y, target_rot, 3.5 * delta)

		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_cooldown
			_spawn_spiderlings()

		if dist > 3.0:
			velocity.x = dir.normalized().x * move_speed
			velocity.z = dir.normalized().z * move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_bite_attack(player)

	move_and_slide()

func _bite_attack(target: Node3D) -> void:
	is_acting = true
	var tw = create_tween()
	tw.tween_property(visuals, "position:z", -0.8, 0.25)
	tw.tween_callback(func():
		AudioManager.play_sword_hit()
		Global.boss_attacked.emit()
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= 3.8:
			var knock = (target.global_position - global_position).normalized() * 9.0
			if target.has_method("take_damage"):
				target.take_damage(attack_damage, false, self, knock)
	)
	tw.tween_property(visuals, "position:z", 0.0, 0.3)
	tw.tween_interval(0.6)
	tw.tween_callback(func(): is_acting = false)

func _spawn_spiderlings() -> void:
	if not spider_scene:
		return
	var root = get_tree().current_scene
	for i in range(3):
		var sp = spider_scene.instantiate()
		root.add_child(sp)
		sp.global_position = global_position + Vector3(randf_range(-2.0, 2.0), 0.2, randf_range(-2.0, 2.0))

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
	for i in range(14):
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(20, 35)
		root.add_child(coin)
		coin.global_position = global_position + Vector3(randf_range(-1.8, 1.8), 0.5, randf_range(-1.8, 1.8))

	var drop_wpn = loot_scene.instantiate()
	drop_wpn.item_type = 2
	drop_wpn.rarity = 2
	drop_wpn.item_name = "★ Клыкастый Крис Паучьей Матки"
	root.add_child(drop_wpn)
	drop_wpn.global_position = global_position + Vector3.UP * 0.5

	queue_free()

class_name PlagueZombie
extends CharacterBody3D

@export var max_health: float = 110.0
@export var health: float = 110.0
@export var move_speed: float = 2.2
@export var attack_damage: float = 26.0
@export var attack_range: float = 1.9
@export var attack_cooldown: float = 1.8

var is_dead: bool = false
var is_attacking: bool = false
var attack_timer: float = 0.5

var poison_cloud_scene: PackedScene = preload("res://scenes/combat/PoisonCloud.tscn")
var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var health_bar: Node3D = $HealthBar3D
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("enemies")
	if Global.current_floor > 1:
		max_health = round(max_health * Global.get_floor_hp_multiplier())
		health = max_health
		attack_damage = round(attack_damage * Global.get_floor_damage_multiplier())
	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(health, max_health)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var player: CharacterBody3D = Global.current_player
	if not player or not is_instance_valid(player):
		move_and_slide()
		return

	var dist: float = global_position.distance_to(player.global_position)

	# Face player
	var look_target := Vector3(player.global_position.x, visuals.global_position.y, player.global_position.z)
	if look_target.distance_squared_to(visuals.global_position) > 0.05:
		visuals.look_at(look_target, Vector3.UP)

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	if dist <= attack_range:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if attack_timer <= 0.0:
			_start_heavy_slam(player)
	else:
		var dir: Vector3 = (player.global_position - global_position).normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed

	move_and_slide()

func _start_heavy_slam(player: Node3D) -> void:
	is_attacking = true
	attack_timer = attack_cooldown

	# Heavy telegraph wind-up (0.50s)
	var tween := create_tween()
	tween.tween_property(visuals, "position:y", 0.4, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visuals, "rotation_degrees:x", -25.0, 0.50)

	# Slam down (0.12s)
	tween.tween_property(visuals, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visuals, "rotation_degrees:x", 30.0, 0.12)
	tween.tween_callback(func():
		if is_dead:
			return
		if player and is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist <= attack_range + 0.6:
				var hurt: Hurtbox3D = player.get_node_or_null("Hurtbox3D")
				if hurt and not hurt.is_invulnerable:
					hurt.received_damage.emit(attack_damage, false, self, 8.0)
					AudioManager.play_hit()
	)

	# Recovery (0.35s)
	tween.tween_property(visuals, "rotation_degrees:x", 0.0, 0.35)
	tween.tween_callback(func():
		is_attacking = false
	)

func _on_received_damage(amount: float, is_crit: bool, source: Node3D, knockback: float) -> void:
	take_damage(amount, is_crit, source, (global_position - (source.global_position if source else global_position)).normalized() * knockback)

func take_damage(amount: float, is_crit: bool, source: Node3D, knock_velocity: Vector3) -> void:
	if is_dead:
		return

	health -= amount
	Global.damage_spawned.emit(global_position + Vector3.UP * 1.6, int(amount), is_crit, false)
	# Heavy zombie resists knockback by 50%
	velocity += knock_velocity * 0.5

	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(health, max_health)

	if body_mesh:
		var tween := create_tween()
		tween.tween_property(body_mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
		tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.08)

	if health <= 0.0:
		_die()

func _die() -> void:
	Global.enemies_killed_floor += 1
	Global.enemies_killed_total += 1
	is_dead = true
	is_attacking = false
	velocity = Vector3.ZERO
	if hurtbox:
		hurtbox.queue_free()

	Global.player_xp_changed.emit(35, 100, Global.player_level)
	_spawn_loot()

	# Swell and explode with toxic cloud!
	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3(1.4, 1.4, 1.4), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_spawn_poison_explosion()
	)
	tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.1)
	tween.tween_callback(queue_free)

func _spawn_poison_explosion() -> void:
	var root := get_tree().current_scene
	var cloud = poison_cloud_scene.instantiate()
	root.add_child(cloud)
	cloud.global_position = global_position

func _spawn_loot() -> void:
	var root := get_tree().current_scene
	var drop_origin := global_position + Vector3.UP * 0.3

	# 40% chance 1 coin
	if randf() < 0.40:
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(4, 8)
		root.add_child(coin)
		coin.global_position = drop_origin

	# 8% chance potion
	if randf() < 0.08:
		var pot = loot_scene.instantiate()
		pot.item_type = 1
		pot.amount = 1
		pot.item_name = "Зелье Здоровья"
		pot.rarity = 1
		root.add_child(pot)
		pot.global_position = drop_origin

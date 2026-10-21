class_name SkeletonArcher
extends CharacterBody3D

@export var max_health: float = 50.0
@export var health: float = 50.0
@export var move_speed: float = 3.8
@export var shoot_range: float = 9.0
@export var retreat_range: float = 4.2
@export var shoot_cooldown: float = 1.6

var is_dead: bool = false
var is_aiming: bool = false
var shoot_timer: float = 0.8

var arrow_scene: PackedScene = preload("res://scenes/combat/Arrow3D.tscn")
var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var health_bar: Node3D = $HealthBar3D
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var bow_mesh: MeshInstance3D = $Visuals/Bow

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("enemies")
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

	# Always face player
	var look_target := Vector3(player.global_position.x, visuals.global_position.y, player.global_position.z)
	if look_target.distance_squared_to(visuals.global_position) > 0.05:
		visuals.look_at(look_target, Vector3.UP)

	if is_aiming:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	if shoot_timer > 0.0:
		shoot_timer -= delta

	# Kiting logic
	if dist < retreat_range:
		# Run away from player
		var retreat_dir: Vector3 = (global_position - player.global_position).normalized()
		velocity.x = retreat_dir.x * move_speed
		velocity.z = retreat_dir.z * move_speed
	elif dist > shoot_range:
		# Move closer into firing range
		var approach_dir: Vector3 = (player.global_position - global_position).normalized()
		velocity.x = approach_dir.x * move_speed
		velocity.z = approach_dir.z * move_speed
	else:
		# In good position: stop and shoot
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

		if shoot_timer <= 0.0:
			_start_shoot(player)

	move_and_slide()

func _start_shoot(player: Node3D) -> void:
	is_aiming = true
	shoot_timer = shoot_cooldown

	# Windup telegraph: pull back bow and flash eyes violet
	var tween := create_tween()
	if bow_mesh:
		tween.tween_property(bow_mesh, "position:z", 0.25, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_interval(0.50)

	tween.tween_callback(func():
		if is_dead:
			return
		_release_arrow(player)
		if bow_mesh:
			bow_mesh.position.z = 0.0
		is_aiming = false
	)

func _release_arrow(player: Node3D) -> void:
	if not player or not is_instance_valid(player):
		return

	AudioManager.play_bow_shot()

	var root := get_tree().current_scene
	var arrow = arrow_scene.instantiate()
	root.add_child(arrow)

	var spawn_pos := global_position + Vector3.UP * 1.0 + (-visuals.global_transform.basis.z * 0.6)
	arrow.global_position = spawn_pos

	var target_pos := player.global_position + Vector3.UP * 0.8
	var shoot_dir := (target_pos - spawn_pos).normalized()
	arrow.setup(shoot_dir, self)

func _on_received_damage(amount: float, is_crit: bool, source: Node3D, knockback: float) -> void:
	take_damage(amount, is_crit, source, (global_position - (source.global_position if source else global_position)).normalized() * knockback)

func take_damage(amount: float, is_crit: bool, source: Node3D, knock_velocity: Vector3) -> void:
	if is_dead:
		return

	health -= amount
	Global.damage_spawned.emit(global_position + Vector3.UP * 1.5, int(amount), is_crit, false)
	velocity += knock_velocity * 0.7

	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(health, max_health)

	# Flash body
	if body_mesh:
		var tween := create_tween()
		tween.tween_property(body_mesh, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
		tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.08)

	if health <= 0.0:
		_die()

func _die() -> void:
	AudioManager.play_bone_crunch()
	is_dead = true
	is_aiming = false
	velocity = Vector3.ZERO
	if hurtbox:
		hurtbox.queue_free()

	Global.player_xp_changed.emit(25, 100, Global.player_level)
	_spawn_loot()

	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _spawn_loot() -> void:
	var root := get_tree().current_scene
	var drop_origin := global_position + Vector3.UP * 0.3

	# 35% chance 1 coin
	if randf() < 0.35:
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(3, 7)
		root.add_child(coin)
		coin.global_position = drop_origin

	# 5% chance potion
	if randf() < 0.05:
		var pot = loot_scene.instantiate()
		pot.item_type = 1
		pot.amount = 1
		pot.item_name = "Зелье Здоровья"
		pot.rarity = 1
		root.add_child(pot)
		pot.global_position = drop_origin

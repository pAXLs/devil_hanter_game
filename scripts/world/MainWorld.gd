class_name MainWorld
extends Node3D

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/SkeletonEnemy.tscn")
@export var archer_scene: PackedScene = preload("res://scenes/enemies/SkeletonArcher.tscn")
@export var zombie_scene: PackedScene = preload("res://scenes/enemies/PlagueZombie.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/CryptLordBoss.tscn")
@export var spawn_interval: float = 6.0
@export var max_enemies: float = 7

var spawn_timer: float = 0.0
var session_time: float = 0.0
var boss_spawned: bool = false
var boss_active: bool = false

func _ready() -> void:
	Global.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	session_time += delta

	# Check boss spawn condition: after 45 seconds of battle or level up
	if not boss_spawned and (session_time >= 40.0 or Global.player_level >= 2):
		_spawn_boss()

	if boss_active:
		# Don't spawn regular waves while boss duel is active
		return

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_check_and_spawn()

func _check_and_spawn() -> void:
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	if existing_enemies.size() >= max_enemies:
		return

	var angle := randf() * TAU
	var dist := randf_range(11.0, 16.0)
	var spawn_pos := Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)

	if Global.current_player:
		spawn_pos += Global.current_player.global_position
		spawn_pos.y = 0.5

	# Pick enemy type: 50% Skeleton Warrior, 30% Skeleton Archer, 20% Plague Zombie
	var roll := randf()
	var selected_scene: PackedScene = enemy_scene
	if roll < 0.30:
		selected_scene = archer_scene
	elif roll < 0.50:
		selected_scene = zombie_scene

	var enemy = selected_scene.instantiate()
	enemy.add_to_group("enemies")
	enemy.position = spawn_pos
	add_child(enemy)

func _spawn_boss() -> void:
	boss_spawned = true
	boss_active = true

	var spawn_pos := Vector3(0, 0.2, -10.0)
	if Global.current_player:
		var forward := -Global.current_player.global_transform.basis.z.normalized()
		spawn_pos = Global.current_player.global_position + forward * 10.0
		spawn_pos.y = 0.2

	var boss = boss_scene.instantiate()
	boss.global_position = spawn_pos
	add_child(boss)

func _on_boss_defeated() -> void:
	boss_active = false
	# Allow waves again after boss falls
	spawn_timer = 0.0

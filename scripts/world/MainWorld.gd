class_name MainWorld
extends Node3D

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/SkeletonEnemy.tscn")
@export var archer_scene: PackedScene = preload("res://scenes/enemies/SkeletonArcher.tscn")
@export var zombie_scene: PackedScene = preload("res://scenes/enemies/PlagueZombie.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/CryptLordBoss.tscn")
@export var spawn_interval: float = 2.8
@export var max_enemies: float = 10

var spawn_timer: float = 1.6
var session_time: float = 0.0
var boss_spawned: bool = false
var boss_active: bool = false

func _ready() -> void:
	Global.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	session_time += delta

	# Check boss spawn condition: after 50 seconds of battle or level up
	if not boss_spawned and (session_time >= 50.0 or Global.player_level >= 2):
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
	var current_count: int = existing_enemies.size()
	if current_count >= max_enemies:
		return

	# Dynamic pack spawn: 1 to 2 enemies per pulse
	var pack_size: int = randi_range(1, 2)
	var slots_available: int = int(max_enemies - current_count)
	pack_size = mini(pack_size, slots_available)

	var base_angle := randf() * TAU
	var base_dist := randf_range(8.5, 12.5)

	for i in range(pack_size):
		var angle: float = base_angle + (i * 0.45)
		var dist: float = base_dist + randf_range(-0.8, 0.8)
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

		# 18% chance to spawn as an Elite Champion with special affixes!
		if selected_scene == enemy_scene and randf() < 0.18:
			var aff_roll := randf()
			var affix: String = BaseEnemy.AFFIX_MOLTEN
			if aff_roll < 0.35:
				affix = BaseEnemy.AFFIX_MOLTEN
			elif aff_roll < 0.70:
				affix = BaseEnemy.AFFIX_FROZEN
			else:
				affix = BaseEnemy.AFFIX_VAMPIRIC
			enemy.make_elite(affix)

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

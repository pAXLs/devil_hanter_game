class_name MainWorld
extends Node3D

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/SkeletonEnemy.tscn")
@export var archer_scene: PackedScene = preload("res://scenes/enemies/SkeletonArcher.tscn")
@export var zombie_scene: PackedScene = preload("res://scenes/enemies/PlagueZombie.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/CryptLordBoss.tscn")
@export var portal_scene: PackedScene = preload("res://scenes/world/DungeonPortal.tscn")

@export var base_spawn_interval: float = 2.8
@export var base_max_enemies: int = 10

var spawn_timer: float = 1.6
var session_time: float = 0.0
var boss_spawned: bool = false
var boss_active: bool = false
var last_boss_death_pos: Vector3 = Vector3(0, 0.05, -3.0)

# Environment and Lighting references
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var moonlight: DirectionalLight3D = $Moonlight
@onready var floor_mesh: MeshInstance3D = $DungeonFloor/FloorMesh
@onready var pillars_node: Node3D = $Pillars

func _ready() -> void:
	Global.boss_defeated.connect(_on_boss_defeated)
	Global.execute_floor_descent.connect(_on_execute_floor_descent)

	# Ensure unique materials for runtime biome transitions
	if world_env and world_env.environment:
		world_env.environment = world_env.environment.duplicate()
	if floor_mesh:
		var base_mat := floor_mesh.get_active_material(0)
		if base_mat:
			floor_mesh.material_override = base_mat.duplicate()

	_apply_biome(Global.current_floor)

func _process(delta: float) -> void:
	session_time += delta

	# Check boss spawn condition: after 50 seconds of battle or level up
	if not boss_spawned and (session_time >= 50.0 or Global.player_level >= 2):
		_spawn_boss()

	if boss_active:
		# Don't spawn regular waves while boss duel is active
		return

	spawn_timer += delta
	var current_spawn_interval: float = maxf(1.8, base_spawn_interval - (Global.current_floor - 1) * 0.25)
	if spawn_timer >= current_spawn_interval:
		spawn_timer = 0.0
		_check_and_spawn()

func _check_and_spawn() -> void:
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	var current_count: int = existing_enemies.size()
	var current_max_enemies: int = mini(base_max_enemies + (Global.current_floor - 1) * 2, 16)
	if current_count >= current_max_enemies:
		return

	# Dynamic pack spawn: 1 to 2 enemies per pulse
	var pack_size: int = randi_range(1, 2)
	var slots_available: int = current_max_enemies - current_count
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

		# Floor-scaled chance to spawn as an Elite Champion with special affixes!
		var elite_chance: float = Global.get_floor_elite_chance()
		if selected_scene == enemy_scene and randf() < elite_chance:
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
	spawn_timer = 0.0

	# Find boss position for portal spawn
	var portal_pos := Vector3(0, 0.05, -3.0)
	var bosses := get_tree().get_nodes_in_group("bosses")
	if bosses.size() > 0 and is_instance_valid(bosses[0]):
		portal_pos = bosses[0].global_position
		portal_pos.y = 0.05

	# Spawn the glowing dungeon descent portal
	var portal = portal_scene.instantiate()
	portal.add_to_group("portals")
	portal.global_position = portal_pos
	add_child(portal)

func _on_execute_floor_descent() -> void:
	# Clean up remaining regular enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Remove existing portals
	for portal in get_tree().get_nodes_in_group("portals"):
		if is_instance_valid(portal):
			portal.queue_free()

	# Advance floor
	Global.current_floor += 1
	Global.enemies_killed_floor = 0
	Global.gold_collected_floor = 0

	# Reset session timers for the new floor
	session_time = 0.0
	boss_spawned = false
	boss_active = false
	spawn_timer = 1.0

	# Heal player by 35% max HP as floor completion reward
	if Global.current_player and is_instance_valid(Global.current_player):
		if Global.current_player.has_method("heal"):
			Global.current_player.heal(Global.current_player.max_health * 0.35)
		# Reposition player towards starting area
		Global.current_player.global_position = Vector3(0, 0.2, 0)

	# Transition biome graphics (fog, lighting, floor texture)
	_apply_biome(Global.current_floor)

	# Notify UI
	var floor_name := Global.get_floor_name(Global.current_floor)
	Global.floor_changed.emit(Global.current_floor, floor_name)

func _apply_biome(floor_num: int) -> void:
	var env: Environment = world_env.environment if world_env else null
	var floor_mat: StandardMaterial3D = (floor_mesh.material_override as StandardMaterial3D) if floor_mesh else null

	var ambient_col: Color
	var fog_col: Color
	var fog_dens: float
	var moon_col: Color
	var floor_col: Color
	var torch_col: Color

	match floor_num:
		1:
			# Floor 1: «Древний Склеп» — Cold Blue/Steel Crypt
			ambient_col = Color(0.15, 0.18, 0.25, 1.0)
			fog_col = Color(0.10, 0.12, 0.18, 1.0)
			fog_dens = 0.015
			moon_col = Color(0.65, 0.75, 0.90, 1.0)
			floor_col = Color(0.18, 0.20, 0.24, 1.0)
			torch_col = Color(1.0, 0.65, 0.20, 1.0)
		2:
			# Floor 2: «Кровавые Катакомбы» — Scorched Blood Sanctum & Crimson Fog
			ambient_col = Color(0.24, 0.07, 0.07, 1.0)
			fog_col = Color(0.18, 0.04, 0.04, 1.0)
			fog_dens = 0.022
			moon_col = Color(1.0, 0.45, 0.35, 1.0)
			floor_col = Color(0.20, 0.10, 0.10, 1.0)
			torch_col = Color(1.0, 0.32, 0.08, 1.0)
		3:
			# Floor 3: «Обитель Хаоса» — Mystic Void Purple & Void Flames
			ambient_col = Color(0.16, 0.07, 0.24, 1.0)
			fog_col = Color(0.12, 0.04, 0.18, 1.0)
			fog_dens = 0.026
			moon_col = Color(0.75, 0.45, 1.0, 1.0)
			floor_col = Color(0.12, 0.08, 0.16, 1.0)
			torch_col = Color(0.85, 0.25, 0.95, 1.0)
		_:
			# Floor 4+: «Глубины Преисподней» — Hellfire Brimstone
			ambient_col = Color(0.26, 0.04, 0.04, 1.0)
			fog_col = Color(0.22, 0.02, 0.02, 1.0)
			fog_dens = 0.030
			moon_col = Color(1.0, 0.25, 0.20, 1.0)
			floor_col = Color(0.10, 0.05, 0.05, 1.0)
			torch_col = Color(1.0, 0.20, 0.05, 1.0)

	# Smooth tween of atmosphere colors
	var tween := create_tween()
	if env:
		tween.tween_property(env, "ambient_light_color", ambient_col, 0.8)
		tween.parallel().tween_property(env, "fog_light_color", fog_col, 0.8)
		tween.parallel().tween_property(env, "fog_density", fog_dens, 0.8)
	if moonlight:
		tween.parallel().tween_property(moonlight, "light_color", moon_col, 0.8)
	if floor_mat:
		tween.parallel().tween_property(floor_mat, "albedo_color", floor_col, 0.8)

	# Update torch lights on pillars
	if pillars_node:
		for pillar in pillars_node.get_children():
			var torch_light: OmniLight3D = pillar.get_node_or_null("TorchMesh/OmniLight3D")
			if torch_light:
				tween.parallel().tween_property(torch_light, "light_color", torch_col, 0.8)

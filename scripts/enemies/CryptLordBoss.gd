class_name CryptLordBoss
extends CharacterBody3D

@export var max_health: float = 700.0
@export var health: float = 700.0
@export var move_speed: float = 3.4
@export var enraged_speed: float = 4.8
@export var attack_damage: float = 34.0
@export var cleave_range: float = 3.8

var is_dead: bool = false
var is_enraged: bool = false
var is_acting: bool = false
var summoned_phase_1: bool = false
var summoned_phase_2: bool = false

var action_timer: float = 2.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Node references
@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var axe_pivot: Node3D = $Visuals/AxePivot
@onready var eye_light: OmniLight3D = $Visuals/Head/EyeLight
@onready var aura_light: OmniLight3D = $Visuals/AuraLight

var skeleton_scene: PackedScene = preload("res://scenes/enemies/SkeletonEnemy.tscn")
var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")

	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

	# Notify HUD to display boss health bar
	Global.boss_spawned.emit("ЛООРД СКЛЕПА — ВЛАДЫКА ТЬМЫ", max_health)
	Global.boss_health_changed.emit(health, max_health)

	# Entrance roar camera shake
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.5, 0.4)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var player: Node3D = Global.current_player
	if not player or not is_instance_valid(player):
		move_and_slide()
		return

	if is_acting:
		move_and_slide()
		return

	# Turn towards player
	var look_target := Vector3(player.global_position.x, visuals.global_position.y, player.global_position.z)
	if look_target.distance_squared_to(visuals.global_position) > 0.1:
		visuals.look_at(look_target, Vector3.UP)

	var dist := global_position.distance_to(player.global_position)

	# Action timer countdown
	action_timer -= delta
	if action_timer <= 0.0:
		_choose_attack(dist, player)
		return

	# Movement
	if dist > cleave_range - 0.5:
		var dir := (player.global_position - global_position).normalized()
		var spd := enraged_speed if is_enraged else move_speed
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

	move_and_slide()

func _choose_attack(dist: float, player: Node3D) -> void:
	# Check summons at thresholds
	if health <= max_health * 0.65 and not summoned_phase_1:
		summoned_phase_1 = true
		_perform_slam_and_summon(player)
		return
	elif health <= max_health * 0.35 and not summoned_phase_2:
		summoned_phase_2 = true
		_perform_slam_and_summon(player)
		return

	# In close range: Heavy Cleave
	if dist <= cleave_range:
		_perform_cleave(player)
	else:
		# Medium/Long range: Charge or Approach
		if randf() < 0.65:
			_perform_charge(player)
		else:
			action_timer = 1.0

func _perform_cleave(player: Node3D) -> void:
	is_acting = true
	velocity = Vector3.ZERO
	action_timer = 1.8 if not is_enraged else 1.2

	var tween := create_tween()
	# 1. Telegraph wind-up: raise axe high, glow red
	tween.tween_property(axe_pivot, "rotation_degrees:x", -95.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(axe_pivot, "rotation_degrees:y", 45.0, 0.45)

	# 2. Heavy downward slam
	tween.tween_callback(func():
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.45, 0.25)
	)
	tween.tween_property(axe_pivot, "rotation_degrees:x", 30.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(axe_pivot, "rotation_degrees:y", -35.0, 0.12)

	# Hit check
	tween.tween_callback(func():
		if is_dead:
			return
		if player and is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist <= cleave_range + 0.6:
				var forward := -visuals.global_transform.basis.z.normalized()
				var to_player := (player.global_position - global_position).normalized()
				if forward.dot(to_player) > -0.2: # Wide 160° arc
					var hurt := player.get_node_or_null("Hurtbox3D")
					if hurt and not hurt.is_invulnerable:
						hurt.received_damage.emit(attack_damage * (1.2 if is_enraged else 1.0), true, self, 14.0)
	)

	# 3. Recovery
	tween.tween_interval(0.3)
	tween.tween_property(axe_pivot, "rotation_degrees:x", 0.0, 0.3)
	tween.parallel().tween_property(axe_pivot, "rotation_degrees:y", 0.0, 0.3)
	tween.tween_callback(func(): is_acting = false)

func _perform_charge(player: Node3D) -> void:
	is_acting = true
	velocity = Vector3.ZERO
	action_timer = 2.4

	# Telegraph: Crouch back and glow
	var charge_dir := (player.global_position - global_position).normalized()
	charge_dir.y = 0.0
	charge_dir = charge_dir.normalized()

	var tween := create_tween()
	tween.tween_property(visuals, "position:z", 0.6, 0.45)
	tween.tween_callback(func():
		# Dash forward with high velocity
		velocity = charge_dir * (13.5 if not is_enraged else 16.5)
	)
	tween.tween_interval(0.45)
	tween.tween_callback(func():
		# Stop charge
		velocity = Vector3.ZERO
		# Shockwave hit on impact
		if player and is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist <= 3.2:
				var hurt := player.get_node_or_null("Hurtbox3D")
				if hurt and not hurt.is_invulnerable:
					hurt.received_damage.emit(attack_damage * 1.15, true, self, 16.0)
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.35, 0.2)
	)
	tween.tween_property(visuals, "position:z", 0.0, 0.25)
	tween.tween_callback(func(): is_acting = false)

func _perform_slam_and_summon(player: Node3D) -> void:
	is_acting = true
	is_enraged = true
	velocity = Vector3.ZERO
	action_timer = 2.6

	if aura_light:
		aura_light.light_color = Color(1.0, 0.15, 0.15, 1.0)
		aura_light.light_energy = 4.0
	if eye_light:
		eye_light.light_color = Color(1.0, 0.1, 0.1, 1.0)

	var tween := create_tween()
	# Jump up
	tween.tween_property(visuals, "position:y", 2.2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Slam down
	tween.tween_property(visuals, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.65, 0.4)

		# Spawn 2 skeleton minions around boss
		_spawn_minions(2)

		# Radial shockwave damage to player if too close
		if player and is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist <= 5.5:
				var hurt := player.get_node_or_null("Hurtbox3D")
				if hurt and not hurt.is_invulnerable:
					hurt.received_damage.emit(25.0, false, self, 12.0)
	)
	tween.tween_interval(0.4)
	tween.tween_callback(func(): is_acting = false)

func _spawn_minions(count: int) -> void:
	var root := get_tree().current_scene
	for i in range(count):
		var skel = skeleton_scene.instantiate()
		var angle := randf() * TAU
		var dist := randf_range(3.0, 5.0)
		skel.global_position = global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
		skel.add_to_group("enemies")
		root.add_child(skel)

func _on_received_damage(amount: float, is_crit: bool, source: Node3D, knockback: float) -> void:
	take_damage(amount, is_crit, source, (global_position - (source.global_position if source else global_position)).normalized() * (knockback * 0.25)) # Heavy poise

func take_damage(amount: float, is_crit: bool, source: Node3D, knock_velocity: Vector3) -> void:
	if is_dead:
		return

	health -= amount
	Global.boss_health_changed.emit(health, max_health)
	Global.damage_spawned.emit(global_position + Vector3.UP * 2.8, int(amount), is_crit, false)

	# Minimal knockback due to massive boss armor
	velocity += knock_velocity * 0.2

	# Flash effect
	var tween := create_tween()
	tween.tween_property(body_mesh, "scale", Vector3(1.08, 0.94, 1.08), 0.06)
	tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.06)

	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	is_acting = true
	velocity = Vector3.ZERO
	if hurtbox:
		hurtbox.queue_free()

	Global.boss_defeated.emit()

	# Huge reward XP
	Global.player_xp_changed.emit(100, 100, Global.player_level + 1)

	# Epic death shake and time slowdown hit-stop
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.8, 0.6)

	_spawn_legendary_loot_fountain()

	var tween := create_tween()
	tween.tween_property(visuals, "rotation_degrees:x", -80.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visuals, "position:y", -0.5, 0.8)
	tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tween.tween_callback(queue_free)

func _spawn_legendary_loot_fountain() -> void:
	var root := get_tree().current_scene
	var spawn_pos := global_position + Vector3.UP * 1.0

	# 1. 10-14 Gold coins
	for i in range(randi_range(10, 14)):
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.rarity = 0
		coin.amount = randi_range(25, 60)
		root.add_child(coin)
		coin.global_position = spawn_pos
		var angle := randf() * TAU
		var spd := randf_range(2.5, 5.0)
		coin.velocity = Vector3(cos(angle) * spd, randf_range(4.5, 7.0), sin(angle) * spd)

	# 2. 1 Health Potion
	var pot = loot_scene.instantiate()
	pot.item_type = 1
	pot.rarity = 1
	pot.amount = 1
	pot.item_name = "Зелье Здоровья"
	root.add_child(pot)
	pot.global_position = spawn_pos
	var angle := randf() * TAU
	var spd := randf_range(2.0, 4.0)
	pot.velocity = Vector3(cos(angle) * spd, randf_range(4.0, 6.5), sin(angle) * spd)

	# 3. Guaranteed Legendary Axe of the Crypt Lord!
	var boss_weapon = loot_scene.instantiate()
	boss_weapon.item_type = 2
	boss_weapon.rarity = 3 # Legendary
	boss_weapon.item_name = "★ Секира Лорда Склепа (+15 к урону)"
	root.add_child(boss_weapon)
	boss_weapon.global_position = spawn_pos
	boss_weapon.velocity = Vector3(0, 7.5, 0)

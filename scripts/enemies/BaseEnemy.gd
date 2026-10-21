class_name BaseEnemy
extends CharacterBody3D

@export var max_health: float = 60.0
@export var health: float = 60.0
@export var move_speed: float = 3.8
@export var attack_damage: float = 12.0
@export var attack_range: float = 2.0
@export var aggro_range: float = 14.0
@export var attack_cooldown: float = 1.4

const AFFIX_NONE = ""
const AFFIX_MOLTEN = "molten"       # Leaves burning magma, explodes on death
const AFFIX_FROZEN = "frozen"       # Chills & slows player on hit
const AFFIX_VAMPIRIC = "vampiric"   # Heals 50% on hit

@export var is_elite: bool = false
@export var elite_affix: String = AFFIX_NONE

var molten_timer: float = 0.0
var lava_scene: PackedScene = preload("res://scenes/combat/LavaPatch.tscn")
var aura_mesh: MeshInstance3D = null

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var attack_timer: float = 0.0
var is_dead: bool = false
var is_attacking: bool = false

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var health_bar: Node3D = $HealthBar3D

var attack_tween: Tween = null

func _ready() -> void:
	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(health, max_health)

func make_elite(affix: String) -> void:
	is_elite = true
	elite_affix = affix
	max_health = 120.0
	health = max_health
	attack_damage = 22.0

	# 20% larger size
	scale = Vector3(1.22, 1.22, 1.22)

	var title := "★ ЭЛИТНЫЙ СКЕЛЕТ"
	var col := Color.WHITE

	match affix:
		AFFIX_MOLTEN:
			title = "★ [ОГНЕННЫЙ] СКЕЛЕТ"
			col = Color(1.0, 0.4, 0.1, 1.0)
		AFFIX_FROZEN:
			title = "★ [ЛЕДЯНОЙ] СКЕЛЕТ"
			col = Color(0.2, 0.8, 1.0, 1.0)
		AFFIX_VAMPIRIC:
			title = "★ [ВАМПИР] СКЕЛЕТ"
			col = Color(1.0, 0.15, 0.25, 1.0)

	if health_bar and health_bar.has_method("set_title"):
		health_bar.set_title(title, col)
		health_bar.update_health(health, max_health)

	_create_elite_aura(col)

func _create_elite_aura(color: Color) -> void:
	if aura_mesh:
		aura_mesh.queue_free()

	aura_mesh = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.05
	aura_mesh.mesh = disc

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	aura_mesh.material_override = mat

	add_child(aura_mesh)
	aura_mesh.position = Vector3(0, 0.04, 0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Molten trail
	if is_elite and elite_affix == AFFIX_MOLTEN:
		molten_timer += delta
		if molten_timer >= 1.6:
			molten_timer = 0.0
			var root := get_tree().current_scene
			var lava = lava_scene.instantiate()
			root.add_child(lava)
			lava.global_position = global_position

	if attack_timer > 0.0:
		attack_timer -= delta

	if is_attacking:
		# During attack wind-up / swing, slow down or hold position
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		
		# Always face player
		var look_target := Vector3(player.global_position.x, visuals.global_position.y, player.global_position.z)
		if look_target.distance_squared_to(visuals.global_position) > 0.1:
			visuals.look_at(look_target, Vector3.UP)

		if dist <= attack_range:
			# In range: stop and wind up attack if off cooldown
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			if attack_timer <= 0.0:
				_start_telegraphed_attack(player)
		elif dist <= aggro_range:
			# Chase player
			var dir: Vector3 = (player.global_position - global_position).normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
		else:
			# Idle
			velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)

	move_and_slide()

func _start_telegraphed_attack(target_player: Node3D) -> void:
	is_attacking = true
	attack_timer = attack_cooldown

	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()

	attack_tween = create_tween()

	# 1. TELEGRAPH (0.45s): Skeleton reels back, raising weapon, visual cue
	attack_tween.tween_property(visuals, "position:z", 0.35, 0.45).set_trans(Tween.TRANS_SINE)
	attack_tween.parallel().tween_property(visuals, "rotation_degrees:x", -15.0, 0.45)
	
	# Glow / pulse head/eyes slightly to warn player
	if head_mesh:
		attack_tween.parallel().tween_property(head_mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.45)

	# 2. LUNGE SWING (0.12s): Swift forward strike
	attack_tween.tween_callback(func():
		if head_mesh:
			head_mesh.scale = Vector3.ONE
	)
	attack_tween.tween_property(visuals, "position:z", -0.7, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attack_tween.parallel().tween_property(visuals, "rotation_degrees:x", 25.0, 0.12)

	# Check hit at the moment of the strike
	attack_tween.tween_callback(func():
		if is_dead:
			return
		if target_player and is_instance_valid(target_player):
			var dist := global_position.distance_to(target_player.global_position)
			# Hit succeeds only if player is still in range (hasn't dashed away!)
			if dist <= attack_range + 0.5:
				var forward := -visuals.global_transform.basis.z.normalized()
				var to_player := (target_player.global_position - global_position).normalized()
				if forward.dot(to_player) > 0.1:
					var hurt := target_player.get_node_or_null("Hurtbox3D")
					if hurt and not hurt.is_invulnerable:
						hurt.received_damage.emit(attack_damage, false, self, 7.0)
						if is_elite and elite_affix == AFFIX_VAMPIRIC:
							var heal_amt: float = minf(max_health - health, attack_damage * 0.6)
							if heal_amt > 0.0:
								health += heal_amt
								Global.damage_spawned.emit(global_position + Vector3.UP * 1.8, int(heal_amt), false, false)
								if health_bar and health_bar.has_method("update_health"):
									health_bar.update_health(health, max_health)
	)

	# 3. RECOVERY (0.28s): Reset back to idle stance
	attack_tween.tween_property(visuals, "position:z", 0.0, 0.28)
	attack_tween.parallel().tween_property(visuals, "rotation_degrees:x", 0.0, 0.28)
	attack_tween.tween_callback(func():
		is_attacking = false
	)

func _on_received_damage(amount: float, is_crit: bool, source: Node3D, knockback: float) -> void:
	take_damage(amount, is_crit, source, (global_position - (source.global_position if source else global_position)).normalized() * knockback)

func take_damage(amount: float, is_crit: bool, source: Node3D, knock_velocity: Vector3) -> void:
	if is_dead:
		return

	health -= amount
	Global.damage_spawned.emit(global_position + Vector3.UP * 1.5, int(amount), is_crit, false)
	velocity += knock_velocity

	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(health, max_health)

	# Interrupt attack on heavy hit / crit
	if is_crit and is_attacking:
		if attack_tween and attack_tween.is_valid():
			attack_tween.kill()
		visuals.position.z = 0.0
		visuals.rotation_degrees.x = 0.0
		if head_mesh:
			head_mesh.scale = Vector3.ONE
		is_attacking = false
		attack_timer = 0.6

	# Flash effect
	var tween := create_tween()
	tween.tween_property(body_mesh, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
	tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.08)

	if health <= 0.0:
		_die()

func _die() -> void:
	AudioManager.play_bone_crunch()
	is_dead = true
	is_attacking = false
	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	velocity = Vector3.ZERO
	if hurtbox:
		hurtbox.queue_free()

	if is_elite and elite_affix == AFFIX_MOLTEN:
		_spawn_molten_burst()

	# Drop physical loot drops & XP (Elite grants 65 XP!)
	Global.player_xp_changed.emit(65 if is_elite else 25, 100, Global.player_level)
	_spawn_death_loot()

	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _spawn_molten_burst() -> void:
	var root := get_tree().current_scene
	AudioManager.play_toxic_burst()
	for i in range(4):
		var angle := i * (PI / 2.0)
		var offset := Vector3(cos(angle) * 1.5, 0.0, sin(angle) * 1.5)
		var lava = lava_scene.instantiate()
		root.add_child(lava)
		lava.global_position = global_position + offset

func _spawn_death_loot() -> void:
	var root := get_tree().current_scene
	var loot_scene = preload("res://scenes/items/LootDrop.tscn")
	var drop_origin := global_position + Vector3.UP * 0.3

	if is_elite:
		# Guaranteed elite reward: 4-6 coins, 1 potion, 1 Rare/Epic equipment!
		for i in range(randi_range(4, 6)):
			var coin = loot_scene.instantiate()
			coin.item_type = 0
			coin.amount = randi_range(6, 14)
			root.add_child(coin)
			coin.global_position = drop_origin

		var pot = loot_scene.instantiate()
		pot.item_type = 1
		pot.amount = 1
		pot.item_name = "Зелье Здоровья"
		pot.rarity = 1
		root.add_child(pot)
		pot.global_position = drop_origin

		var gear = loot_scene.instantiate()
		gear.item_type = 2
		gear.rarity = 2 if randf() < 0.4 else 1 # Epic or Rare
		gear.item_name = "★ Клинок Победителя" if gear.rarity == 2 else "◆ Закаленный Палаш"
		root.add_child(gear)
		gear.global_position = drop_origin
		return

	# Standard enemy drops
	# 35% chance to drop 1 Coin (Type 0 = Gold)
	if randf() < 0.35:
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(3, 7)
		root.add_child(coin)
		coin.global_position = drop_origin

	# 5% chance HP potion (Single potion, 1 charge)
	if randf() < 0.05:
		var pot = loot_scene.instantiate()
		pot.item_type = 1
		pot.item_name = "Зелье Здоровья"
		pot.amount = 1
		pot.rarity = 1
		root.add_child(pot)
		pot.global_position = drop_origin

	# 2% chance Weapon drop with beam
	if randf() < 0.02:
		var wpn = loot_scene.instantiate()
		wpn.item_type = 2
		wpn.item_name = "◆ Костяной Меч"
		wpn.rarity = 1
		root.add_child(wpn)
		wpn.global_position = drop_origin

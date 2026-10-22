class_name PlayerController
extends CharacterBody3D

@export_group("Movement")
@export var speed: float = 6.8 # Controlled, grounded ARPG movement
@export var acceleration: float = 35.0
@export var friction: float = 30.0
@export var dash_speed: float = 16.5 # Balanced dodge roll (~3.3m)
@export var dash_duration: float = 0.20
@export var dash_cooldown: float = 0.65

@export_group("Combat")
@export var attack_damage: float = 32.0
@export var attack_range: float = 2.4
@export var attack_cooldown: float = 0.38

@export_group("Stats")
@export var max_health: float = 150.0
@export var health: float = 150.0
@export var max_resource: float = 100.0
@export var resource: float = 100.0
@export var resource_regen_rate: float = 15.0

# State
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cd_timer: float = 0.0
var dash_dir: Vector3 = Vector3.FORWARD

var is_attacking: bool = false
var attack_cd_timer: float = 0.0
var q_cd_timer: float = 0.0
@export var q_cooldown: float = 4.0
var can_act: bool = true
var invuln_timer: float = 0.0
@export var invuln_duration: float = 0.35 # Post-damage i-frames to prevent multiple hits
var iron_skin_timer: float = 0.0

# Shrine buffs: 0 = Frenzy (+100% crit & +25% atk speed), 1 = Protection (+75 armor & +8 hp/s regen)
var active_shrine_type: int = -1
var shrine_buff_timer: float = 0.0

# Town Portal channeling
var is_channeling_portal: bool = false
var portal_channel_timer: float = 0.0
const PORTAL_CHANNEL_DURATION: float = 1.2

# References
const PLAYER_ARROW_SCENE: PackedScene = preload("res://scenes/player/projectiles/PlayerArrow.tscn")
const ARCANE_BOLT_SCENE: PackedScene = preload("res://scenes/player/projectiles/ArcaneBolt.tscn")
const FIREBALL_SCENE: PackedScene = preload("res://scenes/player/projectiles/Fireball.tscn")
const METEOR_STRIKE_SCENE: PackedScene = preload("res://scenes/player/skills/MeteorStrike.tscn")
const POISON_TRAP_SCENE: PackedScene = preload("res://scenes/player/skills/PlayerPoisonTrap.tscn")

# 3D Equipment Models
const WEAPON_SWORD_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponSword.tscn")
const WEAPON_GREATSWORD_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponGreatsword.tscn")
const WEAPON_WARHAMMER_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponWarhammer.tscn")
const WEAPON_GREATHAMMER_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponGreathammer.tscn")
const WEAPON_BOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponBow.tscn")
const WEAPON_COMPOSITE_BOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponCompositeBow.tscn")
const WEAPON_CROSSBOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponCrossbow.tscn")
const WEAPON_HEAVY_CROSSBOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponHeavyCrossbow.tscn")
const WEAPON_STAFF_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponStaff.tscn")
const WEAPON_WAND_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponWand.tscn")
const WEAPON_DAGGER_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponDagger.tscn")
const WEAPON_AXE_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponAxe.tscn")
const SHIELD_BUCKLER_SCENE: PackedScene = preload("res://scenes/player/equipment/ShieldBuckler.tscn")
const SHIELD_TOWER_SCENE: PackedScene = preload("res://scenes/player/equipment/ShieldTower.tscn")

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var weapon_pivot: Node3D = $Visuals/WeaponPivot
@onready var shield_pivot: Node3D = $Visuals/ShieldPivot
@onready var sword_mesh: MeshInstance3D = $Visuals/WeaponPivot.get_node_or_null("SwordMesh")
@onready var slash_arc: MeshInstance3D = $Visuals/SlashArc
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var warrior_gear: Node3D = $Visuals.get_node_or_null("ClassGear/WarriorGear")
@onready var rogue_gear: Node3D = $Visuals.get_node_or_null("ClassGear/RogueGear")
@onready var mage_gear: Node3D = $Visuals.get_node_or_null("ClassGear/MageGear")
@onready var rogue_cowl: MeshInstance3D = $Visuals.get_node_or_null("ClassGear/RogueGear/RogueCowl")
@onready var warrior_pot_helm: MeshInstance3D = $Visuals.get_node_or_null("ClassGear/WarriorGear/PotHelmet")

var current_weapon_model: Node3D = null
var current_shield_model: Node3D = null
var current_displayed_weapon_id: String = ""

var base_armor: float = 15.0
var combat_timer: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D = null
var slash_material: StandardMaterial3D = null

# Input tracking for seamless gamepad & mouse hybrid control
var prev_mouse_pos: Vector2 = Vector2.ZERO
var mouse_active_timer: float = 0.0

func _ready() -> void:
	Global.current_player = self
	Global.class_changed.connect(_on_class_changed)
	Global.player_respawn_requested.connect(_on_player_respawn_requested)
	InventoryManager.equipment_updated.connect(_update_equipment_visuals)

	_apply_class_stats(Global.current_class)
	_update_class_visuals()
	_update_equipment_visuals()
	
	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

	_setup_slash_arc()
	camera = get_viewport().get_camera_3d()

	if not Global.in_town and Global.saved_dungeon_player_pos != Vector3.ZERO:
		global_position = Global.saved_dungeon_player_pos

func _on_class_changed(new_c: String) -> void:
	_apply_class_stats(new_c)
	_update_class_visuals()
	_update_equipment_visuals()

func _apply_class_stats(c_id: String) -> void:
	var info: Dictionary = Global.get_class_info(c_id)
	if info.is_empty():
		return

	var class_base_hp: float = info.get("base_hp", 120.0)
	max_health = class_base_hp + SkillManager.bonus_max_hp + InventoryManager.bonus_max_hp
	health = max_health
	Global.player_health_changed.emit(health, max_health)

	speed = info.get("speed", 6.8)
	base_armor = info.get("armor", 15.0)

	max_resource = info.get("max_resource", 100.0)
	resource = clampf(info.get("start_resource", 100.0), 0.0, max_resource)
	Global.player_resource_changed.emit(resource, max_resource)

func on_equipment_stats_changed() -> void:
	var info: Dictionary = Global.get_class_info(Global.current_class)
	var class_base_hp: float = info.get("base_hp", 120.0) if not info.is_empty() else 120.0
	var prev_max := max_health
	max_health = class_base_hp + SkillManager.bonus_max_hp + InventoryManager.bonus_max_hp
	if max_health > prev_max:
		health += (max_health - prev_max)
	health = clampf(health, 0.0, max_health)
	Global.player_health_changed.emit(health, max_health)

func get_effective_damage() -> float:
	return (attack_damage + InventoryManager.bonus_damage) * SkillManager.attack_damage_mult

func get_effective_armor() -> float:
	var bonus := 75.0 if active_shrine_type == 1 else 0.0
	return base_armor + InventoryManager.bonus_armor + bonus

func get_effective_crit_chance() -> float:
	if active_shrine_type == 0:
		return 1.0 # 100% Critical Strike Chance during Frenzy!
	var class_info := Global.get_class_info(Global.current_class)
	var base_crit: float = class_info.get("crit_chance", 0.05) if not class_info.is_empty() else 0.05
	return base_crit + SkillManager.crit_chance_bonus + InventoryManager.bonus_crit_chance

func apply_shrine_buff(type: int, duration: float) -> void:
	active_shrine_type = type
	shrine_buff_timer = duration
	Global.shrine_buff_changed.emit(active_shrine_type, shrine_buff_timer)

func get_effective_crit_mult() -> float:
	return 1.75 + SkillManager.crit_damage_bonus + InventoryManager.bonus_crit_damage

func get_effective_speed() -> float:
	return speed * (1.0 + InventoryManager.bonus_move_speed)

func _setup_slash_arc() -> void:
	if not slash_arc:
		return

	# Build a clean forward-facing crescent/sector mesh (115 degrees in front)
	slash_arc.mesh = _build_forward_crescent_mesh(0.9, 2.3, 115.0)

	slash_material = StandardMaterial3D.new()
	slash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	slash_material.albedo_color = Color(1.0, 0.95, 0.8, 0.45) # Soft translucent warm white
	slash_material.emission_enabled = true
	slash_material.emission = Color(1.0, 0.85, 0.5)
	slash_material.emission_energy_multiplier = 0.4 # Gentle glow, not blinding
	slash_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	slash_arc.material_override = slash_material
	slash_arc.visible = true
	# Pre-warm GPU pipeline with transparent alpha on first frame
	slash_material.albedo_color.a = 0.001
	await get_tree().process_frame
	if is_instance_valid(slash_arc):
		slash_arc.visible = false

func _build_forward_crescent_mesh(inner_r: float, outer_r: float, angle_deg: float) -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var segments := 20
	var half_angle := deg_to_rad(angle_deg / 2.0)
	var start_angle := -half_angle
	var end_angle := half_angle
	var step := (end_angle - start_angle) / segments

	for i in range(segments + 1):
		var theta := start_angle + i * step
		# Facing -Z (forward in Godot)
		var vx := sin(theta)
		var vz := -cos(theta)

		vertices.append(Vector3(vx * inner_r, 0.0, vz * inner_r))
		uvs.append(Vector2(float(i) / segments, 0.0))

		vertices.append(Vector3(vx * outer_r, 0.0, vz * outer_r))
		uvs.append(Vector2(float(i) / segments, 1.0))

	for i in range(segments):
		var base := i * 2
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)

		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh

func _process(delta: float) -> void:
	_process_class_resources(delta)

func _process_class_resources(delta: float) -> void:
	if combat_timer > 0.0:
		combat_timer -= delta

	var prev_resource := resource
	match Global.current_class:
		Global.CLASS_WARRIOR:
			# Warrior: Fury (starts at 0, decays if not in combat (-5/sec), builds on hit)
			if combat_timer <= 0.0 and resource > 0.0:
				resource = maxf(0.0, resource - 5.0 * delta)
		Global.CLASS_ROGUE:
			# Rogue: Energy (max 100, rapidly regens +20/sec)
			if resource < max_resource:
				resource = minf(max_resource, resource + 20.0 * delta)
		Global.CLASS_MAGE:
			# Mage: Mana (max 150, regens +6/sec)
			if resource < max_resource:
				resource = minf(max_resource, resource + 6.0 * delta)
		_:
			if resource < max_resource:
				resource = minf(max_resource, resource + resource_regen_rate * delta)

	if not is_equal_approx(prev_resource, resource):
		Global.player_resource_changed.emit(resource, max_resource)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Passive HP regeneration from Paladin tree
	if SkillManager.hp_regen_per_sec > 0.0 and health < max_health:
		health = minf(max_health, health + SkillManager.hp_regen_per_sec * delta)
		Global.player_health_changed.emit(health, max_health)

	# Protection Shrine Regen (+8 HP/s)
	if active_shrine_type == 1 and health < max_health:
		health = minf(max_health, health + 8.0 * delta)
		Global.player_health_changed.emit(health, max_health)

	if shrine_buff_timer > 0.0:
		shrine_buff_timer -= delta
		Global.shrine_buff_changed.emit(active_shrine_type, shrine_buff_timer)
		if shrine_buff_timer <= 0.0:
			active_shrine_type = -1
			Global.shrine_buff_changed.emit(-1, 0.0)

	if dash_cd_timer > 0.0:
		dash_cd_timer -= delta
	if attack_cd_timer > 0.0:
		attack_cd_timer -= delta
	if q_cd_timer > 0.0:
		q_cd_timer -= delta
	if invuln_timer > 0.0:
		invuln_timer -= delta
	if iron_skin_timer > 0.0:
		iron_skin_timer -= delta
	if mouse_active_timer > 0.0:
		mouse_active_timer -= delta

	if is_channeling_portal:
		var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move_input != Vector2.ZERO or is_attacking or is_dashing:
			is_channeling_portal = false
		else:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			portal_channel_timer -= delta
			if portal_channel_timer <= 0.0:
				_complete_town_portal()
			move_and_slide()
			return

	if is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)
		_process_aim()
		_handle_actions()

	move_and_slide()

func _process_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	var effective_speed := speed * (1.0 + InventoryManager.bonus_move_speed)
	var current_speed := effective_speed * (0.6 if is_attacking else 1.0)

	if move_dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_dir.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

func _process_aim() -> void:
	# 1. Gamepad Right Stick Aiming (Twin-stick shooter style)
	var joy_rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var joy_ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var joy_aim := Vector2(joy_rx, joy_ry)
	if joy_aim.length() > 0.3:
		var aim_target := visuals.global_position + Vector3(joy_aim.x, 0.0, joy_aim.y)
		visuals.look_at(aim_target, Vector3.UP)
		return

	# 2. Check mouse movement to toggle mouse aiming mode
	var current_mouse := get_viewport().get_mouse_position()
	if current_mouse.distance_squared_to(prev_mouse_pos) > 4.0:
		prev_mouse_pos = current_mouse
		mouse_active_timer = 2.5 # prioritize mouse for 2.5s after cursor moves

	# 3. If moving with stick or WASD and mouse is idle, face movement direction
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if mouse_active_timer <= 0.0 and move_input != Vector2.ZERO and not is_attacking:
		var move_look := visuals.global_position + Vector3(move_input.x, 0.0, move_input.y)
		visuals.look_at(move_look, Vector3.UP)
		return

	# 4. Standard mouse cursor raycast onto player's horizontal plane
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return

	var ray_origin := camera.project_ray_origin(current_mouse)
	var ray_dir := camera.project_ray_normal(current_mouse)

	var plane := Plane(Vector3.UP, global_position.y)
	var intersect = plane.intersects_ray(ray_origin, ray_dir)

	if intersect:
		var target_pos: Vector3 = intersect
		var look_target := Vector3(target_pos.x, visuals.global_position.y, target_pos.z)
		if look_target.distance_squared_to(visuals.global_position) > 0.05:
			visuals.look_at(look_target, Vector3.UP)

func get_aim_target_position() -> Vector3:
	var cam := camera if camera else get_viewport().get_camera_3d()
	if cam:
		var current_mouse := get_viewport().get_mouse_position()
		var ray_origin := cam.project_ray_origin(current_mouse)
		var ray_dir := cam.project_ray_normal(current_mouse)
		var plane := Plane(Vector3.UP, global_position.y)
		var intersect = plane.intersects_ray(ray_origin, ray_dir)
		if intersect:
			return intersect
	return global_position - visuals.global_transform.basis.z * 5.0

func get_aim_direction() -> Vector3:
	var target := get_aim_target_position()
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		return dir.normalized()
	return -visuals.global_transform.basis.z.normalized()

func _handle_actions() -> void:
	if not can_act:
		return

	if Input.is_action_just_pressed("dash") and dash_cd_timer <= 0.0:
		_start_dash()
		return

	if Input.is_action_just_pressed("attack_primary") and attack_cd_timer <= 0.0 and not is_attacking:
		_perform_primary_attack()
		return

	# Skill [Q] (Unlocked via Skill Tree)
	if Input.is_action_just_pressed("skill_1") and q_cd_timer <= 0.0 and not is_attacking:
		_handle_q_skill_input()
		return

	if Input.is_action_just_pressed("skill_ultimate") and not is_attacking:
		_handle_ultimate_skill_input()
		return

	# Town Portal [T]
	if (Input.is_action_just_pressed("town_portal") or Input.is_key_pressed(KEY_T)) and not is_attacking and not is_dashing:
		if not Global.in_town and not is_channeling_portal:
			_start_town_portal_channeling()

func _start_town_portal_channeling() -> void:
	is_channeling_portal = true
	portal_channel_timer = PORTAL_CHANNEL_DURATION
	AudioManager.play_portal_spawn()

func _complete_town_portal() -> void:
	is_channeling_portal = false
	AudioManager.play_portal_enter()
	Global.saved_dungeon_floor = Global.current_floor
	Global.saved_dungeon_player_pos = global_position
	Global.town_portal_active = true
	SceneTransition.change_scene_to_file(
		"res://scenes/world/TownCamp.tscn",
		"ВОЗВРАЩЕНИЕ В ДЕРЕВНЮ",
		"Лагерь Охотников — Безопасная зона"
	)

func _start_dash() -> void:
	AudioManager.play_dash()
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		dash_dir = Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	else:
		dash_dir = -visuals.global_transform.basis.z

	is_dashing = true
	dash_timer = dash_duration
	dash_cd_timer = dash_cooldown
	if hurtbox:
		hurtbox.is_invulnerable = true

	velocity.x = dash_dir.x * dash_speed
	velocity.z = dash_dir.z * dash_speed

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.x = dash_dir.x * dash_speed
	velocity.z = dash_dir.z * dash_speed

	if dash_timer <= 0.0:
		is_dashing = false
		if hurtbox:
			hurtbox.is_invulnerable = false

func _handle_q_skill_input() -> void:
	var q_id := SkillManager.active_q_skill
	# Warrior skills
	if q_id == "holy_hammer" and resource >= 25.0:
		_cast_holy_hammer()
	elif q_id == "whirlwind" and resource >= 30.0:
		_cast_whirlwind()
	elif q_id == "thunder_slam" and resource >= 30.0:
		_cast_thunder_slam()
	elif q_id == "iron_skin" and resource >= 20.0:
		_cast_iron_skin()
	# Rogue skills
	elif q_id == "rain_of_arrows" and resource >= 25.0:
		_cast_rain_of_arrows()
	elif q_id == "shadowstep" and resource >= 20.0:
		_cast_shadowstep()
	elif q_id == "poison_trap" and resource >= 25.0:
		_cast_poison_trap()
	elif q_id == "hunters_focus" and resource >= 20.0:
		_cast_hunters_focus()
	# Mage skills
	elif q_id == "fireball" and resource >= 25.0:
		_cast_fireball()
	elif (q_id == "arcane_blink" or q_id == "arcane_teleport") and resource >= 20.0:
		_cast_arcane_teleport()
	elif (q_id == "chain_lightning" or q_id == "meteor_strike") and resource >= 25.0:
		_cast_chain_lightning()
	elif q_id == "frost_nova" and resource >= 25.0:
		_cast_frost_nova()

func _handle_ultimate_skill_input() -> void:
	if resource < 50.0:
		return
	match Global.current_class:
		Global.CLASS_ROGUE:
			_perform_blade_storm()
		Global.CLASS_MAGE:
			_perform_arcane_cataclysm()
		_:
			_perform_earthquake()

func _perform_primary_attack() -> void:
	var weapon_item = InventoryManager.equipment.get("weapon")
	var weapon: Dictionary = weapon_item if (weapon_item != null and weapon_item is Dictionary) else {}
	var subtype: String = weapon.get("subtype", "")

	if subtype == "bow":
		_perform_rogue_shot()
	elif subtype == "staff" or subtype == "wand":
		_perform_mage_bolt()
	elif subtype != "":
		_perform_warrior_slash()
	else:
		match Global.current_class:
			Global.CLASS_ROGUE:
				_perform_rogue_shot()
			Global.CLASS_MAGE:
				_perform_mage_bolt()
			_:
				_perform_warrior_slash()

func _perform_warrior_slash() -> void:
	is_attacking = true
	var aim_dir := get_aim_direction()
	var look_pos := global_position + aim_dir * 5.0
	look_pos.y = visuals.global_position.y
	visuals.look_at(look_pos, Vector3.UP)

	var speed_mult: float = SkillManager.attack_speed_mult * InventoryManager.equipment_attack_speed_mult
	var cd: float = (attack_cooldown / speed_mult) * (0.75 if active_shrine_type == 0 else 1.0)
	attack_cd_timer = maxf(0.12, cd)
	combat_timer = 4.0

	var tween := create_tween()
	
	# 1. Wind-up
	tween.tween_property(weapon_pivot, "rotation_degrees:y", -75.0, 0.06)
	
	# 2. Forward slash + show soft crescent slash arc
	tween.tween_callback(func():
		AudioManager.play_slash()
		if slash_arc and slash_material:
			slash_arc.visible = true
			slash_arc.scale = Vector3(0.7, 1.0, 0.7)
			slash_material.albedo_color.a = 0.45
			var arc_tween := create_tween()
			arc_tween.parallel().tween_property(slash_arc, "scale", Vector3(1.05, 1.0, 1.05), 0.13)
			arc_tween.parallel().tween_property(slash_material, "albedo_color:a", 0.0, 0.13)
			arc_tween.tween_callback(func(): slash_arc.visible = false)
	)
	
	tween.tween_property(weapon_pivot, "rotation_degrees:y", 95.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Hit detection at mid-swing
	tween.tween_callback(_damage_enemies_in_arc)
	
	# 3. Recovery
	tween.tween_property(weapon_pivot, "rotation_degrees:y", 0.0, 0.14)
	tween.tween_callback(func():
		is_attacking = false
	)

func _perform_rogue_shot() -> void:
	if resource >= 8.0:
		resource -= 8.0
		Global.player_resource_changed.emit(resource, max_resource)
	combat_timer = 4.0

	var aim_dir := get_aim_direction()
	var look_pos := global_position + aim_dir * 5.0
	look_pos.y = visuals.global_position.y
	visuals.look_at(look_pos, Vector3.UP)

	var speed_mult: float = SkillManager.attack_speed_mult * InventoryManager.equipment_attack_speed_mult
	var cd: float = (0.28 / speed_mult) * (0.75 if active_shrine_type == 0 else 1.0)
	attack_cd_timer = maxf(0.12, cd)
	is_attacking = true

	AudioManager.play_bow_shot()

	var spawn_pos := global_position + Vector3.UP * 0.85 + aim_dir * 0.65

	var arrow = PLAYER_ARROW_SCENE.instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = spawn_pos
	arrow.setup(aim_dir, self, get_effective_damage(), get_effective_crit_chance(), get_effective_crit_mult())

	# Quick weapon recoil
	var tween := create_tween()
	tween.tween_property(weapon_pivot, "position:z", 0.2, 0.07).as_relative()
	tween.tween_property(weapon_pivot, "position:z", -0.2, 0.11).as_relative()
	tween.tween_callback(func():
		is_attacking = false
	)

func _perform_mage_bolt() -> void:
	# Basic attack (LMB) is free and never blocked by low mana
	combat_timer = 4.0

	var aim_dir := get_aim_direction()
	var look_pos := global_position + aim_dir * 5.0
	look_pos.y = visuals.global_position.y
	visuals.look_at(look_pos, Vector3.UP)

	var speed_mult: float = SkillManager.attack_speed_mult * InventoryManager.equipment_attack_speed_mult
	var cd: float = (0.35 / speed_mult) * (0.75 if active_shrine_type == 0 else 1.0)
	attack_cd_timer = maxf(0.12, cd)
	is_attacking = true

	if AudioManager.has_method("play_arcane_bolt"):
		AudioManager.play_arcane_bolt()

	var spawn_pos := global_position + Vector3.UP * 0.9 + aim_dir * 0.75

	var bolt = ARCANE_BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = spawn_pos
	bolt.setup(aim_dir, self, get_effective_damage() * 1.15, get_effective_crit_chance(), get_effective_crit_mult())

	# Quick cast gesture
	var tween := create_tween()
	tween.tween_property(weapon_pivot, "position:z", -0.25, 0.08).as_relative()
	tween.tween_property(weapon_pivot, "position:z", 0.25, 0.14).as_relative()
	tween.tween_callback(func():
		is_attacking = false
	)

func _damage_enemies_in_arc() -> void:
	var forward := -visuals.global_transform.basis.z.normalized()
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = attack_range
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.8)
	query.collision_mask = 1 << 2

	var results := space.intersect_shape(query, 16)
	var hit_any: bool = false

	for r in results:
		var enemy: Node3D = r.collider as Node3D
		if enemy and enemy.has_method("take_damage"):
			var to_enemy: Vector3 = (enemy.global_position - global_position).normalized()
			var dot: float = forward.dot(to_enemy)
			# Dot >= 0.25 covers roughly the 120-degree forward crescent
			if dot >= 0.25:
				var crit_rate: float = 0.20 + SkillManager.crit_chance_bonus + InventoryManager.bonus_crit_chance
				var is_crit: bool = randf() < crit_rate
				var crit_mult: float = 1.75 + SkillManager.crit_damage_bonus + InventoryManager.bonus_crit_damage
				var base_dmg: float = (attack_damage + InventoryManager.bonus_damage) * SkillManager.attack_damage_mult
				var dmg: float = base_dmg * (crit_mult if is_crit else 1.0)
				var knock_dir: Vector3 = (to_enemy + Vector3.UP * 0.15).normalized()
				enemy.take_damage(dmg, is_crit, self, knock_dir * 12.0)
				if is_crit:
					AudioManager.play_crit()
				else:
					AudioManager.play_hit()
				hit_any = true

				# Life steal from Berserker tree
				if SkillManager.lifesteal_percent > 0.0:
					var leech: float = dmg * SkillManager.lifesteal_percent
					health = minf(max_health, health + leech)
					Global.player_health_changed.emit(health, max_health)

	if hit_any:
		combat_timer = 4.0
		if Global.current_class == Global.CLASS_WARRIOR:
			resource = minf(max_resource, resource + 8.0)
			Global.player_resource_changed.emit(resource, max_resource)
		if camera and camera.has_method("shake"):
			camera.shake(0.12, 0.1)

func _cast_holy_hammer() -> void:
	AudioManager.play_hammer()
	resource -= 25.0
	q_cd_timer = q_cooldown
	Global.player_resource_changed.emit(resource, max_resource)

	var hammer_scene = preload("res://scenes/skills/HolyHammer.tscn")
	var hammer = hammer_scene.instantiate()
	get_tree().current_scene.add_child(hammer)

	if camera and camera.has_method("shake"):
		camera.shake(0.18, 0.12)

func _cast_whirlwind() -> void:
	resource -= 30.0
	q_cd_timer = 3.5
	is_attacking = true
	Global.player_resource_changed.emit(resource, max_resource)

	# High-speed spinning 360-degree attack
	var spins := 3
	var spin_duration := 0.9
	var tween := create_tween()
	tween.tween_property(visuals, "rotation_degrees:y", visuals.rotation_degrees.y + 360.0 * spins, spin_duration).set_trans(Tween.TRANS_LINEAR)

	for i in range(spins):
		tween.tween_callback(_damage_enemies_in_circle)
		tween.tween_interval(spin_duration / spins)

	tween.tween_callback(func(): is_attacking = false)

func _damage_enemies_in_circle() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 1 << 2

	var results := space.intersect_shape(query, 16)
	for r in results:
		var enemy: Node3D = r.collider as Node3D
		if enemy and enemy.has_method("take_damage"):
			var dmg: float = attack_damage * 0.8
			var knock: Vector3 = (enemy.global_position - global_position).normalized() * 8.0
			enemy.take_damage(dmg, false, self, knock)

			if SkillManager.lifesteal_percent > 0.0:
				var leech: float = dmg * SkillManager.lifesteal_percent
				health = minf(max_health, health + leech)
				Global.player_health_changed.emit(health, max_health)

	if camera and camera.has_method("shake"):
		camera.shake(0.1, 0.08)

func _cast_thunder_slam() -> void:
	resource -= 30.0
	q_cd_timer = 3.5
	is_attacking = true
	Global.player_resource_changed.emit(resource, max_resource)

	var tween := create_tween()
	tween.tween_property(visuals, "position:y", 1.0, 0.15)
	tween.tween_property(visuals, "position:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		var slam_rank: int = SkillManager.get_skill_rank("thunder_slam")
		var radius: float = 4.5 + (1.0 if SkillManager.get_skill_rank("shockwave") > 0 else 0.0)
		var base_dmg: float = 40.0 + (12.0 * slam_rank)

		var space := get_world_3d().direct_space_state
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		query.shape = sphere
		query.transform = global_transform
		query.collision_mask = 1 << 2

		if camera and camera.has_method("shake"):
			camera.shake(0.35, 0.2)
		AudioManager.play_slam()

		var results := space.intersect_shape(query, 24)
		for r in results:
			var enemy: Node3D = r.collider as Node3D
			if enemy and enemy.has_method("take_damage"):
				var knock_dir: Vector3 = (enemy.global_position - global_position).normalized()
				knock_dir.y = 0.25
				enemy.take_damage(base_dmg, true, self, knock_dir * 16.0)

		is_attacking = false
	)

func _cast_iron_skin() -> void:
	resource -= 20.0
	q_cd_timer = 5.0
	iron_skin_timer = 4.0
	Global.player_resource_changed.emit(resource, max_resource)

	if camera and camera.has_method("shake"):
		camera.shake(0.15, 0.1)

	# Pulse visuals gold
	if body_mesh:
		var tween := create_tween()
		tween.tween_property(body_mesh, "scale", Vector3(1.25, 1.25, 1.25), 0.15)
		tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.15)

func _perform_earthquake() -> void:
	resource -= 50.0
	Global.player_resource_changed.emit(resource, max_resource)
	can_act = false

	var tween := create_tween()
	tween.tween_property(visuals, "position:y", 1.2, 0.2)
	tween.tween_property(visuals, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_callback(func():
		_spawn_shockwave()
		can_act = true
	)

func _spawn_shockwave() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 6.0
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 1 << 2

	if camera and camera.has_method("shake"):
		camera.shake(0.4, 0.3)
	AudioManager.play_slam()

	var results := space.intersect_shape(query, 32)
	for r in results:
		var collider: Node3D = r.collider as Node3D
		if collider and collider.has_method("take_damage"):
			var knock_dir: Vector3 = (collider.global_position - global_position).normalized()
			knock_dir.y = 0.3
			collider.take_damage(65.0, true, self, knock_dir * 18.0)

# --- Rogue Skills ---
func _cast_rain_of_arrows() -> void:
	resource -= 25.0
	q_cd_timer = 4.0
	is_attacking = true
	Global.player_resource_changed.emit(resource, max_resource)

	var target_pos := get_aim_target_position()
	var aim_dir := get_aim_direction()
	var look_pos := global_position + aim_dir * 5.0
	look_pos.y = visuals.global_position.y
	visuals.look_at(look_pos, Vector3.UP)

	AudioManager.play_bow_shot()
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 0.15)

	# Shoot up volley animation
	var tween := create_tween()
	tween.tween_property(weapon_pivot, "rotation_degrees:x", -45.0, 0.12)
	tween.tween_property(weapon_pivot, "rotation_degrees:x", 0.0, 0.15)
	tween.tween_callback(func():
		is_attacking = false
	)

	# Rain down arrows in targeted zone
	var rank: int = SkillManager.get_skill_rank("rain_of_arrows")
	var arrow_count: int = 8 + (rank * 2) + (SkillManager.get_skill_rank("arrow_barrage") * 3)
	var base_dmg: float = get_effective_damage() * (0.8 + 0.15 * rank)
	var radius: float = 4.5

	for i in range(arrow_count):
		get_tree().create_timer(i * 0.04).timeout.connect(func():
			if not is_inside_tree():
				return
			var offset := Vector3(randf_range(-radius, radius), 0.0, randf_range(-radius, radius))
			if offset.length() > radius:
				offset = offset.normalized() * randf_range(0.0, radius)
			var land_pos := target_pos + offset
			var sky_pos := land_pos + Vector3(0.0, 9.0, 0.0)

			var arrow = PLAYER_ARROW_SCENE.instantiate()
			get_tree().current_scene.add_child(arrow)
			arrow.global_position = sky_pos
			arrow.setup(Vector3.DOWN, self, base_dmg, get_effective_crit_chance(), get_effective_crit_mult())
		)

func _cast_shadowstep() -> void:
	resource -= 20.0
	q_cd_timer = 3.5
	Global.player_resource_changed.emit(resource, max_resource)

	var target := get_aim_target_position()
	var to_target := target - global_position
	to_target.y = 0.0
	var dist := minf(to_target.length(), 8.0)
	var dest := global_position + to_target.normalized() * dist

	AudioManager.play_dash()
	if camera and camera.has_method("shake"):
		camera.shake(0.15, 0.1)

	# Blink to location
	global_position = dest

func _cast_poison_trap() -> void:
	resource -= 25.0
	q_cd_timer = 4.5
	Global.player_resource_changed.emit(resource, max_resource)

	var rank: int = SkillManager.get_skill_rank("poison_trap")
	var trap_dmg: float = 24.0 + (10.0 * rank)

	var trap = POISON_TRAP_SCENE.instantiate()
	get_tree().current_scene.add_child(trap)
	trap.global_position = global_position
	trap.setup(self, trap_dmg)

func _cast_hunters_focus() -> void:
	resource -= 20.0
	q_cd_timer = 6.0
	dash_cd_timer = 0.0
	Global.player_resource_changed.emit(resource, max_resource)

	if camera and camera.has_method("shake"):
		camera.shake(0.12, 0.1)

	# Flash hunter glow
	if body_mesh:
		var tween := create_tween()
		tween.tween_property(body_mesh, "scale", Vector3(1.15, 1.15, 1.15), 0.12)
		tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)

func _perform_blade_storm() -> void:
	resource -= 50.0
	Global.player_resource_changed.emit(resource, max_resource)
	can_act = false

	if camera and camera.has_method("shake"):
		camera.shake(0.35, 0.25)
	AudioManager.play_slash()

	var spins := 12
	for i in range(spins):
		get_tree().create_timer(i * 0.03).timeout.connect(func():
			if not is_inside_tree():
				return
			var angle := (float(i) / float(spins)) * TAU
			var dir := Vector3(cos(angle), 0.0, sin(angle))
			var arrow = PLAYER_ARROW_SCENE.instantiate()
			get_tree().current_scene.add_child(arrow)
			arrow.global_position = global_position + Vector3.UP * 0.85 + dir * 0.5
			arrow.setup(dir, self, get_effective_damage() * 1.5, 0.5, 2.0)
		)

	var tween := create_tween()
	tween.tween_property(visuals, "rotation_degrees:y", visuals.rotation_degrees.y + 720.0, 0.4)
	tween.tween_callback(func():
		can_act = true
	)

# --- Mage Skills ---
func _cast_fireball() -> void:
	resource -= 25.0
	q_cd_timer = 3.2
	is_attacking = true
	Global.player_resource_changed.emit(resource, max_resource)

	var aim_dir := get_aim_direction()
	var look_pos := global_position + aim_dir * 5.0
	look_pos.y = visuals.global_position.y
	visuals.look_at(look_pos, Vector3.UP)

	var rank: int = SkillManager.get_skill_rank("fireball")
	var dmg: float = get_effective_damage() * (1.6 + 0.3 * rank)

	var spawn_pos := global_position + Vector3.UP * 0.9 + aim_dir * 0.85
	var fb = FIREBALL_SCENE.instantiate()
	get_tree().current_scene.add_child(fb)
	fb.global_position = spawn_pos
	fb.setup(aim_dir, self, dmg, get_effective_crit_chance() + 0.1, get_effective_crit_mult())

	var tween := create_tween()
	tween.tween_property(weapon_pivot, "position:z", -0.2, 0.08).as_relative()
	tween.tween_property(weapon_pivot, "position:z", 0.2, 0.12).as_relative()
	tween.tween_callback(func():
		is_attacking = false
	)

func _cast_arcane_teleport() -> void:
	resource -= 20.0
	q_cd_timer = 3.5
	Global.player_resource_changed.emit(resource, max_resource)

	var target := get_aim_target_position()
	var to_target := target - global_position
	to_target.y = 0.0
	var dist := minf(to_target.length(), 9.0)
	var dest := global_position + to_target.normalized() * dist

	AudioManager.play_dash()
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 0.15)

	global_position = dest

func _cast_meteor_strike() -> void:
	resource -= 35.0
	q_cd_timer = 5.0
	Global.player_resource_changed.emit(resource, max_resource)

	var target_pos := get_aim_target_position()
	var rank: int = SkillManager.get_skill_rank("meteor_strike")
	var dmg: float = get_effective_damage() * (2.2 + 0.4 * rank)

	var meteor = METEOR_STRIKE_SCENE.instantiate()
	get_tree().current_scene.add_child(meteor)
	meteor.setup(target_pos, self, dmg, get_effective_crit_chance() + 0.15, get_effective_crit_mult() + 0.3)

func _cast_frost_nova() -> void:
	resource -= 25.0
	q_cd_timer = 4.0
	Global.player_resource_changed.emit(resource, max_resource)

	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.2)
	AudioManager.play_slam()

	var rank: int = SkillManager.get_skill_rank("frost_nova")
	var radius: float = 5.2 + (0.5 * rank)
	var dmg: float = get_effective_damage() * (1.1 + 0.2 * rank)

	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 1 << 2

	var results := space.intersect_shape(query, 24)
	for r in results:
		var enemy: Node3D = r.collider as Node3D
		if enemy and enemy.has_method("take_damage"):
			var knock := (enemy.global_position - global_position).normalized() * 6.0
			enemy.take_damage(dmg, true, self, knock)

func _cast_chain_lightning() -> void:
	resource -= 25.0
	q_cd_timer = 3.8
	Global.player_resource_changed.emit(resource, max_resource)

	var aim_dir := get_aim_direction()
	var look_pos := global_position + aim_dir * 5.0
	look_pos.y = visuals.global_position.y
	visuals.look_at(look_pos, Vector3.UP)

	AudioManager.play_hit()
	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.15)

	var rank: int = SkillManager.get_skill_rank("chain_lightning")
	var max_targets: int = 4 + (2 if SkillManager.get_skill_rank("thunderstorm") > 0 else 0)
	var base_dmg: float = get_effective_damage() * (1.3 + 0.25 * rank)

	# Find initial target near mouse or aim
	var target_pos := get_aim_target_position()
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 8.0
	query.shape = sphere
	query.transform = Transform3D(Basis(), target_pos)
	query.collision_mask = 1 << 2

	var hits := space.intersect_shape(query, 16)
	var targets: Array[Node3D] = []

	# Sort hits by proximity to target_pos
	var enemy_candidates: Array[Node3D] = []
	for r in hits:
		var enemy: Node3D = r.collider as Node3D
		if enemy and enemy.has_method("take_damage") and enemy != self:
			enemy_candidates.append(enemy)

	enemy_candidates.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(target_pos) < b.global_position.distance_squared_to(target_pos)
	)

	var chained_count := 0
	for enemy in enemy_candidates:
		if chained_count >= max_targets:
			break
		targets.append(enemy)
		chained_count += 1

	# Sequentially strike targets with chained electric shock
	for i in range(targets.size()):
		var target_enemy := targets[i]
		get_tree().create_timer(i * 0.08).timeout.connect(func():
			if is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
				var dmg_mult: float = 1.0 + (i * 0.2 if SkillManager.get_skill_rank("high_voltage") > 0 else 0.0)
				var is_crit: bool = randf() < get_effective_crit_chance()
				var final_dmg: float = base_dmg * dmg_mult * (get_effective_crit_mult() if is_crit else 1.0)
				var knock := (target_enemy.global_position - global_position).normalized() * 8.0
				target_enemy.take_damage(final_dmg, is_crit, self, knock)
				if is_crit:
					AudioManager.play_crit()
				else:
					AudioManager.play_hit()
		)

func _perform_arcane_cataclysm() -> void:
	resource -= 50.0
	Global.player_resource_changed.emit(resource, max_resource)
	can_act = false

	var target_pos := get_aim_target_position()
	if camera and camera.has_method("shake"):
		camera.shake(0.45, 0.35)

	for i in range(3):
		get_tree().create_timer(i * 0.18).timeout.connect(func():
			if not is_inside_tree():
				return
			var offset := Vector3(randf_range(-3.5, 3.5), 0.0, randf_range(-3.5, 3.5))
			var meteor = METEOR_STRIKE_SCENE.instantiate()
			get_tree().current_scene.add_child(meteor)
			meteor.setup(target_pos + offset, self, get_effective_damage() * 2.8, 0.4, 2.2)
		)

	get_tree().create_timer(0.6).timeout.connect(func():
		can_act = true
	)

func _on_received_damage(amount: float, is_crit: bool, source: Node3D, knockback: float) -> void:
	if invuln_timer > 0.0 or is_dashing:
		return

	is_channeling_portal = false

	# If iron skin unbreakable upgrade is active during first 1.2s, ignore damage
	if iron_skin_timer > 2.8 and SkillManager.get_skill_rank("unbreakable") > 0:
		return

	# If iron skin active, reduce damage
	var final_amount: float = amount
	if iron_skin_timer > 0.0:
		var iron_rank: int = SkillManager.get_skill_rank("iron_skin")
		var reduction: float = 0.40 + (0.08 * iron_rank)
		final_amount = maxf(1.0, amount * (1.0 - reduction))

	# Equipment & Shrine Armor damage reduction: damage * (100 / (100 + armor))
	var armor: float = get_effective_armor()
	if armor > 0.0:
		var armor_mult: float = 100.0 / (100.0 + armor)
		final_amount = maxf(1.0, final_amount * armor_mult)

	invuln_timer = invuln_duration
	combat_timer = 4.0
	health = max(0.0, health - final_amount)
	Global.player_health_changed.emit(health, max_health)
	Global.damage_spawned.emit(global_position + Vector3.UP * 1.8, int(final_amount), is_crit, true)

	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.15)

	# Flash player body red
	if body_mesh:
		var tween := create_tween()
		tween.tween_property(body_mesh, "scale", Vector3(1.2, 0.85, 1.2), 0.08)
		tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.08)

	# Thorns / Retribution aura from Paladin tree
	if SkillManager.thorn_damage_percent > 0.0 and source and source.has_method("take_damage"):
		source.take_damage(amount * SkillManager.thorn_damage_percent, false, self, Vector3.ZERO)

	if source:
		var knock_dir := (global_position - source.global_position).normalized()
		velocity += knock_dir * knockback

	if health <= 0.0:
		_die()

var is_dead: bool = false

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	can_act = false
	velocity = Vector3.ZERO
	if hurtbox:
		hurtbox.is_invulnerable = true

	# Gothic death fall: tilt player backward onto the ground
	if visuals:
		var death_tween := create_tween()
		death_tween.tween_property(visuals, "rotation_degrees:x", 85.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.parallel().tween_property(visuals, "position:y", -0.3, 0.45)

	Global.notify_player_death()

func _on_player_respawn_requested() -> void:
	is_dead = false
	can_act = true
	health = max_health
	var class_info := Global.get_class_info(Global.current_class)
	resource = clampf(class_info.get("start_resource", 100.0), 0.0, max_resource)
	if hurtbox:
		hurtbox.is_invulnerable = false
	if visuals:
		visuals.rotation_degrees.x = 0.0
		visuals.position.y = 0.0
	Global.player_health_changed.emit(health, max_health)
	Global.player_resource_changed.emit(resource, max_resource)

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	Global.player_health_changed.emit(health, max_health)

func _update_class_visuals() -> void:
	if not body_mesh or not head_mesh:
		return

	var body_mat := StandardMaterial3D.new()
	var head_mat := StandardMaterial3D.new()

	match Global.current_class:
		Global.CLASS_WARRIOR:
			# Warrior: Iron/steel plate armor & golden helmet
			body_mat.albedo_color = Color(0.24, 0.28, 0.36, 1.0)
			body_mat.metallic = 0.88
			body_mat.roughness = 0.28

			head_mat.albedo_color = Color(0.92, 0.75, 0.22, 1.0)
			head_mat.metallic = 0.90
			head_mat.roughness = 0.20
			head_mat.emission_enabled = true
			head_mat.emission = Color(0.85, 0.65, 0.15)
			head_mat.emission_energy_multiplier = 0.4

		Global.CLASS_ROGUE:
			# Rogue: Dark studded leather armor & forest green hooded cowl
			body_mat.albedo_color = Color(0.20, 0.15, 0.11, 1.0)
			body_mat.metallic = 0.10
			body_mat.roughness = 0.82

			head_mat.albedo_color = Color(0.12, 0.34, 0.18, 1.0)
			head_mat.metallic = 0.05
			head_mat.roughness = 0.78
			head_mat.emission_enabled = false

		Global.CLASS_MAGE:
			# Mage: Mystic deep violet robe & arcane azure hood/orb
			body_mat.albedo_color = Color(0.22, 0.12, 0.38, 1.0)
			body_mat.metallic = 0.15
			body_mat.roughness = 0.55
			body_mat.rim_enabled = true
			body_mat.rim = 0.45
			body_mat.rim_tint = 0.7

			head_mat.albedo_color = Color(0.28, 0.48, 0.96, 1.0)
			head_mat.metallic = 0.25
			head_mat.roughness = 0.20
			head_mat.emission_enabled = true
			head_mat.emission = Color(0.35, 0.65, 1.0, 1.0)
			head_mat.emission_energy_multiplier = 1.2

	body_mesh.material_override = body_mat
	head_mesh.material_override = head_mat

	# Toggle class-specific 3D gear sets
	if warrior_gear:
		warrior_gear.visible = (Global.current_class == Global.CLASS_WARRIOR)
	if rogue_gear:
		rogue_gear.visible = (Global.current_class == Global.CLASS_ROGUE)
	if mage_gear:
		mage_gear.visible = (Global.current_class == Global.CLASS_MAGE)

	# Dynamic helmet logic: if helm equipped, hide default cowl/pot helm
	var has_helm: bool = (InventoryManager.equipment.get("helm") != null)
	if rogue_cowl:
		rogue_cowl.visible = not has_helm
	if warrior_pot_helm:
		warrior_pot_helm.visible = not has_helm

func _update_equipment_visuals() -> void:
	if not weapon_pivot:
		return
	if sword_mesh:
		sword_mesh.visible = false

	# 1. Update Weapon Model in right hand
	var weapon_item = InventoryManager.equipment.get("weapon")
	var weapon: Dictionary = weapon_item if (weapon_item != null and weapon_item is Dictionary) else {}
	var weapon_id: String = weapon.get("id", "")
	var subtype: String = weapon.get("subtype", "")

	if weapon_id == "":
		match Global.current_class:
			Global.CLASS_ROGUE:
				subtype = "bow"
			Global.CLASS_MAGE:
				subtype = "staff"
			_:
				subtype = "sword"

	var needed_weapon_type := subtype
	var weapon_cache_key := weapon_id + "_" + needed_weapon_type
	if current_displayed_weapon_id != weapon_cache_key:
		current_displayed_weapon_id = weapon_cache_key
		if current_weapon_model and is_instance_valid(current_weapon_model):
			current_weapon_model.queue_free()
			current_weapon_model = null

		var target_scene: PackedScene = null
		if weapon_id.begins_with("wpn_greathammer") or subtype == "greathammer":
			target_scene = WEAPON_GREATHAMMER_SCENE
		elif weapon_id.begins_with("wpn_warhammer") or subtype == "hammer":
			target_scene = WEAPON_WARHAMMER_SCENE
		elif weapon_id.begins_with("wpn_greatsword") or subtype == "greatsword":
			target_scene = WEAPON_GREATSWORD_SCENE
		elif weapon_id.begins_with("wpn_heavy_crossbow") or subtype == "heavy_crossbow":
			target_scene = WEAPON_HEAVY_CROSSBOW_SCENE
		elif weapon_id.begins_with("wpn_crossbow") or subtype == "crossbow":
			target_scene = WEAPON_CROSSBOW_SCENE
		elif weapon_id.begins_with("wpn_composite_bow") or subtype == "composite_bow":
			target_scene = WEAPON_COMPOSITE_BOW_SCENE
		elif weapon_id.begins_with("wpn_wand") or subtype == "wand":
			target_scene = WEAPON_WAND_SCENE
		elif subtype == "staff":
			target_scene = WEAPON_STAFF_SCENE
		elif subtype == "bow":
			target_scene = WEAPON_BOW_SCENE
		elif subtype == "dagger":
			target_scene = WEAPON_DAGGER_SCENE
		elif subtype == "axe":
			target_scene = WEAPON_AXE_SCENE
		else:
			target_scene = WEAPON_SWORD_SCENE

		if target_scene:
			current_weapon_model = target_scene.instantiate()
			weapon_pivot.add_child(current_weapon_model)

			var weapon_rarity: int = weapon.get("rarity", 0)
			if weapon_rarity > 0:
				_apply_weapon_rarity_glow(current_weapon_model, weapon_rarity)

	# 2. Update Shield Model in left hand
	var shield_item = InventoryManager.equipment.get("shield")
	var shield: Dictionary = shield_item if (shield_item != null and shield_item is Dictionary) else {}
	var shield_id: String = shield.get("id", "")
	var shield_subtype: String = shield.get("subtype", "")

	if shield_pivot:
		if shield_id != "":
			var target_shield_scene: PackedScene = SHIELD_BUCKLER_SCENE
			if shield_id.begins_with("shd_tower") or shield_subtype == "tower_shield":
				target_shield_scene = SHIELD_TOWER_SCENE
			elif shield_subtype == "dagger" or shield_id.contains("dagger"):
				target_shield_scene = WEAPON_DAGGER_SCENE

			if current_shield_model == null or not is_instance_valid(current_shield_model) or current_shield_model.scene_file_path != target_shield_scene.resource_path:
				if current_shield_model and is_instance_valid(current_shield_model):
					current_shield_model.queue_free()
				current_shield_model = target_shield_scene.instantiate()
				shield_pivot.add_child(current_shield_model)
			current_shield_model.visible = true
			var shield_rarity: int = shield.get("rarity", 0)
			if shield_rarity > 0:
				_apply_shield_rarity_glow(current_shield_model, shield_rarity)
		else:
			if current_shield_model and is_instance_valid(current_shield_model):
				current_shield_model.visible = false

func _apply_weapon_rarity_glow(model: Node3D, rarity: int) -> void:
	if not model or not is_instance_valid(model):
		return
	var glow_color := Color(0.24, 0.62, 1.0)
	if rarity == 2:
		glow_color = Color(0.75, 0.35, 1.0)
	elif rarity >= 3:
		glow_color = Color(1.0, 0.65, 0.12)

	for child in model.get_children():
		if child is MeshInstance3D:
			var mat = child.get_active_material(0)
			if mat and (mat is StandardMaterial3D):
				var m: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				if child.name in ["Gem", "ArcaneOrb", "Spike", "BladeTip", "Blade"]:
					m.emission_enabled = true
					m.emission = glow_color
					m.emission_energy_multiplier = 1.8
					child.material_override = m
		for subchild in child.get_children():
			if subchild is MeshInstance3D:
				var smat = subchild.get_active_material(0)
				if smat and (smat is StandardMaterial3D):
					var sm: StandardMaterial3D = smat.duplicate() as StandardMaterial3D
					if subchild.name in ["Gem", "Tip"]:
						sm.emission_enabled = true
						sm.emission = glow_color
						sm.emission_energy_multiplier = 1.8
						subchild.material_override = sm

func _apply_shield_rarity_glow(model: Node3D, rarity: int) -> void:
	if not model or not is_instance_valid(model):
		return
	var glow_color := Color(0.24, 0.62, 1.0)
	if rarity == 2:
		glow_color = Color(0.75, 0.35, 1.0)
	elif rarity >= 3:
		glow_color = Color(1.0, 0.65, 0.12)

	for child in model.get_children():
		if child is MeshInstance3D and child.name in ["CenterBoss", "Spike"]:
			var mat = child.get_active_material(0)
			if mat and (mat is StandardMaterial3D):
				var m: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				m.emission_enabled = true
				m.emission = glow_color
				m.emission_energy_multiplier = 1.6
				child.material_override = m

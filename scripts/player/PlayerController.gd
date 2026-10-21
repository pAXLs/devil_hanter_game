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

# References
@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var weapon_pivot: Node3D = $Visuals/WeaponPivot
@onready var slash_arc: MeshInstance3D = $Visuals/SlashArc
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D = null
var slash_material: StandardMaterial3D = null

# Input tracking for seamless gamepad & mouse hybrid control
var prev_mouse_pos: Vector2 = Vector2.ZERO
var mouse_active_timer: float = 0.0

func _ready() -> void:
	Global.current_player = self
	Global.player_health_changed.emit(health, max_health)
	Global.player_resource_changed.emit(resource, max_resource)
	
	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

	_setup_slash_arc()
	camera = get_viewport().get_camera_3d()

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

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if resource < max_resource:
		resource = min(max_resource, resource + resource_regen_rate * delta)
		Global.player_resource_changed.emit(resource, max_resource)

	# Passive HP regeneration from Paladin tree
	if SkillManager.hp_regen_per_sec > 0.0 and health < max_health:
		health = minf(max_health, health + SkillManager.hp_regen_per_sec * delta)
		Global.player_health_changed.emit(health, max_health)

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

	var current_speed := speed * (0.6 if is_attacking else 1.0)

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
		if SkillManager.active_q_skill == "holy_hammer" and resource >= 25.0:
			_cast_holy_hammer()
			return
		elif SkillManager.active_q_skill == "whirlwind" and resource >= 30.0:
			_cast_whirlwind()
			return
		elif SkillManager.active_q_skill == "thunder_slam" and resource >= 30.0:
			_cast_thunder_slam()
			return
		elif SkillManager.active_q_skill == "iron_skin" and resource >= 20.0:
			_cast_iron_skin()
			return

	if Input.is_action_just_pressed("skill_ultimate") and not is_attacking:
		if resource >= 50.0:
			_perform_earthquake()

func _start_dash() -> void:
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

func _perform_primary_attack() -> void:
	is_attacking = true
	attack_cd_timer = attack_cooldown

	var tween := create_tween()
	
	# 1. Wind-up
	tween.tween_property(weapon_pivot, "rotation_degrees:y", -75.0, 0.06)
	
	# 2. Forward slash + show soft crescent slash arc
	tween.tween_callback(func():
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
				var crit_rate: float = 0.20 + SkillManager.crit_chance_bonus
				var is_crit: bool = randf() < crit_rate
				var crit_mult: float = 1.75 + SkillManager.crit_damage_bonus
				var base_dmg: float = attack_damage * SkillManager.attack_damage_mult
				var dmg: float = base_dmg * (crit_mult if is_crit else 1.0)
				var knock_dir: Vector3 = (to_enemy + Vector3.UP * 0.15).normalized()
				enemy.take_damage(dmg, is_crit, self, knock_dir * 12.0)
				hit_any = true

				# Life steal from Berserker tree
				if SkillManager.lifesteal_percent > 0.0:
					var leech: float = dmg * SkillManager.lifesteal_percent
					health = minf(max_health, health + leech)
					Global.player_health_changed.emit(health, max_health)

	if hit_any and camera and camera.has_method("shake"):
		camera.shake(0.12, 0.1)

func _cast_holy_hammer() -> void:
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

	var results := space.intersect_shape(query, 32)
	for r in results:
		var collider: Node3D = r.collider as Node3D
		if collider and collider.has_method("take_damage"):
			var knock_dir: Vector3 = (collider.global_position - global_position).normalized()
			knock_dir.y = 0.3
			collider.take_damage(65.0, true, self, knock_dir * 18.0)

func _on_received_damage(amount: float, is_crit: bool, source: Node3D, knockback: float) -> void:
	if invuln_timer > 0.0 or is_dashing:
		return

	# If iron skin unbreakable upgrade is active during first 1.2s, ignore damage
	if iron_skin_timer > 2.8 and SkillManager.get_skill_rank("unbreakable") > 0:
		return

	# If iron skin active, reduce damage
	var final_amount: float = amount
	if iron_skin_timer > 0.0:
		var iron_rank: int = SkillManager.get_skill_rank("iron_skin")
		var reduction: float = 0.40 + (0.08 * iron_rank)
		final_amount = maxf(1.0, amount * (1.0 - reduction))

	invuln_timer = invuln_duration
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

func _die() -> void:
	can_act = false
	await get_tree().create_timer(1.5).timeout
	health = max_health
	resource = max_resource
	can_act = true
	Global.player_health_changed.emit(health, max_health)
	Global.player_resource_changed.emit(resource, max_resource)

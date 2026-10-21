class_name BaseEnemy
extends CharacterBody3D

@export var max_health: float = 60.0
@export var health: float = 60.0
@export var move_speed: float = 3.8
@export var attack_damage: float = 12.0
@export var attack_range: float = 2.0
@export var aggro_range: float = 14.0
@export var attack_cooldown: float = 1.4

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var attack_timer: float = 0.0
var is_dead: bool = false
var is_attacking: bool = false

@onready var visuals: Node3D = $Visuals
@onready var hurtbox: Area3D = $Hurtbox3D
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head

var attack_tween: Tween = null

func _ready() -> void:
	if hurtbox:
		hurtbox.received_damage.connect(_on_received_damage)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

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
	is_dead = true
	is_attacking = false
	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	velocity = Vector3.ZERO
	if hurtbox:
		hurtbox.queue_free()

	# Drop gold and XP
	Global.player_gold += randi_range(5, 20)
	Global.player_xp_changed.emit(25, 100, Global.player_level)

	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

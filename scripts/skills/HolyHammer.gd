class_name HolyHammer
extends Node3D

@export var damage: float = 24.0
@export var orbit_radius: float = 2.2
@export var orbit_speed: float = 6.0
@export var duration: float = 5.0

var current_angle: float = 0.0
var target_player: Node3D = null
var hit_cooldowns: Dictionary = {}

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	target_player = Global.current_player
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		queue_free()
		return

	current_angle += orbit_speed * delta
	var offset := Vector3(cos(current_angle) * orbit_radius, 0.9, sin(current_angle) * orbit_radius)
	global_position = target_player.global_position + offset
	rotation.y += 12.0 * delta

	# Hit detection with enemies
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 1 << 2 # Enemies

	var hits := space.intersect_shape(query, 8)
	var now := Time.get_ticks_msec() / 1000.0

	for h in hits:
		var enemy = h.collider
		if enemy and enemy.has_method("take_damage"):
			var last_hit: float = hit_cooldowns.get(enemy, 0.0)
			if now - last_hit >= 0.5: # damage tick every 0.5s per enemy
				hit_cooldowns[enemy] = now
				var knock: Vector3 = (enemy.global_position - global_position).normalized() * 10.0
				enemy.take_damage(damage, true, target_player, knock)

class_name Arrow3D
extends Area3D

@export var speed: float = 14.5
@export var damage: float = 16.0
@export var lifetime: float = 3.5

var velocity: Vector3 = Vector3.ZERO
var shooter: Node3D = null

func _ready() -> void:
	collision_layer = 16 # Layer 5: EnemyHitbox
	collision_mask = 2   # Layer 2: Player
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	var tween := create_tween()
	tween.tween_interval(lifetime)
	tween.tween_callback(queue_free)

func setup(dir: Vector3, from_shooter: Node3D) -> void:
	shooter = from_shooter
	velocity = dir.normalized() * speed
	look_at(global_position + dir, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		_hit_player(body)

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D and area.get_parent() is PlayerController:
		_hit_player(area.get_parent())

func _hit_player(player: Node3D) -> void:
	var hurt: Hurtbox3D = player.get_node_or_null("Hurtbox3D")
	if hurt and not hurt.is_invulnerable:
		hurt.received_damage.emit(damage, false, shooter, 5.0)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.08)
	tween.tween_callback(queue_free)

class_name PoisonCloud
extends Area3D

@export var tick_damage: float = 7.0
@export var duration: float = 3.5
@export var tick_interval: float = 0.5

var tick_timer: float = 0.0
var elapsed: float = 0.0

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player

	AudioManager.play_toxic_burst()

	# Gentle fade out
	var tween := create_tween()
	tween.tween_interval(duration - 0.5)
	if mesh_inst and mesh_inst.material_override:
		tween.tween_property(mesh_inst.material_override, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	elapsed += delta
	tick_timer += delta

	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_deal_poison_ticks()

func _deal_poison_ticks() -> void:
	for body in get_overlapping_bodies():
		if body is PlayerController:
			var hurt: Hurtbox3D = body.get_node_or_null("Hurtbox3D")
			if hurt and not hurt.is_invulnerable:
				hurt.received_damage.emit(tick_damage, false, self, 0.0)

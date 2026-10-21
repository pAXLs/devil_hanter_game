class_name LavaPatch
extends Area3D

@export var damage_per_tick: float = 6.0
@export var duration: float = 3.0
@export var tick_interval: float = 0.5

var tick_timer: float = 0.0

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player

	var tween := create_tween()
	tween.tween_interval(duration - 0.4)
	if mesh_inst and mesh_inst.material_override:
		tween.tween_property(mesh_inst.material_override, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		for body in get_overlapping_bodies():
			if body is PlayerController:
				var hurt: Hurtbox3D = body.get_node_or_null("Hurtbox3D")
				if hurt and not hurt.is_invulnerable:
					hurt.received_damage.emit(damage_per_tick, false, self, 0.0)

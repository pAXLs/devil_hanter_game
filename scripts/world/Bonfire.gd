class_name Bonfire
extends Area3D

@export var heal_per_sec: float = 18.0

var player_in_range: bool = false
var flicker_time: float = 0.0

@onready var fire_light: OmniLight3D = $Visuals/FireLight
@onready var flame_core: MeshInstance3D = $Visuals/FlameCore
@onready var label: Label3D = $Label3D

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if label:
		label.visible = false

func _process(delta: float) -> void:
	flicker_time += delta

	# Warm campfire flicker
	if fire_light:
		fire_light.light_energy = 2.8 + sin(flicker_time * 8.0) * 0.4 + cos(flicker_time * 13.0) * 0.25

	if flame_core:
		flame_core.scale = Vector3(
			1.0 + sin(flicker_time * 9.0) * 0.1,
			1.0 + cos(flicker_time * 11.0) * 0.15,
			1.0 + sin(flicker_time * 7.0) * 0.1
		)

	if player_in_range:
		var player: CharacterBody3D = Global.current_player
		if player and is_instance_valid(player):
			if player.health < player.max_health:
				if player.has_method("heal"):
					player.heal(heal_per_sec * delta)
				else:
					player.health = minf(player.max_health, player.health + heal_per_sec * delta)
					Global.player_health_changed.emit(player.health, player.max_health)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController or body.is_in_group("player"):
		player_in_range = true
		if label:
			label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController or body.is_in_group("player"):
		player_in_range = false
		if label:
			label.visible = false

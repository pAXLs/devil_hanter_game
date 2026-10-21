class_name TownPortalReturn
extends Area3D

@export var interaction_radius: float = 2.6

@onready var visuals: Node3D = $Visuals
@onready var vortex: MeshInstance3D = $Visuals/InnerVortex
@onready var light: OmniLight3D = $Visuals/PortalLight
@onready var label: Label3D = $Label3D

var anim_time: float = 0.0
var is_transitioning: bool = false

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2

	visible = Global.town_portal_active
	if label:
		label.visible = false

	if visible:
		AudioManager.play_portal_spawn()
		var target_floor: int = Global.saved_dungeon_floor
		var f_name: String = Global.get_floor_name(target_floor)
		label.text = "[F] Вернуться в Подземелье: %s (Этаж %d)" % [f_name, target_floor]

func _process(delta: float) -> void:
	if not visible or is_transitioning:
		return

	anim_time += delta
	if vortex:
		vortex.rotation.y += 2.0 * delta

	if light:
		light.light_energy = 3.0 + sin(anim_time * 5.0) * 0.8

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if label and not label.visible:
				label.visible = true

			if Input.is_action_just_pressed("interact"):
				_return_to_dungeon()
		else:
			if label and label.visible:
				label.visible = false

func _return_to_dungeon() -> void:
	is_transitioning = true
	if label:
		label.visible = false

	AudioManager.play_portal_enter()
	Global.town_portal_active = false
	Global.in_town = false

	get_tree().change_scene_to_file("res://scenes/world/Main.tscn")

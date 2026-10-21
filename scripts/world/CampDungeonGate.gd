class_name CampDungeonGate
extends Area3D

@export var interaction_radius: float = 2.8

@onready var visuals: Node3D = $Visuals
@onready var portal_disc: MeshInstance3D = $Visuals/PortalDisc
@onready var label: Label3D = $Label3D

var anim_time: float = 0.0
var is_transitioning: bool = false

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	_update_label()

func _update_label() -> void:
	if not label:
		return
	var target_floor: int = Global.current_floor
	var floor_name: String = Global.get_floor_name(target_floor)
	label.text = "[F] Спуститься в Катакомбы: %s (Этаж %d)" % [floor_name, target_floor]
	label.visible = false

func _process(delta: float) -> void:
	anim_time += delta
	if portal_disc:
		portal_disc.rotation.z += 1.2 * delta

	if is_transitioning:
		return

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if label and not label.visible:
				label.visible = true
				_update_label()

			if Input.is_action_just_pressed("interact"):
				_enter_dungeon()
		else:
			if label and label.visible:
				label.visible = false

func _enter_dungeon() -> void:
	is_transitioning = true
	if label:
		label.visible = false

	AudioManager.play_portal_enter()
	Global.in_town = false

	# Transition to Main dungeon scene
	get_tree().change_scene_to_file("res://scenes/world/Main.tscn")

class_name HeroAltar
extends Area3D

@export var interaction_radius: float = 2.8

@onready var label: Label3D = $Label3D
@onready var glyphs_node: Node3D = $Visuals/Glyphs
@onready var altar_light: OmniLight3D = $Visuals/AltarLight

var anim_timer: float = 0.0

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	if label:
		label.visible = false

func _process(delta: float) -> void:
	anim_timer += delta

	if glyphs_node:
		glyphs_node.rotation.y += 0.8 * delta
		glyphs_node.position.y = 1.6 + sin(anim_timer * 2.5) * 0.08

	if altar_light:
		altar_light.light_energy = 2.4 + sin(anim_timer * 4.0) * 0.5

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if label and not label.visible:
				label.visible = true

			if Input.is_action_just_pressed("interact"):
				AudioManager.play_ui_click()
				Global.open_class_selection.emit()
		else:
			if label and label.visible:
				label.visible = false

class_name MerchantNPC
extends Area3D

@export var interaction_radius: float = 2.8

@onready var label: Label3D = $Label3D
@onready var badge_icon: Label3D = $BadgeIcon
@onready var char_node: Node3D = $Visuals/Character
@onready var head_node: MeshInstance3D = $Visuals/Character/Head

var anim_timer: float = 0.0

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	if label:
		label.visible = false

func _process(delta: float) -> void:
	anim_timer += delta

	# Gentle breathing / swaying
	if char_node:
		char_node.position.y = sin(anim_timer * 2.5) * 0.025
	if badge_icon:
		badge_icon.position.y = 2.7 + sin(anim_timer * 3.0) * 0.06

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if label and not label.visible:
				label.visible = true

			# Subtle head tilt towards player
			if head_node:
				var local_p := char_node.to_local(player.global_position)
				head_node.rotation.y = clampf(atan2(local_p.x, local_p.z), -0.5, 0.5)

			if Input.is_action_just_pressed("interact"):
				_open_merchant()
		else:
			if label and label.visible:
				label.visible = false
			if head_node:
				head_node.rotation.y = lerpf(head_node.rotation.y, 0.0, delta * 4.0)

func _open_merchant() -> void:
	AudioManager.play_ui_click()
	Global.merchant_opened.emit()

class_name MerchantNPC
extends Area3D

@export var interaction_radius: float = 2.6

@onready var label: Label3D = $Label3D

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	if label:
		label.visible = false

func _process(_delta: float) -> void:
	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if label and not label.visible:
				label.visible = true

			if Input.is_action_just_pressed("interact"):
				_open_merchant()
		else:
			if label and label.visible:
				label.visible = false

func _open_merchant() -> void:
	AudioManager.play_ui_click()
	Global.merchant_opened.emit()

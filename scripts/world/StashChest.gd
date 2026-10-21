class_name StashChest
extends Area3D

@export var interaction_radius: float = 2.4

@onready var visuals: Node3D = $Visuals
@onready var lid: Node3D = $Visuals/Lid
@onready var label: Label3D = $Label3D

var is_open: bool = false

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
				_toggle_stash()
		else:
			if label and label.visible:
				label.visible = false

func _toggle_stash() -> void:
	AudioManager.play_chest()
	is_open = true

	# Animate lid spring
	if lid:
		var tween := create_tween()
		tween.tween_property(lid, "rotation_degrees:x", -50.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(lid, "rotation_degrees:x", -40.0, 0.1)

	Global.stash_opened.emit()

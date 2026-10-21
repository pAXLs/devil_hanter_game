class_name BlacksmithNPC
extends Area3D

@export var interaction_radius: float = 2.8

@onready var label: Label3D = $Label3D
@onready var badge_icon: Label3D = $BadgeIcon
@onready var char_node: Node3D = $Visuals/Character
@onready var arm_r_pivot: Node3D = $Visuals/Character/ArmR_Pivot
@onready var hot_light: OmniLight3D = $Visuals/AnvilStation/HotLight

var anim_timer: float = 0.0
var strike_cooldown: float = 2.5
var is_striking: bool = false
var strike_timer: float = 0.0

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	if label:
		label.visible = false

func _process(delta: float) -> void:
	anim_timer += delta

	# Breathing and badge floating
	if char_node:
		char_node.position.y = sin(anim_timer * 2.2) * 0.02
	if badge_icon:
		badge_icon.position.y = 2.7 + sin(anim_timer * 3.0) * 0.06
	if hot_light:
		hot_light.light_energy = 2.0 + sin(anim_timer * 6.0) * 0.5

	# Idle hammer striking animation
	strike_cooldown -= delta
	if strike_cooldown <= 0.0 and not is_striking:
		is_striking = true
		strike_timer = 0.0

	if is_striking and arm_r_pivot:
		strike_timer += delta * 4.0
		if strike_timer < 1.0:
			# Raise hammer
			arm_r_pivot.rotation.x = -sin(strike_timer * PI * 0.5) * 1.1
		elif strike_timer < 1.3:
			# Swift strike down
			var down_progress := (strike_timer - 1.0) / 0.3
			arm_r_pivot.rotation.x = lerpf(-1.1, 0.4, down_progress)
			if down_progress >= 0.8 and strike_cooldown < -0.2:
				strike_cooldown = 0.0 # prevent double ping
				AudioManager.play_hammer()
		elif strike_timer < 2.0:
			# Return to rest
			var rest_progress := (strike_timer - 1.3) / 0.7
			arm_r_pivot.rotation.x = lerpf(0.4, 0.0, rest_progress)
		else:
			is_striking = false
			arm_r_pivot.rotation.x = 0.0
			strike_cooldown = randf_range(2.8, 4.5)

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if label and not label.visible:
				label.visible = true

			if Input.is_action_just_pressed("interact"):
				_open_blacksmith()
		else:
			if label and label.visible:
				label.visible = false

func _open_blacksmith() -> void:
	AudioManager.play_ui_click()
	Global.blacksmith_opened.emit()

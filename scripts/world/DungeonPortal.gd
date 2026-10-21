class_name DungeonPortal
extends Area3D

@export var interaction_radius: float = 2.6

var is_transitioning: bool = false
var anim_time: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var rune_ring: MeshInstance3D = $Visuals/RuneRing
@onready var inner_vortex: MeshInstance3D = $Visuals/InnerVortex
@onready var light_beam: MeshInstance3D = $Visuals/LightBeam
@onready var portal_light: OmniLight3D = $Visuals/PortalLight
@onready var prompt_label: Label3D = $PromptLabel

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2

	AudioManager.play_portal_spawn()

	# Start collapsed and pop open with an epic magical tween
	visuals.scale = Vector3(0.01, 0.01, 0.01)
	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3(1.0, 1.0, 1.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_update_prompt_text()

func _update_prompt_text() -> void:
	if not prompt_label:
		return
	var next_floor := Global.current_floor + 1
	var next_name := Global.get_floor_name(next_floor)
	prompt_label.text = "[F] Спуститься: %s (Этаж %d)" % [next_name, next_floor]
	prompt_label.visible = false

func _process(delta: float) -> void:
	anim_time += delta

	# Mystical rotation animations
	if rune_ring:
		rune_ring.rotation.y -= 0.5 * delta
	if inner_vortex:
		inner_vortex.rotation.y += 1.6 * delta
		inner_vortex.scale = Vector3.ONE * (1.0 + sin(anim_time * 4.0) * 0.08)

	# Pulsating mystic light beam & omni glow
	if light_beam:
		var beam_mat: StandardMaterial3D = light_beam.material_override
		if beam_mat:
			var base_alpha := 0.45 + sin(anim_time * 3.5) * 0.15
			beam_mat.albedo_color.a = clampf(base_alpha, 0.2, 0.7)

	if portal_light:
		portal_light.light_energy = 3.0 + sin(anim_time * 5.0) * 1.0

	# Interaction check
	if is_transitioning:
		return

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if prompt_label and not prompt_label.visible:
				prompt_label.visible = true
				_update_prompt_text()

			if Input.is_action_just_pressed("interact"):
				_activate_portal()
		else:
			if prompt_label and prompt_label.visible:
				prompt_label.visible = false

func _activate_portal() -> void:
	is_transitioning = true
	if prompt_label:
		prompt_label.visible = false

	AudioManager.play_portal_enter()

	# Vortex compression suck-in effect
	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3(1.3, 2.5, 1.3), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", Vector3(0.01, 4.0, 0.01), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	var next_floor := Global.current_floor + 1
	var stats: Dictionary = {
		"cleared_floor": Global.current_floor,
		"floor_name": Global.get_floor_name(Global.current_floor),
		"next_floor": next_floor,
		"next_name": Global.get_floor_name(next_floor),
		"enemies_killed": Global.enemies_killed_floor,
		"gold_collected": Global.gold_collected_floor,
		"total_kills": Global.enemies_killed_total
	}

	Global.request_floor_transition.emit(stats)

class_name CampDungeonGate
extends Area3D

@export var interaction_radius: float = 3.2

@onready var visuals: Node3D = $Visuals
@onready var portal_disc: MeshInstance3D = $Visuals/PortalDisc
@onready var label: Label3D = $Label3D
@onready var always_sign: Label3D = $AlwaysSignLabel

var anim_time: float = 0.0
var is_transitioning: bool = false
var ui_layer: CanvasLayer
var enter_btn: Button

func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	_update_label()
	_create_screen_button()

func _create_screen_button() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 50
	add_child(ui_layer)

	enter_btn = Button.new()
	var target_floor: int = Global.current_floor
	var floor_name: String = Global.get_floor_name(target_floor)
	enter_btn.text = "⚔️ ВОЙТИ В ПОДЗЕМЕЛЬЕ: %s (ЭТАЖ %d) [F]" % [floor_name, target_floor]
	enter_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	enter_btn.offset_left = -260
	enter_btn.offset_right = 260
	enter_btn.offset_top = -135
	enter_btn.offset_bottom = -80

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.1, 0.16, 0.25, 0.92)
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = Color(0.35, 0.75, 1.0, 0.9)
	sb_normal.corner_radius_top_left = 8
	sb_normal.corner_radius_top_right = 8
	sb_normal.corner_radius_bottom_right = 8
	sb_normal.corner_radius_bottom_left = 8
	enter_btn.add_theme_stylebox_override("normal", sb_normal)

	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.18, 0.28, 0.45, 0.98)
	sb_hover.border_color = Color(0.6, 0.9, 1.0, 1.0)
	enter_btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(0.06, 0.1, 0.18, 1.0)
	sb_pressed.border_color = Color(1.0, 0.85, 0.4, 1.0)
	enter_btn.add_theme_stylebox_override("pressed", sb_pressed)

	enter_btn.add_theme_font_size_override("font_size", 16)
	enter_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	enter_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

	if ResourceLoader.exists("res://assets/fonts/Cinzel-Bold.ttf"):
		var font := load("res://assets/fonts/Cinzel-Bold.ttf") as Font
		enter_btn.add_theme_font_override("font", font)

	enter_btn.pressed.connect(_enter_dungeon)
	enter_btn.visible = false
	enter_btn.modulate.a = 0.0
	ui_layer.add_child(enter_btn)

func _update_label() -> void:
	var target_floor: int = Global.current_floor
	var floor_name: String = Global.get_floor_name(target_floor)
	if label:
		label.text = "[F] Спуститься в Катакомбы: %s (Этаж %d)" % [floor_name, target_floor]
		label.visible = false
	if enter_btn:
		enter_btn.text = "⚔️ ВОЙТИ В ПОДЗЕМЕЛЬЕ: %s (ЭТАЖ %d) [F]" % [floor_name, target_floor]

func _process(delta: float) -> void:
	anim_time += delta
	if portal_disc:
		portal_disc.rotation.z += 1.2 * delta

	if always_sign:
		always_sign.position.y = 4.9 + sin(anim_time * 2.0) * 0.08

	if is_transitioning:
		return

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_radius:
			if label and not label.visible:
				label.visible = true
				_update_label()
			if enter_btn and not enter_btn.visible:
				enter_btn.visible = true
				var tw := create_tween()
				tw.tween_property(enter_btn, "modulate:a", 1.0, 0.2)

			if Input.is_action_just_pressed("interact"):
				_enter_dungeon()
		else:
			if label and label.visible:
				label.visible = false
			if enter_btn and enter_btn.visible:
				var tw := create_tween()
				tw.tween_property(enter_btn, "modulate:a", 0.0, 0.15)
				tw.tween_callback(func(): enter_btn.visible = false)

func _enter_dungeon() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	if label:
		label.visible = false
	if enter_btn:
		enter_btn.visible = false

	AudioManager.play_portal_enter()
	Global.in_town = false

	var target_floor: int = Global.current_floor
	var floor_name: String = Global.get_floor_name(target_floor)

	# Transition to Main dungeon scene using SceneTransition
	SceneTransition.change_scene_to_file(
		"res://scenes/world/Main.tscn",
		"СПУСК В КАТАКОМБЫ",
		"Этаж %d: «%s»" % [target_floor, floor_name]
	)

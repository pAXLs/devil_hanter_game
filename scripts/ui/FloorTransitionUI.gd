class_name FloorTransitionUI
extends Control

signal descent_confirmed

@onready var title_label: Label = $Vignette/Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Vignette/Panel/VBox/SubtitleLabel
@onready var kills_label: Label = $Vignette/Panel/VBox/StatsBox/StatsMargin/StatsInnerVBox/KillsLabel
@onready var gold_label: Label = $Vignette/Panel/VBox/StatsBox/StatsMargin/StatsInnerVBox/GoldLabel
@onready var total_kills_label: Label = $Vignette/Panel/VBox/StatsBox/StatsMargin/StatsInnerVBox/TotalKillsLabel
@onready var next_floor_label: Label = $Vignette/Panel/VBox/NextFloorBox/NextFloorLabel
@onready var descent_btn: Button = $Vignette/Panel/VBox/DescentButton
@onready var panel: Panel = $Vignette/Panel
@onready var vignette: ColorRect = $Vignette

var is_active: bool = false

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	Global.request_floor_transition.connect(_on_request_floor_transition)
	if descent_btn:
		descent_btn.pressed.connect(_on_descent_pressed)

func _on_request_floor_transition(stats: Dictionary) -> void:
	is_active = true
	visible = true

	# Populate stats
	var cleared_floor: int = stats.get("cleared_floor", 1)
	var cleared_name: String = stats.get("floor_name", "Древний Склеп")
	var next_floor: int = stats.get("next_floor", 2)
	var next_name: String = stats.get("next_name", "Кровавые Катакомбы")
	var kills: int = stats.get("enemies_killed", 0)
	var gold: int = stats.get("gold_collected", 0)
	var total_kills: int = stats.get("total_kills", 0)

	if title_label:
		title_label.text = "🏆 ЭТАЖ %d ОЧИЩЕН!" % cleared_floor
	if subtitle_label:
		subtitle_label.text = "«%s» зачищен от скверны. Путь открыт." % cleared_name
	if kills_label:
		kills_label.text = "💀 Врагов уничтожено: %d" % kills
	if gold_label:
		gold_label.text = "💰 Золота добыто: %d" % gold
	if total_kills_label:
		total_kills_label.text = "⚔️ Всего повержено в склепе: %d" % total_kills
	if next_floor_label:
		next_floor_label.text = "Этаж %d — «%s»" % [next_floor, next_name]

	if descent_btn:
		descent_btn.disabled = false
		descent_btn.grab_focus()

	# Cinematic smooth fade in
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_F:
			_on_descent_pressed()
			get_viewport().set_input_as_handled()

func _on_descent_pressed() -> void:
	if not is_active:
		return
	is_active = false

	if descent_btn:
		descent_btn.disabled = true

	AudioManager.play_portal_enter()

	# Smooth fade out, then return to TownCamp village to rest, trade, and forge
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = false
		Global.current_floor += 1
		Global.enemies_killed_floor = 0
		Global.gold_collected_floor = 0
		if Global.current_player and is_instance_valid(Global.current_player):
			if Global.current_player.has_method("heal"):
				Global.current_player.heal(Global.current_player.max_health * 0.35)
		get_tree().change_scene_to_file("res://scenes/world/TownCamp.tscn")
	)

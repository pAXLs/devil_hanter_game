class_name DeathScreenUI
extends Control

# Death Screen UI matching Gothic ARPG reference
# Shows "ВЫ ПОГИБЛИ" banner, run statistics, and respawn / main menu buttons

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var content_container: VBoxContainer = $ContentContainer
@onready var banner_rect: TextureRect = $ContentContainer/BannerContainer/BannerRect
@onready var stats_panel: PanelContainer = $ContentContainer/StatsPanel
@onready var kills_value: Label = $ContentContainer/StatsPanel/Margin/VBox/StatsGrid/KillsValue
@onready var gold_value: Label = $ContentContainer/StatsPanel/Margin/VBox/StatsGrid/GoldValue
@onready var floor_value: Label = $ContentContainer/StatsPanel/Margin/VBox/StatsGrid/FloorValue
@onready var btn_respawn: Button = $ContentContainer/ButtonsContainer/RespawnButton
@onready var btn_main_menu: Button = $ContentContainer/ButtonsContainer/MainMenuButton

var font_cinzel: Font = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Process input even when game paused or player disabled

	if ResourceLoader.exists("res://assets/fonts/Cinzel-Bold.ttf"):
		font_cinzel = load("res://assets/fonts/Cinzel-Bold.ttf")

	Global.player_died.connect(_on_player_died)

	if btn_respawn:
		btn_respawn.pressed.connect(_on_respawn_pressed)
		btn_respawn.mouse_entered.connect(_on_button_hover.bind(btn_respawn))
		btn_respawn.mouse_exited.connect(_on_button_unhover.bind(btn_respawn))

	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
		btn_main_menu.mouse_entered.connect(_on_button_hover.bind(btn_main_menu))
		btn_main_menu.mouse_exited.connect(_on_button_unhover.bind(btn_main_menu))

func _on_player_died(kills: int, gold: int) -> void:
	# Update statistic displays
	if kills_value:
		kills_value.text = str(kills)
	if gold_value:
		gold_value.text = str(gold)
	if floor_value:
		floor_value.text = "%d («%s»)" % [Global.current_floor, Global.get_floor_name(Global.current_floor)]

	# Display with dramatic fade & blood-red vignette
	visible = true
	modulate.a = 0.0
	content_container.scale = Vector2(0.9, 0.9)
	content_container.pivot_offset = content_container.size / 2.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(content_container, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_respawn_pressed() -> void:
	AudioManager.play_ui_click()
	btn_respawn.disabled = true
	btn_main_menu.disabled = true

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		visible = false
		btn_respawn.disabled = false
		btn_main_menu.disabled = false
		Global.respawn_player_in_camp()
	)

func _on_main_menu_pressed() -> void:
	AudioManager.play_ui_click()
	btn_respawn.disabled = true
	btn_main_menu.disabled = true

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		visible = false
		btn_respawn.disabled = false
		btn_main_menu.disabled = false
		Global.return_to_main_menu()
	)

func _on_button_hover(btn: Button) -> void:
	AudioManager.play_ui_click()
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_SINE)

func _on_button_unhover(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)

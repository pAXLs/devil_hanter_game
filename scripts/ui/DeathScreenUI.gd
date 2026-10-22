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
		btn_respawn.mouse_entered.connect(func(): AudioManager.play_ui_click())

	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
		btn_main_menu.mouse_entered.connect(func(): AudioManager.play_ui_click())

func _on_player_died(kills: int, gold: int) -> void:
	# Update statistic displays
	if kills_value:
		kills_value.text = str(kills)
	if gold_value:
		gold_value.text = str(gold)
	if floor_value:
		floor_value.text = "%d («%s»)" % [Global.current_floor, Global.get_floor_name(Global.current_floor)]

	# Display with dramatic fade
	visible = true
	modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _on_respawn_pressed() -> void:
	AudioManager.play_ui_click()
	btn_respawn.disabled = true
	btn_main_menu.disabled = true

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
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
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		visible = false
		btn_respawn.disabled = false
		btn_main_menu.disabled = false
		Global.return_to_main_menu()
	)

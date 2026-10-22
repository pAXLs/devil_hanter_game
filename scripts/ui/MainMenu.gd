class_name MainMenu
extends Control

# Devil Hunter Main Menu
# Features:
# - Continue game
# - Save slot selector (Slot 1, Slot 2, Slot 3)
# - Co-op / Play with friends modal (modular network architecture ready)
# - Settings modal (Audio volumes, Fullscreen)
# - Quit game

@onready var bg_rect: TextureRect = $BackgroundRect
@onready var btn_continue: Button = $LeftMenu/ButtonsContainer/ContinueBtn
@onready var btn_saves: Button = $LeftMenu/ButtonsContainer/SavesBtn
@onready var btn_friends: Button = $LeftMenu/ButtonsContainer/FriendsBtn
@onready var btn_settings: Button = $LeftMenu/ButtonsContainer/SettingsBtn
@onready var btn_quit: Button = $LeftMenu/ButtonsContainer/QuitBtn

# Modals
@onready var saves_modal: Control = $SavesModal
@onready var saves_container: VBoxContainer = $SavesModal/Panel/Margin/VBox/SlotsContainer
@onready var saves_close_btn: Button = $SavesModal/Panel/Margin/VBox/CloseSavesBtn

@onready var friends_modal: Control = $FriendsModal
@onready var friends_close_btn: Button = $FriendsModal/Panel/Margin/VBox/CloseFriendsBtn

@onready var settings_modal: Control = $SettingsModal
@onready var master_slider: HSlider = $SettingsModal/Panel/Margin/VBox/MasterSlider
@onready var master_val_label: Label = $SettingsModal/Panel/Margin/VBox/MasterValLabel
@onready var fullscreen_check: CheckBox = $SettingsModal/Panel/Margin/VBox/FullscreenCheck
@onready var settings_close_btn: Button = $SettingsModal/Panel/Margin/VBox/CloseSettingsBtn

# New Game Class Selector Modal (opened when picking an empty save slot)
@onready var class_pick_modal: Control = $ClassPickModal
@onready var class_pick_close_btn: Button = $ClassPickModal/Panel/Margin/VBox/CloseClassBtn
@onready var btn_pick_warrior: Button = $ClassPickModal/Panel/Margin/VBox/ClassesHBox/WarriorBtn
@onready var btn_pick_rogue: Button = $ClassPickModal/Panel/Margin/VBox/ClassesHBox/RogueBtn
@onready var btn_pick_mage: Button = $ClassPickModal/Panel/Margin/VBox/ClassesHBox/MageBtn
var target_new_game_slot: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide all sub-modals initially
	if saves_modal: saves_modal.visible = false
	if friends_modal: friends_modal.visible = false
	if settings_modal: settings_modal.visible = false
	if class_pick_modal: class_pick_modal.visible = false

	# Connect main navigation buttons
	_setup_button(btn_continue, _on_continue_pressed)
	_setup_button(btn_saves, _on_saves_pressed)
	_setup_button(btn_friends, _on_friends_pressed)
	_setup_button(btn_settings, _on_settings_pressed)
	_setup_button(btn_quit, _on_quit_pressed)

	# Connect modal close buttons
	if saves_close_btn:
		_setup_button(saves_close_btn, func(): saves_modal.visible = false)
	if friends_close_btn:
		_setup_button(friends_close_btn, func(): friends_modal.visible = false)
	if settings_close_btn:
		_setup_button(settings_close_btn, func(): settings_modal.visible = false)
	if class_pick_close_btn:
		_setup_button(class_pick_close_btn, func(): class_pick_modal.visible = false)

	# Connect class picker buttons
	if btn_pick_warrior:
		_setup_button(btn_pick_warrior, func(): choose_new_game_class(Global.CLASS_WARRIOR))
	if btn_pick_rogue:
		_setup_button(btn_pick_rogue, func(): choose_new_game_class(Global.CLASS_ROGUE))
	if btn_pick_mage:
		_setup_button(btn_pick_mage, func(): choose_new_game_class(Global.CLASS_MAGE))

	# Setup settings controls
	_init_settings_values()

	# Check continue button text / availability
	_refresh_continue_button()

func _setup_button(btn: Button, callback: Callable) -> void:
	if not btn: return
	btn.pressed.connect(callback)
	btn.mouse_entered.connect(func():
		AudioManager.play_ui_click()
		var tw := create_tween()
		tw.tween_property(btn, "position:x", 12.0, 0.12).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "position:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	)

func _refresh_continue_button() -> void:
	if not btn_continue: return
	var has_any := Global.has_save(1) or Global.has_save(2) or Global.has_save(3)
	if has_any:
		btn_continue.text = "ПРОДОЛЖИТЬ"
	else:
		btn_continue.text = "НАЧАТЬ ИГРУ"

func _on_continue_pressed() -> void:
	AudioManager.play_ui_click()
	# Load slot 1 if exists, otherwise first existing slot, or start new game in slot 1
	var target_slot := 1
	if not Global.has_save(target_slot):
		for s in [2, 3]:
			if Global.has_save(s):
				target_slot = s
				break
	
	if Global.has_save(target_slot):
		Global.load_game(target_slot)
		SceneTransition.change_scene_to_file(
			"res://scenes/world/TownCamp.tscn",
			"ЛАГЕРЬ СТРАЖЕЙ",
			"Возвращение в безопасную обитель..."
		)
	else:
		_open_class_picker_for_slot(1)

func _on_saves_pressed() -> void:
	AudioManager.play_ui_click()
	_refresh_save_slots()
	saves_modal.visible = true

func _on_friends_pressed() -> void:
	AudioManager.play_ui_click()
	friends_modal.visible = true

func _on_settings_pressed() -> void:
	AudioManager.play_ui_click()
	settings_modal.visible = true

func _on_quit_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().quit()

# --- Save Slot Management ---

func _refresh_save_slots() -> void:
	if not saves_container: return
	for child in saves_container.get_children():
		child.queue_free()

	for slot_idx in range(1, 4):
		var info: Dictionary = Global.get_save_slot_info(slot_idx)
		var slot_card := _create_slot_card(slot_idx, info)
		saves_container.add_child(slot_card)

func _create_slot_card(slot: int, info: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.07, 0.9)
	style.border_color = Color(0.7, 0.55, 0.25, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var exists: bool = info.get("exists", false)

	# Slot Title & Info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 16)

	if exists:
		var c_id: String = info.get("class", Global.CLASS_WARRIOR)
		var c_info := Global.get_class_info(c_id)
		var c_icon: String = c_info.get("icon", "⚔")
		var c_name: String = c_info.get("name", "Герой")
		var lvl: int = int(info.get("level", 1))
		var gold: int = int(info.get("gold", 0))
		var floor_num: int = int(info.get("floor", 1))
		var time_str: String = info.get("datetime", "")

		title_lbl.text = "СЛОТ %d: %s %s (Ур. %d)" % [slot, c_icon, c_name, lvl]
		info_vbox.add_child(title_lbl)

		var details_lbl := Label.new()
		details_lbl.text = "🪙 Золото: %d   |   🏰 Этаж: %d («%s»)   |   %s" % [
			gold, floor_num, Global.get_floor_name(floor_num), time_str
		]
		details_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1.0))
		details_lbl.add_theme_font_size_override("font_size", 13)
		info_vbox.add_child(details_lbl)

		# Buttons: Play & Delete
		var btn_play := Button.new()
		btn_play.text = "▶  ИГРАТЬ"
		btn_play.custom_minimum_size = Vector2(100, 38)
		btn_play.pressed.connect(func():
			AudioManager.play_ui_click()
			Global.load_game(slot)
			SceneTransition.change_scene_to_file(
				"res://scenes/world/TownCamp.tscn",
				"ЛАГЕРЬ СТРАЖЕЙ",
				"Загрузка приключения..."
			)
		)
		hbox.add_child(btn_play)

		var btn_del := Button.new()
		btn_del.text = "✖"
		btn_del.tooltip_text = "Удалить сохранение"
		btn_del.custom_minimum_size = Vector2(38, 38)
		btn_del.pressed.connect(func():
			AudioManager.play_ui_click()
			Global.delete_save(slot)
			_refresh_save_slots()
			_refresh_continue_button()
		)
		hbox.add_child(btn_del)
	else:
		title_lbl.text = "СЛОТ %d: [ ПУСТОЙ СЛОТ ]" % slot
		info_vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = "Нажмите «Новая игра», чтобы начать поход новым персонажем."
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
		desc_lbl.add_theme_font_size_override("font_size", 13)
		info_vbox.add_child(desc_lbl)

		var btn_new := Button.new()
		btn_new.text = "✚  НОВАЯ ИГРА"
		btn_new.custom_minimum_size = Vector2(130, 38)
		btn_new.pressed.connect(func():
			AudioManager.play_ui_click()
			_open_class_picker_for_slot(slot)
		)
		hbox.add_child(btn_new)

	return card

func _open_class_picker_for_slot(slot: int) -> void:
	target_new_game_slot = slot
	saves_modal.visible = false
	class_pick_modal.visible = true

func choose_new_game_class(c_id: String) -> void:
	AudioManager.play_ui_click()
	class_pick_modal.visible = false
	Global.start_new_game(target_new_game_slot, c_id)

# --- Settings & Audio ---

func _init_settings_values() -> void:
	if master_slider:
		var current_vol: float = db_to_linear(AudioManager.master_volume_offset)
		master_slider.value = current_vol * 100.0
		_update_master_val_label(master_slider.value)
		master_slider.value_changed.connect(_on_master_volume_changed)

	if fullscreen_check:
		fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _update_master_val_label(val: float) -> void:
	if master_val_label:
		master_val_label.text = "%d%%" % int(val)

func _on_master_volume_changed(val: float) -> void:
	_update_master_val_label(val)
	var linear_vol: float = val / 100.0
	AudioManager.master_volume_offset = linear_to_db(maxf(linear_vol, 0.0001))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), AudioManager.master_volume_offset)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	AudioManager.play_ui_click()
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

class_name MainMenu
extends Control

# Devil Hunter Main Menu
# Features:
# - Continue / Play game (instant jump into TownCamp)
# - Save slot manager (Slot 1, Slot 2, Slot 3)
# - Play with friends modal (co-op preview)
# - Settings modal (Audio volumes, Fullscreen)
# - Quit game

@onready var bg_rect: TextureRect = $BackgroundRect
@onready var sidebar_panel: PanelContainer = $SidebarPanel
@onready var btn_continue: Button = $SidebarPanel/Margin/VBox/ButtonsContainer/ContinueBtn
@onready var btn_saves: Button = $SidebarPanel/Margin/VBox/ButtonsContainer/SavesBtn
@onready var btn_friends: Button = $SidebarPanel/Margin/VBox/ButtonsContainer/FriendsBtn
@onready var btn_settings: Button = $SidebarPanel/Margin/VBox/ButtonsContainer/SettingsBtn
@onready var btn_quit: Button = $SidebarPanel/Margin/VBox/ButtonsContainer/QuitBtn

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide all sub-modals initially
	_close_all_modals()

	# Connect main navigation buttons
	_bind_button(btn_continue, _on_continue_pressed)
	_bind_button(btn_saves, _on_saves_pressed)
	_bind_button(btn_friends, _on_friends_pressed)
	_bind_button(btn_settings, _on_settings_pressed)
	_bind_button(btn_quit, _on_quit_pressed)

	# Connect modal close buttons
	if saves_close_btn:
		_bind_button(saves_close_btn, func(): saves_modal.visible = false)
	if friends_close_btn:
		_bind_button(friends_close_btn, func(): friends_modal.visible = false)
	if settings_close_btn:
		_bind_button(settings_close_btn, func(): settings_modal.visible = false)

	# Setup settings controls
	_init_settings_values()

	# Check continue button text / availability
	_refresh_continue_button()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if saves_modal.visible or friends_modal.visible or settings_modal.visible:
			_close_all_modals()
			AudioManager.play_ui_click()
			get_viewport().set_input_as_handled()

func _close_all_modals() -> void:
	if saves_modal: saves_modal.visible = false
	if friends_modal: friends_modal.visible = false
	if settings_modal: settings_modal.visible = false

func _bind_button(btn: Button, callback: Callable) -> void:
	if not btn: return
	btn.pressed.connect(callback)
	btn.mouse_entered.connect(func():
		AudioManager.play_ui_click()
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
	# Load first existing save slot or start new game immediately
	var target_slot := 1
	var found_save := false
	for s in [1, 2, 3]:
		if Global.has_save(s):
			target_slot = s
			found_save = true
			break

	if found_save:
		Global.load_game(target_slot)
		_transition_to_camp("Загрузка похода...")
	else:
		# Start fresh game immediately in slot 1 with default Warrior class
		# Hero can freely pick or switch class at Hero Altar in town
		Global.start_new_game(1, Global.CLASS_WARRIOR)

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
	style.bg_color = Color(0.08, 0.05, 0.07, 0.95)
	style.border_color = Color(0.7, 0.55, 0.25, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var exists: bool = info.get("exists", false)

	# Info side
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.4, 1.0))
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

		# Button Play
		var btn_play := Button.new()
		btn_play.text = "▶  ИГРАТЬ"
		btn_play.custom_minimum_size = Vector2(110, 42)
		btn_play.mouse_entered.connect(func(): AudioManager.play_ui_click())
		btn_play.pressed.connect(func():
			AudioManager.play_ui_click()
			saves_modal.visible = false
			Global.load_game(slot)
			_transition_to_camp("Загрузка приключения...")
		)
		hbox.add_child(btn_play)

		# Button Delete
		var btn_del := Button.new()
		btn_del.text = "✖"
		btn_del.tooltip_text = "Удалить сохранение"
		btn_del.custom_minimum_size = Vector2(42, 42)
		btn_del.mouse_entered.connect(func(): AudioManager.play_ui_click())
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
		desc_lbl.text = "Нажмите «Новая игра», чтобы начать поход с лагеря."
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
		desc_lbl.add_theme_font_size_override("font_size", 13)
		info_vbox.add_child(desc_lbl)

		var btn_new := Button.new()
		btn_new.text = "✚  НОВАЯ ИГРА"
		btn_new.custom_minimum_size = Vector2(140, 42)
		btn_new.mouse_entered.connect(func(): AudioManager.play_ui_click())
		btn_new.pressed.connect(func():
			AudioManager.play_ui_click()
			saves_modal.visible = false
			Global.start_new_game(slot, Global.CLASS_WARRIOR)
		)
		hbox.add_child(btn_new)

	return card

func _transition_to_camp(subtitle: String = "") -> void:
	var trans_node = get_node_or_null("/root/SceneTransition")
	if trans_node and trans_node.has_method("change_scene_to_file"):
		trans_node.change_scene_to_file(
			"res://scenes/world/TownCamp.tscn",
			"ЛАГЕРЬ СТРАЖЕЙ",
			subtitle if subtitle != "" else "Возвращение в безопасную обитель..."
		)
	else:
		get_tree().change_scene_to_file("res://scenes/world/TownCamp.tscn")

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

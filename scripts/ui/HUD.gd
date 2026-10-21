class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $BottomBar/HBox/HealthContainer/HealthBar
@onready var health_label: Label = $BottomBar/HBox/HealthContainer/HealthLabel
@onready var resource_bar: ProgressBar = $BottomBar/HBox/ResourceContainer/ResourceBar
@onready var resource_label: Label = $BottomBar/HBox/ResourceContainer/ResourceLabel
@onready var gold_label: Label = $TopBar/GoldContainer/GoldLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var shrine_buff_label: Label = $TopBar/ShrineBuffLabel
@onready var floor_label: Label = $TopBar/FloorLabel
@onready var skills_btn: Button = $TopBar/SkillsButton
@onready var skill_tree_ui: Control = $SkillTreeUI
@onready var inventory_btn: Button = $TopBar/InventoryButton
@onready var inventory_ui: Control = $InventoryUI
@onready var merchant_ui: Control = $MerchantUI
@onready var blacksmith_ui: Control = $BlacksmithUI
@onready var skill_potion_panel: Panel = $BottomBar/HBox/SkillsContainer/SkillPotion
@onready var potion_count_label: Label = $BottomBar/HBox/SkillsContainer/SkillPotion/CountLabel
@onready var skill_q_panel: Panel = $BottomBar/HBox/SkillsContainer/SkillQ
@onready var skill_q_label: Label = $BottomBar/HBox/SkillsContainer/SkillQ/Label
@onready var skill_portal_panel: Panel = $BottomBar/HBox/SkillsContainer/SkillPortal

# Boss UI
@onready var boss_container: VBoxContainer = $BossContainer
@onready var boss_name_label: Label = $BossContainer/BossNameLabel
@onready var boss_bar: ProgressBar = $BossContainer/BossBar
@onready var boss_health_label: Label = $BossContainer/BossHealthLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Process input even when game paused

	Global.player_health_changed.connect(_on_health_changed)
	Global.player_resource_changed.connect(_on_resource_changed)
	Global.player_xp_changed.connect(_on_xp_changed)

	Global.boss_spawned.connect(_on_boss_spawned)
	Global.boss_health_changed.connect(_on_boss_health_changed)
	Global.boss_defeated.connect(_on_boss_defeated)
	Global.shrine_buff_changed.connect(_on_shrine_buff_changed)
	Global.floor_changed.connect(_on_floor_changed)
	_on_floor_changed(Global.current_floor, Global.get_floor_name(Global.current_floor))

	if skills_btn and skill_tree_ui:
		skills_btn.pressed.connect(toggle_skill_tree)
	if inventory_btn and inventory_ui:
		inventory_btn.pressed.connect(toggle_inventory)

	if skill_potion_panel:
		skill_potion_panel.gui_input.connect(_on_potion_slot_gui_input)
	if skill_portal_panel:
		skill_portal_panel.gui_input.connect(_on_portal_slot_gui_input)

	InventoryManager.potion_count_changed.connect(func(_cur, _mx): _update_potion_slot())
	_update_potion_slot()

	SkillManager.skill_unlocked.connect(func(_id): _update_q_slot())
	SkillManager.skills_updated.connect(_update_q_slot)

	_update_q_slot()

func _on_potion_slot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		InventoryManager.use_potion()

func _on_portal_slot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var player = Global.current_player
		if player and is_instance_valid(player) and player.has_method("_start_town_portal_channeling"):
			if not Global.in_town:
				player._start_town_portal_channeling()

func _update_potion_slot() -> void:
	if not potion_count_label:
		return
	potion_count_label.text = "%d / %d" % [InventoryManager.potion_belt_count, InventoryManager.MAX_POTION_BELT]
	if skill_potion_panel:
		if InventoryManager.potion_belt_count > 0:
			skill_potion_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			skill_potion_panel.modulate = Color(0.45, 0.45, 0.45, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("use_potion") or event.physical_keycode == KEY_1 or event.keycode == KEY_1 or event.key_label == KEY_1:
			InventoryManager.use_potion()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("inventory") or event.physical_keycode == KEY_I or event.keycode == KEY_I or event.key_label == KEY_I or event.physical_keycode == KEY_B or event.keycode == KEY_B or event.key_label == KEY_B:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("skill_tree") or event.physical_keycode == KEY_K or event.keycode == KEY_K or event.key_label == KEY_K:
			toggle_skill_tree()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			var handled := false
			if merchant_ui and merchant_ui.visible:
				merchant_ui.close_merchant()
				handled = true
			if blacksmith_ui and blacksmith_ui.visible:
				blacksmith_ui.close_blacksmith()
				handled = true
			if inventory_ui and inventory_ui.visible:
				toggle_inventory()
				handled = true
			if skill_tree_ui and skill_tree_ui.visible:
				toggle_skill_tree()
				handled = true
			if handled:
				get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	if inventory_ui and inventory_ui.has_method("toggle_visibility"):
		if not inventory_ui.visible and skill_tree_ui and skill_tree_ui.visible:
			skill_tree_ui.toggle_visibility()
		inventory_ui.toggle_visibility()

func toggle_skill_tree() -> void:
	if skill_tree_ui and skill_tree_ui.has_method("toggle_visibility"):
		if not skill_tree_ui.visible and inventory_ui and inventory_ui.visible:
			inventory_ui.toggle_visibility()
		skill_tree_ui.toggle_visibility()

func _update_q_slot() -> void:
	if not skill_q_panel or not skill_q_label:
		return

	if SkillManager.active_q_skill == "":
		skill_q_panel.modulate = Color(0.35, 0.35, 0.35, 0.35)
		skill_q_label.text = "🔒"
	else:
		skill_q_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		match SkillManager.active_q_skill:
			"holy_hammer":
				skill_q_label.text = "🔨 Q"
			"whirlwind":
				skill_q_label.text = "🌪️ Q"
			"thunder_slam":
				skill_q_label.text = "💥 Q"
			"iron_skin":
				skill_q_label.text = "🛡️ Q"
			_:
				skill_q_label.text = "Q"

func _process(_delta: float) -> void:
	if gold_label:
		gold_label.text = "💰 " + str(Global.player_gold)

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_resource_changed(current: float, max_val: float) -> void:
	if resource_bar:
		resource_bar.max_value = max_val
		resource_bar.value = current
	if resource_label:
		resource_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_xp_changed(_current: int, _needed: int, level: int) -> void:
	if level_label:
		level_label.text = "Lv. %d - %s" % [level, Global.player_class]

func _on_boss_spawned(b_name: String, max_hp: float) -> void:
	if boss_container:
		boss_container.visible = true
		boss_container.modulate.a = 1.0
	if boss_name_label:
		boss_name_label.text = "☠ " + b_name + " ☠"
	if boss_bar:
		boss_bar.max_value = max_hp
		boss_bar.value = max_hp
	if boss_health_label:
		boss_health_label.text = "%d / %d" % [int(max_hp), int(max_hp)]

func _on_boss_health_changed(current: float, max_val: float) -> void:
	if boss_bar:
		boss_bar.max_value = max_val
		boss_bar.value = max(0.0, current)
	if boss_health_label:
		boss_health_label.text = "%d / %d" % [int(max(0.0, current)), int(max_val)]

func _on_boss_defeated() -> void:
	if boss_name_label:
		boss_name_label.text = "🏆 БОСС ПОВЕРЖЕН! 🏆"
	if boss_container:
		var tween := create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(boss_container, "modulate:a", 0.0, 1.2)
		tween.tween_callback(func():
			boss_container.visible = false
			boss_container.modulate.a = 1.0
		)

func _on_shrine_buff_changed(shrine_type: int, time_left: float) -> void:
	if not shrine_buff_label:
		return

	if shrine_type == -1 or time_left <= 0.0:
		shrine_buff_label.visible = false
		return

	shrine_buff_label.visible = true
	var secs: int = int(ceilf(time_left))
	if shrine_type == 0:
		shrine_buff_label.text = "🔥 ЯРОСТЬ: %dс (+100%% Крит, Скорость)" % secs
		shrine_buff_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
	elif shrine_type == 1:
		shrine_buff_label.text = "🛡️ ЗАЩИТА: %dс (+75 Броня, Реген)" % secs
		shrine_buff_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

func _on_floor_changed(floor_num: int, floor_name: String) -> void:
	if not floor_label:
		return
	if floor_num == 0:
		floor_label.text = "🏕️ ЛАГЕРЬ ОХОТНИКОВ (Хаб)"
		floor_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5, 1.0))
	else:
		floor_label.text = "🏰 ЭТАЖ %d: %s" % [floor_num, floor_name]
		floor_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45, 1.0))
	if is_inside_tree() and floor_num > 1:
		var tween := create_tween()
		tween.tween_property(floor_label, "scale", Vector2(1.15, 1.15), 0.2)
		tween.tween_property(floor_label, "scale", Vector2.ONE, 0.2)

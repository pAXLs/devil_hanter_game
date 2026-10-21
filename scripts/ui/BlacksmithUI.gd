class_name BlacksmithUI
extends Control

@onready var close_btn: Button = $Panel/HeaderBar/CloseButton
@onready var gold_label: Label = $Panel/HeaderBar/GoldLabel
@onready var upgrade_btn: Button = $Panel/BodyHBox/AnvilColumn/UpgradeButton
@onready var anvil_icon: Label = $Panel/BodyHBox/AnvilColumn/AnvilSlot/Icon
@onready var item_name_label: Label = $Panel/BodyHBox/AnvilColumn/ItemNameLabel
@onready var stats_preview_label: Label = $Panel/BodyHBox/AnvilColumn/StatsPreviewLabel
@onready var bag_grid: GridContainer = $Panel/BodyHBox/BagColumn/GridPanel/BagGrid
@onready var bag_capacity_label: Label = $Panel/BodyHBox/BagColumn/BagHeader/CapacityLabel

# Tooltip
@onready var tooltip_panel: Panel = $TooltipPanel
@onready var tip_title: Label = $TooltipPanel/Margin/VBox/Title
@onready var tip_type: Label = $TooltipPanel/Margin/VBox/TypeTag
@onready var tip_stats: Label = $TooltipPanel/Margin/VBox/StatsLabel
@onready var tip_desc: Label = $TooltipPanel/Margin/VBox/DescLabel
@onready var tip_hint: Label = $TooltipPanel/Margin/VBox/HintLabel

var selected_bag_idx: int = -1
var bag_slot_controls: Array[Control] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_btn:
		close_btn.pressed.connect(close_blacksmith)
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)

	Global.blacksmith_opened.connect(open_blacksmith)
	Global.blacksmith_closed.connect(close_blacksmith)
	InventoryManager.inventory_updated.connect(_refresh_ui)

	_setup_bag_grid()

func open_blacksmith() -> void:
	visible = true
	get_tree().paused = true
	selected_bag_idx = -1
	_auto_select_first_weapon()
	_refresh_ui()

func close_blacksmith() -> void:
	visible = false
	get_tree().paused = false
	if tooltip_panel:
		tooltip_panel.visible = false
	Global.blacksmith_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_blacksmith()
			get_viewport().set_input_as_handled()

func _auto_select_first_weapon() -> void:
	for i in range(InventoryManager.BAG_SIZE):
		var item = InventoryManager.bag[i]
		if item != null and item is Dictionary:
			var t: String = item.get("type", "")
			if t == "weapon" or t == "shield" or t == "armor" or t == "helm":
				selected_bag_idx = i
				return

func _setup_bag_grid() -> void:
	if not bag_grid:
		return
	for c in bag_grid.get_children():
		c.queue_free()
	bag_slot_controls.clear()

	for i in range(InventoryManager.BAG_SIZE):
		var slot_pnl := Panel.new()
		slot_pnl.custom_minimum_size = Vector2(50, 50)
		slot_pnl.mouse_filter = Control.MOUSE_FILTER_STOP

		var base_sb := StyleBoxFlat.new()
		base_sb.bg_color = Color(0.08, 0.09, 0.12, 0.9)
		base_sb.border_width_left = 1
		base_sb.border_width_top = 1
		base_sb.border_width_right = 1
		base_sb.border_width_bottom = 1
		base_sb.border_color = Color(0.25, 0.28, 0.35, 0.8)
		base_sb.corner_radius_top_left = 4
		base_sb.corner_radius_top_right = 4
		base_sb.corner_radius_bottom_right = 4
		base_sb.corner_radius_bottom_left = 4
		slot_pnl.add_theme_stylebox_override("panel", base_sb)

		var icon_lbl := Label.new()
		icon_lbl.name = "Icon"
		icon_lbl.anchors_preset = Control.PRESET_FULL_RECT
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_pnl.add_child(icon_lbl)

		var amount_lbl := Label.new()
		amount_lbl.name = "Amount"
		amount_lbl.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		amount_lbl.offset_left = -26.0
		amount_lbl.offset_top = -18.0
		amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amount_lbl.add_theme_font_size_override("font_size", 11)
		amount_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_pnl.add_child(amount_lbl)

		var idx := i
		slot_pnl.gui_input.connect(func(ev: InputEvent): _on_bag_slot_gui_input(ev, idx))
		slot_pnl.mouse_entered.connect(func(): _on_bag_slot_mouse_entered(idx, slot_pnl))
		slot_pnl.mouse_exited.connect(_on_slot_mouse_exited)

		bag_grid.add_child(slot_pnl)
		bag_slot_controls.append(slot_pnl)

func _refresh_ui() -> void:
	if gold_label:
		gold_label.text = "💰 %d" % Global.player_gold

	_update_anvil_display()
	_refresh_bag()

func _update_anvil_display() -> void:
	var item: Dictionary = {}
	if selected_bag_idx >= 0 and selected_bag_idx < InventoryManager.BAG_SIZE:
		var raw = InventoryManager.bag[selected_bag_idx]
		if raw != null and raw is Dictionary:
			item = raw

	if item.is_empty():
		anvil_icon.text = "🔨"
		item_name_label.text = "Выберите снаряжение из сумки"
		item_name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		stats_preview_label.text = "Кликните по оружию или доспеху справа, чтобы положить его на наковальню."
		upgrade_btn.disabled = true
		upgrade_btn.text = "ВЫБЕРИТЕ ПРЕДМЕТ"
		return

	anvil_icon.text = item.get("icon", "⚔️")
	var cur_lvl: int = item.get("upgrade_level", 0)
	var rar: int = item.get("rarity", 0)
	var rar_color: Color = InventoryManager.RARITY_COLORS.get(rar, Color.WHITE)

	item_name_label.text = item.get("name", "Предмет")
	item_name_label.add_theme_color_override("font_color", rar_color)

	if cur_lvl >= 5:
		stats_preview_label.text = "⭐ МАКСИМАЛЬНЫЙ УРОВЕНЬ ЗАТОЧКИ (+5)"
		upgrade_btn.disabled = true
		upgrade_btn.text = "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		return

	var cost := InventoryManager.get_upgrade_cost(item)
	var stats: Dictionary = item.get("stats", {})
	var preview_text := ""

	for k in stats.keys():
		var cur_val = stats[k]
		var next_val = round(cur_val * 1.25)
		match k:
			"damage": preview_text += "Урон: %d ➜ %d (+%d)\n" % [int(cur_val), int(next_val), int(next_val - cur_val)]
			"armor": preview_text += "Броня: %d ➜ %d (+%d)\n" % [int(cur_val), int(next_val), int(next_val - cur_val)]
			"max_hp": preview_text += "Здоровье: %d ➜ %d (+%d)\n" % [int(cur_val), int(next_val), int(next_val - cur_val)]
			"crit_chance": preview_text += "Крит: %.1f%% ➜ %.1f%%\n" % [cur_val * 100.0, next_val * 100.0]

	stats_preview_label.text = preview_text.strip_edges()

	var can_afford: bool = (Global.player_gold >= cost)
	upgrade_btn.disabled = !can_afford
	upgrade_btn.text = "🔨 ЗАТОЧИТЬ ЭКИПИРОВКУ (💰 %d)" % cost
	if not can_afford:
		upgrade_btn.text = "НЕДОСТАТОЧНО ЗОЛОТА (💰 %d)" % cost

func _on_upgrade_pressed() -> void:
	if selected_bag_idx < 0 or selected_bag_idx >= InventoryManager.BAG_SIZE:
		return
	var item = InventoryManager.bag[selected_bag_idx]
	if item == null or not (item is Dictionary):
		return

	var success := InventoryManager.upgrade_item(item)
	if success:
		AudioManager.play_hammer()
		# Punch scale effect on anvil
		var tween := create_tween()
		tween.tween_property(anvil_icon, "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(anvil_icon, "scale", Vector2.ONE, 0.1)
		_refresh_ui()

func _refresh_bag() -> void:
	if not visible:
		return

	var count := 0
	for i in range(InventoryManager.BAG_SIZE):
		var ctrl: Control = bag_slot_controls[i]
		var item = InventoryManager.bag[i]
		var icon_lbl: Label = ctrl.get_node("Icon")
		var amount_lbl: Label = ctrl.get_node("Amount")
		var sb: StyleBoxFlat = ctrl.get_theme_stylebox("panel").duplicate()

		if item != null and item is Dictionary:
			count += 1
			icon_lbl.text = item.get("icon", "📦")
			var amt: int = item.get("amount", 1)
			amount_lbl.text = ("x%d" % amt) if amt > 1 else ""

			var rar: int = item.get("rarity", 0)
			var color: Color = InventoryManager.RARITY_COLORS.get(rar, Color.WHITE)
			sb.border_color = color
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			if i == selected_bag_idx:
				sb.border_color = Color(1.0, 0.9, 0.2, 1.0)
				sb.border_width_left = 3
				sb.border_width_top = 3
				sb.border_width_right = 3
				sb.border_width_bottom = 3
				sb.shadow_color = Color(1.0, 0.8, 0.2, 0.6)
				sb.shadow_size = 8
			else:
				sb.shadow_color = Color(color.r, color.g, color.b, 0.35)
				sb.shadow_size = 5
		else:
			icon_lbl.text = ""
			amount_lbl.text = ""
			sb.border_color = Color(0.22, 0.25, 0.3, 0.7)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.shadow_size = 0

		ctrl.add_theme_stylebox_override("panel", sb)

	if bag_capacity_label:
		bag_capacity_label.text = "Сумка: %d / %d" % [count, InventoryManager.BAG_SIZE]

func _on_bag_slot_gui_input(event: InputEvent, bag_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		var item = InventoryManager.bag[bag_idx]
		if item != null and item is Dictionary:
			var t: String = item.get("type", "")
			if t == "weapon" or t == "shield" or t == "armor" or t == "helm":
				selected_bag_idx = bag_idx
				AudioManager.play_ui_click()
				_refresh_ui()

func _on_bag_slot_mouse_entered(bag_idx: int, slot_ctrl: Control) -> void:
	var item = InventoryManager.bag[bag_idx]
	if item != null and item is Dictionary:
		_show_tooltip(item, slot_ctrl)

func _on_slot_mouse_exited() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _show_tooltip(item: Dictionary, target_node: Control) -> void:
	if not tooltip_panel:
		return

	var rar: int = item.get("rarity", 0)
	var color: Color = InventoryManager.RARITY_COLORS.get(rar, Color.WHITE)

	tip_title.text = item.get("name", "Предмет")
	tip_title.add_theme_color_override("font_color", color)

	var rar_name: String = InventoryManager.RARITY_NAMES.get(rar, "")
	var type_str: String = item.get("type", "weapon").to_upper()
	tip_type.text = "%s %s" % [rar_name.to_upper(), type_str]
	tip_type.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.85))

	var stats_text := ""
	var stats: Dictionary = item.get("stats", {})
	for k in stats.keys():
		var val = stats[k]
		match k:
			"damage": stats_text += "+%d к урону оружия\n" % int(val)
			"armor": stats_text += "+%d к показателю брони\n" % int(val)
			"max_hp": stats_text += "+%d к максимальному здоровью\n" % int(val)
			"crit_chance": stats_text += "+%.1f%% к шансу критического удара\n" % (val * 100.0)
			"crit_damage": stats_text += "+%d%% к силе критического удара\n" % int(val * 100.0)

	tip_stats.text = stats_text.strip_edges()
	tip_desc.text = item.get("desc", "")
	tip_hint.text = "Кликните, чтобы положить на наковальню"

	tooltip_panel.visible = true
	var global_rect := target_node.get_global_rect()
	var pos := Vector2(global_rect.position.x - 290.0, global_rect.position.y)
	if pos.x < 10.0:
		pos.x = global_rect.end.x + 10.0
	pos.y = clampf(pos.y, 10.0, get_viewport_rect().size.y - 240.0)
	tooltip_panel.global_position = pos

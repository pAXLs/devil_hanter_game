class_name InventoryUI
extends Control

@onready var close_btn: Button = $Panel/HeaderBar/CloseButton
@onready var gold_label: Label = $Panel/HeaderBar/GoldLabel

# Character stats labels
@onready var stat_damage_label: Label = $Panel/BodyHBox/CharColumn/StatsCard/VBox/DmgRow/Val
@onready var stat_armor_label: Label = $Panel/BodyHBox/CharColumn/StatsCard/VBox/ArmorRow/Val
@onready var stat_health_label: Label = $Panel/BodyHBox/CharColumn/StatsCard/VBox/HpRow/Val
@onready var stat_crit_label: Label = $Panel/BodyHBox/CharColumn/StatsCard/VBox/CritRow/Val
@onready var stat_crit_dmg_label: Label = $Panel/BodyHBox/CharColumn/StatsCard/VBox/CritDmgRow/Val
@onready var stat_speed_label: Label = $Panel/BodyHBox/CharColumn/StatsCard/VBox/SpeedRow/Val

# Doll container & equipment slots
@onready var doll_container: Control = $Panel/BodyHBox/CharColumn/DollContainer
@onready var slot_helm: Control = $Panel/BodyHBox/CharColumn/DollContainer/SlotHelm
@onready var slot_amulet: Control = $Panel/BodyHBox/CharColumn/DollContainer/SlotAmulet
@onready var slot_armor: Control = $Panel/BodyHBox/CharColumn/DollContainer/SlotArmor
@onready var slot_weapon: Control = $Panel/BodyHBox/CharColumn/DollContainer/SlotWeapon
@onready var slot_shield: Control = $Panel/BodyHBox/CharColumn/DollContainer/SlotShield
@onready var slot_ring1: Control = $Panel/BodyHBox/CharColumn/DollContainer/SlotRing1
@onready var slot_ring2: Control = $Panel/BodyHBox/CharColumn/DollContainer/SlotRing2

# Bag grid
@onready var bag_grid: GridContainer = $Panel/BodyHBox/BagColumn/GridPanel/BagGrid
@onready var bag_capacity_label: Label = $Panel/BodyHBox/BagColumn/BagHeader/CapacityLabel

# Rich Tooltip
@onready var tooltip_panel: Panel = $TooltipPanel
@onready var tip_title: Label = $TooltipPanel/Margin/VBox/Title
@onready var tip_type: Label = $TooltipPanel/Margin/VBox/TypeTag
@onready var tip_stats: Label = $TooltipPanel/Margin/VBox/StatsLabel
@onready var tip_desc: Label = $TooltipPanel/Margin/VBox/DescLabel
@onready var tip_hint: Label = $TooltipPanel/Margin/VBox/HintLabel

var bag_slot_controls: Array[Control] = []
var equip_slot_map: Dictionary = {} # slot_name -> Control

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_btn:
		close_btn.pressed.connect(toggle_visibility)

	InventoryManager.inventory_updated.connect(_refresh_ui)
	InventoryManager.equipment_updated.connect(_refresh_ui)
	Global.player_health_changed.connect(func(_cur, _mx): _update_stats())

	_setup_equipment_slots()
	_setup_bag_grid()
	_refresh_ui()

func toggle_visibility() -> void:
	visible = !visible
	get_tree().paused = visible
	if visible:
		_refresh_ui()
	else:
		if tooltip_panel:
			tooltip_panel.visible = false

func _setup_equipment_slots() -> void:
	equip_slot_map = {
		"helm": slot_helm,
		"amulet": slot_amulet,
		"armor": slot_armor,
		"weapon": slot_weapon,
		"shield": slot_shield,
		"ring_1": slot_ring1,
		"ring_2": slot_ring2,
	}

	for slot_name in equip_slot_map.keys():
		var ctrl: Control = equip_slot_map[slot_name]
		if not ctrl:
			continue
		ctrl.gui_input.connect(_on_equip_slot_gui_input.bind(slot_name))
		ctrl.mouse_entered.connect(_on_equip_slot_mouse_entered.bind(slot_name, ctrl))
		ctrl.mouse_exited.connect(_on_slot_mouse_exited)

func _setup_bag_grid() -> void:
	for child in bag_grid.get_children():
		child.queue_free()
	bag_slot_controls.clear()

	for i in range(InventoryManager.BAG_SIZE):
		var slot_ctrl := _create_slot_control(i)
		bag_grid.add_child(slot_ctrl)
		bag_slot_controls.append(slot_ctrl)

func _create_slot_control(index: int) -> Control:
	var root := Panel.new()
	root.custom_minimum_size = Vector2(58, 58)
	root.size = Vector2(58, 58)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.25, 0.28, 0.35, 0.8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	root.add_theme_stylebox_override("panel", sb)

	var icon_lbl := Label.new()
	icon_lbl.name = "Icon"
	icon_lbl.size = Vector2(58, 58)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon_lbl)

	var amount_lbl := Label.new()
	amount_lbl.name = "Amount"
	amount_lbl.size = Vector2(54, 20)
	amount_lbl.position = Vector2(0, 36)
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_lbl.add_theme_font_size_override("font_size", 11)
	amount_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(amount_lbl)

	root.gui_input.connect(_on_bag_slot_gui_input.bind(index))
	root.mouse_entered.connect(_on_bag_slot_mouse_entered.bind(index, root))
	root.mouse_exited.connect(_on_slot_mouse_exited)

	return root

func _refresh_ui() -> void:
	_update_stats()
	_update_doll()
	_update_bag()

func _update_stats() -> void:
	if gold_label:
		gold_label.text = "💰 %d" % Global.player_gold

	var player = Global.current_player
	if not player or not is_instance_valid(player):
		return

	if stat_damage_label:
		var eff_dmg: float = player.get_effective_damage() if player.has_method("get_effective_damage") else player.attack_damage
		var bonus_dmg: float = InventoryManager.bonus_damage
		if bonus_dmg > 0.0:
			stat_damage_label.text = "%d (+%d)" % [int(eff_dmg), int(bonus_dmg)]
		else:
			stat_damage_label.text = "%d" % int(eff_dmg)

	if stat_armor_label:
		var arm: float = InventoryManager.bonus_armor
		if arm > 0.0:
			var red: float = (arm / (arm + 100.0)) * 100.0
			stat_armor_label.text = "%d (%.1f%%)" % [int(arm), red]
		else:
			stat_armor_label.text = "0 (0%)"

	if stat_health_label:
		stat_health_label.text = "%d / %d" % [int(player.health), int(player.max_health)]

	if stat_crit_label:
		var crit: float = player.get_effective_crit_chance() * 100.0 if player.has_method("get_effective_crit_chance") else 20.0
		stat_crit_label.text = "%.1f%%" % crit

	if stat_crit_dmg_label:
		var mult: float = player.get_effective_crit_mult() * 100.0 if player.has_method("get_effective_crit_mult") else 175.0
		stat_crit_dmg_label.text = "%d%%" % int(mult)

	if stat_speed_label:
		var spd: float = player.get_effective_speed() if player.has_method("get_effective_speed") else player.speed
		stat_speed_label.text = "%.1f м/с" % spd

func _update_doll() -> void:
	for slot_name in equip_slot_map.keys():
		var ctrl: Control = equip_slot_map[slot_name]
		if not ctrl:
			continue
		var item = InventoryManager.equipment.get(slot_name)
		var icon_lbl: Label = ctrl.get_node_or_null("Icon")
		var watermark_lbl: Label = ctrl.get_node_or_null("Watermark")

		var sb: StyleBoxFlat = ctrl.get_theme_stylebox("panel").duplicate()

		if item != null and item is Dictionary:
			if icon_lbl:
				icon_lbl.text = item.get("icon", "⚔️")
				icon_lbl.visible = true
			if watermark_lbl:
				watermark_lbl.visible = false

			var rar: int = item.get("rarity", 0)
			var color: Color = InventoryManager.RARITY_COLORS.get(rar, Color.WHITE)
			sb.border_color = color
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.shadow_color = Color(color.r, color.g, color.b, 0.4)
			sb.shadow_size = 6
		else:
			if icon_lbl:
				icon_lbl.text = ""
				icon_lbl.visible = false
			if watermark_lbl:
				watermark_lbl.visible = true

			sb.border_color = Color(0.25, 0.28, 0.35, 0.8)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.shadow_size = 0

		ctrl.add_theme_stylebox_override("panel", sb)

func _update_bag() -> void:
	var occupied_count: int = 0
	for i in range(InventoryManager.BAG_SIZE):
		if i >= bag_slot_controls.size():
			continue
		var ctrl := bag_slot_controls[i]
		var item = InventoryManager.bag[i]
		var icon_lbl: Label = ctrl.get_node("Icon")
		var amount_lbl: Label = ctrl.get_node("Amount")

		var sb: StyleBoxFlat = ctrl.get_theme_stylebox("panel").duplicate()

		if item != null and item is Dictionary:
			occupied_count += 1
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
			sb.shadow_color = Color(color.r, color.g, color.b, 0.35)
			sb.shadow_size = 6
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
		bag_capacity_label.text = "Вместимость: %d / %d" % [occupied_count, InventoryManager.BAG_SIZE]

# Input interactions
func _on_bag_slot_gui_input(event: InputEvent, bag_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# RMB: Use potion or Equip gear
			var used := InventoryManager.use_item_at(bag_idx)
			if used:
				if tooltip_panel:
					tooltip_panel.visible = false

func _on_equip_slot_gui_input(event: InputEvent, slot_name: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# RMB on equipment doll: unequip back to bag
			var unequipped := InventoryManager.unequip_slot_to_bag(slot_name)
			if unequipped:
				if tooltip_panel:
					tooltip_panel.visible = false

# Tooltips
func _on_bag_slot_mouse_entered(bag_idx: int, slot_ctrl: Control) -> void:
	if bag_idx < 0 or bag_idx >= InventoryManager.bag.size():
		return
	var item = InventoryManager.bag[bag_idx]
	if item != null and item is Dictionary:
		_show_item_tooltip(item, slot_ctrl, false)

func _on_equip_slot_mouse_entered(slot_name: String, slot_ctrl: Control) -> void:
	var item = InventoryManager.equipment.get(slot_name)
	if item != null and item is Dictionary:
		_show_item_tooltip(item, slot_ctrl, true)

func _on_slot_mouse_exited() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _show_item_tooltip(item: Dictionary, target_node: Control, is_doll_slot: bool) -> void:
	if not tooltip_panel or not is_instance_valid(target_node):
		return

	var rar: int = item.get("rarity", 0)
	var rar_color: Color = InventoryManager.RARITY_COLORS.get(rar, Color.WHITE)
	var rar_name: String = InventoryManager.RARITY_NAMES.get(rar, "Обычный")

	tip_title.text = item.get("name", "Предмет")
	tip_title.add_theme_color_override("font_color", rar_color)

	var type_str: String = item.get("type", "")
	var type_readable := "Снаряжение"
	match type_str:
		InventoryManager.TYPE_WEAPON: type_readable = "Оружие (Основная рука)"
		InventoryManager.TYPE_SHIELD: type_readable = "Щит (Вторая рука)"
		InventoryManager.TYPE_ARMOR: type_readable = "Доспех (Тело)"
		InventoryManager.TYPE_HELM: type_readable = "Шлем (Голова)"
		InventoryManager.TYPE_AMULET: type_readable = "Амулет (Шея)"
		InventoryManager.TYPE_RING: type_readable = "Кольцо"
		InventoryManager.TYPE_POTION: type_readable = "Зелье (Расходник)"

	tip_type.text = "◆ %s • %s" % [type_readable, rar_name]

	# Build Stats text
	var stats: Dictionary = item.get("stats", {})
	var stat_lines: Array[String] = []

	if stats.has("damage"):
		stat_lines.append("⚔️ +%d к Урону оружия" % int(stats["damage"]))
	if stats.has("armor"):
		stat_lines.append("🛡️ +%d к Броне" % int(stats["armor"]))
	if stats.has("max_hp"):
		stat_lines.append("❤️ +%d к Макс. Здоровью" % int(stats["max_hp"]))
	if stats.has("crit_chance"):
		stat_lines.append("🎯 +%.1f%% Шанс крит. удара" % (stats["crit_chance"] * 100.0))
	if stats.has("crit_damage"):
		stat_lines.append("💥 +%d%% Крит. урон" % int(stats["crit_damage"] * 100.0))
	if stats.has("move_speed"):
		stat_lines.append("⚡ +%d%% Скорость бега" % int(stats["move_speed"] * 100.0))
	if stats.has("heal"):
		stat_lines.append("🧪 Восстанавливает %d HP" % int(stats["heal"]))

	tip_stats.text = "\n".join(stat_lines) if stat_lines.size() > 0 else "Нет дополнительных свойств."

	# Description
	tip_desc.text = item.get("desc", "")
	tip_desc.visible = (tip_desc.text != "")

	# Interaction hint
	if is_doll_slot:
		tip_hint.text = "[ПКМ] Снять предмет в сумку"
	else:
		if type_str == InventoryManager.TYPE_POTION:
			tip_hint.text = "[ПКМ] Выпить зелье (+%d HP)" % int(stats.get("heal", 45))
		else:
			tip_hint.text = "[ПКМ] Экипировать снаряжение"

	tooltip_panel.visible = true

	# Position tooltip intelligently
	var global_slot_pos := target_node.global_position
	var slot_size := target_node.size
	var tip_size := tooltip_panel.size

	var target_x: float = global_slot_pos.x + slot_size.x + 12.0
	if target_x + tip_size.x > get_viewport_rect().size.x - 10.0:
		target_x = global_slot_pos.x - tip_size.x - 12.0

	var target_y: float = clampf(global_slot_pos.y - 10.0, 10.0, get_viewport_rect().size.y - tip_size.y - 10.0)
	tooltip_panel.global_position = Vector2(target_x, target_y)

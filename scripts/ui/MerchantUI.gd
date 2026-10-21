class_name MerchantUI
extends Control

@onready var close_btn: Button = $Panel/HeaderBar/CloseButton
@onready var gold_label: Label = $Panel/HeaderBar/GoldLabel
@onready var shop_vbox: VBoxContainer = $Panel/BodyHBox/ShopColumn/Scroll/ShopList
@onready var bag_grid: GridContainer = $Panel/BodyHBox/BagColumn/GridPanel/BagGrid
@onready var bag_capacity_label: Label = $Panel/BodyHBox/BagColumn/BagHeader/CapacityLabel

# Tooltip
@onready var tooltip_panel: Panel = $TooltipPanel
@onready var tip_title: Label = $TooltipPanel/Margin/VBox/Title
@onready var tip_type: Label = $TooltipPanel/Margin/VBox/TypeTag
@onready var tip_stats: Label = $TooltipPanel/Margin/VBox/StatsLabel
@onready var tip_desc: Label = $TooltipPanel/Margin/VBox/DescLabel
@onready var tip_hint: Label = $TooltipPanel/Margin/VBox/HintLabel

var bag_slot_controls: Array[Control] = []

var merchant_stock: Array[Dictionary] = [
	{
		"name": "Зелье Здоровья (1 шт)",
		"type": "potion",
		"rarity": 1,
		"icon": "🧪",
		"stats": {"heal": 45.0},
		"desc": "Восстанавливает 45 ед. здоровья.",
		"price": 30,
		"amount": 1
	},
	{
		"name": "Связка Зелий (3 шт)",
		"type": "potion",
		"rarity": 1,
		"icon": "🧪",
		"stats": {"heal": 45.0},
		"desc": "Связка из трех лечебных зелий.",
		"price": 75,
		"amount": 3
	},
	{
		"name": "Стальной Палаш",
		"type": "weapon",
		"rarity": 1,
		"icon": "⚔️",
		"stats": {"damage": 20.0, "crit_chance": 0.06},
		"desc": "Острый палаш городской стражи.",
		"price": 110,
		"amount": 1
	},
	{
		"name": "Железный Оплот",
		"type": "shield",
		"rarity": 1,
		"icon": "🛡️",
		"stats": {"armor": 26.0, "max_hp": 30.0},
		"desc": "Массивный щит, отражающий стрелы и топоры.",
		"price": 120,
		"amount": 1
	},
	{
		"name": "Кираса Охотника",
		"type": "armor",
		"rarity": 1,
		"icon": "🥋",
		"stats": {"armor": 30.0, "max_hp": 35.0},
		"desc": "Закаленная кираса из темного металла.",
		"price": 130,
		"amount": 1
	},
	{
		"name": "Перстень Защиты",
		"type": "ring",
		"rarity": 2,
		"icon": "💍",
		"stats": {"armor": 18.0, "max_hp": 25.0},
		"desc": "Магическое кольцо, ограждающее носителя аурой.",
		"price": 160,
		"amount": 1
	}
]

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_btn:
		close_btn.pressed.connect(close_merchant)

	Global.merchant_opened.connect(open_merchant)
	Global.merchant_closed.connect(close_merchant)
	InventoryManager.inventory_updated.connect(_refresh_bag)

	_setup_shop_items()
	_setup_bag_grid()

func open_merchant() -> void:
	visible = true
	get_tree().paused = true
	_refresh_ui()

func close_merchant() -> void:
	visible = false
	get_tree().paused = false
	if tooltip_panel:
		tooltip_panel.visible = false
	Global.merchant_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_merchant()
			get_viewport().set_input_as_handled()

func _setup_shop_items() -> void:
	if not shop_vbox:
		return

	for c in shop_vbox.get_children():
		c.queue_free()

	for it in merchant_stock:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 52)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.09, 0.12, 0.9)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.3, 0.35, 0.45, 0.7)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_right = 6
		sb.corner_radius_bottom_left = 6
		row.add_theme_stylebox_override("panel", sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)

		var icon_lbl := Label.new()
		icon_lbl.text = it.get("icon", "📦")
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.custom_minimum_size = Vector2(36, 0)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(icon_lbl)

		var name_vbox := VBoxContainer.new()
		name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_vbox)

		var title_lbl := Label.new()
		title_lbl.text = it.get("name", "")
		var rar: int = it.get("rarity", 0)
		title_lbl.add_theme_color_override("font_color", InventoryManager.RARITY_COLORS.get(rar, Color.WHITE))
		title_lbl.add_theme_font_size_override("font_size", 13)
		name_vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = it.get("desc", "")
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75, 0.8))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		name_vbox.add_child(desc_lbl)

		var price: int = it.get("price", 50)
		var buy_btn := Button.new()
		buy_btn.text = "💰 %d" % price
		buy_btn.custom_minimum_size = Vector2(80, 34)
		buy_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		var it_data := it
		buy_btn.pressed.connect(func(): _buy_item(it_data))
		hbox.add_child(buy_btn)

		shop_vbox.add_child(row)

func _buy_item(item_info: Dictionary) -> void:
	var price: int = item_info.get("price", 50)
	if Global.player_gold < price:
		AudioManager.play_ui_click()
		return

	var is_potion: bool = (item_info.get("type") == "potion")
	var new_item := InventoryManager.create_item(
		"shop_" + str(randi() % 100000),
		item_info.get("name", "Товар"),
		item_info.get("type", "weapon"),
		item_info.get("rarity", 1),
		item_info.get("icon", "📦"),
		item_info.get("stats", {}),
		item_info.get("desc", ""),
		item_info.get("amount", 1)
	)

	var success := InventoryManager.add_item(new_item)
	if success:
		Global.player_gold -= price
		AudioManager.play_gold()
		_refresh_ui()

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
	_refresh_bag()

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
		bag_capacity_label.text = "Сумка: %d / %d" % [count, InventoryManager.BAG_SIZE]

func _on_bag_slot_gui_input(event: InputEvent, bag_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Sell item to merchant!
			_sell_bag_item(bag_idx)

func _sell_bag_item(bag_idx: int) -> void:
	var item = InventoryManager.bag[bag_idx]
	if item == null or not (item is Dictionary):
		return

	var sell_price := InventoryManager.get_item_sell_price(item)
	InventoryManager.bag[bag_idx] = null
	Global.player_gold += sell_price
	AudioManager.play_gold()

	if tooltip_panel:
		tooltip_panel.visible = false

	InventoryManager.inventory_updated.emit()
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
			"heal": stats_text += "+%d мгновенного исцеления\n" % int(val)

	tip_stats.text = stats_text.strip_edges()
	tip_desc.text = item.get("desc", "")

	var price: int = InventoryManager.get_item_sell_price(item)
	tip_hint.text = "💰 Цена продажи: %d золота. [ПКМ] Продать" % price
	tip_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	tooltip_panel.visible = true
	var global_rect := target_node.get_global_rect()
	var pos := Vector2(global_rect.position.x - 290.0, global_rect.position.y)
	if pos.x < 10.0:
		pos.x = global_rect.end.x + 10.0
	pos.y = clampf(pos.y, 10.0, get_viewport_rect().size.y - 240.0)
	tooltip_panel.global_position = pos

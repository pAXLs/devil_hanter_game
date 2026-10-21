class_name StashUI
extends Control

@onready var close_btn: Button = $Panel/HeaderBar/CloseButton
@onready var stash_grid: GridContainer = $Panel/GridPanel/StashGrid
@onready var capacity_label: Label = $Panel/HeaderBar/CapacityLabel

# Tooltip
@onready var tooltip_panel: Panel = $TooltipPanel
@onready var tip_title: Label = $TooltipPanel/Margin/VBox/Title
@onready var tip_type: Label = $TooltipPanel/Margin/VBox/TypeTag
@onready var tip_stats: Label = $TooltipPanel/Margin/VBox/StatsLabel
@onready var tip_desc: Label = $TooltipPanel/Margin/VBox/DescLabel
@onready var tip_hint: Label = $TooltipPanel/Margin/VBox/HintLabel

var slot_controls: Array[Control] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_btn:
		close_btn.pressed.connect(close_stash)

	Global.stash_opened.connect(open_stash)
	Global.stash_closed.connect(close_stash)
	InventoryManager.stash_updated.connect(_refresh_ui)

	_setup_stash_grid()

func open_stash() -> void:
	visible = true
	get_tree().paused = true
	_refresh_ui()

func close_stash() -> void:
	visible = false
	if tooltip_panel:
		tooltip_panel.visible = false
	# If inventory is not separately open, unpause
	var inv = get_parent().get_node_or_null("InventoryUI")
	if inv and not inv.visible:
		get_tree().paused = false
	elif not inv:
		get_tree().paused = false
	Global.stash_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_stash()
			get_viewport().set_input_as_handled()

func _setup_stash_grid() -> void:
	if not stash_grid:
		return

	for child in stash_grid.get_children():
		child.queue_free()
	slot_controls.clear()

	for i in range(InventoryManager.STASH_SIZE):
		var slot_pnl := Panel.new()
		slot_pnl.custom_minimum_size = Vector2(50, 50)
		slot_pnl.mouse_filter = Control.MOUSE_FILTER_STOP

		var base_sb := StyleBoxFlat.new()
		base_sb.bg_color = Color(0.08, 0.09, 0.12, 0.95)
		base_sb.border_width_left = 1
		base_sb.border_width_top = 1
		base_sb.border_width_right = 1
		base_sb.border_width_bottom = 1
		base_sb.border_color = Color(0.22, 0.25, 0.32, 0.8)
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
		slot_pnl.gui_input.connect(func(ev: InputEvent): _on_slot_gui_input(ev, idx))
		slot_pnl.mouse_entered.connect(func(): _on_slot_mouse_entered(idx, slot_pnl))
		slot_pnl.mouse_exited.connect(func(): _on_slot_mouse_exited())

		stash_grid.add_child(slot_pnl)
		slot_controls.append(slot_pnl)

func _refresh_ui() -> void:
	if not visible:
		return

	var occupied := 0
	for i in range(InventoryManager.STASH_SIZE):
		var ctrl: Control = slot_controls[i]
		var item = InventoryManager.stash[i]
		var icon_lbl: Label = ctrl.get_node("Icon")
		var amount_lbl: Label = ctrl.get_node("Amount")

		var sb: StyleBoxFlat = ctrl.get_theme_stylebox("panel").duplicate()

		if item != null and item is Dictionary:
			occupied += 1
			icon_lbl.text = item.get("icon", "📦")
			var amt: int = item.get("amount", 1)
			amount_lbl.text = str(amt) if amt > 1 else ""

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
			sb.border_color = Color(0.22, 0.25, 0.32, 0.8)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.shadow_size = 0

		ctrl.add_theme_stylebox_override("panel", sb)

	if capacity_label:
		capacity_label.text = "Вместимость: %d / %d" % [occupied, InventoryManager.STASH_SIZE]

func _on_slot_gui_input(event: InputEvent, stash_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# RMB: move from stash to player inventory bag!
			var moved: bool = InventoryManager.move_stash_to_bag(stash_idx)
			if moved:
				if tooltip_panel:
					tooltip_panel.visible = false

func _on_slot_mouse_entered(stash_idx: int, slot_ctrl: Control) -> void:
	var item = InventoryManager.stash[stash_idx]
	if item != null and item is Dictionary:
		_show_tooltip(item, slot_ctrl)

func _on_slot_mouse_exited() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _show_tooltip(item: Dictionary, anchor_node: Control) -> void:
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
			"move_speed": stats_text += "+%.1f м/с к скорости передвижения\n" % val
			"heal": stats_text += "+%d мгновенного исцеления\n" % int(val)

	tip_stats.text = stats_text.strip_edges()
	tip_desc.text = item.get("description", "")
	tip_hint.text = "ПКМ — переложить в сумку персонажа"

	tooltip_panel.visible = true
	var global_rect := anchor_node.get_global_rect()
	var pos := Vector2(global_rect.position.x - 290.0, global_rect.position.y)
	if pos.x < 10.0:
		pos.x = global_rect.end.x + 10.0
	pos.y = clampf(pos.y, 10.0, get_viewport_rect().size.y - 240.0)
	tooltip_panel.global_position = pos

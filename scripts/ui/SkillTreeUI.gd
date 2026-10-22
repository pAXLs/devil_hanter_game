class_name SkillTreeUI
extends Control

@onready var points_label: Label = $Panel/HeaderBar/PointsLabel
@onready var reset_btn: Button = $Panel/HeaderBar/ResetButton
@onready var close_btn: Button = $Panel/HeaderBar/CloseButton
@onready var tree_container: Control = $Panel/TreeContainer
@onready var tracks_canvas: Control = $Panel/TreeContainer/TracksCanvas
@onready var nodes_container: Control = $Panel/TreeContainer/NodesContainer
@onready var tooltip_panel: Panel = $TooltipPanel
@onready var tip_title: Label = $TooltipPanel/Margin/VBox/Title
@onready var tip_type: Label = $TooltipPanel/Margin/VBox/TypeTag
@onready var tip_rank: Label = $TooltipPanel/Margin/VBox/RankLabel
@onready var tip_desc: Label = $TooltipPanel/Margin/VBox/DescLabel
@onready var tip_stat: Label = $TooltipPanel/Margin/VBox/StatLabel
@onready var tip_hint: Label = $TooltipPanel/Margin/VBox/HintLabel

var node_controls: Dictionary = {} # id -> Control
var hovered_skill_id: String = ""
var hub_pos: Vector2 = Vector2(480, 275)

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_btn:
		close_btn.pressed.connect(toggle_visibility)
	if reset_btn:
		reset_btn.pressed.connect(_on_reset_pressed)

	SkillManager.skill_points_changed.connect(func(_pts): _refresh_ui())
	SkillManager.skills_updated.connect(_refresh_ui)
	Global.class_changed.connect(_on_class_changed)

	if tracks_canvas:
		tracks_canvas.draw.connect(_on_tracks_draw)

	_build_tree()
	_refresh_ui()

func _on_class_changed(_new_class: String) -> void:
	_build_tree()
	_refresh_ui()

func toggle_visibility() -> void:
	visible = !visible
	get_tree().paused = visible
	if visible:
		_refresh_ui()
	else:
		if tooltip_panel:
			tooltip_panel.visible = false

func _build_tree() -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	node_controls.clear()

	# Create Central Hub Crest (Hero Emblem)
	var hub := _create_hub_crest()
	nodes_container.add_child(hub)

	# Create all skill nodes from definitions
	for id in SkillManager.skill_defs.keys():
		var def: Dictionary = SkillManager.skill_defs[id]
		var node_ctrl := _create_skill_node(id, def)
		nodes_container.add_child(node_ctrl)
		node_controls[id] = node_ctrl

func _create_hub_crest() -> Control:
	var hub := Control.new()
	hub.custom_minimum_size = Vector2(80, 80)
	hub.size = Vector2(80, 80)
	hub.position = hub_pos - Vector2(40, 40)
	hub.mouse_filter = Control.MOUSE_FILTER_PASS

	var bg := Panel.new()
	bg.size = Vector2(60, 60)
	bg.position = Vector2(10, 10)
	bg.rotation_degrees = 45.0
	bg.pivot_offset = Vector2(30, 30)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.shadow_size = 12

	var emblem_icon: String = "⚔️"
	var emblem_name: String = "ВОИТЕЛЬ"
	var text_color: Color = Color(1.0, 0.85, 0.4)

	match Global.current_class:
		"rogue":
			sb.bg_color = Color(0.06, 0.12, 0.08, 0.95)
			sb.border_color = Color(0.2, 0.85, 0.45, 1.0)
			sb.shadow_color = Color(0.1, 0.6, 0.2, 0.6)
			emblem_icon = "🏹"
			emblem_name = "ЛОВКАЧ"
			text_color = Color(0.4, 1.0, 0.6)
		"mage":
			sb.bg_color = Color(0.10, 0.06, 0.16, 0.95)
			sb.border_color = Color(0.65, 0.35, 1.0, 1.0)
			sb.shadow_color = Color(0.5, 0.2, 0.9, 0.6)
			emblem_icon = "🔮"
			emblem_name = "МАГ"
			text_color = Color(0.75, 0.6, 1.0)
		_:
			sb.bg_color = Color(0.12, 0.08, 0.08, 0.95)
			sb.border_color = Color(0.85, 0.65, 0.22, 1.0)
			sb.shadow_color = Color(0.85, 0.2, 0.1, 0.6)
			emblem_icon = "⚔️"
			emblem_name = "ВОИТЕЛЬ"
			text_color = Color(1.0, 0.85, 0.4)

	bg.add_theme_stylebox_override("panel", sb)
	hub.add_child(bg)

	var icon := Label.new()
	icon.text = emblem_icon
	icon.size = Vector2(80, 40)
	icon.position = Vector2(0, 12)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = emblem_name
	name_lbl.size = Vector2(80, 20)
	name_lbl.position = Vector2(0, 48)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", text_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub.add_child(name_lbl)

	return hub

func _create_skill_node(id: String, def: Dictionary) -> Control:
	var shape: String = def["shape"]
	var node := Control.new()
	var base_size := Vector2(56, 56) if shape == "square" else (Vector2(44, 44) if shape == "circle" else Vector2(40, 40))
	node.custom_minimum_size = base_size
	node.size = base_size
	node.position = hub_pos + (def["pos"] as Vector2) - (base_size / 2.0)
	node.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background Panel
	var bg := Panel.new()
	bg.name = "Background"
	bg.size = base_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shape == "diamond":
		bg.rotation_degrees = 45.0
		bg.pivot_offset = base_size / 2.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.25, 0.28, 0.35, 0.8)

	if shape == "circle":
		var r := int(base_size.x / 2.0)
		sb.corner_radius_top_left = r
		sb.corner_radius_top_right = r
		sb.corner_radius_bottom_right = r
		sb.corner_radius_bottom_left = r
	elif shape == "square":
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_right = 6
		sb.corner_radius_bottom_left = 6

	bg.add_theme_stylebox_override("panel", sb)
	node.add_child(bg)

	# Icon
	var icon := Label.new()
	icon.name = "Icon"
	icon.text = def["icon"]
	icon.size = base_size
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 20 if shape != "diamond" else 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(icon)

	# [Q] equipped badge
	if def["type"] == "active":
		var q_badge := Label.new()
		q_badge.name = "QBadge"
		q_badge.text = "[Q]"
		q_badge.size = Vector2(24, 14)
		q_badge.position = Vector2(2, 2)
		q_badge.add_theme_font_size_override("font_size", 9)
		q_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		q_badge.visible = false
		q_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(q_badge)

	# Rank Pill below node
	var pill := Panel.new()
	pill.name = "RankPill"
	pill.size = Vector2(34, 15)
	pill.position = Vector2((base_size.x - 34) / 2.0, base_size.y + 3)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.04, 0.05, 0.07, 0.95)
	pill_sb.border_width_left = 1
	pill_sb.border_width_top = 1
	pill_sb.border_width_right = 1
	pill_sb.border_width_bottom = 1
	pill_sb.border_color = Color(0.25, 0.3, 0.4, 0.6)
	pill_sb.corner_radius_top_left = 4
	pill_sb.corner_radius_top_right = 4
	pill_sb.corner_radius_bottom_right = 4
	pill_sb.corner_radius_bottom_left = 4
	pill.add_theme_stylebox_override("panel", pill_sb)

	var rank_lbl := Label.new()
	rank_lbl.name = "RankLabel"
	rank_lbl.text = "0/%d" % def["max_rank"]
	rank_lbl.size = pill.size
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", 9)
	rank_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(rank_lbl)

	node.add_child(pill)

	# Input & Hover signals
	node.gui_input.connect(func(ev: InputEvent): _on_node_gui_input(ev, id))
	node.mouse_entered.connect(func(): _on_node_mouse_entered(id, node))
	node.mouse_exited.connect(func(): _on_node_mouse_exited(id))

	return node

func _on_node_gui_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if SkillManager.can_upgrade_skill(id):
				SkillManager.upgrade_skill(id)
				_update_tooltip(id)
			elif SkillManager.skill_defs[id]["type"] == "active" and SkillManager.get_skill_rank(id) > 0:
				SkillManager.set_active_q_skill(id)
				_update_tooltip(id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if SkillManager.can_refund_skill(id):
				SkillManager.refund_skill(id)
				_update_tooltip(id)

func _on_node_mouse_entered(id: String, node_ctrl: Control) -> void:
	hovered_skill_id = id
	_update_tooltip(id)
	if tooltip_panel:
		tooltip_panel.visible = true
		# Position tooltip beside the node, clamped to screen
		var node_global_pos := node_ctrl.global_position
		var tip_x := node_global_pos.x + node_ctrl.size.x + 12
		var tip_y := node_global_pos.y - 30

		var vp_size := get_viewport_rect().size
		if tip_x + tooltip_panel.size.x > vp_size.x - 20:
			tip_x = node_global_pos.x - tooltip_panel.size.x - 12
		tip_y = clampf(tip_y, 20.0, vp_size.y - tooltip_panel.size.y - 20.0)

		tooltip_panel.global_position = Vector2(tip_x, tip_y)

func _on_node_mouse_exited(id: String) -> void:
	if hovered_skill_id == id:
		hovered_skill_id = ""
		if tooltip_panel:
			tooltip_panel.visible = false

func _update_tooltip(id: String) -> void:
	if not SkillManager.skill_defs.has(id):
		return
	var def: Dictionary = SkillManager.skill_defs[id]
	var rank: int = SkillManager.get_skill_rank(id)
	var max_r: int = def["max_rank"]
	var type_str: String = def["type"]

	tip_title.text = "%s %s" % [def["icon"], def["name"]]
	match type_str:
		"active":
			tip_type.text = "[АКТИВНОЕ УМЕНИЕ (Q)]"
			tip_type.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		"upgrade":
			tip_type.text = "[МОДИФИКАТОР НАВЫКА]"
			tip_type.add_theme_color_override("font_color", Color(0.35, 0.75, 0.95))
		"passive":
			tip_type.text = "[ПАССИВНОЕ СВОЙСТВО]"
			tip_type.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))

	tip_rank.text = "Ранг: %d / %d" % [rank, max_r]
	tip_desc.text = def["desc"]
	tip_stat.text = def["stat_desc"]

	var hint_text := ""
	if SkillManager.can_upgrade_skill(id):
		hint_text += "[ЛКМ] Вложить очко"
	elif type_str == "active" and rank > 0:
		if SkillManager.active_q_skill == id:
			hint_text += "★ Назначено на [Q]"
		else:
			hint_text += "[ЛКМ] Назначить на [Q]"

	if SkillManager.can_refund_skill(id):
		if hint_text != "":
			hint_text += "  •  "
		hint_text += "[ПКМ] Сбросить очко"

	if hint_text == "":
		if rank >= max_r:
			hint_text = "★ Максимальный ранг"
		else:
			hint_text = "🔒 Требуется открыть предыдущий узел"

	tip_hint.text = hint_text

func _on_reset_pressed() -> void:
	SkillManager.reset_all_skills()
	_refresh_ui()

func _refresh_ui() -> void:
	if points_label:
		points_label.text = "◆ Доступно очков: %d    |    Потрачено: %d" % [
			SkillManager.available_skill_points,
			SkillManager.total_points_spent
		]

	for id in node_controls.keys():
		var node: Control = node_controls[id]
		var def: Dictionary = SkillManager.skill_defs[id]
		var rank: int = SkillManager.get_skill_rank(id)
		var max_r: int = def["max_rank"]
		var can_up: bool = SkillManager.can_upgrade_skill(id)
		var shape: String = def["shape"]

		var bg: Panel = node.get_node("Background") as Panel
		var pill: Panel = node.get_node("RankPill") as Panel
		var rank_lbl: Label = pill.get_node("RankLabel") as Label

		rank_lbl.text = "%d/%d" % [rank, max_r]

		var sb: StyleBoxFlat = bg.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if rank > 0:
			if shape == "square":
				sb.border_color = Color(0.9, 0.65, 0.15, 1.0) # Gold active
				sb.bg_color = Color(0.2, 0.08, 0.08, 0.95)
			elif shape == "diamond":
				sb.border_color = Color(0.2, 0.8, 0.95, 1.0) # Cyan upgrade
				sb.bg_color = Color(0.06, 0.14, 0.2, 0.95)
			else:
				sb.border_color = Color(0.3, 0.9, 0.45, 1.0) # Green passive
				sb.bg_color = Color(0.06, 0.16, 0.09, 0.95)
			rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		elif can_up:
			sb.border_color = Color(0.95, 0.85, 0.35, 0.9)
			sb.bg_color = Color(0.14, 0.15, 0.18, 0.95)
			rank_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		else:
			sb.border_color = Color(0.22, 0.25, 0.32, 0.6)
			sb.bg_color = Color(0.07, 0.08, 0.1, 0.9)
			rank_lbl.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55))

		bg.add_theme_stylebox_override("panel", sb)

		if node.has_node("QBadge"):
			var q_badge: Label = node.get_node("QBadge") as Label
			q_badge.visible = (SkillManager.active_q_skill == id)

	if tracks_canvas:
		tracks_canvas.queue_redraw()

	if hovered_skill_id != "":
		_update_tooltip(hovered_skill_id)

func _on_tracks_draw() -> void:
	if not tracks_canvas:
		return

	# Draw tracks connecting nodes
	for id in SkillManager.skill_defs.keys():
		var def: Dictionary = SkillManager.skill_defs[id]
		var start_pt := hub_pos
		var prereq: String = def["prereq"]
		if prereq != "" and SkillManager.skill_defs.has(prereq):
			start_pt = hub_pos + (SkillManager.skill_defs[prereq]["pos"] as Vector2)

		var end_pt: Vector2 = hub_pos + (def["pos"] as Vector2)
		var is_unlocked: bool = SkillManager.get_skill_rank(id) > 0

		if is_unlocked:
			# Diablo 4 glowing crimson blood track
			tracks_canvas.draw_line(start_pt, end_pt, Color(0.1, 0.02, 0.02, 1.0), 9.0) # Dark outer rim
			tracks_canvas.draw_line(start_pt, end_pt, Color(0.85, 0.08, 0.15, 0.85), 5.0) # Fiery red glow
			tracks_canvas.draw_line(start_pt, end_pt, Color(1.0, 0.5, 0.6, 0.95), 2.0) # Bright inner core
		else:
			# Dark steel / iron rail
			tracks_canvas.draw_line(start_pt, end_pt, Color(0.08, 0.09, 0.12, 1.0), 7.0) # Dark casing
			tracks_canvas.draw_line(start_pt, end_pt, Color(0.18, 0.22, 0.28, 0.8), 3.0) # Steel rail

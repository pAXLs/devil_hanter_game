class_name ClassSelectionUI
extends Control

signal class_selected(class_id: String)

@onready var modal_panel: Panel = $CenterContainer/ModalPanel
@onready var close_button: Button = $CenterContainer/ModalPanel/Header/CloseButton

# Cards
@onready var card_warrior: Panel = $CenterContainer/ModalPanel/CardsHBox/CardWarrior
@onready var card_rogue: Panel = $CenterContainer/ModalPanel/CardsHBox/CardRogue
@onready var card_mage: Panel = $CenterContainer/ModalPanel/CardsHBox/CardMage

@onready var btn_warrior: Button = $CenterContainer/ModalPanel/CardsHBox/CardWarrior/VBox/SelectButton
@onready var btn_rogue: Button = $CenterContainer/ModalPanel/CardsHBox/CardRogue/VBox/SelectButton
@onready var btn_mage: Button = $CenterContainer/ModalPanel/CardsHBox/CardMage/VBox/SelectButton

@onready var badge_warrior: Label = $CenterContainer/ModalPanel/CardsHBox/CardWarrior/VBox/CurrentBadge
@onready var badge_rogue: Label = $CenterContainer/ModalPanel/CardsHBox/CardRogue/VBox/CurrentBadge
@onready var badge_mage: Label = $CenterContainer/ModalPanel/CardsHBox/CardMage/VBox/CurrentBadge

var is_animating: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_button:
		close_button.pressed.connect(close_ui)

	if btn_warrior:
		btn_warrior.pressed.connect(func(): _on_class_button_pressed(Global.CLASS_WARRIOR))
	if btn_rogue:
		btn_rogue.pressed.connect(func(): _on_class_button_pressed(Global.CLASS_ROGUE))
	if btn_mage:
		btn_mage.pressed.connect(func(): _on_class_button_pressed(Global.CLASS_MAGE))

	Global.open_class_selection.connect(open_ui)
	Global.class_changed.connect(_on_global_class_changed)

func open_ui() -> void:
	if is_animating or visible:
		return

	visible = true
	get_tree().paused = true
	_update_cards_state()

	# Animated entrance
	is_animating = true
	modulate.a = 0.0
	if modal_panel:
		modal_panel.scale = Vector2(0.9, 0.9)
		modal_panel.pivot_offset = modal_panel.size / 2.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if modal_panel:
		tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): is_animating = false)

func close_ui() -> void:
	if not visible or is_animating:
		return

	is_animating = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if modal_panel:
		tween.tween_property(modal_panel, "scale", Vector2(0.92, 0.92), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		visible = false
		get_tree().paused = false
		is_animating = false
	)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_ui()
			get_viewport().set_input_as_handled()

func _on_global_class_changed(_new_class: String) -> void:
	if visible:
		_update_cards_state()

func _on_class_button_pressed(class_id: String) -> void:
	AudioManager.play_ui_click()
	AudioManager.play_equip()

	Global.set_character_class(class_id)
	InventoryManager.switch_class_starter_equipment(class_id)

	class_selected.emit(class_id)
	close_ui()

func _update_cards_state() -> void:
	var cur := Global.current_class
	_setup_card(card_warrior, btn_warrior, badge_warrior, cur == Global.CLASS_WARRIOR, Color(0.95, 0.25, 0.25, 1.0))
	_setup_card(card_rogue, btn_rogue, badge_rogue, cur == Global.CLASS_ROGUE, Color(0.35, 0.95, 0.35, 1.0))
	_setup_card(card_mage, btn_mage, badge_mage, cur == Global.CLASS_MAGE, Color(0.25, 0.65, 1.0, 1.0))

func _setup_card(card: Panel, btn: Button, badge: Label, is_current: bool, accent_color: Color) -> void:
	if not card or not btn:
		return

	if badge:
		badge.visible = is_current

	var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
	if sb:
		var dup_sb := sb.duplicate() as StyleBoxFlat
		if is_current:
			dup_sb.border_color = Color(1.0, 0.85, 0.25, 1.0) # Gold active highlight
			dup_sb.border_width_left = 3
			dup_sb.border_width_top = 3
			dup_sb.border_width_right = 3
			dup_sb.border_width_bottom = 3
			dup_sb.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
			dup_sb.shadow_size = 12
		else:
			dup_sb.border_color = accent_color.lerp(Color(0.2, 0.2, 0.2), 0.5)
			dup_sb.border_width_left = 2
			dup_sb.border_width_top = 2
			dup_sb.border_width_right = 2
			dup_sb.border_width_bottom = 2
			dup_sb.shadow_color = Color(0, 0, 0, 0.5)
			dup_sb.shadow_size = 6
		card.add_theme_stylebox_override("panel", dup_sb)

	if is_current:
		btn.text = "✓ Текущий класс"
		btn.disabled = true
		btn.modulate = Color(0.85, 0.85, 0.85, 0.75)
	else:
		btn.text = "Выбрать класс"
		btn.disabled = false
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

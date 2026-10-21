extends CanvasLayer

# Smooth cinematic transition & loading screen between Village and Dungeon

var overlay: ColorRect
var center_vbox: VBoxContainer
var title_label: Label
var subtitle_label: Label
var tip_panel: PanelContainer
var tip_label: Label
var rune_spinner: Label

var is_animating: bool = false
var font_cinzel: Font

const GAME_TIPS: Array[String] = [
	"💡 Остерегайтесь Чумных Зомби: после смерти они взрываются смертоносным ядовитым облаком.",
	"💡 Кузнец Брок в деревне затачивает оружие и броню (+25% к характеристикам за уровень заточки).",
	"💡 Торговец Альдред скупает любое снаряжение за золото. Кликните ПКМ по предмету в сумке.",
	"💡 Рывок на [Space] дарует 0.35 сек полной неуязвимости к любым атакам и снарядам.",
	"💡 В подземелье можно призвать Городской Портал клавишей [T], чтобы вернуться в деревню.",
	"💡 Отдых у костра в центре деревни восстанавливает +18 здоровья каждую секунду.",
	"💡 Святилища силы [F] в катакомбах временно удваивают критический урон или дают мощную броню.",
	"💡 Личное Хранилище (Stash) в деревне позволяет хранить до 36 ценных реликвий."
]

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists("res://assets/fonts/Cinzel-Bold.ttf"):
		font_cinzel = load("res://assets/fonts/Cinzel-Bold.ttf")

	_create_ui()
	overlay.visible = false
	overlay.modulate.a = 0.0

func _create_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.05, 0.07, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Decorative vignette border
	var border_vignette := Panel.new()
	border_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 6
	sb.border_width_top = 6
	sb.border_width_right = 6
	sb.border_width_bottom = 6
	sb.border_color = Color(0.3, 0.22, 0.14, 0.8)
	border_vignette.add_theme_stylebox_override("panel", sb)
	border_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(border_vignette)

	center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_CENTER)
	center_vbox.add_theme_constant_override("separation", 16)
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center_vbox)

	rune_spinner = Label.new()
	rune_spinner.text = "✧ ⚔ ✧"
	rune_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rune_spinner.add_theme_font_size_override("font_size", 34)
	rune_spinner.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35, 1.0))
	center_vbox.add_child(rune_spinner)

	title_label = Label.new()
	title_label.text = "СПУСК В КАТАКОМБЫ"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_cinzel:
		title_label.add_theme_font_override("font", font_cinzel)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	center_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Этаж 1: Древний Склеп"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_cinzel:
		subtitle_label.add_theme_font_override("font", font_cinzel)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85, 1.0))
	center_vbox.add_child(subtitle_label)

	# Bottom tip box
	tip_panel = PanelContainer.new()
	tip_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip_panel.offset_top = -90.0
	tip_panel.offset_bottom = -25.0
	tip_panel.offset_left = 60.0
	tip_panel.offset_right = -60.0

	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	tip_sb.border_width_left = 1
	tip_sb.border_width_top = 1
	tip_sb.border_width_right = 1
	tip_sb.border_width_bottom = 1
	tip_sb.border_color = Color(0.4, 0.35, 0.25, 0.6)
	tip_sb.corner_radius_top_left = 6
	tip_sb.corner_radius_top_right = 6
	tip_sb.corner_radius_bottom_right = 6
	tip_sb.corner_radius_bottom_left = 6
	tip_panel.add_theme_stylebox_override("panel", tip_sb)
	overlay.add_child(tip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	tip_panel.add_child(margin)

	tip_label = Label.new()
	tip_label.text = GAME_TIPS[0]
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_font_size_override("font_size", 13)
	tip_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75, 1.0))
	margin.add_child(tip_label)

func change_scene_to_file(scene_path: String, custom_title: String = "", custom_subtitle: String = "") -> void:
	if is_animating:
		return
	is_animating = true

	# Set texts
	if custom_title.is_empty():
		title_label.text = "ЗАГРУЗКА..."
	else:
		title_label.text = custom_title

	if custom_subtitle.is_empty():
		subtitle_label.text = ""
	else:
		subtitle_label.text = custom_subtitle

	tip_label.text = GAME_TIPS[randi() % GAME_TIPS.size()]

	overlay.visible = true
	overlay.modulate.a = 0.0

	# Fade in
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Change scene
	get_tree().change_scene_to_file(scene_path)

	# Brief pause to allow scene ready initialization
	await get_tree().create_timer(0.25).timeout

	# Fade out
	var tween_out := create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.tween_property(overlay, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_out.finished

	overlay.visible = false
	is_animating = false

extends CanvasLayer
## Menu principale (sopra il paesaggio dell'alba), menu di pausa, pannello impostazioni, contatore FPS.
## Gira sempre, anche a gioco in pausa.

signal play_pressed

const W := 640.0
const H := 360.0

var in_game := false          # il main lo mette a true durante il gioco vero e proprio
var audio: Node

var mono: SystemFont
var theme_ui: Theme
var root: Control
var main_menu: Control
var pause_menu: Control
var settings_panel: PanelContainer
var fps_label: Label
var _settings_from := ""
var _controls := {}           # chiave impostazione -> [tipo, controllo, etichetta valore]
var _refreshing := false


func setup() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Lucida Console", "Courier New", "Liberation Mono", "monospace"])
	theme_ui = _make_theme()

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_ui
	add_child(root)

	_build_main_menu()
	_build_pause_menu()
	_build_settings()

	fps_label = Label.new()
	fps_label.position = Vector2(4, 2)
	fps_label.add_theme_font_size_override("font_size", 9)
	fps_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	fps_label.add_theme_constant_override("outline_size", 3)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)

	main_menu.visible = false
	pause_menu.visible = false
	settings_panel.visible = false


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = mono
	t.default_font_size = 11
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.1)
	hover.set_content_margin_all(3)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1, 1, 1, 0.18)
	pressed.set_content_margin_all(3)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.04)
	normal.border_color = Color(1, 1, 1, 0.22)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(3)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("focus", type, empty)
		t.set_color("font_color", type, Color(0.92, 0.92, 0.9))
		t.set_color("font_hover_color", type, Color(1.0, 0.86, 0.62))
		t.set_color("font_focus_color", type, Color(1.0, 0.86, 0.62))
		t.set_color("font_pressed_color", type, Color(1.0, 0.8, 0.5))
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(st, "CheckButton", empty)
	t.set_stylebox("focus", "HSlider", empty)
	t.set_color("font_color", "Label", Color(0.9, 0.9, 0.88))
	var popup := StyleBoxFlat.new()
	popup.bg_color = Color(0.06, 0.06, 0.07, 0.97)
	popup.border_color = Color(1, 1, 1, 0.25)
	popup.set_border_width_all(1)
	popup.set_content_margin_all(4)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_hover_color", "PopupMenu", Color(1.0, 0.86, 0.62))
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = Color(1, 1, 1, 0.12)
	tab_sel.border_color = Color(1.0, 0.86, 0.62)
	tab_sel.border_width_bottom = 1
	tab_sel.set_content_margin_all(5)
	var tab_un := StyleBoxFlat.new()
	tab_un.bg_color = Color(0, 0, 0, 0)
	tab_un.set_content_margin_all(5)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", hover)
	t.set_stylebox("panel", "TabContainer", empty)
	t.set_color("font_selected_color", "TabContainer", Color(1.0, 0.9, 0.7))
	t.set_color("font_unselected_color", "TabContainer", Color(0.7, 0.7, 0.68))
	return t


func _text(txt: String, size: int, pos: Vector2, parent: Control, color := Color(0.97, 0.95, 0.9)) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _menu_button(label: String, parent: Control, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	b.add_theme_constant_override("outline_size", 3)
	b.custom_minimum_size = Vector2(150, 24)
	var sb := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func(): b.text = "> " + label)
	b.focus_exited.connect(func(): b.text = "  " + label)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# =================================================================== menu principale

func _build_main_menu() -> void:
	main_menu = Control.new()
	main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(main_menu)
	# leggera ombra a sinistra per staccare il testo dal cielo
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.42))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 64
	gt.height = 8
	shade.texture = gt
	shade.position = Vector2(0, 0)
	shade.size = Vector2(300, H)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu.add_child(shade)

	_text("TAPE 01", 46, Vector2(34, 46), main_menu)
	_text("THE PIER PARK", 18, Vector2(38, 102), main_menu)

	var vb := VBoxContainer.new()
	vb.position = Vector2(26, 190)
	vb.add_theme_constant_override("separation", 4)
	main_menu.add_child(vb)
	var play := _menu_button("PLAY", vb, func(): _on_play())
	_menu_button("SETTINGS", vb, func(): open_settings("main"))
	_menu_button("QUIT", vb, func(): get_tree().quit())
	main_menu.set_meta("first", play)

	_text("v0.2 — prototipo", 9, Vector2(W - 104, H - 18), main_menu, Color(1, 1, 1, 0.55))


func show_main_menu() -> void:
	in_game = false
	main_menu.visible = true
	main_menu.modulate.a = 0.0
	create_tween().tween_property(main_menu, "modulate:a", 1.0, 1.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first: Button = main_menu.get_meta("first")
	first.grab_focus()


func _on_play() -> void:
	main_menu.visible = false
	play_pressed.emit()


# =================================================================== pausa

func _build_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(dim)
	_text("PAUSE", 30, Vector2(40, 70), pause_menu)
	_text("il nastro è fermo", 11, Vector2(42, 108), pause_menu, Color(1, 1, 1, 0.6))
	var vb := VBoxContainer.new()
	vb.position = Vector2(30, 150)
	vb.add_theme_constant_override("separation", 4)
	pause_menu.add_child(vb)
	var resume := _menu_button("RESUME", vb, func(): resume_game())
	_menu_button("SETTINGS", vb, func(): open_settings("pause"))
	_menu_button("MAIN MENU", vb, func(): _to_main_menu())
	_menu_button("QUIT", vb, func(): get_tree().quit())
	pause_menu.set_meta("first", resume)


func pause_game() -> void:
	get_tree().paused = true
	if audio:
		audio.paused = true
	pause_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first: Button = pause_menu.get_meta("first")
	first.grab_focus()


func resume_game() -> void:
	settings_panel.visible = false
	pause_menu.visible = false
	get_tree().paused = false
	if audio:
		audio.paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	if settings_panel.visible:
		close_settings()
	elif pause_menu.visible:
		resume_game()
	elif in_game:
		pause_game()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	fps_label.visible = bool(Settings.g("show_fps"))
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


# =================================================================== impostazioni

func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(56, 18)
	settings_panel.size = Vector2(528, 324)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.035, 0.045, 0.92)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	settings_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(settings_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	settings_panel.add_child(vb)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.75))
	vb.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tabs)

	var v := _tab(tabs, "Video")
	_opt(v, "quality", "Qualità grafica", Settings.QUALITY_NAMES)
	_opt(v, "window_mode", "Modalità schermo", ["Finestra", "Schermo intero", "Senza bordi"])
	var res_names: Array = []
	for r in Settings.RESOLUTIONS:
		var rv: Vector2i = r
		res_names.append("%d × %d" % [rv.x, rv.y])
	_opt(v, "resolution", "Risoluzione", res_names)
	_check(v, "vsync", "V-Sync")
	_opt(v, "max_fps", "Limite FPS", ["30", "60", "120", "144", "240", "Illimitato"])
	_slider(v, "render_scale", "Scala di rendering 3D", 50, 100, 5, "%")
	_opt(v, "msaa", "Antialiasing (MSAA)", ["Disattivato", "2x", "4x", "8x"])
	_opt(v, "shadows", "Ombre", ["Disattivate", "Basse", "Alte"])
	_opt(v, "view_distance", "Distanza visiva", ["Corta", "Media", "Lunga", "Massima"])
	_check(v, "dyn_lights", "Luci dinamiche (lampioni)")
	_slider(v, "fov", "Campo visivo (FOV)", 55, 95, 1, "°")
	_slider(v, "brightness", "Luminosità", 50, 150, 5, "%")
	_slider(v, "vhs", "Intensità effetto VHS", 0, 100, 5, "%")
	_check(v, "show_fps", "Mostra FPS")

	var a := _tab(tabs, "Audio")
	_slider(a, "vol_master", "Volume generale", 0, 100, 1, "%")
	_slider(a, "vol_music", "Musica", 0, 100, 1, "%")
	_slider(a, "vol_sfx", "Effetti sonori", 0, 100, 1, "%")
	_slider(a, "vol_ambient", "Ambiente (mare, nastro)", 0, 100, 1, "%")
	_slider(a, "vol_voice", "Voce dei dialoghi", 0, 100, 1, "%")
	_check(a, "mute_bg", "Silenzia se la finestra non è attiva")

	var gm := _tab(tabs, "Gioco")
	_slider(gm, "sens", "Sensibilità mouse", 0.2, 3.0, 0.05, "x")
	_check(gm, "invert_y", "Inverti asse Y")
	_opt(gm, "stamina_bar", "Barra della stamina", ["Automatica", "Sempre visibile", "Nascosta"])
	_check(gm, "sprint_toggle", "Corsa a interruttore (Shift)")
	_check(gm, "head_bob", "Oscillazione della camera")
	_check(gm, "hints", "Suggerimenti a schermo")

	var ac := _tab(tabs, "Accessibilità")
	_check(ac, "subs", "Sottotitoli")
	_opt(ac, "subs_size", "Dimensione sottotitoli", ["Piccola", "Media", "Grande"])
	_check(ac, "subs_bg", "Sfondo dei sottotitoli")
	_opt(ac, "text_speed", "Velocità del testo", ["Lenta", "Normale", "Veloce", "Istantanea"])
	_check(ac, "reduce_flash", "Riduci glitch e lampeggi")

	var cm := _tab(tabs, "Comandi")
	for pair in [["Muoviti", "W A S D  /  frecce"], ["Guarda", "Mouse"], ["Corri", "Shift"],
			["Riavvolgi (tieni premuto)", "Q  /  tasto destro"], ["Sintonizza", "A·D  /  mouse  /  rotella"],
			["Scelta al faro", "Q = REW   E = EJECT"], ["Pausa", "Esc"], ["Ricomincia (dopo un finale)", "R"]]:
		var p: Array = pair
		var l1 := Label.new()
		l1.text = str(p[0])
		l1.custom_minimum_size = Vector2(190, 18)
		cm.add_child(l1)
		var l2 := Label.new()
		l2.text = str(p[1])
		l2.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
		cm.add_child(l2)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	vb.add_child(bottom)
	var reset := Button.new()
	reset.text = " Ripristina predefiniti "
	reset.pressed.connect(func():
		Settings.reset_defaults()
		_refresh())
	bottom.add_child(reset)
	var back := Button.new()
	back.text = " Indietro "
	back.pressed.connect(func(): close_settings())
	bottom.add_child(back)
	Settings.changed.connect(_refresh)


func _tab(tabs: TabContainer, title: String) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	return grid


func _label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(190, 18)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(l)


func _opt(grid: GridContainer, key: String, text: String, items: Array) -> void:
	_label(grid, text)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(230, 18)
	for it in items:
		ob.add_item(str(it))
	ob.item_selected.connect(func(i: int):
		if not _refreshing:
			Settings.set_v(key, i))
	grid.add_child(ob)
	_controls[key] = ["opt", ob, null]


func _check(grid: GridContainer, key: String, text: String) -> void:
	_label(grid, text)
	var cb := CheckButton.new()
	cb.toggled.connect(func(on: bool):
		if not _refreshing:
			Settings.set_v(key, on))
	grid.add_child(cb)
	_controls[key] = ["check", cb, null]


func _slider(grid: GridContainer, key: String, text: String, mn: float, mx: float, step: float, suffix: String) -> void:
	_label(grid, text)
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(230, 18)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = step
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(sl)
	var val := Label.new()
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(val)
	sl.value_changed.connect(func(x: float):
		val.text = _fmt(x, step, suffix)
		if not _refreshing:
			Settings.set_v(key, x if step < 1.0 else int(round(x))))
	grid.add_child(hb)
	_controls[key] = ["slider", sl, [val, step, suffix]]


func _fmt(x: float, step: float, suffix: String) -> String:
	return ("%.2f" % x if step < 1.0 else "%d" % int(round(x))) + suffix


func _refresh() -> void:
	_refreshing = true
	for key in _controls.keys():
		var entry: Array = _controls[key]
		var kind: String = entry[0]
		var v: Variant = Settings.g(key)
		match kind:
			"opt":
				var ob: OptionButton = entry[1]
				ob.select(int(v))
			"check":
				var cb: CheckButton = entry[1]
				cb.set_pressed_no_signal(bool(v))
			"slider":
				var sl: HSlider = entry[1]
				var extra: Array = entry[2]
				sl.set_value_no_signal(float(v))
				var lbl: Label = extra[0]
				lbl.text = _fmt(float(v), float(extra[1]), str(extra[2]))
	_refreshing = false


func open_settings(from: String) -> void:
	_settings_from = from
	_refresh()
	main_menu.visible = false
	pause_menu.visible = false
	settings_panel.visible = true


func close_settings() -> void:
	settings_panel.visible = false
	if _settings_from == "pause":
		pause_menu.visible = true
		var first: Button = pause_menu.get_meta("first")
		first.grab_focus()
	else:
		main_menu.visible = true
		var first2: Button = main_menu.get_meta("first")
		first2.grab_focus()

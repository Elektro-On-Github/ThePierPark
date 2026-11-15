extends CanvasLayer
## Il mirino della videocamera: filtro VHS a schermo intero + OSD (REC, batteria, data,
## timecode, icone PLAY/REW/PAUSE/EJECT), barra del rewind, quadrante di sintonia,
## barra della stamina, sottotitoli "a macchina da scrivere" con voce a sillabe, finali.

signal voice_char(c: String)

const POST := preload("res://shaders/vhs_post.gdshader")
const W := 640.0
const H := 360.0
const CLOCK_START := 18 * 3600 + 41 * 60   # 18:41
const TEXT_CPS := [16.0, 30.0, 55.0, 100000.0]
const SUB_SIZES := [10, 13, 16]

var post_mat: ShaderMaterial
var freeze_rect: TextureRect
var osd: Control
var mono: SystemFont
var mode_label: Label
var date_label: Label
var time_label: Label
var info_label: Label
var prompt_label: Label
var sub_label: Label
var ending_panel: ColorRect
var ending_title: Label
var ending_body: Label
var fade_rect: ColorRect
var tbc_label: Label
var tbc_hint: Label

var mode := "play"
var rewind_progress := 0.0
var dial_active := false
var dial_freq := 0.5
var dial_signal := 0.0
var dial_lock := 0.0
var choice_on := false
var clock_frozen := false
var clock_seconds := 0.0
var subs_playing := false
var stamina := 1.0
var exhausted := false

var _t := 0.0
var _info_left := 0.0
var _flash_mode := ""
var _flash_left := 0.0
var _subs: Array = []
var _sub_left := 0.0
var _typing := false
var _shown := 0.0
var _letters := 0
var _pause := 0.0
var _line_secs := 0.0
var _line_elapsed := 0.0
var _stam_alpha := 0.0
var _stam_full_t := 0.0
var _sub_bg: StyleBoxFlat
var _sub_empty: StyleBoxEmpty
var _fade_tween: Tween


func setup() -> void:
	layer = 5
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Lucida Console", "Courier New", "Liberation Mono", "monospace"])

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	freeze_rect = TextureRect.new()
	freeze_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	freeze_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	freeze_rect.stretch_mode = TextureRect.STRETCH_SCALE
	freeze_rect.visible = false
	root.add_child(freeze_rect)

	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST
	post.material = post_mat
	root.add_child(post)

	osd = Control.new()
	osd.set_anchors_preset(Control.PRESET_FULL_RECT)
	osd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	osd.draw.connect(_draw_osd)
	root.add_child(osd)

	_lbl("REC", 15, Vector2(50, 22), Vector2(60, 20), HORIZONTAL_ALIGNMENT_LEFT, osd)
	_lbl("SP", 12, Vector2(W - 72, 42), Vector2(40, 16), HORIZONTAL_ALIGNMENT_LEFT, osd)
	mode_label = _lbl("PLAY", 15, Vector2(W / 2.0 - 30.0, 22), Vector2(90, 20), HORIZONTAL_ALIGNMENT_LEFT, osd)
	date_label = _lbl("NOV.14 1994", 14, Vector2(30, H - 46), Vector2(160, 20), HORIZONTAL_ALIGNMENT_LEFT, osd)
	time_label = _lbl("PM  6:41:00", 14, Vector2(W - 190, H - 46), Vector2(160, 20), HORIZONTAL_ALIGNMENT_RIGHT, osd)
	info_label = _lbl("", 13, Vector2(60, 50), Vector2(W - 120, 20), HORIZONTAL_ALIGNMENT_CENTER, osd)
	prompt_label = _lbl("", 13, Vector2(60, 238), Vector2(W - 120, 20), HORIZONTAL_ALIGNMENT_CENTER, osd)

	sub_label = _lbl("", 13, Vector2(80, 276), Vector2(W - 160, 0), HORIZONTAL_ALIGNMENT_CENTER, root)
	sub_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_sub_bg = StyleBoxFlat.new()
	_sub_bg.bg_color = Color(0, 0, 0, 0.55)
	_sub_bg.set_content_margin_all(4)
	_sub_empty = StyleBoxEmpty.new()

	ending_panel = ColorRect.new()
	ending_panel.color = Color(0, 0, 0, 0.62)
	ending_panel.position = Vector2(0, 196)
	ending_panel.size = Vector2(W, 164)
	ending_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_panel.visible = false
	root.add_child(ending_panel)
	ending_title = _lbl("", 20, Vector2(20, 14), Vector2(W - 40, 28), HORIZONTAL_ALIGNMENT_CENTER, ending_panel)
	ending_body = _lbl("", 13, Vector2(40, 50), Vector2(W - 80, 110), HORIZONTAL_ALIGNMENT_CENTER, ending_panel)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

	# schermata finale "To be continued..." (sopra il nero della dissolvenza)
	tbc_label = _lbl("", 24, Vector2(0, 160), Vector2(W, 34), HORIZONTAL_ALIGNMENT_CENTER, root)
	tbc_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	tbc_hint = _lbl("[R]  MENU PRINCIPALE", 11, Vector2(0, 300), Vector2(W, 18), HORIZONTAL_ALIGNMENT_CENTER, root)
	tbc_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	tbc_label.visible = false
	tbc_hint.visible = false


func _lbl(text: String, size: int, pos: Vector2, sz: Vector2, align: HorizontalAlignment, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", mono)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- API

func set_prompt(t: String) -> void:
	prompt_label.text = t


func flash_info(t: String, secs: float = 3.5) -> void:
	info_label.text = t
	_info_left = secs


func flash_mode(m: String, secs: float) -> void:
	_flash_mode = m
	_flash_left = secs


func play_subs(lines: Array) -> void:
	_subs = lines.duplicate()
	_sub_left = 0.0
	_typing = false
	sub_label.text = ""
	subs_playing = lines.size() > 0


func show_freeze(tex: Texture2D) -> void:
	freeze_rect.texture = tex
	freeze_rect.visible = true


func set_osd_visible(v: bool) -> void:
	osd.visible = v


func fade_to(alpha: float, secs: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", alpha, secs)


## "To be continued..." lettera per lettera, poi i puntini che pulsano.
func show_tbc() -> void:
	ending_panel.visible = false
	sub_label.text = ""
	tbc_label.text = ""
	tbc_label.visible = true
	var full := "To be continued"
	for i in full.length():
		tbc_label.text = full.substr(0, i + 1)
		await get_tree().create_timer(0.09).timeout
	for d in 3:
		await get_tree().create_timer(0.45).timeout
		tbc_label.text = full + ".".repeat(d + 1)
	await get_tree().create_timer(1.2).timeout
	tbc_hint.modulate.a = 0.0
	tbc_hint.visible = true
	create_tween().tween_property(tbc_hint, "modulate:a", 1.0, 1.5)


func show_ending(title: String, body: String) -> void:
	ending_title.text = title
	ending_body.text = body
	ending_panel.modulate.a = 0.0
	ending_panel.visible = true
	create_tween().tween_property(ending_panel, "modulate:a", 1.0, 2.0)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_t += delta
	if not clock_frozen:
		clock_seconds += delta
	var total := CLOCK_START + int(clock_seconds)
	var hh := (total / 3600) % 24
	var mm := (total / 60) % 60
	var ss := total % 60
	time_label.text = "PM %2d:%02d:%02d" % [hh - 12 if hh > 12 else hh, mm, ss]

	if _info_left > 0.0:
		_info_left -= delta
		if _info_left <= 0.0:
			info_label.text = ""
	if _flash_left > 0.0:
		_flash_left -= delta

	_update_subs(delta)
	prompt_label.visible = bool(Settings.g("hints"))

	# stamina: visibile mentre non è piena (modalità automatica)
	var mode_bar := int(Settings.g("stamina_bar"))
	var target := 0.0
	if mode_bar == 1:
		target = 1.0
	elif mode_bar == 0:
		if stamina < 0.999:
			_stam_full_t = 1.2
			target = 1.0
		else:
			_stam_full_t -= delta
			target = 1.0 if _stam_full_t > 0.0 else 0.0
	_stam_alpha = move_toward(_stam_alpha, target, delta * 3.0)

	var m := current_mode()
	mode_label.text = {"play": "PLAY", "rew": "REW", "pause": "PAUSE", "eject": "EJECT"}.get(m, "PLAY")
	osd.queue_redraw()


func _update_subs(delta: float) -> void:
	var size_i := clampi(int(Settings.g("subs_size")), 0, 2)
	sub_label.add_theme_font_size_override("font_size", SUB_SIZES[size_i])
	sub_label.visible = bool(Settings.g("subs"))
	var has_text := sub_label.text != ""
	sub_label.add_theme_stylebox_override("normal", _sub_bg if (has_text and bool(Settings.g("subs_bg"))) else _sub_empty)
	sub_label.size.y = 0.0
	sub_label.position.y = 304.0 - sub_label.get_combined_minimum_size().y

	if _typing:
		_line_elapsed += delta
		if _pause > 0.0:
			_pause -= delta
			return
		var cps: float = TEXT_CPS[clampi(int(Settings.g("text_speed")), 0, 3)]
		var before := int(_shown)
		_shown += cps * delta
		var total_chars := sub_label.text.length()
		var after := mini(int(_shown), total_chars)
		for i in range(before, after):
			var c := sub_label.text[i]
			if c.to_lower() != c.to_upper() or "àèéìòù".contains(c):
				_letters += 1
				if _letters % 2 == 1:
					voice_char.emit(c)
			elif ".,!?;:—…".contains(c) and cps < 1000.0:
				_pause = 0.16 if c == "," else 0.3
				_shown = float(i + 1)
				after = i + 1
				break
		sub_label.visible_characters = after
		if after >= total_chars:
			_typing = false
			sub_label.visible_characters = -1
			_sub_left = maxf(1.6, _line_secs - _line_elapsed)
		return

	if _sub_left > 0.0:
		_sub_left -= delta
	if _sub_left <= 0.0:
		if _subs.size() > 0:
			var line: Array = _subs.pop_front()
			var text := str(line[0])
			sub_label.text = text
			_line_secs = float(line[1])
			_line_elapsed = 0.0
			if text.begins_with("MEMORIA"):
				# intestazione: appare di colpo, senza voce
				sub_label.visible_characters = -1
				_sub_left = _line_secs
			else:
				_typing = true
				_shown = 0.0
				_letters = 0
				_pause = 0.0
				sub_label.visible_characters = 0
		elif subs_playing:
			subs_playing = false
			sub_label.text = ""


func current_mode() -> String:
	return _flash_mode if _flash_left > 0.0 else mode


# ---------------------------------------------------------------- disegno OSD

func _draw_osd() -> void:
	var c := Color(1, 1, 1, 0.88)
	var m := 16.0
	var l := 22.0
	for corner in [Vector2(m, m), Vector2(W - m, m), Vector2(m, H - m), Vector2(W - m, H - m)]:
		var p: Vector2 = corner
		var sx := 1.0 if p.x < W / 2.0 else -1.0
		var sy := 1.0 if p.y < H / 2.0 else -1.0
		osd.draw_line(p, p + Vector2(l * sx, 0), c, 2.0)
		osd.draw_line(p, p + Vector2(0, l * sy), c, 2.0)

	# mirino: due rettangoli da 1 px perfettamente centrati, bracci uguali
	var ctr := Vector2(W / 2.0, H / 2.0)
	var arm := 3.5
	var cc := Color(1, 1, 1, 0.7)
	var sh := Color(0, 0, 0, 0.35)
	osd.draw_rect(Rect2(ctr.x - arm - 0.5, ctr.y - 0.5 + 0.6, arm * 2.0 + 1.0, 1.0), sh)
	osd.draw_rect(Rect2(ctr.x - 0.5 + 0.6, ctr.y - arm - 0.5, 1.0, arm * 2.0 + 1.0), sh)
	osd.draw_rect(Rect2(ctr.x - arm - 0.5, ctr.y - 0.5, arm * 2.0 + 1.0, 1.0), cc)
	osd.draw_rect(Rect2(ctr.x - 0.5, ctr.y - arm - 0.5, 1.0, arm * 2.0 + 1.0), cc)

	var cm := current_mode()
	if fmod(_t, 1.0) < 0.6 and cm != "pause":
		osd.draw_circle(Vector2(38, 31), 6.0, Color(0.95, 0.1, 0.1))

	var bx := W - 72.0
	var by := 24.0
	osd.draw_rect(Rect2(bx, by, 34, 14), c, false, 2.0)
	osd.draw_rect(Rect2(bx + 34, by + 4, 4, 6), c)
	var cells := 3 if clock_seconds < 600.0 else 2
	for i in cells:
		osd.draw_rect(Rect2(bx + 4 + i * 10, by + 3, 7, 8), c)

	_draw_icon(Vector2(W / 2.0 - 48.0, 31.0), cm, c)

	if rewind_progress > 0.001 and not dial_active:
		var bw := 180.0
		var x0 := W / 2.0 - bw / 2.0
		var y0 := 262.0
		_draw_icon(Vector2(x0 - 20.0, y0 + 4.0), "rew", c)
		osd.draw_rect(Rect2(x0, y0, bw, 8), c, false, 1.0)
		osd.draw_rect(Rect2(x0 + 2, y0 + 2, (bw - 4) * rewind_progress, 4), Color(1, 1, 1, 0.92))

	if dial_active:
		_draw_dial(c)

	if choice_on:
		_draw_icon(Vector2(212, 262), "rew", c)
		osd.draw_string(mono, Vector2(230, 267), "REW   [Q]", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
		_draw_icon(Vector2(368, 262), "eject", c)
		osd.draw_string(mono, Vector2(386, 267), "EJECT [E]", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)

	if _stam_alpha > 0.01:
		_draw_stamina()


func _draw_stamina() -> void:
	var segs := 12
	var sw := 7.0
	var gap := 2.0
	var total_w := segs * sw + (segs - 1) * gap
	var x0 := W / 2.0 - total_w / 2.0
	var y0 := H - 26.0
	var base := Color(1, 1, 1, 0.9)
	if exhausted:
		base = Color(1.0, 0.32, 0.25, 0.95) if fmod(_t, 0.5) < 0.3 else Color(1.0, 0.32, 0.25, 0.5)
	var a := _stam_alpha
	var filled := stamina * segs
	for i in segs:
		var r := Rect2(x0 + i * (sw + gap), y0, sw, 3.0)
		osd.draw_rect(r, Color(1, 1, 1, 0.18 * a))
		var f := clampf(filled - i, 0.0, 1.0)
		if f > 0.0:
			osd.draw_rect(Rect2(r.position, Vector2(sw * f, 3.0)), Color(base.r, base.g, base.b, base.a * a))


func _draw_icon(p: Vector2, kind: String, c: Color) -> void:
	match kind:
		"play":
			osd.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -7), p + Vector2(7, 0), p + Vector2(-5, 7)]), c)
		"rew":
			osd.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(0, 6), p + Vector2(-9, 0)]), c)
			osd.draw_colored_polygon(PackedVector2Array([p + Vector2(9, -6), p + Vector2(9, 6), p + Vector2(0, 0)]), c)
		"pause":
			osd.draw_rect(Rect2(p + Vector2(-6, -7), Vector2(4, 14)), c)
			osd.draw_rect(Rect2(p + Vector2(2, -7), Vector2(4, 14)), c)
		"eject":
			osd.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 2), p + Vector2(7, 2), p + Vector2(0, -7)]), c)
			osd.draw_rect(Rect2(p + Vector2(-7, 4), Vector2(14, 3)), c)


func _draw_dial(c: Color) -> void:
	var ctr := Vector2(W / 2.0, 168.0)
	var r := 56.0
	var a0 := deg_to_rad(150.0)
	var a1 := deg_to_rad(390.0)
	osd.draw_circle(ctr, r + 10.0, Color(0, 0, 0, 0.45))
	osd.draw_arc(ctr, r, a0, a1, 48, c, 2.0)
	for i in 21:
		var a := lerpf(a0, a1, i / 20.0)
		var inner := r - (9.0 if i % 5 == 0 else 5.0)
		osd.draw_line(ctr + Vector2(cos(a), sin(a)) * inner, ctr + Vector2(cos(a), sin(a)) * r, c, 1.0)
	var na := lerpf(a0, a1, dial_freq)
	var ncol := Color(1.0, 0.85, 0.4).lerp(Color(0.5, 1.0, 0.6), dial_signal)
	osd.draw_line(ctr, ctr + Vector2(cos(na), sin(na)) * (r - 4.0), ncol, 2.0)
	osd.draw_circle(ctr, 3.0, c)
	osd.draw_string(mono, ctr + Vector2(-60, 30), "%5.1f MHz" % (88.0 + 20.0 * dial_freq), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, c)
	var bars := int(round(dial_signal * 5.0))
	for i in 5:
		var h := 4.0 + i * 3.0
		var rect := Rect2(ctr.x + 74.0 + i * 7.0, ctr.y + 10.0 - h, 5.0, h)
		if i < bars:
			osd.draw_rect(rect, c)
		else:
			osd.draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.0)
	osd.draw_string(mono, Vector2(ctr.x + 70.0, ctr.y + 26.0), "SIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
	var lw := 120.0
	var lx := ctr.x - lw / 2.0
	var ly := ctr.y + 46.0
	osd.draw_string(mono, Vector2(lx - 40.0, ly + 8.0), "LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
	osd.draw_rect(Rect2(lx, ly, lw, 8), c, false, 1.0)
	osd.draw_rect(Rect2(lx + 2, ly + 2, (lw - 4) * clampf(dial_lock, 0.0, 1.0), 4), Color(0.6, 1.0, 0.7))
	if bool(Settings.g("hints")):
		osd.draw_string(mono, Vector2(ctr.x - 220.0, ly + 30.0), "A/D o MOUSE: ALLINEA FINCHÉ LA STATICA SPARISCE", HORIZONTAL_ALIGNMENT_CENTER, 440, 10, Color(1, 1, 1, 0.7))

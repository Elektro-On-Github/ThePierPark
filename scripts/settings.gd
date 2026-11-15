extends Node
## Autoload "Settings": tutte le impostazioni del gioco, salvate in user://settings.cfg.
## Video, Audio, Gioco, Accessibilità. Applica subito finestra/vsync/fps/msaa/scala 3D/volume;
## il resto lo leggono main, player, hud e audio_synth.

signal changed

const PATH := "user://settings.cfg"

const RESOLUTIONS := [
	Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1440, 900),
	Vector2i(1600, 900), Vector2i(1680, 1050), Vector2i(1920, 1080), Vector2i(1920, 1200),
	Vector2i(2048, 1080), Vector2i(2560, 1440), Vector2i(2560, 1600), Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
const FPS_LIMITS := [30, 60, 120, 144, 240, 0]
const QUALITY_NAMES := ["Bassa", "Media", "Alta", "Ultra", "Personalizzata"]
## preset: scala 3D, MSAA, ombre, distanza visiva, luci dinamiche
const PRESETS := [
	{"render_scale": 60, "msaa": 0, "shadows": 0, "view_distance": 0, "dyn_lights": false},
	{"render_scale": 80, "msaa": 1, "shadows": 1, "view_distance": 1, "dyn_lights": true},
	{"render_scale": 100, "msaa": 2, "shadows": 1, "view_distance": 2, "dyn_lights": true},
	{"render_scale": 100, "msaa": 3, "shadows": 2, "view_distance": 3, "dyn_lights": true},
]
const PRESET_KEYS := ["render_scale", "msaa", "shadows", "view_distance", "dyn_lights"]
const VIEW_FAR := [110.0, 170.0, 260.0, 400.0]

const DEFAULTS := {
	# video
	"quality": 2, "window_mode": 0, "resolution": 2, "vsync": true, "max_fps": 5,
	"render_scale": 100, "msaa": 2, "shadows": 1, "view_distance": 2, "dyn_lights": true,
	"fov": 68, "brightness": 100, "vhs": 100, "show_fps": false,
	# audio
	"vol_master": 80, "vol_music": 70, "vol_sfx": 85, "vol_ambient": 80, "vol_voice": 80, "mute_bg": true,
	# gioco
	"sens": 1.0, "invert_y": false, "head_bob": true, "stamina_bar": 0, "hints": true, "sprint_toggle": false,
	# accessibilità
	"subs": true, "subs_size": 1, "subs_bg": true, "text_speed": 1, "reduce_flash": false,
}

var data := {}
var _focused := true


func _ready() -> void:
	data = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS.keys():
			if cf.has_section_key("settings", k):
				data[k] = cf.get_value("settings", k)
	apply_all()


func g(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_v(key: String, value: Variant) -> void:
	data[key] = value
	if key == "quality" and int(value) < PRESETS.size():
		var p: Dictionary = PRESETS[int(value)]
		for k in p.keys():
			data[k] = p[k]
	elif key in PRESET_KEYS:
		data["quality"] = _match_preset()
	save()
	_apply_key(key)
	changed.emit()


## Applica solo ciò che serve: così trascinare uno slider del volume non ridimensiona la finestra.
func _apply_key(key: String) -> void:
	if key in ["window_mode", "resolution", "vsync"]:
		_apply_window()
		get_viewport().scaling_3d_scale = _scale_3d()
	elif key == "max_fps":
		Engine.max_fps = FPS_LIMITS[clampi(int(g("max_fps")), 0, FPS_LIMITS.size() - 1)]
	elif key in ["quality", "render_scale", "msaa"]:
		_apply_viewport()
	elif key == "vol_master" or key == "mute_bg":
		_apply_master()


func reset_defaults() -> void:
	data = DEFAULTS.duplicate()
	save()
	apply_all()


func _match_preset() -> int:
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		var same := true
		for k in p.keys():
			if p[k] != data[k]:
				same = false
				break
		if same:
			return i
	return 4


func save() -> void:
	var cf := ConfigFile.new()
	for k in data.keys():
		cf.set_value("settings", k, data[k])
	cf.save(PATH)


func resolution() -> Vector2i:
	return RESOLUTIONS[clampi(int(g("resolution")), 0, RESOLUTIONS.size() - 1)]


func view_far() -> float:
	return VIEW_FAR[clampi(int(g("view_distance")), 0, 3)]


func vol(key: String) -> float:
	return clampf(float(g(key)) / 100.0, 0.0, 1.0)


func apply_all() -> void:
	_apply_window()
	Engine.max_fps = FPS_LIMITS[clampi(int(g("max_fps")), 0, FPS_LIMITS.size() - 1)]
	_apply_viewport()
	_apply_master()
	changed.emit()


func _apply_viewport() -> void:
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][clampi(int(g("msaa")), 0, 3)]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = _scale_3d()


func _apply_master() -> void:
	var mv := vol("vol_master")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(mv, 0.0001)))
	AudioServer.set_bus_mute(0, mv <= 0.001 or (not _focused and bool(g("mute_bg"))))


func _scale_3d() -> float:
	var s := float(g("render_scale")) / 100.0
	if DisplayServer.get_name() == "headless":
		return s
	if int(g("window_mode")) != 0:
		# a schermo intero la risoluzione scelta diventa la risoluzione interna del 3D
		var screen := DisplayServer.screen_get_size()
		s *= clampf(float(resolution().y) / float(maxi(screen.y, 1)), 0.25, 2.0)
	return clampf(s, 0.25, 2.0)


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vsync := DisplayServer.VSYNC_ENABLED if bool(g("vsync")) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)
	var win := get_window()
	match int(g("window_mode")):
		1:
			win.borderless = false
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		2:
			win.mode = Window.MODE_FULLSCREEN
		_:
			if win.mode != Window.MODE_WINDOWED:
				win.mode = Window.MODE_WINDOWED
			win.borderless = false
			var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
			var res := resolution()
			var sz := Vector2i(mini(res.x, usable.size.x), mini(res.y, usable.size.y))
			win.size = sz
			win.position = usable.position + (usable.size - sz) / 2


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		AudioServer.set_bus_mute(0, bool(g("mute_bg")) or vol("vol_master") <= 0.001)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		AudioServer.set_bus_mute(0, vol("vol_master") <= 0.001)

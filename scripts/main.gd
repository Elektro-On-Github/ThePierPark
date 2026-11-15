extends Node3D
## Tape 01: The Pier Park.
## Costruisce il parco costiero via codice (niente asset esterni), gestisce i 3 Memory Node,
## la sintonia, i log, il faro e i 2 finali.

const PS1 := preload("res://shaders/ps1.gdshader")
const SEA := preload("res://shaders/sea.gdshader")
const BEACON := preload("res://shaders/beacon.gdshader")
const PlayerScript := preload("res://scripts/player.gd")
const NodeScript := preload("res://scripts/memory_node.gd")
const HudScript := preload("res://scripts/hud.gd")
const AudioScript := preload("res://scripts/audio_synth.gd")
const MenuScript := preload("res://scripts/menu.gd")

const TITLE := 0
const PLAY := 1
const ENDING := 2
const MENU := 3
const SUN_DIR := Vector3(0.45, 0.1, -1.0)   # da dove sorge il sole (alba)

const START_POS := Vector3(0, 0.1, 56)
const LIGHTHOUSE := Vector3(0, 0, -180)
const PIER_RESPAWN := Vector3(0, 0.1, -46)
const BENCH_POS := Vector3(-17, 0, 20)
const GAZEBO_POS := Vector3(22, 0, -12)
const BRIDGE_POS := Vector3(0, 0, -97)

const LOGS := {
	"intro": [
		["(Videocamera ritrovata. Dentro, un solo nastro.)", 4.5],
		["(Ultima registrazione: 14 novembre 1994. Pier Park.)", 4.5],
		["(Il nastro è rovinato in tre punti.)", 4.0],
	],
	"bench": [
		["MEMORIA 01 — LA PANCHINA", 3.0],
		["«Questa era la nostra panchina. Ci venivamo dopo scuola, a guardare il molo.»", 6.0],
		["«Il giorno che è andato tutto storto sono venuto qui e sono rimasto seduto fino al buio.»", 6.5],
		["«Pensavo che cadere volesse dire essere finito.»", 4.5],
		["«Invece cadere è una cosa che ti succede. Non è chi sei.»", 5.0],
		["«Quel giorno mi sono alzato tardi. Però mi sono alzato.»", 5.0],
	],
	"gazebo": [
		["MEMORIA 02 — IL GAZEBO", 3.0],
		["«La domenica qui suonava la banda del paese.»", 4.5],
		["«Una volta il trombettista ha sbagliato una nota, forte, davanti a tutti.»", 5.5],
		["«Ha riso, ha ripreso fiato, e ha ricominciato dalla battuta prima.»", 5.5],
		["«Nessuno si ricorda la nota sbagliata. Tutti si ricordano che ha finito il pezzo.»", 6.0],
		["«Non devi ripartire da zero. Ti basta ripartire dalla battuta prima.»", 5.5],
	],
	"bridge": [
		["MEMORIA 03 — IL PONTE DEL MOLO", 3.0],
		["«La mareggiata del '94 si è portata via un pezzo di molo. Dicevano che non l'avrebbero più rifatto.»", 7.0],
		["«L'hanno rifatto con le assi vecchie e quelle nuove, mischiate.»", 5.0],
		["«Si vede ancora, dove si è rotto. Le cicatrici si vedono sempre.»", 5.5],
		["«Ma ci passi sopra lo stesso. Un ponte serve a questo.»", 5.0],
		["«Il faro è in fondo. Lì il nastro finisce, e decidi tu cosa farne.»", 5.5],
	],
	"lighthouse": [
		["(Fine del nastro.)", 3.5],
		["(Riavvolgere ancora. O espellere.)", 4.5],
	],
}

var state := TITLE
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var env: Environment
var moon: DirectionalLight3D
var nodes: Array = []
var bridge_wall: StaticBody3D
var lh_pivot: Node3D
var lh_lantern_mat: ShaderMaterial
var lh_light: OmniLight3D
var lh_on := false
var sea_mat: ShaderMaterial
var dial_node: Node3D = null
var warmth := 0.0
var warmth_target := 0.0
var glitch_spike := 0.0
var force_hold := false
var dawn := false
var ending_id := 0
var menu: CanvasLayer
var menu_cam: Camera3D
var ambient_lamps: Array = []
var _menu_rot := Vector3.ZERO
var voice_count := 0

var _noise: ImageTexture
var _sil_mat: StandardMaterial3D
var _t := 0.0
var _choice_announced := false
var _loop_t := 2.0
var _test := ""
var _path_segs: Array = []


# =================================================================== setup

func _ready() -> void:
	seed(1994)
	_noise = _make_noise()
	_sil_mat = StandardMaterial3D.new()
	_sil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sil_mat.albedo_color = Color(0.01, 0.01, 0.015, 0.93)
	_sil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_build_env()
	_build_ground()
	_build_paths()
	_build_entrance()
	_build_pier()
	_build_lighthouse()
	_build_nodes()
	_build_trees()
	_build_lamps()
	_build_bounds()
	randomize()

	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	add_child(player)
	player.setup(START_POS, 0.0)
	player.step.connect(_on_step)
	player.locked = true
	player.look_locked = true

	audio = Node.new()
	audio.set_script(AudioScript)
	add_child(audio)
	audio.setup()

	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	hud.setup()
	hud.voice_char.connect(_on_voice)

	menu = CanvasLayer.new()
	menu.set_script(MenuScript)
	add_child(menu)
	menu.setup()
	menu.audio = audio
	menu.play_pressed.connect(_on_play)

	menu_cam = Camera3D.new()
	menu_cam.fov = 62.0
	menu_cam.far = 400.0
	menu_cam.near = 0.12
	menu_cam.position = Vector3(1.3, 1.8, -136.0)
	add_child(menu_cam)
	menu_cam.look_at(Vector3(3.5, 7.0, -180.0), Vector3.UP)
	_menu_rot = menu_cam.rotation

	Settings.changed.connect(_apply_settings)
	_apply_settings()

	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		_test = "auto"
		_autotest()
	elif "--shots" in args:
		_test = "shots"
		_shots()
	else:
		_enter_menu()


func _on_voice(c: String) -> void:
	voice_count += 1
	audio.voice(c)


## Sfondo del menu: l'alba del finale 2, vista dal molo verso il faro.
func _enter_menu() -> void:
	state = MENU
	_set_dawn()
	menu_cam.current = true
	hud.set_osd_visible(false)
	hud.post_mat.set_shader_parameter("clean", 1.0)
	audio.hiss = 0.0
	audio.pad = 0.55
	hud.fade_rect.color = Color(0, 0, 0, 1)
	hud.fade_to(0.0, 2.0)
	menu.show_main_menu()


func _on_play() -> void:
	hud.fade_to(1.0, 0.8)
	await get_tree().create_timer(0.9).timeout
	_on_start()
	hud.fade_to(0.0, 1.4)


func _apply_settings() -> void:
	var sh := int(Settings.g("shadows"))
	moon.shadow_enabled = sh >= 1
	moon.directional_shadow_max_distance = 60.0
	RenderingServer.directional_shadow_atlas_set_size(4096 if sh >= 2 else 2048, true)
	var dyn := bool(Settings.g("dyn_lights"))
	for l in ambient_lamps:
		var ol: OmniLight3D = l
		ol.visible = dyn
		ol.shadow_enabled = sh >= 2
	var calm := bool(Settings.g("reduce_flash"))
	for n in nodes:
		var bm: ShaderMaterial = n.beacon.material_override
		bm.set_shader_parameter("flicker", 0.2 if calm else 1.0)


func _set_night() -> void:
	dawn = false
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.33, 0.4)
	env.fog_light_color = Color(0.3, 0.33, 0.4)
	env.fog_density = 0.045
	env.fog_sky_affect = 1.0
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.55
	moon.light_color = Color(0.6, 0.7, 0.9)
	moon.light_energy = 0.3
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	sea_mat.set_shader_parameter("deep", Color(0.07, 0.1, 0.13))
	sea_mat.set_shader_parameter("crest", Color(0.22, 0.27, 0.3))
	lh_pivot.visible = lh_on


func _on_start() -> void:
	_set_night()
	player.camera.current = true
	hud.set_osd_visible(true)
	hud.post_mat.set_shader_parameter("clean", 0.0)
	audio.hiss = 1.0
	audio.pad = 0.0
	state = PLAY
	menu.in_game = true
	player.locked = false
	player.look_locked = false
	hud.play_subs(LOGS["intro"])
	if DisplayServer.get_name() != "headless" and _test == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _make_noise() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var v := 0.75 + randf() * 0.25
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _mat(color: Color, uv := Vector2.ONE, emission := Color.BLACK, energy := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("tex", _noise)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", energy)
	return m


func _box(size: Vector3, pos: Vector3, color: Color, collide := false, uv := Vector2.ONE, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	var m := _mat(color, uv)
	if maxf(size.x, size.z) > 6.0:
		# superfici grandi (prato, molo, sentieri): niente distorsione affine né tremolio dei vertici,
		# su poligoni così grandi diventano "pavimento glitchato"
		m.set_shader_parameter("affine", 0.0)
		m.set_shader_parameter("snap", 0.0)
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	if collide:
		_wall(size, pos, parent)
	return mi


func _cyl(rt: float, rb: float, h: float, pos: Vector3, color: Color, segs := 8, parent: Node3D = null) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _wall(size: Vector3, pos: Vector3, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	(parent if parent != null else self).add_child(body)
	return body


func _beacon_mat(c1: Color, c2: Color, strength: float, flicker: float, invert: bool, height := 40.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BEACON
	m.set_shader_parameter("color", c1)
	m.set_shader_parameter("color2", c2)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("flicker", flicker)
	m.set_shader_parameter("invert", invert)
	m.set_shader_parameter("height", height)
	return m


func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# =================================================================== mondo

func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.33, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.33, 0.4)
	env.fog_density = 0.045
	env.fog_sky_affect = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 0.9)
	moon.light_energy = 0.3
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	add_child(moon)


func _build_ground() -> void:
	_box(Vector3(130, 3, 104), Vector3(0, -1.5, 10), Color(0.3, 0.36, 0.25), true, Vector2(40, 32))
	_box(Vector3(130, 2.2, 0.6), Vector3(0, -1.1, -42.0), Color(0.48, 0.47, 0.44), false, Vector2(30, 1))
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 400)
	pm.subdivide_width = 80
	pm.subdivide_depth = 64
	sea.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = SEA
	sea.material_override = sm
	sea_mat = sm
	sea.position = Vector3(0, -1.4, -200)
	add_child(sea)


func _path(a: Vector2, b: Vector2, w := 2.4) -> void:
	var d := b - a
	var mid := (a + b) * 0.5
	var lift := 0.03 + _path_segs.size() * 0.006
	var mi := _box(Vector3(w, 0.02, d.length() + w * 0.5), Vector3(mid.x, lift, mid.y), Color(0.52, 0.47, 0.38), false, Vector2(1, d.length() / 3.0))
	mi.rotation.y = atan2(d.x, d.y)
	_path_segs.append([a, b])


func _build_paths() -> void:
	_path(Vector2(0, 60), Vector2(0, -41.5), 2.6)
	_path(Vector2(0, 30), Vector2(-17, 20))
	_path(Vector2(-17, 20), Vector2(-30, -8))
	_path(Vector2(-30, -8), Vector2(-10, -30))
	_path(Vector2(0, 2), Vector2(22, -12))
	_path(Vector2(22, -12), Vector2(36, 18))
	_path(Vector2(36, 18), Vector2(8, 44))


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _build_trees() -> void:
	var avoid := [Vector2(BENCH_POS.x, BENCH_POS.z), Vector2(GAZEBO_POS.x, GAZEBO_POS.z), Vector2(0, 50), Vector2(6, 46)]
	var placed := 0
	var tries := 0
	while placed < 150 and tries < 2000:
		tries += 1
		var p := Vector2(randf_range(-61, 61), randf_range(-37, 59))
		var ok := true
		for s in _path_segs:
			var seg: Array = s
			if _seg_dist(p, seg[0], seg[1]) < 3.2:
				ok = false
				break
		if ok:
			for a in avoid:
				var av: Vector2 = a
				if p.distance_to(av) < 9.0:
					ok = false
					break
		if not ok:
			continue
		placed += 1
		var h := randf_range(2.4, 3.6)
		_cyl(0.14, 0.2, h, Vector3(p.x, h * 0.5, p.y), Color(0.3, 0.22, 0.16), 6)
		var g := randf_range(0.16, 0.26)
		_cyl(0.0, randf_range(1.2, 1.8), randf_range(3.0, 4.2), Vector3(p.x, h + 1.4, p.y), Color(g * 0.6, g, g * 0.65), 7)
		_wall(Vector3(0.5, 3, 0.5), Vector3(p.x, 1.5, p.y))
	for i in 50:
		var p2 := Vector2(randf_range(-60, 60), randf_range(-36, 58))
		var near_path := false
		for s in _path_segs:
			var seg: Array = s
			if _seg_dist(p2, seg[0], seg[1]) < 2.0:
				near_path = true
		if near_path:
			continue
		_box(Vector3(randf_range(0.8, 1.6), randf_range(0.5, 0.9), randf_range(0.8, 1.6)), Vector3(p2.x, 0.35, p2.y), Color(0.16, 0.24, 0.15))


func _lamp(pos: Vector3, lit: bool, parent: Node3D = null) -> ShaderMaterial:
	_cyl(0.06, 0.08, 3.2, pos + Vector3(0, 1.6, 0), Color(0.12, 0.13, 0.12), 6, parent)
	var bulb := _box(Vector3(0.3, 0.3, 0.3), pos + Vector3(0, 3.35, 0), Color(0.9, 0.85, 0.6), false, Vector2.ONE, parent)
	var bm := _mat(Color(0.9, 0.85, 0.6), Vector2.ONE, Color(1.0, 0.8, 0.45), 1.6 if lit else 0.0)
	bulb.material_override = bm
	if lit:
		var l := OmniLight3D.new()
		l.position = pos + Vector3(0, 3.0, 0)
		l.light_color = Color(1.0, 0.82, 0.55)
		l.light_energy = 0.9
		l.omni_range = 8.0
		(parent if parent != null else self).add_child(l)
		ambient_lamps.append(l)
	return bm


func _build_lamps() -> void:
	var zs := [44.0, 24.0, 4.0, -16.0, -36.0]
	for i in zs.size():
		var z: float = zs[i]
		var x := 2.2 if i % 2 == 0 else -2.2
		_lamp(Vector3(x, 0, z), i == 0 or i == 2 or i == 4)


func _build_entrance() -> void:
	var c := Color(0.35, 0.32, 0.3)
	_box(Vector3(0.4, 4.4, 0.4), Vector3(-3.2, 2.2, 50), c, true)
	_box(Vector3(0.4, 4.4, 0.4), Vector3(3.2, 2.2, 50), c, true)
	_box(Vector3(7.0, 0.8, 0.3), Vector3(0, 4.4, 50), Color(0.55, 0.2, 0.18))
	var lbl := Label3D.new()
	lbl.text = "PIER PARK"
	lbl.font_size = 64
	lbl.pixel_size = 0.009
	lbl.modulate = Color(1.0, 0.92, 0.75)
	lbl.position = Vector3(0, 4.4, 50.17)
	add_child(lbl)
	# chiosco dei gelati
	_box(Vector3(3.0, 2.6, 3.0), Vector3(7, 1.3, 45), Color(0.75, 0.7, 0.62), true)
	_box(Vector3(3.6, 0.2, 3.6), Vector3(7, 2.7, 45), Color(0.6, 0.25, 0.25))
	var k := Label3D.new()
	k.text = "GELATI"
	k.font_size = 40
	k.pixel_size = 0.008
	k.position = Vector3(7, 2.1, 46.52)
	k.modulate = Color(0.95, 0.85, 0.75)
	add_child(k)
	# panchine qualunque lungo il viale (intere, mai rotte)
	for z in [36.0, 12.0, -24.0]:
		_box(Vector3(0.5, 0.06, 1.8), Vector3(-2.6, 0.45, z), Color(0.5, 0.36, 0.22))
		_box(Vector3(0.06, 0.4, 1.8), Vector3(-2.85, 0.7, z), Color(0.5, 0.36, 0.22))


func _build_pier() -> void:
	var wood := Color(0.45, 0.36, 0.27)
	var dark := Color(0.25, 0.2, 0.16)
	_box(Vector3(4.4, 0.3, 50.5), Vector3(0, -0.15, -67), wood, true, Vector2(2, 25))
	_box(Vector3(4.4, 0.3, 62), Vector3(0, -0.15, -133), wood, true, Vector2(2, 30))
	_box(Vector3(16, 0.3, 24), Vector3(0, -0.15, -176), wood, true, Vector2(8, 12))
	var z := -44.0
	while z > -188.0:
		if z < -91.0 and z > -103.0:
			z -= 6.0
			continue
		var xs := [-2.0, 2.0] if z > -164.0 else [-7.5, -2.5, 2.5, 7.5]
		for x in xs:
			_cyl(0.18, 0.18, 4.0, Vector3(x, -2.1, z), dark, 6)
		z -= 6.0
	_rail(-42.0, -92.0)
	_rail(-102.0, -164.0)
	# parapetto della piattaforma del faro
	_box(Vector3(0.1, 0.1, 24), Vector3(-8, 1.0, -176), dark)
	_box(Vector3(0.1, 0.1, 24), Vector3(8, 1.0, -176), dark)
	_box(Vector3(16, 0.1, 0.1), Vector3(0, 1.0, -188), dark)
	_box(Vector3(5.8, 0.1, 0.1), Vector3(-5.1, 1.0, -164), dark)
	_box(Vector3(5.8, 0.1, 0.1), Vector3(5.1, 1.0, -164), dark)
	_wall(Vector3(0.3, 2, 24), Vector3(-8.1, 1, -176))
	_wall(Vector3(0.3, 2, 24), Vector3(8.1, 1, -176))
	_wall(Vector3(16, 2, 0.3), Vector3(0, 1, -188.1))
	_wall(Vector3(5.8, 2, 0.3), Vector3(-5.1, 1, -164))
	_wall(Vector3(5.8, 2, 0.3), Vector3(5.1, 1, -164))
	# muro invisibile sul bordo del crollo (sparisce quando il ponte è ripristinato)
	bridge_wall = _wall(Vector3(4.4, 3, 0.3), Vector3(0, 1.5, -91.9))
	# assi spezzate sui bordi del crollo
	var a := _box(Vector3(0.9, 0.08, 1.6), Vector3(-1.2, -0.2, -92.4), wood)
	a.rotation = Vector3(0.35, 0.1, 0.0)
	var b := _box(Vector3(0.7, 0.08, 1.4), Vector3(1.4, -0.25, -101.6), wood)
	b.rotation = Vector3(-0.4, -0.2, 0.1)
	# cartello
	_box(Vector3(0.08, 1.6, 0.08), Vector3(2.9, 0.8, -40.5), dark)
	_box(Vector3(1.4, 0.8, 0.06), Vector3(2.9, 1.7, -40.5), Color(0.8, 0.78, 0.7))
	var s := Label3D.new()
	s.text = "MOLO CHIUSO\nDANNI MAREGGIATA"
	s.font_size = 22
	s.pixel_size = 0.006
	s.modulate = Color(0.55, 0.12, 0.1)
	s.position = Vector3(2.9, 1.7, -40.46)
	add_child(s)


func _rail(z0: float, z1: float) -> void:
	var dark := Color(0.25, 0.2, 0.16)
	var seg_len := absf(z1 - z0)
	var zc := (z0 + z1) * 0.5
	for x in [-2.1, 2.1]:
		_box(Vector3(0.08, 0.08, seg_len), Vector3(x, 1.0, zc), dark)
		_wall(Vector3(0.3, 2, seg_len), Vector3(x * 1.05, 1, zc))
		var z := z0
		while z >= z1:
			_box(Vector3(0.1, 1.0, 0.1), Vector3(x, 0.5, z), dark)
			z -= 3.0


func _build_lighthouse() -> void:
	var p := LIGHTHOUSE
	_cyl(2.6, 2.8, 1.2, p + Vector3(0, 0.6, 0), Color(0.45, 0.44, 0.42), 10)
	for i in 4:
		var rb := lerpf(2.2, 1.5, i / 4.0)
		var rt := lerpf(2.2, 1.5, (i + 1) / 4.0)
		var col := Color(0.82, 0.8, 0.74) if i % 2 == 0 else Color(0.6, 0.16, 0.13)
		_cyl(rt, rb, 3.0, p + Vector3(0, 2.7 + 3.0 * i, 0), col, 10)
	_cyl(2.0, 2.0, 0.2, p + Vector3(0, 13.3, 0), Color(0.15, 0.15, 0.15), 10)
	var lantern := _cyl(1.2, 1.2, 1.6, p + Vector3(0, 14.2, 0), Color(0.9, 0.85, 0.6), 10)
	lh_lantern_mat = _mat(Color(0.5, 0.5, 0.45), Vector2.ONE, Color(1.0, 0.85, 0.5), 0.0)
	lantern.material_override = lh_lantern_mat
	_cyl(0.05, 1.5, 1.2, p + Vector3(0, 15.6, 0), Color(0.5, 0.14, 0.12), 10)
	_wall(Vector3(4.6, 16, 4.6), p + Vector3(0, 8, 0))
	# porta
	_box(Vector3(1.0, 1.9, 0.1), p + Vector3(0, 1.0, 2.15), Color(0.25, 0.18, 0.12))

	lh_pivot = Node3D.new()
	lh_pivot.position = p + Vector3(0, 14.2, 0)
	lh_pivot.visible = false
	add_child(lh_pivot)
	var bmat := _beacon_mat(Color(1.0, 0.85, 0.55), Color(1.0, 0.85, 0.55), 0.45, 0.0, false, 50.0)
	for side in [0.0, PI]:
		var arm := Node3D.new()
		arm.rotation.y = side
		lh_pivot.add_child(arm)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 4.0
		cm.height = 50.0
		cm.radial_segments = 10
		cm.cap_top = false
		cm.cap_bottom = false
		var beam := MeshInstance3D.new()
		beam.mesh = cm
		beam.material_override = bmat
		beam.rotation.x = PI / 2.0
		beam.position = Vector3(0, 0, -25)
		arm.add_child(beam)
	lh_light = OmniLight3D.new()
	lh_light.position = p + Vector3(0, 12.5, 0)
	lh_light.light_color = Color(1.0, 0.85, 0.55)
	lh_light.light_energy = 1.5
	lh_light.omni_range = 16.0
	lh_light.visible = false
	add_child(lh_light)


# =================================================================== Memory Node

func _new_node(key: String, title: String, pos: Vector3, radius: float) -> Node3D:
	var n: Node3D = Node3D.new()
	n.set_script(NodeScript)
	n.position = pos
	add_child(n)
	n.key = key
	n.title = title
	n.radius = radius
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 40.0
	cm.radial_segments = 6
	cm.cap_top = false
	cm.cap_bottom = false
	var beacon := MeshInstance3D.new()
	beacon.mesh = cm
	beacon.material_override = _beacon_mat(Color(0.85, 0.2, 0.9), Color(0.2, 0.9, 1.0), 0.9, 1.0, true)
	beacon.position = Vector3(0, 23, 0)
	n.add_child(beacon)
	n.beacon = beacon
	nodes.append(n)
	return n


func _piece(n: Node3D, size: Vector3, color: Color, intact: Transform3D, broken: Transform3D, uv := Vector2.ONE) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _mat(color, uv)
	n.add_child(mi)
	n.add_piece(mi, intact, broken)


func _piece_mesh(n: Node3D, mesh: Mesh, color: Color, intact: Transform3D, broken: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	n.add_child(mi)
	n.add_piece(mi, intact, broken)


func _tr(pos: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)


func _scatter(r: float, y0: float, y1: float) -> Transform3D:
	var ang := randf() * TAU
	var d := randf_range(0.6, r)
	var rot := Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-1.2, 1.2))
	return _tr(Vector3(cos(ang) * d, randf_range(y0, y1), sin(ang) * d), rot)


func _build_nodes() -> void:
	# --- 1. la panchina panoramica
	var bench := _new_node("bench", "LA PANCHINA", BENCH_POS, 5.0)
	var wood := Color(0.6, 0.4, 0.22)
	var iron := Color(0.13, 0.14, 0.13)
	for i in 3:
		_piece(bench, Vector3(1.8, 0.05, 0.13), wood, _tr(Vector3(0, 0.45, -0.16 + i * 0.16)), _scatter(2.6, 0.05, 0.2))
	for i in 2:
		_piece(bench, Vector3(1.8, 0.13, 0.04), wood, _tr(Vector3(0, 0.66 + i * 0.17, 0.24), Vector3(-0.2, 0, 0)), _scatter(2.6, 0.05, 0.2))
	for x in [-0.8, 0.8]:
		_piece(bench, Vector3(0.06, 0.45, 0.42), iron, _tr(Vector3(x, 0.22, 0)), _scatter(2.2, 0.1, 0.2))
		_piece(bench, Vector3(0.06, 0.5, 0.06), iron, _tr(Vector3(x, 0.72, 0.25), Vector3(-0.2, 0, 0)), _scatter(2.2, 0.05, 0.15))
	bench.reward_mats.append(_lamp(Vector3(-1.8, 0, 0.8), false, bench))
	var bl := OmniLight3D.new()
	bl.position = Vector3(-1.8, 3.0, 0.8)
	bl.light_color = Color(1.0, 0.8, 0.5)
	bl.light_energy = 1.5
	bl.omni_range = 9.0
	bl.visible = false
	bench.add_child(bl)
	bench.reward_lights.append(bl)
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		bench.add_silhouette(Vector3(cos(a) * 7.0, 0, sin(a) * 7.0), _sil_mat)

	# --- 2. il gazebo
	var gz := _new_node("gazebo", "IL GAZEBO", GAZEBO_POS, 6.0)
	_cyl(3.1, 3.2, 0.25, Vector3(0, 0.12, 0), Color(0.55, 0.53, 0.5), 8, gz)
	var white := Color(0.85, 0.83, 0.76)
	for i in 6:
		var a := i * TAU / 6.0
		var post := CylinderMesh.new()
		post.top_radius = 0.1
		post.bottom_radius = 0.1
		post.height = 2.6
		post.radial_segments = 6
		var broken := _tr(Vector3(cos(a) * randf_range(3.5, 5.0), 0.12, sin(a) * randf_range(3.5, 5.0)), Vector3(PI / 2.0, randf() * TAU, 0))
		_piece_mesh(gz, post, white, _tr(Vector3(cos(a) * 2.7, 1.55, sin(a) * 2.7)), broken)
	for i in range(1, 6):
		var a := (i + 0.5) * TAU / 6.0
		var r := 2.7 * cos(PI / 6.0)
		_piece(gz, Vector3(2.6, 0.08, 0.08), white, _tr(Vector3(cos(a) * r, 0.9, sin(a) * r), Vector3(0, -(a + PI / 2.0), 0)), _scatter(4.5, 0.05, 0.1))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.05
	roof.bottom_radius = 3.5
	roof.height = 1.5
	roof.radial_segments = 6
	_piece_mesh(gz, roof, Color(0.5, 0.22, 0.2), _tr(Vector3(0, 3.6, 0)), _tr(Vector3(1.6, 0.55, 2.2), Vector3(0.5, 0.4, 0.45)))
	var lantern := _box(Vector3(0.25, 0.35, 0.25), Vector3(0, 2.5, 0), Color(0.9, 0.85, 0.6), false, Vector2.ONE, gz)
	var lm := _mat(Color(0.5, 0.45, 0.35), Vector2.ONE, Color(1.0, 0.75, 0.4), 0.0)
	lantern.material_override = lm
	gz.reward_mats.append(lm)
	var gl := OmniLight3D.new()
	gl.position = Vector3(0, 2.4, 0)
	gl.light_color = Color(1.0, 0.75, 0.45)
	gl.light_energy = 1.8
	gl.omni_range = 10.0
	gl.visible = false
	gz.add_child(gl)
	gz.reward_lights.append(gl)
	for i in 4:
		var a := i * TAU / 4.0 + 0.8
		gz.add_silhouette(Vector3(cos(a) * 8.0, 0, sin(a) * 8.0), _sil_mat)

	# --- 3. il ponte del molo crollato
	var br := _new_node("bridge", "IL PONTE DEL MOLO", BRIDGE_POS, 8.5)
	var pw := Color(0.45, 0.36, 0.27)
	for i in 5:
		var intact := _tr(Vector3(0, -0.15, -4.0 + i * 2.0))
		var broken := _tr(Vector3(randf_range(-4.0, 4.0), -1.35, -4.0 + i * 2.0 + randf_range(-1.0, 1.0)), Vector3(randf_range(-0.25, 0.25), randf_range(-0.8, 0.8), randf_range(-0.25, 0.25)))
		_piece(br, Vector3(4.4, 0.3, 2.0), pw, intact, broken, Vector2(2, 1))
	for x in [-2.1, 2.1]:
		_piece(br, Vector3(0.08, 0.08, 10.0), Color(0.25, 0.2, 0.16), _tr(Vector3(x, 1.0, 0)), _tr(Vector3(x * 2.2, -1.3, randf_range(-2, 2)), Vector3(0.1, randf_range(-0.5, 0.5), 0.2)))
	for i in 3:
		br.add_silhouette(Vector3(randf_range(-1.2, 1.2), 0, 12.0 + i * 6.0), _sil_mat)


func _build_bounds() -> void:
	_wall(Vector3(1, 6, 110), Vector3(-64, 3, 10))
	_wall(Vector3(1, 6, 110), Vector3(64, 3, 10))
	_wall(Vector3(130, 6, 1), Vector3(0, 3, 62))
	_wall(Vector3(62.8, 6, 0.6), Vector3(-33.6, 3, -41.6))
	_wall(Vector3(62.8, 6, 0.6), Vector3(33.6, 3, -41.6))
	# ringhiera visibile sul lungomare
	for side in [-1.0, 1.0]:
		_box(Vector3(62.8, 0.08, 0.08), Vector3(side * 33.6, 1.0, -41.5), Color(0.2, 0.2, 0.2))
		var x := 2.4
		while x < 64.0:
			_box(Vector3(0.08, 1.0, 0.08), Vector3(side * x, 0.5, -41.5), Color(0.2, 0.2, 0.2))
			x += 2.5


# =================================================================== loop

func _locked_count() -> int:
	var c := 0
	for n in nodes:
		if n.state == NodeScript.LOCKED:
			c += 1
	return c


func _node(key: String) -> Node3D:
	for n in nodes:
		if n.key == key:
			return n
	return null


func _can_rewind(n: Node3D) -> bool:
	if n.key == "bridge":
		return _locked_count() >= 2
	return true


func _process(delta: float) -> void:
	_t += delta
	if lh_on:
		lh_pivot.rotation.y += delta * 0.55
	warmth = move_toward(warmth, warmth_target, delta * 0.12)
	glitch_spike = maxf(0.0, glitch_spike - delta * 1.4)
	if not dawn:
		var cool := Color(0.3, 0.33, 0.4)
		var warmc := Color(0.5, 0.42, 0.38)
		var fc := cool.lerp(warmc, warmth)
		env.fog_light_color = fc
		env.background_color = fc
		env.fog_density = lerpf(0.045, 0.034, warmth)
		env.ambient_light_color = Color(0.5, 0.55, 0.65).lerp(Color(0.7, 0.6, 0.5), warmth)

	var glitch := 0.0
	if state == PLAY:
		glitch = _play_update(delta)
	elif state == ENDING:
		glitch = _ending_update(delta)
	elif state == MENU:
		menu_cam.rotation = _menu_rot + Vector3(sin(_t * 0.11) * 0.012, sin(_t * 0.07) * 0.03, 0.0)
	var g_total := glitch + glitch_spike
	if bool(Settings.g("reduce_flash")):
		g_total = minf(g_total * 0.35, 0.3)
	hud.post_mat.set_shader_parameter("warmth", warmth)
	hud.post_mat.set_shader_parameter("glitch", g_total)
	hud.post_mat.set_shader_parameter("vhs", float(Settings.g("vhs")) / 100.0)
	hud.post_mat.set_shader_parameter("brightness", float(Settings.g("brightness")) / 100.0)
	audio.pad = 1.0 if hud.subs_playing and state == PLAY and _locked_count() > 0 else audio.pad
	if state == PLAY and not hud.subs_playing:
		audio.pad = 0.0


func _play_update(delta: float) -> float:
	var ppos := player.global_position
	if ppos.y < -3.0:
		player.global_position = PIER_RESPAWN
		player.velocity = Vector3.ZERO
		glitch_spike = 1.2
		hud.flash_info("TRACKING...", 2.0)
		return 0.5

	var holding := force_hold or Input.is_physical_key_pressed(KEY_Q) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var near_node: Node3D = null
	var near_d := 1e9
	var static_level := 0.0
	for n in nodes:
		var d := _hdist(ppos, n.global_position)
		if n.state != NodeScript.LOCKED:
			static_level = maxf(static_level, clampf(1.0 - d / 30.0, 0.0, 1.0))
		if n.state == NodeScript.BROKEN and d < n.radius and d < near_d:
			near_node = n
			near_d = d

	var rewind_vis := 0.0
	for n in nodes:
		var can: bool = n == near_node and _can_rewind(n) and dial_node == null
		n.update_node(delta, holding and can, ppos)
		if n.just_vanished:
			glitch_spike = maxf(glitch_spike, 0.6)
			audio.blip()
		if n.state == NodeScript.BROKEN and n.progress > 0.0:
			rewind_vis = maxf(rewind_vis, n.progress)
		if n.state == NodeScript.DIAL and dial_node == null:
			_start_dial(n)

	var prompt := ""
	var dial_glitch := 0.0
	if dial_node != null:
		dial_glitch = _dial_update(delta)
	elif near_node != null:
		if _can_rewind(near_node):
			prompt = "[Q] TIENI PREMUTO  —  RIAVVOLGI"
		else:
			prompt = "IL NASTRO NON TORNA PIÙ INDIETRO  ·  RICORDI %d/2" % _locked_count()

	var at_lh := _locked_count() == 3 and _hdist(ppos, LIGHTHOUSE) < 12.5
	hud.choice_on = at_lh
	if at_lh and not _choice_announced:
		_choice_announced = true
		hud.play_subs(LOGS["lighthouse"])
		audio.blip()

	var is_rew: bool = holding and rewind_vis > 0.0 and dial_node == null
	hud.rewind_progress = rewind_vis
	hud.stamina = player.stamina
	hud.exhausted = player.exhausted
	audio.breath = clampf(1.0 - player.stamina / 0.6, 0.0, 1.0) * (1.0 if player.exhausted else 0.6)
	hud.set_prompt(prompt)
	hud.mode = "rew" if is_rew else "play"
	audio.node_static = static_level
	audio.rewinding = rewind_vis if is_rew else 0.0
	return 0.05 + static_level * static_level * 0.28 + rewind_vis * 0.45 + dial_glitch


func _start_dial(n: Node3D) -> void:
	dial_node = n
	n.target = randf_range(0.2, 0.8)
	n.freq = clampf(n.target + (0.35 if randf() < 0.5 else -0.35), 0.03, 0.97)
	n.lock_fill = 0.0
	player.locked = true
	player.look_locked = true
	hud.dial_active = true
	audio.dial_on = true
	hud.flash_info("SEGNALE INSTABILE", 3.0)


func _dial_update(delta: float) -> float:
	var n := dial_node
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir += 1.0
	n.freq = clampf(n.freq + dir * delta * 0.28, 0.0, 1.0)
	var tgt: float = n.target + sin(_t * 0.9) * 0.015
	var diff: float = absf(n.freq - tgt)
	if diff < 0.022:
		n.lock_fill = n.lock_fill + delta / 2.8
	else:
		n.lock_fill = maxf(0.0, n.lock_fill - delta * 0.4)
	hud.dial_freq = n.freq
	hud.dial_signal = 1.0 - clampf(diff / 0.12, 0.0, 1.0)
	hud.dial_lock = n.lock_fill
	audio.dial_mis = clampf(diff / 0.15, 0.0, 1.0)
	if n.lock_fill >= 1.0:
		_lock_node(n)
	return clampf(diff / 0.2, 0.0, 1.0) * 0.3


func _lock_node(n: Node3D) -> void:
	n.lock()
	dial_node = null
	hud.dial_active = false
	audio.dial_on = false
	player.locked = false
	player.look_locked = false
	audio.chime()
	var c := _locked_count()
	warmth_target = float(c) / 3.0 * 0.8
	hud.flash_info("MEMORIA %d/3 — RIPRISTINATA" % c, 4.0)
	if n.key == "bridge":
		bridge_wall.queue_free()
		_wall(Vector3(4.4, 0.3, 10.4), Vector3(0, -0.15, BRIDGE_POS.z))
		lh_on = true
		lh_pivot.visible = true
		lh_light.visible = true
		lh_lantern_mat.set_shader_parameter("emission_energy", 2.2)
	await get_tree().create_timer(1.5).timeout
	if state == PLAY:
		hud.play_subs(LOGS[n.key])


func _on_step() -> void:
	audio.step(player.global_position.z < -41.5)


func _unhandled_input(event: InputEvent) -> void:
	if state == ENDING:
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
			get_tree().reload_current_scene()
		return
	if state != PLAY:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _test == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if dial_node != null:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			dial_node.freq = clampf(dial_node.freq + (event as InputEventMouseMotion).relative.x * 0.0012, 0.0, 1.0)
		elif event is InputEventMouseButton and event.pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				dial_node.freq = clampf(dial_node.freq + 0.01, 0.0, 1.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				dial_node.freq = clampf(dial_node.freq - 0.01, 0.0, 1.0)
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SHIFT and bool(Settings.g("sprint_toggle")):
			player.sprint_toggle_on = not player.sprint_toggle_on
		elif hud.choice_on and k == KEY_Q:
			_ending_rewind()
		elif hud.choice_on and k == KEY_E:
			_ending_eject()


# =================================================================== finali

func _ending_update(_delta: float) -> float:
	if ending_id == 1:
		_loop_t -= _delta
		if _loop_t <= 0.0:
			_loop_t = 3.6
			glitch_spike = 1.0
			hud.flash_mode("rew", 0.6)
			audio.chime()
		return 0.25
	return 0.0


func _ending_rewind() -> void:
	state = ENDING
	menu.in_game = false
	audio.breath = 0.0
	hud.stamina = 1.0
	hud.play_subs([])
	ending_id = 0
	hud.choice_on = false
	hud.set_prompt("")
	hud.mode = "rew"
	player.locked = true
	player.look_locked = true
	audio.rewinding = 1.0
	audio.node_static = 0.0
	var tt := 0.0
	while tt < 2.0:
		glitch_spike = 0.3 + tt / 2.0
		await get_tree().process_frame
		tt += get_process_delta_time()
	audio.rewinding = 0.0
	# il passato: la panchina, calda e perfetta
	player.global_position = BENCH_POS + Vector3(3.0, 0.1, -4.5)
	player.look_at_point(BENCH_POS + Vector3(0, 0.6, 0))
	warmth = 1.0
	warmth_target = 1.0
	for i in 4:
		await get_tree().process_frame
	hud.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.visible = true
	hud.show_freeze(ImageTexture.create_from_image(img))
	hud.mode = "pause"
	hud.clock_frozen = true
	hud.post_mat.set_shader_parameter("freeze", 1.0)
	audio.freeze = true
	audio.pad = 0.0
	ending_id = 1
	await get_tree().create_timer(4.0).timeout
	hud.show_ending("FINALE 1 — BLOCCATO NEL REWIND",
		"Hai riavvolto ancora. La panchina è intera, la luce è calda, tutto è fermo.\nIl passato è bellissimo in pausa. Ma in pausa non ci si rialza.")
	print("ENDING 1")
	await _to_be_continued()


func _ending_eject() -> void:
	state = ENDING
	menu.in_game = false
	audio.breath = 0.0
	hud.stamina = 1.0
	hud.play_subs([])
	ending_id = 2
	hud.choice_on = false
	hud.set_prompt("")
	hud.mode = "eject"
	player.locked = true
	player.look_locked = true
	audio.clunk()
	audio.node_static = 0.0
	await get_tree().create_timer(0.8).timeout
	hud.fade_to(1.0, 0.6)
	await get_tree().create_timer(1.3).timeout
	audio.hiss = 0.0
	audio.pad = 1.0
	_set_dawn()
	player.global_position = Vector3(5.5, 0.1, -178.0)
	player.yaw = atan2(-SUN_DIR.x, -SUN_DIR.z)
	player.pitch = 0.12
	hud.set_osd_visible(false)
	hud.post_mat.set_shader_parameter("clean", 1.0)
	hud.fade_to(0.0, 3.0)
	await get_tree().create_timer(4.5).timeout
	hud.show_ending("FINALE 2 — BOUNCE BACK",
		"Hai espulso il nastro. Niente più filtro, niente più timecode: solo l'alba sul molo.\nCadere è successo. Rialzarsi sta succedendo adesso.")
	print("ENDING 2")
	await _to_be_continued()


## Dopo qualunque finale: nero, poi "To be continued..." (è solo il nastro 01).
func _to_be_continued() -> void:
	await get_tree().create_timer(7.0).timeout
	hud.fade_to(1.0, 2.0)
	await get_tree().create_timer(2.3).timeout
	ending_id = ending_id + 10   # ferma il loop del finale 1 sotto il nero
	audio.freeze = false
	audio.hiss = 0.25
	hud.set_osd_visible(false)
	await hud.show_tbc()
	print("TO BE CONTINUED")


func _set_dawn() -> void:
	dawn = true
	warmth = 0.0
	warmth_target = 0.0
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.5, 0.78)
	sky_mat.sky_horizon_color = Color(1.0, 0.68, 0.52)
	sky_mat.ground_horizon_color = Color(0.95, 0.65, 0.52)
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.32)
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_light_color = Color(0.98, 0.78, 0.66)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.25
	env.ambient_light_color = Color(0.95, 0.8, 0.7)
	env.ambient_light_energy = 0.7
	sea_mat.set_shader_parameter("deep", Color(0.28, 0.32, 0.45))
	sea_mat.set_shader_parameter("crest", Color(0.85, 0.62, 0.52))
	moon.light_color = Color(1.0, 0.8, 0.6)
	moon.light_energy = 1.3
	moon.look_at_from_position(Vector3.ZERO, -SUN_DIR.normalized(), Vector3.UP)
	for n in nodes:
		n.beacon.visible = false
	lh_pivot.visible = false


# =================================================================== collaudo

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _solve_node(key: String, stand: Vector3) -> void:
	var n := _node(key)
	player.global_position = stand
	player.velocity = Vector3.ZERO
	force_hold = true
	var guard := 0
	while n.state == NodeScript.BROKEN and guard < 2000:
		await get_tree().process_frame
		guard += 1
	force_hold = false
	guard = 0
	while n.state == NodeScript.DIAL and guard < 2000:
		n.freq = n.target + sin(_t * 0.9) * 0.015
		await get_tree().process_frame
		guard += 1


func _press(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _autotest() -> void:
	await _wait(5)
	_enter_menu()
	await get_tree().create_timer(1.0).timeout
	print("[autotest] menu visibile: ", menu.main_menu.visible, "  stato=", state)
	menu._on_play()
	await get_tree().create_timer(2.5).timeout
	print("[autotest] dal menu al gioco: ", state == PLAY)
	# voce a sillabe durante l'intro
	await get_tree().create_timer(3.0).timeout
	print("[autotest] sillabe di voce emesse nell'intro: ", voice_count)
	# stamina: corsa piena fino allo sfinimento, poi recupero
	_press(KEY_W, true)
	_press(KEY_SHIFT, true)
	await get_tree().create_timer(2.0).timeout
	print("[autotest] corsa: sprinting=%s stamina=%.2f" % [player.sprinting, player.stamina])
	await get_tree().create_timer(6.5).timeout
	print("[autotest] dopo ~8.5 s: stamina=%.2f esausto=%s" % [player.stamina, player.exhausted])
	_press(KEY_SHIFT, false)
	_press(KEY_W, false)
	await get_tree().create_timer(3.0).timeout
	print("[autotest] dopo 3 s di riposo: stamina=%.2f esausto=%s" % [player.stamina, player.exhausted])
	# pausa
	menu.pause_game()
	var tbefore: float = hud.clock_seconds
	await get_tree().create_timer(1.0).timeout
	print("[autotest] pausa ferma il tempo: ", get_tree().paused and absf(hud.clock_seconds - tbefore) < 0.01)
	menu.resume_game()
	# impostazioni: preset e personalizzata
	Settings.set_v("quality", 0)
	var q_low: bool = int(Settings.g("render_scale")) == 60 and int(Settings.g("msaa")) == 0
	Settings.set_v("msaa", 3)
	print("[autotest] preset Bassa applicato: ", q_low, "  -> Personalizzata dopo modifica: ", int(Settings.g("quality")) == 4)
	Settings.reset_defaults()
	# il ponte non deve riavvolgersi prima degli altri due ricordi
	var br := _node("bridge")
	player.global_position = Vector3(0, 0.1, -89.0)
	force_hold = true
	await get_tree().create_timer(1.0).timeout
	force_hold = false
	print("[autotest] ponte bloccato all'inizio: ", br.progress == 0.0)
	await _solve_node("bench", BENCH_POS + Vector3(0, 0.1, -3.0))
	print("[autotest] panchina: ", _node("bench").state == NodeScript.LOCKED)
	await _solve_node("gazebo", GAZEBO_POS + Vector3(-3.0, 0.1, 3.0))
	print("[autotest] gazebo: ", _node("gazebo").state == NodeScript.LOCKED)
	await _solve_node("bridge", Vector3(0, 0.1, -89.0))
	print("[autotest] ponte: ", br.state == NodeScript.LOCKED)
	player.global_position = Vector3(0, 0.6, -97.0)
	await _wait(60)
	print("[autotest] in piedi sul ponte ripristinato (y=%.2f): %s" % [player.global_position.y, player.global_position.y > -0.5])
	player.global_position = Vector3(0, 0.1, -170.0)
	await _wait(10)
	print("[autotest] scelta al faro: ", hud.choice_on)
	if "--ending1" in OS.get_cmdline_user_args():
		_ending_rewind()
	else:
		_ending_eject()
	await get_tree().create_timer(24.0).timeout
	print("[autotest] stato finale: ", ending_id % 10, "  to be continued visibile: ", hud.tbc_label.visible, " -> '", hud.tbc_label.text, "'")
	get_tree().quit()


func _shot(fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	var path: String = OS.get_user_data_dir() + "/" + fname + ".png"
	img.save_png(path)
	print("SHOT ", path)


func _shots() -> void:
	await _wait(5)
	_enter_menu()
	await get_tree().create_timer(2.5).timeout
	await _shot("00_menu")
	menu.open_settings("main")
	await _wait(10)
	await _shot("00_settings_video")
	var tabs: TabContainer = menu.settings_panel.get_child(0).get_child(1)
	tabs.current_tab = 1
	await _wait(10)
	await _shot("00_settings_audio")
	tabs.current_tab = 3
	await _wait(10)
	await _shot("00_settings_accessibilita")
	menu.close_settings()
	menu.main_menu.visible = false
	_on_start()
	hud.fade_rect.color = Color(0, 0, 0, 0)
	await get_tree().create_timer(2.2).timeout
	await _shot("01_ingresso")
	_press(KEY_W, true)
	_press(KEY_SHIFT, true)
	await get_tree().create_timer(3.0).timeout
	await _shot("01b_corsa")
	_press(KEY_SHIFT, false)
	_press(KEY_W, false)
	hud.play_subs([])
	player.global_position = BENCH_POS + Vector3(2.0, 0.1, -4.0)
	player.look_at_point(BENCH_POS + Vector3(0, 0.8, 0))
	await _wait(40)
	await _shot("02_panchina_rotta")
	force_hold = true
	var b := _node("bench")
	while b.progress < 0.55:
		await get_tree().process_frame
	await _shot("03_riavvolgi")
	while b.state == NodeScript.BROKEN:
		await get_tree().process_frame
	force_hold = false
	b.freq = b.target + 0.08
	await _wait(20)
	await _shot("04_sintonia")
	while b.state == NodeScript.DIAL:
		b.freq = b.target + sin(_t * 0.9) * 0.015
		await get_tree().process_frame
	await get_tree().create_timer(3.5).timeout
	await _shot("05_panchina_ripristinata")
	await _solve_node("gazebo", GAZEBO_POS + Vector3(-3.0, 0.1, 3.0))
	player.global_position = GAZEBO_POS + Vector3(-6.0, 0.1, 7.0)
	player.look_at_point(GAZEBO_POS + Vector3(0, 1.8, 0))
	await get_tree().create_timer(3.0).timeout
	await _shot("06_gazebo")
	player.global_position = Vector3(0, 0.1, -72.0)
	player.look_at_point(Vector3(0, 0.5, -97.0))
	await _wait(40)
	await _shot("07_molo_crollato")
	await _solve_node("bridge", Vector3(0, 0.1, -89.0))
	player.global_position = Vector3(0, 0.1, -140.0)
	player.look_at_point(LIGHTHOUSE + Vector3(0, 9, 0))
	await get_tree().create_timer(3.0).timeout
	hud.play_subs([])
	await _shot("08_faro")
	player.global_position = Vector3(0, 0.1, -170.0)
	player.look_at_point(LIGHTHOUSE + Vector3(0, 4, 0))
	await _wait(30)
	await _shot("09_scelta")
	if "--ending1" in OS.get_cmdline_user_args():
		_ending_rewind()
		await get_tree().create_timer(7.0).timeout
		await _shot("11_bloccato")
	else:
		_ending_eject()
		await get_tree().create_timer(7.5).timeout
		await _shot("10_alba")
		await get_tree().create_timer(13.0).timeout
		await _shot("12_to_be_continued")
	get_tree().quit()

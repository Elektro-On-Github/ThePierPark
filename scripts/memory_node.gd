extends Node3D
## Un "Memory Node": un luogo rotto che si può riavvolgere.
## BROKEN: i pezzi sono sparsi e tremano. Tenendo premuto REW tornano al loro posto;
##         se lasci prima, "rimbalzano" indietro verso il rotto.
## DIAL:   l'oggetto è intero ma il segnale è instabile: va sintonizzato (gestito dal main).
## LOCKED: ricordo fissato. Le sagome svaniscono, la luce si accende.

const BROKEN := 0
const DIAL := 1
const LOCKED := 2

var key := ""
var title := ""
var radius := 5.0
var state := BROKEN
var progress := 0.0
var freq := 0.2
var target := 0.5
var lock_fill := 0.0
var just_vanished := false

var pieces: Array = []
var silhouettes: Array = []
var beacon: MeshInstance3D
var reward_lights: Array = []
var reward_mats: Array = []

var _jit_t := 0.0


func add_piece(mi: MeshInstance3D, intact: Transform3D, broken: Transform3D) -> void:
	pieces.append({"n": mi, "a": intact, "b": broken})
	mi.transform = broken


func add_silhouette(local_pos: Vector3, mat: Material) -> void:
	var s := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = 1.95
	cm.radial_segments = 6
	cm.rings = 2
	body.mesh = cm
	body.position.y = 0.98
	body.material_override = mat
	s.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.34
	sm.radial_segments = 6
	sm.rings = 4
	head.mesh = sm
	head.position.y = 2.1
	head.material_override = mat
	s.add_child(head)
	s.position = local_pos
	add_child(s)
	silhouettes.append({"n": s, "home": local_pos, "gone": 0.0})


func update_node(dt: float, holding: bool, player_pos: Vector3) -> void:
	just_vanished = false
	if state == BROKEN:
		if holding:
			progress = minf(1.0, progress + dt / 3.2)
			if progress >= 1.0:
				state = DIAL
		else:
			progress = maxf(0.0, progress - dt * 0.45)

	var w := progress if state == BROKEN else 1.0
	var e := w * w * (3.0 - 2.0 * w)
	_jit_t -= dt
	var jitter := state == BROKEN and _jit_t <= 0.0
	if jitter:
		_jit_t = randf_range(0.05, 0.4)
	for p in pieces:
		var d: Dictionary = p
		var mi: MeshInstance3D = d["n"]
		var a: Transform3D = d["a"]
		var b: Transform3D = d["b"]
		var tr := b.interpolate_with(a, e)
		if jitter and progress < 0.95 and randf() < 0.35:
			tr.origin += Vector3(randf_range(-0.07, 0.07), randf_range(-0.03, 0.03), randf_range(-0.07, 0.07)) * (1.0 - e)
		mi.transform = tr
		mi.visible = state != BROKEN or randf() > 0.03

	for item in silhouettes:
		var sd: Dictionary = item
		var s: Node3D = sd["n"]
		if state == LOCKED:
			s.scale.y = maxf(0.001, s.scale.y - dt * 1.2)
			s.visible = s.scale.y > 0.01 and randf() > 0.35
			continue
		var gone: float = sd["gone"]
		if gone > 0.0:
			gone -= dt
			sd["gone"] = gone
			s.visible = false
			if gone <= 0.0:
				var ang := randf() * TAU
				var home: Vector3 = sd["home"]
				s.position = home + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(0.0, 2.0)
			continue
		var to := player_pos - s.global_position
		to.y = 0.0
		if to.length() < 4.0:
			sd["gone"] = randf_range(6.0, 10.0)
			just_vanished = true
			s.visible = false
			continue
		s.rotation.y = atan2(to.x, to.z)
		s.visible = randf() > 0.05

	if beacon != null:
		beacon.visible = state != LOCKED


func lock() -> void:
	state = LOCKED
	progress = 1.0
	for l in reward_lights:
		var n: Node3D = l
		n.visible = true
	for m in reward_mats:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("emission_energy", 1.8)

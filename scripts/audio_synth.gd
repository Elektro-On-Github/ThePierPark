extends Node
## Tutto l'audio è sintetizzato a campioni, nessun file.
## Categorie (volumi da Settings):
##   AMBIENTE  risacca, fruscio del nastro, statica dei ricordi
##   EFFETTI   motore del rewind, sintonia, chime, passi, clunk, bip, fiatone
##   MUSICA    pad caldo (menu, log, finale)
##   VOCE      borbottio a sillabe dei dialoghi (stile "Bad Parenting")

const RATE := 22050.0

# parametri impostati dal main ogni frame
var hiss := 1.0
var node_static := 0.0
var rewinding := 0.0
var dial_on := false
var dial_mis := 1.0
var pad := 0.0
var freeze := false
var breath := 0.0
var paused := false

var _pb: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _hiss_g := 1.0
var _pad_g := 0.0
var _static_g := 0.0
var _breath_g := 0.0
var _lp1 := 0.0
var _lp2 := 0.0
var _lp3 := 0.0
var _rw_ph := 0.0
var _crack := 0.0
var _chime := 0.0
var _step := 0.0
var _step_wood := false
var _clunk := 0.0
var _blip := 0.0
# voce
var _v_env := 0.0
var _v_att := 0.0
var _v_ph := 0.0
var _v_f := 140.0
var _v_target := 140.0
var _v_lp := 0.0


func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = -3.0
	add_child(player)
	player.play()
	_pb = player.get_stream_playback() as AudioStreamGeneratorPlayback


func chime() -> void:
	_chime = 1.0


func step(wood: bool) -> void:
	_step = 1.0
	_step_wood = wood


func clunk() -> void:
	_clunk = 1.0


func blip() -> void:
	_blip = 1.0


## Una "sillaba" di voce: altezza legata alla lettera (stessa lettera = stesso suono),
## con piccola variazione casuale e un leggero glissato verso il basso.
func voice(c: String) -> void:
	var code := c.to_lower().unicode_at(0)
	var vowel := "aeiouàèéìòù".contains(c.to_lower())
	var base := 118.0 + float(code % 9) * 9.0
	if vowel:
		base *= 1.12
	base *= _rng.randf_range(0.94, 1.06)
	_v_target = base
	_v_f = base * 1.18
	_v_env = 1.0
	_v_att = 0.0


func _process(delta: float) -> void:
	if _pb == null:
		return
	var g_amb := Settings.vol("vol_ambient")
	var g_sfx := Settings.vol("vol_sfx")
	var g_mus := Settings.vol("vol_music")
	var g_voice := Settings.vol("vol_voice")
	if paused:
		g_sfx *= 0.0
		g_voice *= 0.0
	var hiss_target := hiss * (2.5 if freeze else 1.0)
	_hiss_g = move_toward(_hiss_g, hiss_target, delta * 0.8)
	_pad_g = move_toward(_pad_g, pad, delta * 0.35)
	_static_g = move_toward(_static_g, 0.0 if paused else node_static, delta * 1.5)
	_breath_g = move_toward(_breath_g, breath, delta * 0.6)
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var dt := 1.0 / RATE
	var rw := 0.0 if paused else rewinding
	var dial := dial_on and not paused
	var dmis := dial_mis
	var dalign := 1.0 - dial_mis
	for i in n:
		_t += dt
		var w := _rng.randf() * 2.0 - 1.0
		_lp1 += (w - _lp1) * 0.015
		_lp2 += (w - _lp2) * 0.3
		_lp3 += (w - _lp3) * 0.08
		var swell := 0.5 + 0.5 * sin(_t * 0.45)
		swell *= swell
		# --- ambiente
		var amb := _lp1 * 1.1 * (0.25 + 0.75 * swell)
		amb += (w - _lp2) * 0.022 * _hiss_g
		if _static_g > 0.01:
			if _rng.randf() < 0.0015:
				_crack = 1.0
			_crack *= 0.996
			amb += w * _static_g * (0.02 + 0.14 * _crack)
			amb += sin(TAU * 60.0 * _t) * 0.02 * _static_g
		# --- effetti
		var fx := 0.0
		if rw > 0.0:
			_rw_ph += (110.0 + 520.0 * rw + 35.0 * sin(_t * 31.0)) * dt
			fx += (fposmod(_rw_ph, 1.0) * 2.0 - 1.0) * 0.045
			fx += _lp2 * 0.08
		if dial:
			fx += w * 0.18 * dmis
			fx += (sin(TAU * 523.25 * _t) + 0.6 * sin(TAU * 659.25 * _t)) * 0.05 * dalign * dalign
		if _chime > 0.0005:
			fx += (sin(TAU * 880.0 * _t) + 0.7 * sin(TAU * 1318.5 * _t) + 0.4 * sin(TAU * 1760.0 * _t)) * 0.06 * _chime
			_chime *= 0.99992
		if _step > 0.001:
			fx += _lp2 * _step * 0.45
			if _step_wood:
				fx += sin(TAU * 95.0 * _t) * _step * 0.25
			_step *= 0.9975
		if _clunk > 0.001:
			fx += sin(TAU * 55.0 * _t) * _clunk * 0.5
			if _clunk > 0.7:
				fx += w * 0.35
			_clunk *= 0.9988
		if _blip > 0.001:
			fx += sin(TAU * 1400.0 * _t) * _blip * 0.05
			_blip *= 0.9993
		if _breath_g > 0.01:
			# fiatone: inspiro/espiro ~ 0.7 cicli al secondo
			var cyc := sin(TAU * 0.72 * _t)
			var env := cyc * cyc
			fx += (_lp3 - _lp2 * 0.4) * env * _breath_g * 0.5
		# --- musica
		var mus := 0.0
		if _pad_g > 0.001:
			var trem := 0.8 + 0.2 * sin(_t * 1.3)
			mus = (sin(TAU * 220.0 * _t) + 0.8 * sin(TAU * 277.18 * _t) + 0.7 * sin(TAU * 329.63 * _t) + 0.3 * sin(TAU * 440.0 * _t)) * 0.022 * _pad_g * trem
		# --- voce
		var vo := 0.0
		if _v_env > 0.001:
			_v_att = minf(1.0, _v_att + 1.0 / 90.0)
			_v_f += (_v_target - _v_f) * 0.0015
			_v_ph += _v_f * dt
			var ph := fposmod(_v_ph, 1.0)
			var sq := 1.0 if ph < 0.5 else -1.0
			var tri := 1.0 - 4.0 * absf(ph - 0.5)
			var raw := sq * 0.3 + tri * 0.7 + sin(TAU * _v_ph * 3.0) * 0.25
			_v_lp += (raw - _v_lp) * 0.22
			vo = _v_lp * _v_env * _v_att * 0.16
			_v_env *= 0.99962
		var s := amb * g_amb + fx * g_sfx + mus * g_mus + vo * g_voice
		s = clampf(s, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	_pb.push_buffer(buf)

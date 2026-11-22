extends Node
## Procedural audio: synthesised SFX and a synthwave loop rendered to PCM at startup.

const RATE := 22050
const BPM := 140.0
const ROOTS := [55.0, 43.65, 65.41, 49.0]          # A1, F1, C2, G1  (Am - F - C - G)
const CHORDS := [[0, 3, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12], [0, 4, 7, 11]]

var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var music: AudioStreamPlayer
var _mus: PackedFloat32Array
var _mus_i := 0
var _mus_total := 0
var _bass_lp := 0.0
var _noise_prev := 0.0
var _want_music := false
var _music_pitch := 1.0
var _music_db := -9.0


const SFX_NAMES := ["shot", "hit", "kill", "boom", "pickup", "graze", "hurt", "bomb", "eshot", "ui", "select", "nova", "levelup", "warn", "phase"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 18:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	# Audio is synthesised offline by tools/bake_audio.tscn into res://audio/*.wav
	# (runtime synthesis is far too slow for GDScript on WebAssembly).
	for n: String in SFX_NAMES:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	if ResourceLoader.exists("res://audio/music.wav"):
		music.stream = load("res://audio/music.wav")
		music.finished.connect(func() -> void: music.play())


## Offline bake: renders every sound + the music loop and writes WAV files.
func bake(dir: String) -> void:
	_build_sfx()
	for n: String in streams:
		(streams[n] as AudioStreamWAV).save_to_wav(dir.path_join(n + ".wav"))
	_mus_total = int(16.0 * 60.0 / BPM * RATE)
	_mus.resize(_mus_total)
	_mus_i = 0
	_render_music(_mus_total)
	_wav(_mus, false).save_to_wav(dir.path_join("music.wav"))


# ---------------------------------------------------------------- API
func play(name: String, db := 0.0, pitch_var := 0.06, pitch := 1.0) -> void:
	if not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 35:
		return
	_last[name] = now
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()


func play_music(pitch := 1.0, db := -9.0) -> void:
	_want_music = true
	_music_pitch = pitch
	_music_db = db
	if music.stream:
		_start_music()


func set_music_pitch(pitch: float) -> void:
	_music_pitch = pitch
	music.pitch_scale = pitch


func _start_music() -> void:
	music.pitch_scale = _music_pitch
	music.volume_db = _music_db
	if not music.playing:
		music.play()


# ---------------------------------------------------------------- synthesis
func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## wave: 0 sine, 1 square, 2 saw, 3 triangle
func _synth(dur: float, f0: float, f1: float, wave: int, noise: float, vol: float, curve := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		ph += f / RATE
		var fr := fmod(ph, 1.0)
		var s := 0.0
		match wave:
			0: s = sin(ph * TAU)
			1: s = 1.0 if fr < 0.5 else -1.0
			2: s = fr * 2.0 - 1.0
			_: s = absf(fr * 4.0 - 2.0) - 1.0
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.45)
		s = lerpf(s, lp * 1.6, noise)
		var env := pow(1.0 - t, curve) * minf(1.0, i / (RATE * 0.003))
		out[i] = s * env * vol
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size() + offset)
	var out := a.duplicate()
	out.resize(n)
	for i in b.size():
		out[i + offset] += b[i]
	return out


func _build_sfx() -> void:
	streams["shot"] = _wav(_synth(0.05, 1500, 800, 3, 0.05, 0.22, 2.5))
	streams["hit"] = _wav(_synth(0.05, 700, 220, 1, 0.55, 0.16, 2.0))
	streams["kill"] = _wav(_mix(_synth(0.3, 420, 50, 2, 0.6, 0.35, 1.6), _synth(0.08, 1200, 300, 1, 0.2, 0.15)))
	streams["boom"] = _wav(_mix(_synth(1.3, 160, 22, 2, 0.8, 0.7, 1.3), _synth(0.5, 80, 30, 0, 0.0, 0.6, 1.5)))
	streams["pickup"] = _wav(_synth(0.07, 1100, 2200, 0, 0.0, 0.2, 1.5))
	streams["graze"] = _wav(_synth(0.04, 3200, 2400, 3, 0.25, 0.12, 2.0))
	streams["hurt"] = _wav(_mix(_synth(0.45, 260, 40, 1, 0.5, 0.5, 1.2), _synth(0.2, 90, 40, 0, 0.0, 0.6)))
	streams["bomb"] = _wav(_mix(_synth(1.6, 600, 30, 2, 0.55, 0.6, 1.0), _synth(0.9, 60, 25, 0, 0.0, 0.8, 1.2)))
	streams["eshot"] = _wav(_synth(0.08, 520, 980, 0, 0.0, 0.14, 2.0))
	streams["ui"] = _wav(_synth(0.04, 900, 1200, 1, 0.0, 0.08, 2.0))
	streams["select"] = _wav(_mix(_synth(0.09, 700, 700, 1, 0.0, 0.1), _synth(0.12, 1050, 1050, 1, 0.0, 0.1), 1500))
	streams["nova"] = _wav(_synth(0.5, 300, 1400, 0, 0.25, 0.3, 1.5))
	# level-up arpeggio
	var lv := PackedFloat32Array()
	var notes := [523.25, 659.25, 783.99, 1046.5, 1318.5]
	for k in notes.size():
		var f: float = notes[k]
		lv = _mix(lv, _synth(0.35, f, f, 1, 0.0, 0.12, 2.0), int(k * 0.06 * RATE))
	streams["levelup"] = _wav(lv)
	# warning siren
	var wn := PackedFloat32Array()
	for k in 4:
		wn = _mix(wn, _synth(0.4, 440 if k % 2 == 0 else 330, 440 if k % 2 == 0 else 330, 2, 0.05, 0.25, 0.4), int(k * 0.42 * RATE))
	streams["warn"] = _wav(wn)
	# phase-break chord
	var ph := PackedFloat32Array()
	for f: float in [220.0, 277.18, 329.63, 440.0]:
		ph = _mix(ph, _synth(1.2, f, f * 0.5, 2, 0.15, 0.12, 1.2))
	streams["phase"] = _wav(ph)


func _render_music(chunk: int) -> void:
	var spb := 60.0 / BPM
	var st_len := spb / 4.0
	var end := mini(_mus_i + chunk, _mus_total)
	for i in range(_mus_i, end):
		var t := float(i) / RATE
		var step := int(t / st_len)
		var st := t - step * st_len
		var bar := (step / 16) % 4
		var root: float = ROOTS[bar]
		var chord: Array = CHORDS[bar]
		# bass: rolling 16ths with octave jumps
		var bf := root * (2.0 if step % 4 == 2 else 1.0)
		var bs := (fmod(t * bf, 1.0) * 2.0 - 1.0) * 0.5 + (1.0 if fmod(t * bf * 0.5, 1.0) < 0.5 else -1.0) * 0.25
		_bass_lp = lerpf(_bass_lp, bs, 0.18)
		var bass := _bass_lp * exp(-st * 7.0) * 0.55
		# arpeggio
		var semis: int = chord[(step * 3 + step / 4) % 4]
		var af := root * 8.0 * pow(2.0, semis / 12.0)
		var arp := (1.0 if fmod(t * af, 1.0) < 0.5 else -1.0) * exp(-st * 16.0) * 0.07
		# pad
		var pad := 0.0
		for k in 3:
			var pf := root * 4.0 * pow(2.0, int(chord[k]) / 12.0)
			pad += sin(TAU * t * pf + sin(t * 3.0 + k) * 0.6)
		pad *= 0.035 * (0.7 + 0.3 * sin(t * 1.3))
		# drums
		var beat := int(t / spb)
		var bt := t - beat * spb
		var kick := sin(TAU * (48.0 * bt + 4.0 * (1.0 - exp(-bt * 26.0)))) * exp(-bt * 8.0) * 0.75
		var nz := randf() * 2.0 - 1.0
		var hp := nz - _noise_prev
		_noise_prev = nz
		var hat := hp * exp(-st * 55.0) * (0.10 if step % 2 == 1 else 0.035)
		var snare := 0.0
		if beat % 2 == 1:
			snare = (nz * 0.8 + sin(TAU * 185.0 * bt) * 0.4) * exp(-bt * 13.0) * 0.32
		var s := bass + arp + pad + kick + hat + snare
		_mus[i] = tanh(s * 1.1) * 0.8
	_mus_i = end

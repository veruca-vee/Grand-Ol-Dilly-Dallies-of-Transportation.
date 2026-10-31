class_name SfxSynth
extends RefCounted

# ENGINE CORE (core/sfx_synth.gd) — extracted from gate3d/sfx.gd
# in the Engine Core gate, content unchanged.
# Gate 3D-2: all sound effects are synthesized in code into
# AudioStreamWAV — no audio files (the repo is text-only; see
# dressing.gd). Short, dry, PS2-menu-energy blips at 22050 Hz 16-bit.
# A car-engine hum was deliberately NOT synthesized — a looped
# generated hum reads as a fridge drone within seconds; see README.

const MIX_RATE := 22050

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w

static func _noise(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0)

static func gunshot() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var n := int(MIX_RATE * 0.12)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / n
		var env := pow(1.0 - t, 2.0)
		lp = lp * 0.55 + _noise(rng) * 0.45  # soften the burst a touch
		var thump := sin(TAU * 110.0 * float(i) / MIX_RATE) * 0.5 * env
		s[i] = (lp * 1.4 + thump) * env
	return _wav(s)

static func explosion() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var n := int(MIX_RATE * 0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	var walk := 0.0
	for i in range(n):
		var t := float(i) / n
		var env := pow(1.0 - t, 1.6)
		walk = clampf(walk + _noise(rng) * 0.18, -1.0, 1.0)  # brown-ish rumble
		var sub := sin(TAU * 55.0 * float(i) / MIX_RATE) * 0.6
		s[i] = (walk * 0.9 + sub) * env
	return _wav(s)

static func pickup() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.14)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var freq := 880.0 if t < 0.07 else 1318.0
		var env := 1.0 - float(i) / n
		s[i] = sin(TAU * freq * t) * 0.45 * env
	return _wav(s)

static func hurt() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(MIX_RATE * 0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / n
		var env := pow(1.0 - t, 1.5)
		s[i] = (sin(TAU * 90.0 * float(i) / MIX_RATE) * 0.8 + _noise(rng) * 0.15) * env
	return _wav(s)

static func busted() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes: Array[float] = [392.0, 311.0, 262.0]
	for i in range(n):
		var t := float(i) / MIX_RATE
		var idx := mini(int(t / 0.2), 2)
		var local := t - idx * 0.2
		var env := clampf(1.0 - local / 0.2, 0.0, 1.0) * 0.5 + 0.5
		s[i] = sin(TAU * notes[idx] * t) * 0.5 * env * (1.0 - 0.3 * float(i) / n)
	return _wav(s)

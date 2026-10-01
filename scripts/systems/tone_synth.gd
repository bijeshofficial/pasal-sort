class_name ToneSynth
extends RefCounted
## Generates short placeholder sounds as 16-bit PCM so every audio hook is
## audible before real audio files exist. Replace by dropping files into
## assets/audio/ with the same id (see AudioManager).

const RATE := 22050


static func tone(freq: float, dur: float, vol: float = 0.5, wave: String = "sine", decay: float = 0.0, freq_end: float = -1.0, attack: float = 0.004) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var release := minf(0.04, dur * 0.3)
	for i in n:
		var t := float(i) / RATE
		var f := freq if freq_end < 0.0 else lerpf(freq, freq_end, t / dur)
		phase += f / RATE
		var p := fmod(phase, 1.0)
		var s := 0.0
		if wave == "sine":
			s = sin(TAU * p)
		elif wave == "triangle":
			s = 4.0 * absf(p - 0.5) - 1.0
		elif wave == "soft_square":
			s = sin(TAU * p) + sin(TAU * p * 3.0) / 3.0 + sin(TAU * p * 5.0) / 5.0
			s *= 0.8
		elif wave == "bell":
			s = sin(TAU * p) * 0.75 + sin(TAU * p * 2.76) * 0.25 * exp(-t * 9.0)
		var env := 1.0
		if attack > 0.0:
			env = minf(1.0, t / attack)
		var rem := dur - t
		if rem < release:
			env *= rem / release
		if decay > 0.0:
			env *= exp(-t * decay)
		out[i] = s * env * vol
	return out


static func noise(dur: float, vol: float = 0.4, smooth: float = 0.5, decay: float = 0.0, seed_value: int = 7) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var raw := rng.randf_range(-1.0, 1.0)
		prev = lerpf(raw, prev, smooth)
		var env := minf(1.0, t / 0.003)
		var rem := dur - t
		if rem < 0.02:
			env *= rem / 0.02
		if decay > 0.0:
			env *= exp(-t * decay)
		out[i] = prev * env * vol
	return out


static func silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


static func concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


static func mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_sec: float = 0.0) -> PackedFloat32Array:
	var off := int(offset_sec * RATE)
	var out := a.duplicate()
	if out.size() < b.size() + off:
		out.resize(b.size() + off)
	for i in b.size():
		out[i + off] += b[i]
	return out


static func notes(freqs: Array, step: float, dur: float, vol: float, wave: String = "bell", decay: float = 6.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in freqs.size():
		out = mix(out, tone(float(freqs[i]), dur, vol, wave, decay), step * i)
	return out


static func to_stream(samples: PackedFloat32Array, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## A soft marimba-like plink: warm fundamental, a quick woody overtone.
static func marimba(freq: float, dur: float = 0.35, vol: float = 0.2, decay: float = 9.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.002) * exp(-t * decay)
		var rem := dur - t
		if rem < 0.02:
			env *= rem / 0.02
		var v := sin(TAU * freq * t) + 0.22 * sin(TAU * freq * 4.0 * t) * exp(-t * 40.0) + 0.06 * sin(TAU * freq * 9.8 * t) * exp(-t * 70.0)
		out[i] = v * env * vol
	return out


## A round, bubbly pop (pitch glides from f0 to f1).
static func bubble(f0: float, f1: float, dur: float = 0.08, vol: float = 0.18) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := lerpf(f0, f1, 1.0 - pow(1.0 - k, 3.0))
		phase += f / RATE
		var env := minf(1.0, t / 0.003) * exp(-t * 28.0)
		out[i] = sin(TAU * phase) * env * vol
	return out


static func plinks(freqs: Array, step: float, vol: float = 0.18, dur: float = 0.4) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in freqs.size():
		out = mix(out, marimba(float(freqs[i]), dur, vol), step * i)
	return out


## All placeholder sound effects, keyed by AudioManager id. Soft and round:
## marimba plinks and bubble pops, nothing harsh.
static func build_sfx() -> Dictionary:
	var s := {}
	s["button_click"] = bubble(620.0, 980.0, 0.07, 0.16)
	s["select"] = mix(bubble(500.0, 820.0, 0.08, 0.16), marimba(1046.5, 0.18, 0.06))
	s["deselect"] = bubble(760.0, 540.0, 0.07, 0.1)
	s["success"] = plinks([784.0, 1046.5], 0.07, 0.18)
	s["perfect"] = plinks([1046.5, 1318.5, 1568.0, 2093.0], 0.06, 0.15)
	s["failure"] = plinks([784.0, 659.3, 523.3], 0.12, 0.16)
	s["combo"] = plinks([1046.5, 1568.0], 0.05, 0.15)
	s["reward"] = plinks([523.3, 659.3, 784.0, 1046.5, 1318.5], 0.07, 0.17, 0.5)
	s["level_complete"] = plinks([523.3, 659.3, 784.0, 1046.5, 784.0, 1046.5, 1318.5, 1568.0], 0.09, 0.17, 0.6)
	s["coin_pickup"] = mix(marimba(1975.5, 0.18, 0.1), marimba(2637.0, 0.22, 0.08), 0.045)
	# A candy landing: one woody plink (pitch rises per candy in the group).
	s["clack"] = marimba(1046.5, 0.28, 0.17, 12.0)
	s["nope"] = concat([bubble(320.0, 250.0, 0.08, 0.15), silence(0.03), bubble(270.0, 210.0, 0.1, 0.13)])
	s["lid_pop"] = mix(bubble(380.0, 900.0, 0.09, 0.2), plinks([1046.5, 1318.5, 1568.0], 0.055, 0.14), 0.05)
	s["shuffle"] = mix(noise(0.45, 0.05, 0.95, 4.0, 9), plinks([523.3, 659.3, 784.0, 1046.5, 1318.5], 0.06, 0.1))
	s["extra_jar"] = mix(bubble(420.0, 880.0, 0.1, 0.18), plinks([1046.5, 1568.0], 0.07, 0.13), 0.06)
	s["undo"] = plinks([1046.5, 784.0], 0.07, 0.14)
	var rattle := PackedFloat32Array()
	for i in 7:
		rattle = mix(rattle, noise(0.03, 0.1, 0.5, 50.0, 20 + i), 0.035 * i)
	s["shutter"] = mix(rattle, noise(0.28, 0.04, 0.95, 5.0, 31))
	s["reveal"] = mix(noise(0.1, 0.06, 0.7, 25.0, 12), marimba(1568.0, 0.22, 0.12), 0.03)
	s["unlock"] = plinks([1318.5, 1975.5], 0.08, 0.14)
	s["cloth"] = noise(0.35, 0.08, 0.95, 6.0, 14)
	s["heart"] = plinks([784.0, 1046.5, 1318.5], 0.07, 0.16)
	s["cheer"] = plinks([784.0, 987.8, 1174.7, 1568.0], 0.07, 0.17)
	s["pop"] = bubble(500.0, 900.0, 0.08, 0.15)
	var streams := {}
	for k in s.keys():
		streams[k] = to_stream(s[k])
	return streams


## A gentle, slow pentatonic marimba loop over soft pad chords.
static func build_music() -> AudioStreamWAV:
	var rate := 16000
	var bpm := 76.0
	var beat := 60.0 / bpm
	var steps := 32
	var step_len := beat * 0.5
	var total := int(step_len * steps * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	# C major pentatonic, mostly stepwise, with rests (-1).
	var melody := [7, -1, 9, -1, 11, 9, -1, 7, 4, -1, 7, -1, 9, -1, -1, -1, 7, -1, 11, -1, 12, 11, 9, -1, 7, -1, 4, -1, 2, -1, -1, -1]
	var scale := {0: 261.63, 2: 293.66, 4: 329.63, 7: 392.0, 9: 440.0, 11: 493.88, 12: 523.25}
	for i in melody.size():
		var idx: int = melody[i]
		if idx < 0:
			continue
		var f: float = scale.get(idx, 392.0) * 2.0
		var start := int(i * step_len * rate)
		var n := int(rate * 0.9)
		for j in n:
			var k := (start + j) % total
			var t := float(j) / rate
			var env := minf(1.0, t / 0.003) * exp(-t * 5.0)
			out[k] += (sin(TAU * f * t) + 0.18 * sin(TAU * f * 4.0 * t) * exp(-t * 30.0)) * env * 0.09
	# Soft pad: C - Am - F - G, slow attack and release.
	var chords := [[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]
	var bar := total / 4
	for b in 4:
		for j in bar:
			var t := float(j) / rate
			var env := minf(1.0, t / 0.6) * minf(1.0, float(bar - j) / (0.6 * rate))
			var v := 0.0
			for f in chords[b]:
				v += sin(TAU * float(f) * t)
			out[b * bar + j] += v * env * 0.025
	return to_stream(out, true, rate)

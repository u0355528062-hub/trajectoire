class_name Sfx
extends RefCounted
## Sons synthétisés (aucun fichier audio requis).

const RATE := 44100
static var _cache := {}


static func get_stream(sound: StringName) -> AudioStreamWAV:
	if not _cache.has(sound):
		match sound:
			&"thump": _cache[sound] = _make(_gen_thump())
			&"boom": _cache[sound] = _make(_gen_boom())
			&"ignite": _cache[sound] = _make(_gen_ignite())
			&"hiss": _cache[sound] = _make(_gen_hiss())
			&"whistle": _cache[sound] = _make(_gen_whistle())
			&"click": _cache[sound] = _make(_gen_click())
			&"glass_hit": _cache[sound] = _make(_gen_glass_hit())
			&"glass_crack": _cache[sound] = _make(_gen_glass_crack())
			&"glass_break": _cache[sound] = _make(_gen_glass_break())
			&"kick_whoosh": _cache[sound] = _make(_gen_whoosh())
			_: _cache[sound] = _make(PackedFloat32Array([0.0]))
	return _cache[sound]


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


static func _gen_thump() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var a := _buf(1.1)
	var lp := 0.0
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 38.0 + 90.0 * exp(-t * 14.0)
		phase += TAU * f / RATE
		var body := sin(phase) * exp(-t * 6.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.12
		var noise := lp * exp(-t * 16.0) * 2.2
		var pop := rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.8
		a[i] = (body * 0.9 + noise + pop) * 0.85
	return a


static func _gen_boom() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var a := _buf(2.6)
	var lp1 := 0.0
	var lp2 := 0.0
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp1 += (n - lp1) * 0.18
		lp2 += (lp1 - lp2) * 0.25
		var env := (1.0 - exp(-t * 400.0)) * exp(-t * 2.3)
		phase += TAU * (46.0 + 40.0 * exp(-t * 5.0)) / RATE
		var low := sin(phase) * exp(-t * 3.0) * 0.6
		var crack := n * exp(-t * 55.0) * 0.5
		a[i] = (lp2 * 3.2 * env + low + crack) * 0.8
	# crépitements
	for k in 70:
		var start := int(rng.randf_range(0.18, 2.0) * RATE)
		var amp := rng.randf_range(0.08, 0.3) * exp(-float(start) / RATE * 1.2)
		for j in 260:
			var idx := start + j
			if idx >= a.size():
				break
			a[idx] += rng.randf_range(-1.0, 1.0) * amp * exp(-float(j) / 40.0)
	return a


static func _gen_ignite() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := _buf(0.7)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		var click := n * exp(-((t - 0.02) * 400.0) * ((t - 0.02) * 400.0)) * 0.8
		var click2 := n * exp(-((t - 0.09) * 500.0) * ((t - 0.09) * 500.0)) * 0.5
		lp += (n - lp) * 0.7
		var hiss := (n - lp) * smoothstep(0.1, 0.18, t) * exp(-(t - 0.1) * 2.2) * 0.25
		a[i] = click + click2 + hiss
	return a


static func _gen_hiss() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := _buf(0.9)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.6
		var crackle := 1.0 if rng.randf() < 0.01 else 0.0
		a[i] = ((n - lp) * 0.22 + crackle * n * 0.5) * (1.0 - exp(-t * 30.0)) * clampf((0.9 - t) * 6.0, 0.0, 1.0)
	return a


static func _gen_whistle() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var a := _buf(1.6)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		phase += TAU * (700.0 + 1500.0 * t / 1.6) / RATE
		var env := smoothstep(0.0, 0.15, t) * clampf((1.6 - t) * 2.0, 0.0, 1.0)
		a[i] = (sin(phase) * 0.5 + sin(phase * 2.01) * 0.12 + rng.randf_range(-0.05, 0.05)) * env * 0.35
	return a


static func _gen_click() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var a := _buf(0.12)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.5 + sin(TAU * 900.0 * t) * exp(-t * 60.0) * 0.3
	return a


static func _ping(a: PackedFloat32Array, start: int, freq: float, amp: float, decay: float) -> void:
	var n := int(minf(0.35, 6.0 / decay) * RATE)
	for j in n:
		var idx := start + j
		if idx >= a.size():
			break
		var t := float(j) / RATE
		a[idx] += sin(TAU * freq * t) * amp * exp(-t * decay)


static func _gen_glass_hit() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var a := _buf(0.7)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.2
		a[i] = sin(TAU * 150.0 * t) * exp(-t * 28.0) * 0.8 + lp * exp(-t * 60.0) * 0.9
	_ping(a, 0, 2310.0, 0.18, 14.0)
	_ping(a, 0, 3720.0, 0.12, 18.0)
	_ping(a, 0, 5150.0, 0.07, 24.0)
	return a


static func _gen_glass_crack() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var a := _buf(1.0)
	for k in 34:
		var st := int(rng.randf_range(0.0, 0.8) * RATE)
		var amp := rng.randf_range(0.25, 0.8) * (1.0 - float(st) / a.size() * 0.6)
		var prev := 0.0
		for j in 90:
			var idx := st + j
			if idx >= a.size():
				break
			var n := rng.randf_range(-1.0, 1.0)
			a[idx] += (n - prev) * amp * exp(-float(j) / 14.0)
			prev = n
		_ping(a, st, rng.randf_range(3500.0, 8200.0), amp * 0.25, 90.0)
	return a


static func _gen_glass_break() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var a := _buf(3.2)
	var lp := 0.0
	var prev := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.08
		var hp := n - prev * 0.6
		prev = n
		var burst := hp * exp(-t * 7.0) * 0.9 * (1.0 - exp(-t * 900.0))
		var thump := sin(TAU * 95.0 * t) * exp(-t * 14.0) * 0.45
		var roll := hp * exp(-t * 1.6) * 0.07 * (0.5 + 0.5 * sin(t * 53.0))
		a[i] = burst + thump + lp * exp(-t * 30.0) * 0.6 + roll
	for k in 220:
		var tt := pow(rng.randf(), 1.6) * 2.7 + 0.03
		var amp := rng.randf_range(0.05, 0.28) * exp(-tt * 0.9)
		_ping(a, int(tt * RATE), rng.randf_range(2200.0, 9500.0), amp, rng.randf_range(35.0, 110.0))
	return a


static func _gen_whoosh() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var a := _buf(0.5)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		var k := 0.04 + 0.18 * sin(PI * clampf(t / 0.4, 0.0, 1.0))
		lp += (n - lp) * k
		a[i] = lp * sin(PI * clampf(t / 0.4, 0.0, 1.0)) * 0.9
	return a

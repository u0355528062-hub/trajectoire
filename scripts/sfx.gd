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
			&"footstep_a": _cache[sound] = _make(_gen_footstep(61, 150.0))
			&"footstep_b": _cache[sound] = _make(_gen_footstep(62, 170.0))
			&"stone_thud": _cache[sound] = _make(_gen_stone_thud())
			&"throw": _cache[sound] = _make(_gen_throw())
			&"petard_s": _cache[sound] = _make(_gen_petard(false))
			&"petard_m": _cache[sound] = _make(_gen_petard(true))
			&"fuse": _cache[sound] = _make(_gen_fuse())
			&"tinnitus": _cache[sound] = _make_loop(_gen_tinnitus(), 22050)
			&"amb_wind": _cache[sound] = _make_loop(_gen_wind(), 22050)
			&"amb_city": _cache[sound] = _make_loop(_gen_city(), 22050)
			&"amb_crickets": _cache[sound] = _make_loop(_gen_crickets(), 22050)
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


static func _make_loop(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var w := _make(samples)
	w.mix_rate = rate
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = samples.size()
	return w


## Fondu enchaîné fin -> début pour boucler sans clic ; `a` contient n + fade échantillons.
static func _loopify(a: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := a.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = a[i]
	for i in fade:
		var wgt := float(i) / fade
		out[i] = a[i] * wgt + a[n + i] * (1.0 - wgt)
	return out


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


static func _gen_footstep(seed_: int, f0: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var a := _buf(0.22)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.22
		lp2 += (lp - lp2) * 0.3
		a[i] = sin(TAU * f0 * t) * exp(-t * 30.0) * 0.55 + lp2 * exp(-t * 38.0) * 1.3 + n * exp(-t * 210.0) * 0.25
	return a


static func _gen_stone_thud() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var a := _buf(0.3)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.3
		a[i] = sin(TAU * 210.0 * t) * exp(-t * 34.0) * 0.5 + lp * exp(-t * 60.0) * 1.0 + n * exp(-t * 300.0) * 0.4
	return a


static func _gen_throw() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	var a := _buf(0.32)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * (0.1 + 0.25 * sin(PI * clampf(t / 0.28, 0.0, 1.0)))
		a[i] = lp * sin(PI * clampf(t / 0.28, 0.0, 1.0)) * 0.6
	return a


## Pétard : claquement sec (petit) ou détonation sourde + claquement (moyen), suivis d'échos de façades
static func _gen_petard(big: bool) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 if big else 89
	var a := _buf(2.6 if big else 1.5)
	var lp := 0.0
	var lp2 := 0.0
	var prev := 0.0
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * (0.35 if big else 0.6)
		lp2 += (lp - lp2) * 0.3
		var hp := n - prev * 0.85
		prev = n
		var crack := hp * exp(-t * (95.0 if big else 230.0)) * (1.0 - exp(-t * 6000.0))
		var body := lp2 * exp(-t * (26.0 if big else 70.0)) * (3.2 if big else 1.2)
		var low := 0.0
		if big:
			phase += TAU * (58.0 + 85.0 * exp(-t * 22.0)) / RATE
			low = sin(phase) * exp(-t * 17.0) * 0.85
		a[i] = (crack * (0.85 if big else 0.7) + body * 0.5 + low) * 0.9
	# échos : réflexions sur les façades, adoucies
	var taps: Array = [[0.13, 0.5], [0.29, 0.34], [0.52, 0.22], [0.86, 0.12]] if big else [[0.11, 0.34], [0.24, 0.2], [0.43, 0.1]]
	var src := a.duplicate()
	for tp in taps:
		var off := int(float(tp[0]) * RATE)
		var amp: float = tp[1]
		var sm := 0.0
		for i in range(off, mini(a.size(), off + int(0.5 * RATE))):
			sm += (src[i - off] - sm) * 0.2
			a[i] += sm * amp * exp(-float(i - off) / RATE * 7.0)
	# petit « bruit de série » pour les gros : un second claquement étouffé
	if big:
		var off2 := int(0.045 * RATE)
		for j in int(0.08 * RATE):
			if off2 + j < a.size():
				a[off2 + j] += rng.randf_range(-1.0, 1.0) * exp(-float(j) / RATE * 70.0) * 0.18
	for i in a.size():
		a[i] = clampf(a[i], -1.0, 1.0)
	return a


## Acouphène : deux sifflements aigus qui battent légèrement
static func _gen_tinnitus() -> PackedFloat32Array:
	var rate := 22050
	var a := PackedFloat32Array()
	a.resize(rate * 2)
	for i in a.size():
		var t := float(i) / rate
		a[i] = (sin(TAU * 4000.0 * t) * 0.5 + sin(TAU * 4013.0 * t) * 0.5) * 0.16
	return a


## Mèche qui crépite
static func _gen_fuse() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var a := _buf(3.8)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.75
		var hiss := (n - lp) * 0.2
		var spit := 0.0
		if rng.randf() < 0.0016:
			spit = rng.randf_range(-1.0, 1.0) * 0.5
		a[i] = (hiss + spit) * smoothstep(0.0, 0.08, t) * clampf((3.8 - t) * 8.0, 0.0, 1.0) * (0.7 + 0.3 * sin(t * 37.0))
	return a


static func _gen_wind() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var rate := 22050
	var n := 8 * rate
	var fade := rate
	var a := PackedFloat32Array()
	a.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / rate
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.06
		lp2 += (lp - lp2) * 0.15
		var gust := 0.55 + 0.45 * sin(TAU * t / 8.0 * 1.0 + 0.7) * sin(TAU * t / 8.0 * 3.0 + 1.9)
		a[i] = (lp2 * 5.0) * gust
	return _loopify(a, fade)


static func _gen_city() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	var rate := 22050
	var n := 8 * rate
	var fade := rate
	var a := PackedFloat32Array()
	a.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in a.size():
		var t := float(i) / rate
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		lp3 += (lp2 - lp3) * 0.1
		var pass_ := exp(-pow((t - 4.0) / 0.9, 2.0))  # une voiture lointaine
		a[i] = lp3 * (6.0 + 8.0 * pass_) + sin(TAU * 52.0 * t) * 0.03
	return _loopify(a, fade)


static func _gen_crickets() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	var rate := 22050
	var n := 8 * rate
	var a := PackedFloat32Array()
	a.resize(n)
	for c in 3:
		var f := 4100.0 + c * 330.0 + rng.randf() * 80.0
		var period := 0.75 + c * 0.11
		var phase := rng.randf() * period
		for i in n:
			var t := float(i) / rate + phase
			var bt := fmod(t, period)
			if bt < 0.36:
				var pulse := fmod(bt, 0.06) / 0.06
				var env := sin(PI * pulse)
				a[i] += sin(TAU * f * float(i) / rate) * env * 0.06
	return a

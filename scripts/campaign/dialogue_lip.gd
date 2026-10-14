class_name DialogueLip
extends RefCounted
## Synchro labiale sans fichier de voix : une enveloppe (0..1, échantillonnée à AudioLib.ENV_HZ) fabriquée depuis
## le texte d'une réplique — une bosse par syllabe (groupe de voyelles), des silences sur la ponctuation —
## étirée sur la durée de la réplique. Aussi : le découpage mot à mot de l'apparition des sous-titres.

const VOWELS := "aeiouyàâäéèêëîïôöùûüœæAEIOUYÀÂÉÈÊËÎÏÔÙÛÜŒ"


## Enveloppe de parole pour `text` dite en `dur` secondes
static func envelope(text: String, dur: float) -> Array:
	# unités : syllabe = 1, virgule = 1,6 de silence, fin de phrase = 3
	var units: Array = []           # [poids, amplitude] ; amplitude 0 = silence
	var in_vowel := false
	var seed := 0
	for i in text.length():
		var ch := text[i]
		seed = (seed * 31 + ch.unicode_at(0)) % 9973
		if VOWELS.contains(ch):
			if not in_vowel:
				units.append([1.0, 0.55 + float(seed % 45) / 100.0])
			in_vowel = true
			continue
		in_vowel = false
		if ch in [",", ";", ":"]:
			units.append([1.6, 0.0])
		elif ch in [".", "!", "?", "…"]:
			units.append([3.0, 0.0])
	while not units.is_empty() and float(units[-1][1]) == 0.0:
		units.pop_back()
	var n := maxi(int(ceil(dur * AudioLib.ENV_HZ)), 1)
	var out: Array = []
	out.resize(n)
	out.fill(0.0)
	if units.is_empty():
		return out
	var total := 0.0
	for u in units:
		total += float(u[0])
	var pos := 0.0
	for u in units:
		var w := float(u[0]) / total
		var amp := float(u[1])
		if amp > 0.0:
			var a := int(pos * n)
			var b := maxi(int((pos + w) * n), a + 1)
			for k in range(a, mini(b, n)):
				var x := (float(k - a) + 0.5) / float(b - a)
				out[k] = maxf(float(out[k]), amp * pow(sin(PI * x), 0.7))
		pos += w
	return out


## Nombre de caractères visibles quand une fraction `f` (0..1) de la réplique est apparue : on ne coupe jamais
## un mot (apparition mot à mot)
static func visible_chars(text: String, f: float) -> int:
	if f >= 1.0:
		return text.length()
	var c := int(f * text.length())
	if c <= 0:
		return 0
	var sp := text.find(" ", c)
	return text.length() if sp < 0 else sp

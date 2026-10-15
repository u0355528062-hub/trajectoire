"""Voix des dialogues de la campagne (TTS hors ligne Piper) : res://assets/voice/<_id>/<id>.ogg pour chaque
réplique des scripts/story/dlg_*.gd (ids : DialogueUI.line_id, CAMPAGNE.md § 5.3), une voix par personnage.
Les répliques sont lues par Godot (constantes DLG : les ids suivent exactement ceux du jeu), puis synthétisées.

Prérequis : pip install piper-tts numpy ; ffmpeg (libvorbis) ; voix Piper françaises (licences libres) :
  fr-siwis-medium, fr-siwis-low (CC BY 4.0), fr-gilles-low (CC0), fr-mls_1840-low (CC BY 4.0), par exemple les
  archives voice-fr-*.tar.gz de https://github.com/rhasspy/piper/releases/tag/v0.0.2 décompressées dans VOICES_DIR.
Usage : VOICES_DIR=<dossier> python3 tools/build_voices.py [--out <dossier>] [--only <id de chapitre>] [--list]
  --out : dossier de sortie (défaut assets/voice) ; --list : affiche la distribution sans rien générer.
Les personnages n'ont que quatre modèles pour dix rôles : timbre et débit sont différenciés par transposition
(débit compensé) et égalisation ; la présentatrice passe par un filtre « télé ».

ÉTAT (octobre 2026) : voix NON intégrées au jeu (sous-titres seuls). Avec ces modèles v0.0.2, la nasalisation
(« ̃ », absente de leur table de phonèmes) est perdue : an/en/on/in/un sont prononcés comme des voyelles orales ;
les modèles « low » (gilles, mls_1840 : toutes les voix d'hommes) sont en 16 kHz, métalliques, et ajoutent du
charabia en fin de phrase (coupé par clean_speech, pas toujours) ; dix rôles pour deux timbres réels. Le résultat
est robotique. À relancer avec de meilleures voix françaises libres (piper-voices fr_FR-*-medium, vérifier la
licence de chacune) en adaptant MODELS / CAST, puis écouter avant de livrer dans assets/voice."""
import os, sys, json, subprocess, tempfile, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_audio import clean_speech  # noqa: E402  (même nettoyage que les voix des PNJ)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
VD = os.environ.get("VOICES_DIR", os.path.join(ROOT, "..", "piper-voices"))
GD = os.path.join(ROOT, "tools", "dev", "gd")
RATE = 22050

MODELS = {
    "gilles": "voice-fr-gilles-low/fr-gilles-low.onnx",
    "mls": "voice-fr-mls_1840-low/fr-mls_1840-low.onnx",
    "siwis": "voice-fr-siwis-medium/fr-siwis-medium.onnx",
    "siwis_low": "voice-fr-siwis-low/fr-siwis-low.onnx",
}

## personnage -> modèle, transposition (1 = aucune), débit (length_scale), variabilité, égalisation
CAST = {
    "sam": {"model": "gilles", "pitch": 1.03, "ls": 0.95, "noise": 0.6},
    "karim": {"model": "mls", "pitch": 1.05, "ls": 0.88, "noise": 0.7},
    "jo": {"model": "gilles", "pitch": 0.86, "ls": 1.08, "noise": 0.55, "warm": 3.0},
    "commissaire": {"model": "mls", "pitch": 0.9, "ls": 1.02, "noise": 0.4},
    "narrateur": {"model": "gilles", "pitch": 0.93, "ls": 1.1, "noise": 0.45},
    "nadia": {"model": "siwis", "pitch": 0.94, "ls": 1.0, "noise": 0.6},
    "lou": {"model": "siwis", "pitch": 1.07, "ls": 0.9, "noise": 0.7},
    "mme_ferreira": {"model": "siwis_low", "pitch": 0.9, "ls": 1.12, "noise": 0.5},
    "ines": {"model": "siwis_low", "pitch": 1.04, "ls": 0.95, "noise": 0.6},
    "presentatrice": {"model": "siwis", "pitch": 1.0, "ls": 0.94, "noise": 0.4, "tv": True},
}
DEFAULT = {"model": "gilles", "pitch": 1.0, "ls": 1.0, "noise": 0.6}

DUMP_GD = '''extends SceneTree
func _initialize() -> void:
	var out: Array = []
	for f in DirAccess.open("res://scripts/story").get_files():
		if not (f.begins_with("dlg_") and f.ends_with(".gd")):
			continue
		var dlg: Dictionary = (load("res://scripts/story/" + f) as GDScript).get_script_constant_map()["DLG"]
		var did := str(dlg["_id"])
		for node in dlg:
			if node == "_id" or not (dlg[node] is Array):
				continue
			var steps: Array = dlg[node]
			for i in steps.size():
				var s: Dictionary = steps[i]
				if s.has("text"):
					out.append({"dlg": did, "id": DialogueUI.line_id(node, i), "who": str(s.get("who", "narrateur")), "text": str(s["text"])})
				elif s.has("choice"):
					var ch: Array = s["choice"]
					for k in ch.size():
						if (ch[k] as Dictionary).has("say"):
							out.append({"dlg": did, "id": DialogueUI.line_id(node, i, k), "who": "sam", "text": str(ch[k]["say"])})
	var fa := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	fa.store_string(JSON.stringify(out))
	fa.close()
	quit()
'''


def dump_lines(tmp):
    scr = os.path.join(tmp, "dump_dlg.gd")
    out = os.path.join(tmp, "lines.json")
    with open(scr, "w") as f:
        f.write(DUMP_GD)
    subprocess.run([GD, "--headless", "--path", ROOT, "-s", scr, "--", out], check=True, capture_output=True)
    with open(out) as f:
        return json.load(f)


def fft_eq(x, lo=None, hi=None, shelf_hz=None, shelf_db=0.0):
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    g = np.ones_like(f)
    if lo:
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4)
    if hi:
        g *= 1.0 / (1.0 + (f / hi) ** 4)
    if shelf_hz:
        g *= 1.0 + (10 ** (shelf_db / 20) - 1.0) / (1.0 + (np.maximum(f, 1.0) / shelf_hz) ** 2)
    return np.fft.irfft(np.fft.rfft(x) * g, n).astype(np.float32)


def resample(x, sr_in, sr_out):
    if sr_in == sr_out:
        return x
    n = int(len(x) * sr_out / sr_in)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def trim(x, thr=0.012, pad=0.04):
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(pad * RATE))
    b = min(len(x), idx[-1] + int(pad * RATE))
    return x[a:b]


_voices = {}
def synth(text, spec):
    from piper import PiperVoice, SynthesisConfig
    m = spec["model"]
    if m not in _voices:
        _voices[m] = PiperVoice.load(os.path.join(VD, MODELS[m]))
    v = _voices[m]
    p = spec["pitch"]
    cfg = SynthesisConfig(length_scale=spec["ls"] * p, noise_scale=0.667 * spec["noise"] / 0.6, noise_w_scale=0.8)
    chunks = list(v.synthesize(text, syn_config=cfg))
    if not chunks:
        return np.zeros(1, np.float32)
    sr = chunks[0].sample_rate
    x = np.concatenate([c.audio_int16_array.astype(np.float32) / 32768.0 for c in chunks])
    # les modèles « low » ajoutent parfois du charabia après la phrase : coupé au premier vrai silence
    x = trim(clean_speech(resample(x, sr, RATE), text, spec["ls"] * p))
    # transposition par rééchantillonnage (le débit a été allongé d'autant)
    x = resample(x, RATE * p, RATE)
    if spec.get("warm"):
        x = fft_eq(x, lo=70, shelf_hz=300, shelf_db=spec["warm"])
    if spec.get("tv"):
        x = fft_eq(x, lo=220, hi=5500)
    x = trim(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    f = min(len(x), int(0.02 * RATE))
    x[-f:] *= np.linspace(1, 0, f)
    return x


def save_ogg(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "1", path], input=x.astype(np.float32).tobytes(), check=True)


def main(argv):
    out = os.path.join(ROOT, "assets", "voice")
    only = None
    if "--out" in argv:
        out = argv[argv.index("--out") + 1]
    if "--only" in argv:
        only = argv[argv.index("--only") + 1]
    with tempfile.TemporaryDirectory() as tmp:
        lines = dump_lines(tmp)
    if only:
        lines = [l for l in lines if l["dlg"] == only]
    who = {}
    for l in lines:
        who[l["who"]] = who.get(l["who"], 0) + 1
    for w, n in sorted(who.items(), key=lambda kv: -kv[1]):
        spec = CAST.get(w, DEFAULT)
        print("%-14s %3d répliques  %s x%.2f débit %.2f%s" % (w, n, spec["model"], spec["pitch"], spec["ls"],
                                                              "" if w in CAST else "  (voix par défaut)"))
    if "--list" in argv:
        return
    total = 0
    for i, l in enumerate(lines):
        x = synth(l["text"], CAST.get(l["who"], DEFAULT))
        path = os.path.join(out, l["dlg"], l["id"] + ".ogg")
        save_ogg(path, x)
        total += os.path.getsize(path)
        if i % 50 == 0:
            print("%d/%d" % (i, len(lines)))
    print("%d voix, %.1f Mo -> %s" % (len(lines), total / 1e6, out))


if __name__ == "__main__":
    main(sys.argv[1:])

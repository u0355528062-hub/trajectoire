"""Génère assets/audio/* : voix (Piper, TTS neuronal français), foule (chants, acclamations,
brouhaha), bruitages (feu, fumigène, poubelle, téléphone, sifflets, mégaphone).
Usage : PIPER_DIR=<dossier piper> VOICES_DIR=<dossier voix> python3 tools/build_audio.py
Voix : fr-gilles-low (CC0) et fr-siwis-medium (CC BY 4.0). La 2e voix d'homme (m2) est gilles
transposé plus grave (débit compensé) : la voix mls_1840 ajoutait du charabia après les phrases."""
import os, sys, subprocess, tempfile, wave, json, random
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SP = os.environ.get("PIPER_DIR", "/tmp/claude-0/-home-user-trajectoire/2f27e358-36e9-5686-9f33-4bbeb0a130ed/scratchpad/piper/piper")
VD = os.environ.get("VOICES_DIR", "/tmp/claude-0/-home-user-trajectoire/2f27e358-36e9-5686-9f33-4bbeb0a130ed/scratchpad/voices")
RATE = 22050
VOICES = {
    "m1": VD + "/voice-fr-gilles-low/fr-gilles-low.onnx",
    "m2": VD + "/voice-fr-gilles-low/fr-gilles-low.onnx",
    "f1": VD + "/voice-fr-siwis-medium/fr-siwis-medium.onnx",
}
rng = np.random.default_rng(12)
random.seed(12)
ENV = {}
TMP = tempfile.mkdtemp()


# ------------------------------------------------------------------ outils
def read_wav(path):
    with wave.open(path) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    return x, sr


def resample(x, sr_in, sr_out):
    if sr_in == sr_out:
        return x
    n = int(len(x) * sr_out / sr_in)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def pitch(x, factor):
    """Hauteur et tempo multipliés par `factor` (rééchantillonnage)."""
    n = int(len(x) / factor)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def trim(x, thr=0.01, pad=0.03):
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(pad * RATE)); b = min(len(x), idx[-1] + int(pad * RATE))
    return x[a:b]


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x * (peak / m)


def fft_filter(x, lo=None, hi=None, shelf_hz=None, shelf_db=0.0):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    g = np.ones_like(f)
    if lo:
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4)
    if hi:
        g *= 1.0 / (1.0 + (f / hi) ** 4)
    if shelf_hz:
        g *= 1.0 + (10 ** (shelf_db / 20) - 1.0) / (1.0 + (shelf_hz / np.maximum(f, 1.0)) ** 2)
    return np.fft.irfft(X * g, n).astype(np.float32)


def reverb(x, wet=0.25, decay=0.9, pre=0.012):
    n = int(decay * 1.6 * RATE)
    t = np.arange(n) / RATE
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(-t * 6.9 / decay)
    ir[: int(pre * RATE)] = 0
    ir = fft_filter(ir, hi=5000)
    ir /= np.sqrt((ir ** 2).sum()) + 1e-9
    m = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)[: len(x) + n].astype(np.float32)
    out = np.zeros(len(y), np.float32)
    out[: len(x)] += x * (1 - wet)
    out += y * wet * 0.8
    return trim(out, 0.002)


def envelope(x, hz=20):
    step = RATE // hz
    e = [float(np.sqrt(np.mean(x[i:i + step] ** 2))) for i in range(0, len(x), step)]
    m = max(e) + 1e-9
    return [round(min(1.0, v / m * 1.4), 2) for v in e]


def save(name, x, env=False, loop=False):
    x = np.clip(x, -1, 1)
    wav = os.path.join(TMP, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes((x * 32000).astype(np.int16).tobytes())
    subprocess.run(["oggenc", "-Q", "-q", "3", "-o", os.path.join(OUT, name + ".ogg"), wav], check=True)
    if env:
        ENV[name] = envelope(x)


def clean_speech(x, text, ls):
    """Les modèles Piper « low » ajoutent parfois du charabia après une phrase courte :
    on coupe au premier vrai silence une fois la durée attendue presque atteinte."""
    st = RATE // 50
    e = np.array([np.sqrt(np.mean(x[i:i + st] ** 2)) for i in range(0, len(x), st)])
    if len(e) == 0:
        return x
    voiced = e > 0.07 * e.max()
    letters = sum(c.isalpha() for c in text)
    pauses = sum(text.count(c) for c in ",;:") + max(0, sum(text.count(c) for c in ".!?") - 1)
    expected = max(0.3, letters * 0.068 * ls + pauses * 0.22)
    t_min = 0.75 * expected
    cut = len(x)
    gap = 0
    last_voiced = -1
    for i, v in enumerate(voiced):
        t = i / 50.0
        if v:
            if last_voiced >= 0 and gap >= 10 and last_voiced / 50.0 >= t_min:
                cut = (last_voiced + 3) * st
                break
            last_voiced = i
            gap = 0
        else:
            gap += 1
    cut = min(cut, int((1.7 * expected + 0.35) * RATE))
    y = x[:cut].copy()
    f = min(len(y), int(0.03 * RATE))
    if f > 0:
        y[-f:] *= np.linspace(1, 0, f)
    return y


_tts_cache = {}
def tts(text, voice, ls=1.0, nscale=0.667, nw=0.8):
    key = (text, voice, ls, nscale, nw)
    if key in _tts_cache:
        return _tts_cache[key]
    if voice == "m2":
        # autre locuteur : même modèle, débit accéléré puis transposé 12 % plus grave (voix plus grave/large)
        x = tts(text, "m1", ls=ls * 0.88, nscale=min(nscale * 1.1, 0.9), nw=nw)
        x = fft_filter(pitch(x, 0.88), lo=70, shelf_hz=250, shelf_db=2.5)
        x = norm(x, 0.9)
        _tts_cache[key] = x
        return x
    out = os.path.join(TMP, "t.wav")
    env = dict(os.environ, LD_LIBRARY_PATH=SP)
    subprocess.run([SP + "/piper", "--model", VOICES[voice], "--output_file", out, "--length_scale", str(ls),
                    "--noise_scale", str(nscale), "--noise_w", str(nw), "--sentence_silence", "0"],
                   input=text.encode(), check=True, env=env, capture_output=True)
    x, sr = read_wav(out)
    x = trim(resample(x, sr, RATE))
    x = trim(clean_speech(x, text, ls))
    _tts_cache[key] = x
    return x


def shout(x, drive=2.4, up=1.07):
    x = pitch(x, up)
    x = fft_filter(x, lo=140, shelf_hz=1800, shelf_db=6)
    x = np.tanh(x * drive) / np.tanh(drive)
    return norm(x, 0.92)


def mix(parts, length=None):
    L = length or max(o + len(p) for o, p in parts)
    y = np.zeros(L, np.float32)
    for o, p in parts:
        e = min(L, o + len(p))
        y[o:e] += p[: e - o]
    return y


# ------------------------------------------------------------------ voix individuelles
LINES = {
    "ouais": ["Ouais !", "Ouaiiis !", "Ouais, ouais !"],
    "allez": ["Allez !", "Allez, allez !", "Vas-y !", "Envoie !"],
    "bravo": ["Bravo !", "Wouhou !", "Trop fort !", "Encore !"],
    "warn": ["Attention !", "Recule !", "Hé, attention !", "Il vise, recule !"],
    "fire": ["Ça brûle !", "Mets-en encore !", "Regarde le feu !", "Ça crame !"],
    "film": ["Filme, filme !", "Regarde ça !", "Attends, je filme !"],
    "wow": ["Oh la vache !", "Waouh !", "C'est magnifique !", "Oh là là !"],
    "join": ["On y va !", "Je viens !", "Avec toi !", "Allez, on y va !"],
    "refuse": ["Non, sans moi.", "Je reste là, moi.", "Vas-y, pas moi.", "Laisse tomber."],
    "broke": ["Ouais, cassé !", "Bien joué !", "Ouaaais !"],
    "slogan": ["On lâche rien !", "Tous ensemble !", "La rue est à nous !", "On est là !"],
}
TALK = [
    "T'as vu le monde qu'il y a ce soir ?", "C'est blindé de partout.", "Il paraît que ça va bouger vers la place.",
    "J'ai presque plus de batterie, galère.", "Tu restes jusqu'à quelle heure ?", "On se retrouve après au métro.",
    "Regarde là-bas, ils ont des fumigènes.", "Franchement, ça fait du bien.", "T'as reçu le message de Karim ?",
    "Moi, je bouge pas d'ici.", "Il caille un peu quand même.", "C'est la plus grosse manif de l'année.",
    "T'as faim ? Il y a un camion là-bas.", "Ma mère m'a appelé trois fois.", "Tu as vu les feux d'artifice tout à l'heure ?",
    "On aurait dû venir plus tôt.", "J'ai jamais vu autant de gens.", "Les gars du lycée sont là aussi.",
    "Il faut qu'on reste groupés.", "Ça va finir tard ce soir.", "T'as pris une pancarte, toi ?",
    "Écoute, écoute, ils chantent là-bas.",
]
REPLY = ["Ouais.", "Grave.", "Carrément !", "Ah bon ?", "Non mais sérieux ?", "C'est clair.", "Trop pas.",
         "Attends, attends...", "Ah ouais, quand même.", "Bah oui !", "Mais non !", "Je sais pas trop."]
PLAYER = {"call": ["Venez ! Avec moi !", "Tous avec moi !", "Allez, venez !"]}


def build_voices():
    manifest = {}
    for vk in VOICES:
        for cat, lines in LINES.items():
            for i, t in enumerate(lines):
                x = tts(t, vk, ls=0.9, nscale=0.75, nw=0.9)
                x = shout(x, drive=2.6 if cat not in ("refuse",) else 1.2, up=1.06 if cat != "refuse" else 1.0)
                name = f"v_{vk}_{cat}_{i}"
                save(name, reverb(x, 0.12, 0.6), env=True)
                manifest.setdefault(f"{vk}_{cat}", []).append(name)
        for i, t in enumerate(TALK):
            x = norm(fft_filter(tts(t, vk, ls=1.0), lo=90), 0.8)
            name = f"v_{vk}_talk_{i}"
            save(name, x, env=True)
            manifest.setdefault(f"{vk}_talk", []).append(name)
        for i, t in enumerate(REPLY):
            x = norm(fft_filter(tts(t, vk, ls=1.0), lo=90), 0.8)
            name = f"v_{vk}_reply_{i}"
            save(name, x, env=True)
            manifest.setdefault(f"{vk}_reply", []).append(name)
    for i, t in enumerate(PLAYER["call"]):
        x = shout(tts(t, "m2", ls=0.9, nscale=0.75), drive=2.8, up=1.04)
        save(f"player_call_{i}", reverb(x, 0.15, 0.7))
        manifest.setdefault("player_call", []).append(f"player_call_{i}")
    return manifest


# ------------------------------------------------------------------ foule
def crowd_layer(text, n, ls=0.95, jitter=0.09, spread=0.08, drive=2.2, up_range=(0.9, 1.15)):
    parts = []
    for k in range(n):
        vk = random.choice(list(VOICES))
        x = tts(text, vk, ls=ls * random.uniform(0.95, 1.06), nscale=0.8, nw=0.95)
        f = random.uniform(*up_range)
        x = shout(x, drive=drive, up=f)
        x = fft_filter(x, hi=random.uniform(3500, 7000)) * random.uniform(0.35, 1.0)
        parts.append((int(random.uniform(0, spread) * RATE), x))
    y = mix(parts)
    return y


def roar(dur, amp=0.4, lo=300, hi=2500, attack=0.15, release=1.2):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    x = fft_filter(rng.standard_normal(n).astype(np.float32), lo=lo, hi=hi)
    env = np.minimum(1, t / attack) * np.exp(-np.maximum(0, t - attack) / release)
    return norm(x * env, amp)


def whistle(dur=0.9, f0=2900.0, trill=34.0, seed=0):
    r = np.random.default_rng(seed)
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tr = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * trill * t + r.uniform(0, 6)))
    f = f0 * (1 + 0.045 * tr)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    env = np.minimum(1, t / 0.02) * np.minimum(1, (dur - t) / 0.05)
    x = (np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * r.standard_normal(n)) * env
    return norm(fft_filter(x.astype(np.float32), lo=800), 0.7)


CHANTS = {  # texte, période (s), répétitions : scandé en rythme, avec crescendo
    "chant_lacherien": ("On lâche rien !", 1.75, 6),
    "chant_ensemble": ("Tous ensemble, tous ensemble ! Ouais ! Ouais !", 0.0, 3),
    "chant_rue": ("La rue est à nous !", 2.15, 5),
    "chant_onestla": ("On est là ! On est là !", 0.0, 4),
}


def onsets(x, hz=40, thr=0.5, gap=0.2):
    step = RATE // hz
    e = np.array([np.sqrt(np.mean(x[i:i + step] ** 2)) for i in range(0, len(x), step)])
    e = e / (e.max() + 1e-9)
    out = []
    for i in range(1, len(e) - 1):
        if e[i] > thr and e[i] >= e[i - 1] and e[i] > e[i + 1]:
            t = i / hz
            if not out or t - out[-1] > gap:
                out.append(round(t, 3))
    return out


def build_chants():
    beats = {}
    for name, (text, period, reps) in CHANTS.items():
        variants = [crowd_layer(text, 14, ls=1.0, spread=0.06) for _ in range(2)]
        plen = max(len(v) for v in variants) / RATE
        per = max(period, plen + 0.25)
        parts = []
        for r in range(reps):
            v = variants[r % 2] * (0.8 + 0.2 * min(1.0, r / 2.0))
            parts.append((int(r * per * RATE), v))
        y = mix(parts)
        y = y + mix([(0, roar(len(y) / RATE + 0.5, 0.05, attack=0.6, release=5.0))], len(y))
        y = norm(reverb(norm(y, 0.9), 0.28, 1.1), 0.92)
        save(name, y, env=True)
        beats[name] = onsets(y)
    return beats


def build_crowd():
    beats = build_chants()
    for name, (txt, n, extra_roar) in {"cheer_small": ("Ouais !", 6, 0.12), "cheer_big": ("Ouaaais !", 22, 0.35),
                                        "awe": ("Oooooh !", 14, 0.1), "panic": ("Attention !", 7, 0.05)}.items():
        ls = 2.0 if name == "awe" else 1.0
        y = crowd_layer(txt, n, ls=ls, spread=0.35 if name != "awe" else 0.25, up_range=(0.88, 1.2))
        y = y + mix([(0, roar(len(y) / RATE + 0.8, extra_roar, attack=0.08, release=0.9))], len(y))
        if name == "cheer_big":
            for k in range(3):
                y = mix([(0, y), (int(random.uniform(0.1, 0.8) * RATE), whistle(0.7, 2800 + k * 250, seed=k) * 0.25)])
        save(name, norm(reverb(norm(y), 0.3, 1.2), 0.92))
    # brouhaha de foule (boucle)
    L = 30 * RATE
    fade = RATE
    parts = []
    for k in range(70):
        vk = random.choice(list(VOICES))
        t = random.choice(TALK + REPLY)
        x = tts(t, vk, ls=random.uniform(0.95, 1.1))
        x = pitch(x, random.uniform(0.9, 1.12)) * random.uniform(0.15, 0.6)
        parts.append((random.randint(0, L), x))
    y = mix(parts, L + fade + 4 * RATE)
    y = fft_filter(y, lo=120, hi=3200)
    y = reverb(y, 0.35, 1.3)[: L + fade]
    y[:fade] = y[:fade] * np.linspace(0, 1, fade) + y[L:L + fade] * np.linspace(1, 0, fade)
    save("crowd_murmur", norm(y[:L], 0.7))
    # mégaphone
    for i, t in enumerate(["On lâche rien !", "Tous ensemble !", "La rue est à nous !", "Plus fort !"]):
        x = tts(t, "m1", ls=0.95, nscale=0.75)
        x = fft_filter(pitch(x, 1.03), lo=450, hi=3200)
        x = np.tanh(norm(x) * 4.0)
        x = fft_filter(x, lo=500, hi=3500)
        save(f"megaphone_{i}", norm(reverb(x, 0.25, 0.8), 0.95), env=True)
    for i in range(3):
        save(f"whistle_{i}", whistle(random.uniform(0.6, 1.2), 2700 + i * 220, 30 + i * 6, seed=10 + i))
    return beats


# ------------------------------------------------------------------ bruitages
def build_sfx():
    def noise(n):
        return rng.standard_normal(n).astype(np.float32)
    # feu (boucle 8 s) : grondement + crépitements + claquements
    L = 8 * RATE; fade = RATE // 2
    n = L + fade
    t = np.arange(n) / RATE
    base = fft_filter(noise(n), lo=60, hi=420) * (0.7 + 0.3 * np.sin(2 * np.pi * t * 0.37) * np.sin(2 * np.pi * t * 1.13))
    hiss = fft_filter(noise(n), lo=2500, hi=9000) * 0.12
    cr = np.zeros(n, np.float32)
    for k in range(260):
        p = rng.integers(0, n - 2000)
        ln = rng.integers(30, 400)
        a = rng.uniform(0.2, 1.0) * (1.0 if rng.random() < 0.85 else 2.2)
        cr[p:p + ln] += noise(ln) * a * np.exp(-np.arange(ln) / (ln / 4))
    cr = fft_filter(cr, lo=900, hi=8000)
    y = norm(base, 0.5) + norm(cr, 0.55) + hiss
    y[:fade] = y[:fade] * np.linspace(0, 1, fade) + y[L:L + fade] * np.linspace(1, 0, fade)
    save("fire_loop", norm(y[:L], 0.8))
    # embrasement (fwoomp)
    n = int(1.6 * RATE); t = np.arange(n) / RATE
    x = noise(n)
    y = np.zeros(n, np.float32); lp = 0.0
    k = 0.02 + 0.25 * np.minimum(1, t / 0.25)
    for i in range(n):
        lp += (x[i] - lp) * k[i]
        y[i] = lp
    y *= np.minimum(1, t / 0.05) * np.exp(-t * 2.2)
    y += np.sin(2 * np.pi * 55 * t) * np.exp(-t * 6) * 0.6
    save("fire_ignite", norm(y, 0.9))
    # flamme qui reprend (ajout de combustible)
    n = int(1.0 * RATE); t = np.arange(n) / RATE
    y = fft_filter(noise(n), lo=80, hi=1500) * np.minimum(1, t / 0.08) * np.exp(-t * 3.5)
    save("fire_flare_up", norm(y, 0.8))
    # fumigène : craquage + chuintement continu
    n = int(1.2 * RATE); t = np.arange(n) / RATE
    y = fft_filter(noise(n), lo=200, hi=6000) * np.exp(-t * 18) * 1.2
    y += fft_filter(noise(n), lo=1500, hi=9000) * np.minimum(1, np.maximum(0, t - 0.08) / 0.15) * 0.6
    save("flare_ignite", norm(y, 0.85))
    L = 4 * RATE; fade = RATE // 2; n = L + fade; t = np.arange(n) / RATE
    y = fft_filter(noise(n), lo=1200, hi=9500) * (0.8 + 0.2 * np.sin(2 * np.pi * 7.3 * t)) + fft_filter(noise(n), lo=150, hi=900) * 0.35
    sp = np.zeros(n, np.float32)
    for k in range(120):
        p = rng.integers(0, n - 300); sp[p:p + 120] += noise(120) * rng.uniform(0.3, 1.0) * np.exp(-np.arange(120) / 25)
    y += fft_filter(sp, lo=2000) * 0.5
    y[:fade] = y[:fade] * np.linspace(0, 1, fade) + y[L:L + fade] * np.linspace(1, 0, fade)
    save("flare_loop", norm(y[:L], 0.75))
    # couvercle de poubelle (plastique)
    def plastic(dur, freqs, amp, decay, thump):
        n = int(dur * RATE); t = np.arange(n) / RATE
        y = fft_filter(noise(n), lo=80, hi=2500) * np.exp(-t * thump) * 0.9
        for f, a in zip(freqs, amp):
            y += np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * a * np.exp(-t * decay)
        return norm(y, 0.9)
    save("bin_lid_open", plastic(0.5, [180, 430, 910], [0.3, 0.2, 0.1], 18, 40) * 0.7)
    save("bin_lid_close", plastic(0.6, [150, 380, 820, 1500], [0.5, 0.3, 0.15, 0.08], 14, 30))
    save("bin_hit", plastic(0.45, [120, 300, 700], [0.5, 0.3, 0.1], 16, 22))
    L = 2 * RATE; t = np.arange(L) / RATE
    y = fft_filter(noise(L), lo=40, hi=380) * 0.6
    for k in range(int(2 * 7)):
        p = int(k / 7 * RATE)
        y[p:p + 400] += noise(400) * np.exp(-np.arange(400) / 80) * 0.5
    save("bin_roll", norm(y, 0.6))
    # carton / bois jetés
    n = int(0.5 * RATE); t = np.arange(n) / RATE
    save("cardboard_land", norm(fft_filter(noise(n), lo=150, hi=3000) * np.exp(-t * 14) + np.sin(2 * np.pi * 95 * t) * np.exp(-t * 20) * 0.5, 0.8))
    save("wood_land", norm(fft_filter(noise(n), lo=200, hi=4000) * np.exp(-t * 25) + np.sin(2 * np.pi * 230 * t) * np.exp(-t * 18) * 0.6 + np.sin(2 * np.pi * 510 * t) * np.exp(-t * 26) * 0.3, 0.8))
    n = int(0.35 * RATE); t = np.arange(n) / RATE
    save("toss", norm(fft_filter(noise(n), lo=300, hi=2500) * np.sin(np.pi * np.minimum(1, t / 0.3)), 0.5))
    # appareil photo du téléphone
    n = int(0.25 * RATE); t = np.arange(n) / RATE
    y = fft_filter(noise(n), lo=2000) * (np.exp(-((t - 0.01) / 0.004) ** 2) + 0.7 * np.exp(-((t - 0.09) / 0.006) ** 2))
    save("phone_shutter", norm(y, 0.7))
    # papier froissé (ramasser)
    n = int(0.6 * RATE)
    y = np.zeros(n, np.float32)
    for k in range(60):
        p = rng.integers(0, n - 300); y[p:p + 200] += noise(200) * rng.uniform(0.2, 1.0) * np.exp(-np.arange(200) / 40)
    save("paper_rustle", norm(fft_filter(y, lo=1500, hi=9000), 0.6))


if __name__ == "__main__":
    which = sys.argv[1:] or ["voices", "crowd", "sfx"]
    data_path = os.path.join(OUT, "audio.json")
    data = json.load(open(data_path)) if os.path.exists(data_path) else {}
    if "sfx" in which:
        build_sfx()
    if "voices" in which:
        data["voices"] = build_voices()
    if "crowd" in which:
        data["beats"] = build_crowd()
    elif "chants" in which:
        data["beats"] = build_chants()
    old_env = data.get("env", {})
    old_env.update(ENV)
    data["env"] = old_env
    json.dump(data, open(data_path, "w"))
    print("ok", len(os.listdir(OUT)), "fichiers")

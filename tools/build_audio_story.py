"""Génère l'habillage sonore de la campagne dans assets/audio/story/ :
- ambiances de lieux en boucle (mono) : rue du matin, rue de nuit, pluie, intérieur du Zinc, supérette, télé (JT),
  square, cortège (au loin), blocage à l'aube, foule qui gronde ;
- musiques sobres en boucle (stéréo) : titre, prologue, espoir, marche, tension, nasse, aube, fins (claire et
  sombre), bilan du JT (avec jingle d'ouverture), échec (avec accord d'ouverture).
Synthèse procédurale (numpy). Les murmures de voix (café, supérette, télé, foule) réutilisent les répliques déjà
générées du dépôt (assets/audio/v_*.ogg, voix Piper libres) ; aucune ressource extérieure.
Les boucles sont exactes : bruits filtrés par FFT (circulaires), événements et réverbération repliés sur la durée.
Encodage Ogg Vorbis par ffmpeg (libvorbis).
Usage : python3 tools/build_audio_story.py [nom...]   (tout par défaut ; ex. « amb_pluie mus_theme »)"""
import os, sys, subprocess
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "audio")
OUT = os.path.join(SRC, "story")
os.makedirs(OUT, exist_ok=True)
SR_A = 22050      # ambiances (mono)
SR_M = 32000      # musiques (stéréo)
rng = np.random.default_rng(31)


# ================================================================== outils
def secs(sr, d):
    return int(round(d * sr))


def filt(x, sr, lo=None, hi=None, order=4):
    """Passe-haut / passe-bas doux par FFT (circulaire : un bruit filtré boucle sans couture)."""
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1.0 / sr)
    g = np.ones_like(f)
    if lo:
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1e-3)) ** order)
    if hi:
        g *= 1.0 / (1.0 + (f / hi) ** order)
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * g, n, axis=-1).astype(np.float32)


def band(x, sr, f0, bw):
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1.0 / sr)
    g = np.exp(-0.5 * ((f - f0) / bw) ** 2)
    return np.fft.irfft(np.fft.rfft(x) * g, n).astype(np.float32)


def white(n):
    return rng.standard_normal(n).astype(np.float32)


def colored(n, sr, slope, lo=20.0):
    """Bruit en 1/f^slope (0.5 = rose, 1 = brun), circulaire."""
    f = np.fft.rfftfreq(n, 1.0 / sr)
    g = 1.0 / np.maximum(f, lo) ** slope
    y = np.fft.irfft(np.fft.rfft(white(n)) * g, n).astype(np.float32)
    return y / (np.std(y) + 1e-9)


def smooth_noise(n, sr, hz):
    """Modulation lente et circulaire (valeurs ~ -1..1)."""
    y = filt(white(n), sr, hi=hz, order=2)
    return y / (np.max(np.abs(y)) + 1e-9)


def unit(x):
    return x / (np.max(np.abs(x)) + 1e-9)


def place(buf, start, sig, gain=1.0):
    """Ajoute sig dans buf (mono ou stéréo) à partir de l'échantillon start, en repliant la fin au début."""
    n = buf.shape[-1]
    start = int(start) % n
    m = min(sig.shape[-1], n)
    sig = sig[..., :m] * gain
    end = start + m
    if end <= n:
        buf[..., start:end] += sig
    else:
        k = n - start
        buf[..., start:] += sig[..., :k]
        buf[..., :end - n] += sig[..., k:]


def pan2(sig, pan):
    """Mono -> stéréo à puissance constante (pan -1 gauche .. 1 droite)."""
    a = (pan + 1.0) * np.pi / 4.0
    return np.stack([sig * np.cos(a), sig * np.sin(a)])


def ir(sr, decay, seed, hi=5500.0, pre=0.015):
    r = np.random.default_rng(seed)
    n = secs(sr, decay * 1.5)
    t = np.arange(n) / sr
    h = r.standard_normal(n).astype(np.float32) * np.exp(-t * 6.9 / decay)
    h[:secs(sr, pre)] = 0.0
    h = filt(h, sr, hi=hi, order=2)
    return h / (np.sqrt((h ** 2).sum()) + 1e-9)


def conv_wrap(x, h):
    """Convolution circulaire (la queue de réverbération retombe au début de la boucle)."""
    n = x.shape[-1]
    if len(h) > n:
        h = h[:n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h, n), n).astype(np.float32)


def reverb_wrap(x, sr, decay, wet, seed=1, hi=5500.0):
    if x.ndim == 1:
        return x * (1 - wet) + conv_wrap(x, ir(sr, decay, seed, hi)) * wet
    y = np.empty_like(x)
    for c in range(x.shape[0]):
        y[c] = x[c] * (1 - wet) + conv_wrap(x[c], ir(sr, decay, seed + 17 * c, hi)) * wet
    return y


def resamp(x, factor):
    """Hauteur et tempo multipliés par factor."""
    n = max(2, int(len(x) / factor))
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def fades(x, sr, a=0.005, r=0.02):
    x = x.copy()
    na, nr = min(len(x), secs(sr, a)), min(len(x), secs(sr, r))
    if na > 0:
        x[:na] *= np.linspace(0, 1, na)
    if nr > 0:
        x[-nr:] *= np.linspace(1, 0, nr)
    return x


_dec = {}
def decode(name, sr):
    """Son existant du dépôt (assets/audio/<name>.ogg) en mono flottant."""
    key = (name, sr)
    if key not in _dec:
        p = os.path.join(SRC, name + ".ogg")
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-f", "f32le", "-ac", "1", "-ar", str(sr), "-"],
                             check=True, capture_output=True).stdout
        _dec[key] = np.frombuffer(raw, dtype=np.float32).copy()
    return _dec[key]


def lines(prefixes):
    """Noms des répliques existantes commençant par l'un des préfixes."""
    out = []
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".ogg") and any(f.startswith(p) for p in prefixes):
            out.append(f[:-4])
    return out


def save(name, x, sr, rms_db=-20.0, q=2):
    """Normalise en niveau moyen (cohérence entre pistes), adoucit les crêtes, encode en Ogg Vorbis."""
    x = np.asarray(x, np.float32)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (10 ** (rms_db / 20.0) / rms)
    x = np.tanh(x * 1.1) / 1.1
    x = np.clip(x, -0.98, 0.98)
    ch = 1 if x.ndim == 1 else x.shape[0]
    data = x if ch == 1 else x.T.reshape(-1)
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(sr), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=data.astype(np.float32).tobytes(), check=True)
    print("%-22s %5.1f s  %3d Ko" % (name, x.shape[-1] / sr, os.path.getsize(path) // 1024))


# ================================================================== briques d'ambiance (SR_A, mono)
def traffic(n, sr, level=1.0, passes=6, rumble=1.0, horn=0):
    y = filt(colored(n, sr, 1.0), sr, lo=25, hi=320) * 0.5 * rumble
    for _ in range(passes):
        d = rng.uniform(4.0, 8.0)
        m = secs(sr, d)
        t = np.linspace(0, 1, m)
        e = np.exp(-((t - 0.5) / 0.17) ** 2)
        w = white(m)
        tyre = filt(w, sr, lo=150, hi=900) + 0.6 * filt(w, sr, lo=900, hi=2800) * e ** 2
        f0 = rng.uniform(45, 75) * (1.06 - 0.12 * t)
        eng = np.sin(2 * np.pi * np.cumsum(f0) / sr) + 0.4 * np.sin(4 * np.pi * np.cumsum(f0) / sr)
        place(y, rng.integers(n), (tyre * 0.6 + eng * 0.25) * e, rng.uniform(0.3, 0.9))
    for _ in range(horn):
        m = secs(sr, rng.uniform(0.25, 0.5))
        t = np.arange(m) / sr
        f = rng.choice([392.0, 415.0, 466.0])
        s = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sin(2 * np.pi * f * 1.26 * t) * 0.5
        place(y, rng.integers(n), filt(fades(s, sr, 0.01, 0.05), sr, hi=1400), 0.12)
    return y * level


def chirp(sr, f0, f1, d):
    m = secs(sr, d)
    t = np.arange(m) / sr
    f = np.linspace(f0, f1, m)
    return np.sin(2 * np.pi * np.cumsum(f) / sr) * np.sin(np.pi * t / d) ** 2


def birds(n, sr, count=10, song=2):
    y = np.zeros(n, np.float32)
    for _ in range(count):       # moineaux : salves de pépiements
        s0 = rng.integers(n)
        k = rng.integers(2, 7)
        pos = 0
        base = rng.uniform(3200, 5200)
        for _ in range(k):
            d = rng.uniform(0.04, 0.11)
            place(y, s0 + pos, chirp(sr, base * rng.uniform(0.9, 1.1), base * rng.uniform(0.7, 1.25), d),
                  rng.uniform(0.2, 0.5))
            pos += secs(sr, d + rng.uniform(0.05, 0.18))
    for _ in range(song):        # merle : phrase mélodique
        s0 = rng.integers(n)
        pos = 0
        for _ in range(rng.integers(5, 10)):
            d = rng.uniform(0.08, 0.25)
            f = rng.uniform(1600, 3200)
            m = secs(sr, d)
            t = np.arange(m) / sr
            ff = f * (1 + 0.04 * np.sin(2 * np.pi * 28 * t)) * np.linspace(1, rng.uniform(0.85, 1.2), m)
            s = np.sin(2 * np.pi * np.cumsum(ff) / sr) * np.sin(np.pi * t / d)
            place(y, s0 + pos, s, rng.uniform(0.15, 0.35))
            pos += secs(sr, d + rng.uniform(0.02, 0.1))
    return reverb_wrap(filt(y, sr, lo=1200, hi=7500), sr, 0.8, 0.3, seed=5)


def pigeons(n, sr, count=3):
    y = np.zeros(n, np.float32)
    for _ in range(count):
        s0 = rng.integers(n)
        for j in range(rng.integers(2, 4)):
            d = rng.uniform(0.35, 0.6)
            m = secs(sr, d)
            t = np.arange(m) / sr
            f = rng.uniform(380, 460) * np.linspace(1.05, 0.9, m)
            s = (np.sin(2 * np.pi * np.cumsum(f) / sr) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / sr))
            s *= np.sin(np.pi * t / d) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t))
            place(y, s0 + j * secs(sr, d + 0.15), s, 0.25)
    return filt(y, sr, lo=200, hi=1500)


def rain(n, sr, k=1.0):
    bed = filt(colored(n, sr, 0.4), sr, lo=350, hi=8000) * 0.55
    bed += filt(white(n), sr, lo=3500, hi=10000) * 0.12
    imp = np.zeros(n, np.float32)
    cnt = int(n / sr * 900 * k)
    idx = rng.integers(0, n, cnt)
    np.add.at(imp, idx, rng.exponential(1.0, cnt).astype(np.float32) * rng.choice([-1, 1], cnt))
    ker = white(secs(sr, 0.004)) * np.exp(-np.arange(secs(sr, 0.004)) / (sr * 0.0008))
    patter = filt(conv_wrap(imp, ker.astype(np.float32)), sr, lo=900, hi=9000)
    y = bed + unit(patter) * 0.5
    for _ in range(int(n / sr * 5 * k)):      # grosses gouttes (flaques, tôle)
        d = rng.uniform(0.02, 0.05)
        m = secs(sr, d)
        t = np.arange(m) / sr
        f = rng.uniform(1300, 3200) * (1 + 0.8 * t / d)
        place(y, rng.integers(n), np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t / (d * 0.3)), rng.uniform(0.1, 0.3))
    p = rng.integers(n)                       # gouttière : « plok » réguliers
    while p < n * 2:
        d = 0.08
        m = secs(sr, d)
        t = np.arange(m) / sr
        f = rng.uniform(650, 820) * (1 + 0.5 * t / d)
        place(y, p, np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t / 0.018), 0.2)
        p += secs(sr, rng.uniform(0.55, 0.9))
    return y * (1 + 0.15 * smooth_noise(n, sr, 0.3))


def wind(n, sr, k=1.0):
    y = filt(colored(n, sr, 0.8), sr, lo=120, hi=1600)
    return y * (0.6 + 0.4 * smooth_noise(n, sr, 0.15)) * k


def babble(n, sr, names, density, gain_db=(-14, -5), lo=150, hi=3600, pitch=(0.93, 1.07)):
    """Voix lointaines : répliques existantes placées au hasard (density = voix simultanées en moyenne)."""
    y = np.zeros(n, np.float32)
    total = 0.0
    while total < density * n / sr:
        x = decode(rng.choice(names), sr)
        x = resamp(x, rng.uniform(*pitch))
        place(y, rng.integers(n), fades(x, sr, 0.02, 0.05), 10 ** (rng.uniform(*gain_db) / 20))
        total += len(x) / sr
    return filt(y, sr, lo=lo, hi=hi)


def ping(sr, f, d, partials=((1, 1.0), (2.76, 0.5), (5.4, 0.25)), decay=0.15):
    m = secs(sr, d)
    t = np.arange(m) / sr
    s = np.zeros(m, np.float32)
    for r, a in partials:
        s += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (decay / r ** 0.5))
    return s


def clinks(n, sr, count):
    y = np.zeros(n, np.float32)
    for _ in range(count):
        s0 = rng.integers(n)
        for j in range(rng.integers(1, 4)):
            place(y, s0 + secs(sr, j * rng.uniform(0.08, 0.3)), ping(sr, rng.uniform(1900, 3600), 0.35, decay=0.08),
                  rng.uniform(0.1, 0.3))
    return y


def burst(sr, d, lo, hi, am_hz=0.0):
    m = secs(sr, d)
    t = np.arange(m) / sr
    s = filt(white(m), sr, lo=lo, hi=hi) * np.sin(np.pi * t / d) ** 0.5
    if am_hz:
        s *= 0.6 + 0.4 * np.sin(2 * np.pi * am_hz * t)
    return s


# ================================================================== ambiances
def amb_rue_matin(n, sr):
    y = traffic(n, sr, 1.0, passes=9, horn=1)
    y += birds(n, sr, 16, 3) * 0.8 + pigeons(n, sr, 3) * 0.7
    s = burst(sr, 2.6, 300, 2500) * (1 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * np.arange(secs(sr, 2.6)) / sr)))
    place(y, rng.integers(n), s, 0.08)                                   # rideau de fer qu'on lève
    place(y, rng.integers(n), burst(sr, 0.9, 2000, 6000), 0.06)         # soupir de frein d'un bus
    return y


def amb_rue_nuit(n, sr):
    y = traffic(n, sr, 0.7, passes=3, rumble=0.8) + wind(n, sr, 0.35)
    m = secs(sr, 7.0)                                                    # sirène très lointaine
    t = np.arange(m) / sr
    f = np.where((t * 1.1) % 1.0 < 0.5, 435.0, 488.0)
    s = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.sin(np.pi * t / 7.0) ** 2
    place(y, rng.integers(n), filt(s, sr, hi=1200), 0.05)
    hum = sum(np.sin(2 * np.pi * h * np.arange(n) / sr) / h for h in (100, 200, 300))
    return y + hum * 0.004


def amb_pluie(n, sr):
    return rain(n, sr, 1.0)


def amb_cafe(n, sr):
    y = filt(colored(n, sr, 0.6), sr, lo=40, hi=700) * 0.25
    talk = lines(["v_m1_talk", "v_m2_talk", "v_f1_talk", "v_m1_reply", "v_m2_reply", "v_f1_reply", "v_m1_calm",
                  "v_f1_calm", "v_m2_calm"])
    y += reverb_wrap(babble(n, sr, talk, 2.6, hi=3200), sr, 0.6, 0.35, seed=7)
    y += reverb_wrap(clinks(n, sr, 9), sr, 0.5, 0.3, seed=8)
    s0 = rng.integers(n)                                                 # percolateur : moulin puis vapeur
    place(y, s0, burst(sr, 2.5, 900, 4000, am_hz=48), 0.12)
    place(y, s0 + secs(sr, 4.0), burst(sr, 4.0, 2000, 8000), 0.08)
    for _ in range(2):                                                   # chaise qui racle
        place(y, rng.integers(n), burst(sr, 0.4, 400, 1200, am_hz=30), 0.08)
    news = lines(["v_f1_talk", "v_f1_reply"])
    tv = filt(babble(n, sr, news, 0.5, gain_db=(-8, -6), pitch=(1.0, 1.02)), sr, lo=400, hi=3000)
    return y + tv * 0.35


def amb_superette(n, sr):
    t = np.arange(n) / sr
    hum = sum(a * np.sin(2 * np.pi * h * t) for h, a in ((50, 0.5), (100, 1.0), (150, 0.3), (200, 0.25), (300, 0.1)))
    y = hum * 0.04 + filt(colored(n, sr, 0.8), sr, lo=60, hi=400) * 0.18          # vitrines réfrigérées
    y += filt(white(n), sr, lo=2500, hi=5000) * 0.01                                # néons
    p = rng.integers(n)
    for _ in range(9):                                                              # caisse : bips du lecteur
        for j in range(rng.integers(2, 6)):
            m = secs(sr, 0.11)
            b = np.sin(2 * np.pi * 2900 * np.arange(m) / sr)
            place(y, p + secs(sr, j * rng.uniform(0.5, 1.4)), fades(b, sr, 0.003, 0.01), 0.07)
        p += secs(sr, rng.uniform(2.5, 4.5))
    ding = np.concatenate([ping(sr, 659.0, 0.5, decay=0.4), ping(sr, 523.0, 1.0, decay=0.5)])
    place(y, rng.integers(n), ding, 0.12)                                           # porte d'entrée
    m = secs(sr, 2.2)                                                               # chariot
    imp = np.zeros(m, np.float32)
    np.add.at(imp, rng.integers(0, m, 500), rng.standard_normal(500).astype(np.float32))
    place(y, rng.integers(n), filt(imp, sr, lo=800, hi=3500) * np.sin(np.pi * np.arange(m) / m), 0.1)
    for _ in range(3):                                                              # sacs plastique
        place(y, rng.integers(n), burst(sr, 0.8, 3000, 9000, am_hz=23), 0.05)
    talk = lines(["v_m1_talk", "v_f1_talk", "v_m2_reply"])
    y += babble(n, sr, talk, 0.5, gain_db=(-16, -11), hi=2500)
    radio = music_radio(n, sr)                                                      # radio du magasin
    y += filt(radio, sr, lo=400, hi=3200) * 0.06
    return reverb_wrap(y, sr, 0.7, 0.25, seed=9)


def amb_tv(n, sr):
    talk = lines(["v_f1_talk", "v_f1_reply", "v_m1_talk"])
    y = babble(n, sr, talk, 0.85, gain_db=(-7, -5), lo=280, hi=4500, pitch=(0.99, 1.02))
    y += filt(colored(n, sr, 0.6), sr, lo=40, hi=500) * 0.03
    m = secs(sr, 1.6)                                                               # virgule sonore du JT
    t = np.arange(m) / sr
    jing = sum(np.sin(2 * np.pi * f * t) * np.exp(-t / 0.5) for f in (523.25, 659.25, 783.99, 1046.5))
    place(y, rng.integers(n), filt(jing, sr, lo=300, hi=4000), 0.12)
    return reverb_wrap(y, sr, 0.5, 0.2, seed=10)


def amb_square(n, sr):
    y = traffic(n, sr, 0.45, passes=4, rumble=0.7)
    leaves = filt(white(n), sr, lo=800, hi=6000) * (0.4 + 0.6 * np.clip(smooth_noise(n, sr, 0.2), 0, 1)) * 0.08
    y += leaves + birds(n, sr, 22, 4) + pigeons(n, sr, 5)
    for _ in range(6):                                                              # pas sur le gravier
        s0 = rng.integers(n)
        for j in range(rng.integers(4, 9)):
            place(y, s0 + secs(sr, j * 0.55), burst(sr, 0.12, 900, 5000), 0.05)
    talk = lines(["v_m1_talk", "v_f1_talk", "v_m2_talk"])
    return y + babble(n, sr, talk, 0.4, gain_db=(-20, -14), hi=2200)


def amb_cortege(n, sr):
    y = traffic(n, sr, 0.35, passes=2, rumble=0.6)
    y += filt(decode("crowd_murmur", sr)[:n] if len(decode("crowd_murmur", sr)) >= n
              else np.resize(decode("crowd_murmur", sr), n), sr, hi=1400) * 0.5
    for _ in range(8):
        w = decode("whistle_%d" % rng.integers(3), sr)
        place(y, rng.integers(n), filt(w, sr, hi=3500), rng.uniform(0.05, 0.12))
    p = rng.integers(n)                                                             # grosse caisse au loin
    for _ in range(5):
        for j in range(8):
            m = secs(sr, 0.35)
            t = np.arange(m) / sr
            k = np.sin(2 * np.pi * 70 * t * (1 - 0.3 * t)) * np.exp(-t / 0.1)
            place(y, p + secs(sr, j * 0.5 + (0.25 if j % 4 == 3 else 0)), k, 0.12)
        p += secs(sr, rng.uniform(5, 8))
    for i in range(2):
        place(y, rng.integers(n), filt(decode("megaphone_%d" % i, sr), sr, lo=500, hi=2200), 0.06)
    return reverb_wrap(y, sr, 1.4, 0.35, seed=11)


def amb_blocage(n, sr):
    y = wind(n, sr, 0.7) + filt(colored(n, sr, 1.0), sr, lo=25, hi=200) * 0.35     # rocade au loin
    y += birds(n, sr, 6, 2) * 0.6
    fire = decode("fire_loop", sr)
    y += np.resize(fire, n) * 0.18                                                  # brasero
    idle = decode("engine_idle_loop", sr)
    y += filt(np.resize(idle, n), sr, hi=600) * 0.12 * (0.7 + 0.3 * smooth_noise(n, sr, 0.1))
    talk = lines(["v_m1_talk", "v_m2_talk", "v_f1_talk", "v_m1_cold", "v_f1_cold", "v_m2_cold", "v_m1_tired"])
    y += reverb_wrap(babble(n, sr, talk, 0.6, gain_db=(-16, -10), hi=2600), sr, 1.0, 0.4, seed=12)
    for _ in range(2):                                                              # palette, barrière
        place(y, rng.integers(n), ping(sr, rng.uniform(300, 600), 0.8, ((1, 1), (2.4, 0.6), (5.1, 0.4)), 0.2), 0.08)
    return y


def amb_foule_gronde(n, sr):
    angry = lines(["v_m1_anger", "v_m2_anger", "v_f1_anger", "v_m1_defy", "v_m2_defy", "v_f1_defy",
                   "v_m1_refuse", "v_m2_refuse", "v_f1_refuse", "v_m1_police", "v_m2_police", "v_f1_police"])
    y = babble(n, sr, angry, 11.0, gain_db=(-12, -2), lo=120, hi=2600, pitch=(0.86, 1.12))
    y = reverb_wrap(y, sr, 1.6, 0.5, seed=13)
    roar = filt(colored(n, sr, 0.7), sr, lo=150, hi=900) * (0.55 + 0.45 * np.clip(smooth_noise(n, sr, 0.25), -0.2, 1))
    y = unit(y) + unit(roar) * 0.35
    for _ in range(3):
        place(y, rng.integers(n), filt(decode("crowd_boo", sr), sr, hi=2500), 0.25)
    for _ in range(5):
        place(y, rng.integers(n), decode("whistle_%d" % rng.integers(3), sr), 0.12)
    return y


AMBIENCES = {
    "amb_rue_matin": amb_rue_matin, "amb_rue_nuit": amb_rue_nuit, "amb_pluie": amb_pluie, "amb_cafe": amb_cafe,
    "amb_superette": amb_superette, "amb_tv": amb_tv, "amb_square": amb_square, "amb_cortege": amb_cortege,
    "amb_blocage": amb_blocage, "amb_foule_gronde": amb_foule_gronde,
}


# ================================================================== instruments (sr variable)
def mf(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def piano(sr, f, dur, vel=0.7):
    """Piano doux : partiels légèrement inharmoniques, deux cordes désaccordées, extinction par partiel."""
    m = secs(sr, dur + 2.5)
    t = np.arange(m) / sr
    y = np.zeros(m, np.float32)
    B = 0.0004
    for k in range(1, 10):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > sr * 0.45:
            break
        a = (1.0 / k ** 1.4) * (0.4 + vel) ** (k * 0.15)
        d = 0.6 + 0.9 * k * (f / 300.0) ** 0.5
        env = np.exp(-t * d * 0.6)
        y += a * env * (np.sin(2 * np.pi * fk * t) + np.sin(2 * np.pi * fk * 1.0012 * t)) * 0.5
    y *= np.minimum(1, t / 0.004)
    rel = np.where(t > dur, np.exp(-(t - dur) * 7.0), 1.0)
    return (y * rel * vel).astype(np.float32)


def pluck(sr, f, dur, vel=0.7):
    m = secs(sr, dur + 1.2)
    t = np.arange(m) / sr
    y = np.zeros(m, np.float32)
    for k in range(1, 14):
        if f * k > sr * 0.45:
            break
        a = abs(np.sin(np.pi * k * 0.22)) / k ** 1.5
        y += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (1.5 + 0.7 * k))
    y *= np.minimum(1, t / 0.002)
    return (y * np.where(t > dur, np.exp(-(t - dur) * 5), 1.0) * vel).astype(np.float32)


def pad(sr, freqs, dur, vel=0.5, att=1.2, rel=1.6, cut=1400.0, h=14, vib=0.0):
    m = secs(sr, dur + rel)
    t = np.arange(m) / sr
    y = np.zeros(m, np.float32)
    for f in freqs:
        for det in (-0.004, 0.0, 0.0045):
            fv = f * (1 + det)
            ph = 2 * np.pi * fv * t + (vib * fv / 5.0 * np.sin(2 * np.pi * 5.0 * t + rng.uniform(0, 6)) if vib else 0.0)
            ph0 = rng.uniform(0, 2 * np.pi)
            for k in range(1, h + 1):
                fk = fv * k
                if fk > sr * 0.45:
                    break
                g = (1.0 / k) / (1 + (fk / cut) ** 2)
                y += g * np.sin(k * ph + ph0 * k)
    env = np.minimum(1, t / att) * np.where(t > dur, np.exp(-(t - dur) * 4.0 / rel), 1.0)
    return (y * env * vel / max(1, len(freqs)) * 0.5).astype(np.float32)


def strings(sr, freqs, dur, vel=0.5, att=0.6):
    return pad(sr, freqs, dur, vel, att=att, rel=1.2, cut=2200.0, h=16, vib=0.003)


def bass(sr, f, dur, vel=0.7):
    m = secs(sr, dur + 0.3)
    t = np.arange(m) / sr
    y = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
    env = np.minimum(1, t / 0.01) * (0.6 + 0.4 * np.exp(-t * 3)) * np.where(t > dur, np.exp(-(t - dur) * 20), 1.0)
    return (y * env * vel).astype(np.float32)


def bell(sr, f, vel=0.5, d=2.5):
    return ping(sr, f, d, ((1, 1.0), (2.0, 0.4), (3.01, 0.25), (4.2, 0.15), (5.43, 0.1)), decay=0.9) * vel


def kick(sr, vel=0.8, f0=110.0, f1=45.0):
    m = secs(sr, 0.5)
    t = np.arange(m) / sr
    f = f1 + (f0 - f1) * np.exp(-t * 30)
    return (np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t / 0.14) * vel).astype(np.float32)


def snare(sr, vel=0.6, d=0.18, snap=True):
    m = secs(sr, d)
    t = np.arange(m) / sr
    nz = filt(white(m), sr, lo=1200, hi=7000) * np.exp(-t / (d * 0.3))
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.03) * (0.6 if snap else 0.2)
    return ((nz + tone) * vel).astype(np.float32)


def hat(sr, vel=0.3, d=0.05):
    m = secs(sr, d)
    t = np.arange(m) / sr
    return (filt(white(m), sr, lo=6000, hi=12000) * np.exp(-t / (d * 0.25)) * vel).astype(np.float32)


def timpani(sr, f, vel=0.8):
    m = secs(sr, 2.0)
    t = np.arange(m) / sr
    y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / dd) for r, a, dd in ((1, 1, 0.8), (1.5, 0.5, 0.5), (1.98, 0.3, 0.4)))
    y += filt(white(m), sr, lo=60, hi=600) * np.exp(-t / 0.04) * 0.5
    return (y * vel).astype(np.float32)


def swell(sr, d, lo=300, hi=4000):
    m = secs(sr, d)
    t = np.arange(m) / sr
    return filt(white(m), sr, lo=lo, hi=hi) * (t / d) ** 3 * np.where(t > d - 0.05, (d - t) / 0.05, 1.0)


class Song:
    """Boucle stéréo de `bars` mesures à `bpm` ; tout ce qui dépasse la fin retombe au début."""

    def __init__(self, sr, bpm, bars, beats=4):
        self.sr = sr
        self.beat = 60.0 / bpm
        self.bars = bars
        self.beats = beats
        self.n = secs(sr, self.beat * beats * bars)
        self.buf = np.zeros((2, self.n), np.float32)

    def at(self, bar, beat=0.0, human=0.006):
        return secs(self.sr, (bar * self.beats + beat) * self.beat + rng.normal(0, human))

    def add(self, sig, bar, beat=0.0, gain=1.0, pan=0.0, human=0.006):
        place(self.buf, self.at(bar, beat, human), pan2(sig, pan), gain)

    def render(self, decay=2.4, wet=0.3):
        return reverb_wrap(self.buf, self.sr, decay, wet, seed=21, hi=6000)


def chord_notes(root, kind):
    iv = {"m": (0, 3, 7), "M": (0, 4, 7), "m7": (0, 3, 7, 10), "M7": (0, 4, 7, 11), "7": (0, 4, 7, 10),
          "sus": (0, 5, 7), "add9": (0, 4, 7, 14), "dim": (0, 3, 6)}[kind]
    return [root + i for i in iv]


def arp(s, bar, notes, pattern, step=0.5, inst=piano, vel=0.45, pan=0.0, dur=None):
    for i, k in enumerate(pattern):
        if k is None:
            continue
        m = notes[k % len(notes)] + 12 * (k // len(notes))
        s.add(inst(s.sr, mf(m), dur or step * s.beat * 1.6, vel * rng.uniform(0.85, 1.1)), bar, i * step,
              pan=pan + rng.uniform(-0.1, 0.1))


def melody(s, start_bar, notes, inst=piano, vel=0.5, pan=0.1):
    """notes : liste de (midi | None, durée en temps)."""
    b = 0.0
    for m, d in notes:
        if m is not None:
            s.add(inst(s.sr, mf(m), d * s.beat * 0.95, vel * rng.uniform(0.9, 1.05)), start_bar, b, pan=pan)
        b += d


# ================================================================== musiques
def mus_theme(sr):
    s = Song(sr, 72, 16)
    prog = [(57, "m"), (53, "M"), (48, "M"), (55, "M"), (57, "m"), (53, "M"), (50, "m"), (52, "sus")]
    for bar in range(16):
        r, k = prog[bar % 8]
        if bar % 8 == 7 and bar > 0:
            k = "M" if bar == 15 else "sus"
        nt = chord_notes(r, k)
        arp(s, bar, nt, [0, 1, 2, 3, 1, 2, 3, 2], vel=0.32, pan=-0.2)
        s.add(bass(sr, mf(r - 12), s.beat * 3.6, 0.45), bar)
        s.add(pad(sr, [mf(x + 12) for x in nt], s.beat * 4, 0.22), bar, gain=0.8)
        if bar >= 8:
            s.add(strings(sr, [mf(x) for x in nt[:3]], s.beat * 4, 0.25), bar, pan=0.3)
    mel = [(76, 1.5), (74, 0.5), (72, 2), (72, 1.5), (71, 0.5), (69, 2), (67, 1), (69, 1), (72, 2), (71, 3), (None, 1),
           (76, 1.5), (74, 0.5), (72, 2), (77, 1.5), (76, 0.5), (74, 2), (72, 1), (71, 1), (69, 2), (68, 3), (None, 1)]
    melody(s, 8, mel, vel=0.42)
    return s.render(2.6, 0.32)


def mus_matin(sr):
    s = Song(sr, 92, 16)
    prog = [(50, "M"), (57, "M"), (47, "m"), (55, "M"), (50, "M"), (57, "M"), (55, "M"), (57, "sus")]
    for bar in range(16):
        r, k = prog[bar % 8]
        nt = chord_notes(r + 12, k)
        arp(s, bar, nt, [0, 2, 1, 2, 3, 2, 1, 2], inst=pluck, vel=0.4, pan=-0.3)
        s.add(bass(sr, mf(r - 12 if r >= 48 else r), s.beat * 1.8, 0.4), bar)
        s.add(bass(sr, mf((r - 12 if r >= 48 else r) + 7), s.beat * 1.8, 0.3), bar, 2)
        for b in range(8):
            s.add(hat(sr, 0.12 if b % 2 else 0.07, 0.07), bar, b * 0.5, pan=0.4)
        if bar >= 8 and bar % 2 == 0:
            s.add(bell(sr, mf(nt[2] + 12), 0.18), bar, 0, pan=0.5)
            s.add(bell(sr, mf(nt[1] + 12), 0.14), bar, 2.5, pan=0.5)
    return s.render(1.8, 0.25)


def mus_espoir(sr):
    s = Song(sr, 80, 16)
    prog = [(48, "M"), (55, "M"), (57, "m"), (53, "add9")]
    for bar in range(16):
        r, k = prog[bar % 4]
        nt = chord_notes(r + 12, k)
        for b in range(4):
            for x in nt[:3]:
                s.add(piano(sr, mf(x), s.beat * 0.9, 0.18 if b else 0.24), bar, b, pan=-0.15)
        s.add(bass(sr, mf(r - 12), s.beat * 3.8, 0.42), bar)
        if bar >= 4:
            s.add(pad(sr, [mf(x) for x in nt[:3]], s.beat * 4, 0.2), bar, gain=0.8)
        if bar >= 8:
            s.add(strings(sr, [mf(nt[0] + 12), mf(nt[2] + 12)], s.beat * 4, 0.22), bar, pan=0.35)
            s.add(kick(sr, 0.35, 90, 45), bar)
            s.add(kick(sr, 0.25, 90, 45), bar, 2.5)
    mel = [(72, 1), (74, 1), (76, 2), (74, 1), (72, 1), (71, 2), (69, 1.5), (71, 0.5), (72, 2), (77, 2), (76, 4),
           (72, 1), (74, 1), (76, 2), (79, 1), (77, 1), (76, 2), (74, 1.5), (72, 0.5), (71, 2), (72, 4), (None, 4)]
    melody(s, 4, mel, vel=0.38)
    return s.render(2.2, 0.3)


def mus_marche(sr):
    s = Song(sr, 104, 16)
    prog = [(50, "m"), (46, "M"), (53, "M"), (48, "M")]
    for bar in range(16):
        r, k = prog[bar % 4]
        nt = chord_notes(r, k)
        s.add(kick(sr, 0.7, 100, 42), bar, 0)
        s.add(kick(sr, 0.55, 100, 42), bar, 2)
        acc = [0.55, 0.22, 0.3, 0.22, 0.45, 0.22, 0.3, 0.25]
        for b in range(8):
            s.add(snare(sr, acc[b] * 0.7, 0.14), bar, b * 0.5, pan=0.15)
        if bar % 4 == 3:
            for b in range(8):
                s.add(snare(sr, 0.18 + 0.03 * b, 0.08, False), bar, 2 + b * 0.25, pan=0.15)
        for b in range(8):
            s.add(bass(sr, mf(r - 12), s.beat * 0.4, 0.38 if b % 2 == 0 else 0.28), bar, b * 0.5)
        s.add(pad(sr, [mf(x) for x in nt], s.beat * 4, 0.3, att=0.15, rel=0.6, cut=1800), bar, gain=0.7, pan=-0.2)
        if bar >= 8:
            s.add(strings(sr, [mf(nt[0] + 12)], s.beat * 4, 0.18, att=0.2), bar, pan=0.3)
    mel = [(62, 1.5), (62, 0.5), (65, 1), (69, 1), (70, 2), (69, 1), (67, 1), (65, 1.5), (64, 0.5), (65, 1), (67, 1),
           (69, 4), (62, 1.5), (62, 0.5), (65, 1), (69, 1), (74, 2), (72, 1), (70, 1), (69, 1.5), (67, 0.5), (65, 1),
           (64, 1), (62, 4)]
    melody(s, 8, mel, inst=lambda sr_, f, d, v: strings(sr_, [f], d, v, att=0.08), vel=0.42, pan=0.2)
    return s.render(1.6, 0.22)


def mus_tension(sr):
    s = Song(sr, 96, 16)
    roots = [40, 40, 36, 40, 40, 40, 34, 35]
    for bar in range(16):
        r = roots[bar % 8]
        for b in range(8):
            s.add(bass(sr, mf(r), s.beat * 0.35, 0.42 if b % 2 == 0 else 0.3), bar, b * 0.5)
        for b in range(16):
            s.add(hat(sr, 0.06 + (0.05 if b % 4 == 0 else 0), 0.03), bar, b * 0.25, pan=0.5, human=0.002)
        if bar % 4 == 0:
            s.add(pad(sr, [mf(28), mf(35)], s.beat * 16, 0.4, att=2.0, rel=2.0, cut=500), bar, gain=0.9)
            s.add(kick(sr, 0.6, 70, 32), bar)
        if bar % 2 == 1:
            s.add(strings(sr, [mf(78), mf(79)], s.beat * 8, 0.12, att=1.5), bar, pan=-0.4)
        if bar % 4 == 3:
            s.add(swell(sr, s.beat * 4, 800, 6000) * 0.12, bar, pan=0.2)
    return s.render(2.0, 0.25)


def mus_nasse(sr):
    s = Song(sr, 70, 16)
    for bar in range(16):
        for b in (0, 2):
            s.add(kick(sr, 0.7, 70, 38), bar, b)
            s.add(kick(sr, 0.45, 70, 38), bar, b + 0.3)
        if bar % 4 == 0:
            s.add(pad(sr, [mf(37), mf(38), mf(44)], s.beat * 16, 0.45, att=3.0, rel=2.0, cut=700), bar)
            s.add(pad(sr, [mf(25)], s.beat * 16, 0.4, att=2.0, rel=2.0, cut=300), bar)
        if bar % 4 == 2:
            s.add(ping(sr, rng.uniform(180, 260), 4.0, ((1, 1), (2.13, 0.7), (3.7, 0.5), (5.9, 0.4)), 1.5) * 0.25,
                  bar, 1, pan=rng.uniform(-0.6, 0.6))
        if bar % 4 == 3:
            s.add(swell(sr, s.beat * 4, 200, 2500) * 0.18, bar)
        if bar >= 8 and bar % 2 == 0:
            s.add(strings(sr, [mf(73), mf(74)], s.beat * 6, 0.12, att=2.5), bar, pan=0.4)
    return s.render(2.8, 0.35)


def mus_aube(sr):
    s = Song(sr, 60, 12)
    prog = [(53, "M7"), (57, "m7"), (58, "M7"), (48, "add9")]
    for bar in range(12):
        r, k = prog[bar % 4]
        nt = chord_notes(r, k)
        s.add(pad(sr, [mf(x) for x in nt], s.beat * 4, 0.32, att=1.8, rel=2.2, cut=1600), bar)
        s.add(bass(sr, mf(r - 12), s.beat * 3.8, 0.3), bar)
        for i in range(4):
            if rng.random() < 0.75:
                s.add(bell(sr, mf(nt[rng.integers(len(nt))] + 24), 0.14), bar, i + rng.choice([0, 0.5]),
                      pan=rng.uniform(-0.6, 0.6))
        if bar >= 4:
            s.add(strings(sr, [mf(nt[1] + 12), mf(nt[2] + 12)], s.beat * 4, 0.16 + 0.02 * (bar - 4), att=1.5),
                  bar, pan=-0.3)
    return s.render(3.0, 0.38)


def mus_fin(sr):
    s = Song(sr, 70, 16)
    prog = [(55, "M"), (52, "m"), (48, "M"), (50, "M"), (55, "M"), (59, "m"), (48, "M"), (50, "sus")]
    for bar in range(16):
        r, k = prog[bar % 8]
        nt = chord_notes(r, k)
        arp(s, bar, nt, [0, 1, 2, 3, 2, 1], step=4 / 6, vel=0.3, pan=-0.2)
        s.add(bass(sr, mf(r - 12), s.beat * 3.8, 0.4), bar)
        s.add(strings(sr, [mf(x) for x in nt[:3]], s.beat * 4, 0.24, att=1.0), bar, pan=0.25)
    mel = [(74, 2), (71, 1), (72, 1), (74, 2), (76, 2), (72, 3), (71, 1), (69, 4),
           (74, 2), (71, 1), (72, 1), (74, 2), (79, 2), (76, 3), (74, 1), (74, 4)]
    melody(s, 8, mel, vel=0.4)
    return s.render(2.8, 0.34)


def mus_fin_sombre(sr):
    s = Song(sr, 60, 12)
    prog = [(57, "m"), (53, "M7"), (50, "m"), (52, "M")]
    for bar in range(12):
        r, k = prog[bar % 4]
        nt = chord_notes(r, k)
        s.add(pad(sr, [mf(x - 12) for x in nt[:3]], s.beat * 4, 0.22, att=2.0, rel=2.5, cut=900), bar)
        s.add(piano(sr, mf(r - 12), s.beat * 3.5, 0.35), bar)
        for b, i in ((1, 2), (2, 1), (3, 2)):
            if rng.random() < 0.8:
                s.add(piano(sr, mf(nt[i] + 12), s.beat * 1.5, 0.2), bar, b, pan=0.15)
    mel = [(76, 3), (74, 1), (72, 4), (74, 2), (72, 1), (71, 1), (69, 4), (None, 4), (72, 2), (71, 2), (68, 4)]
    melody(s, 4, mel, vel=0.3)
    return s.render(3.2, 0.4)


def mus_jt(sr):
    s = Song(sr, 120, 16)
    prog = [(48, "m"), (44, "M"), (51, "M"), (46, "M")]
    for bar in range(16):
        r, k = prog[bar % 4]
        nt = chord_notes(r + 12, k)
        for b in range(8):
            s.add(bass(sr, mf(r - 12), s.beat * 0.3, 0.35), bar, b * 0.5)
        for b in range(16):
            s.add(hat(sr, 0.12 if b % 4 == 0 else 0.06, 0.025), bar, b * 0.25, pan=0.35, human=0.001)
        s.add(pad(sr, [mf(x) for x in nt], s.beat * 4, 0.25, att=0.3, rel=0.8, cut=2000), bar, gain=0.8)
        s.add(kick(sr, 0.4, 100, 45), bar, 0)
        s.add(kick(sr, 0.3, 100, 45), bar, 2)
        if bar % 2 == 0:
            s.add(bell(sr, mf(nt[2] + 12), 0.12, 1.2), bar, 3.5, pan=0.4)
    return s.render(1.4, 0.2)


def mus_jt_intro(sr):
    n = secs(sr, 3.2)
    buf = np.zeros((2, n), np.float32)
    for i, (d, ch) in enumerate(((0.0, (60, 63, 67)), (0.35, (63, 67, 70)), (0.7, (60, 67, 72, 75)))):
        st = pad(sr, [mf(x) for x in ch], 0.25 if i < 2 else 1.6, 0.6, att=0.01, rel=0.6, cut=3000)
        place(buf, secs(sr, d), pan2(st, -0.1 + 0.1 * i))
    place(buf, secs(sr, 0.7), pan2(timpani(sr, mf(36), 0.9), 0))
    place(buf, secs(sr, 0.7), pan2(bell(sr, mf(84), 0.35, 2.0), 0.3))
    y = reverb_wrap(buf, sr, 1.5, 0.25, seed=22)
    y[:, -secs(sr, 0.4):] *= np.linspace(1, 0, secs(sr, 0.4))
    return y


def mus_echec(sr):
    s = Song(sr, 60, 8)
    for bar in range(8):
        if bar % 4 == 0:
            s.add(pad(sr, [mf(33), mf(40)], s.beat * 16, 0.4, att=2.5, rel=2.5, cut=500), bar)
        if bar % 2 == 0:
            s.add(piano(sr, mf([69, 67, 65, 64][bar // 2]), s.beat * 3, 0.22), bar, 1, pan=0.2)
            s.add(piano(sr, mf([60, 59, 57, 56][bar // 2]), s.beat * 3, 0.18), bar, 1.02, pan=0.2)
    return s.render(3.0, 0.4)


def mus_echec_intro(sr):
    n = secs(sr, 4.0)
    buf = np.zeros((2, n), np.float32)
    for x in (33, 45, 48, 51):
        place(buf, 0, pan2(piano(sr, mf(x), 2.0, 0.6), 0))
    place(buf, 0, pan2(timpani(sr, mf(33), 0.8), 0))
    y = reverb_wrap(buf, sr, 2.5, 0.35, seed=23)
    y[:, -secs(sr, 0.8):] *= np.linspace(1, 0, secs(sr, 0.8))
    return y


def music_radio(n, sr):
    """Petite boucle de variété pour la radio de la supérette (mono, sr des ambiances)."""
    s = Song(sr, 100, 8)
    prog = [(48, "M7"), (45, "m7"), (50, "m7"), (55, "7")]
    for bar in range(8):
        r, k = prog[bar % 4]
        nt = chord_notes(r + 12, k)
        for b in (0, 1.5, 2.5):
            for x in nt:
                s.add(piano(sr, mf(x), s.beat * 0.6, 0.15), bar, b)
        s.add(bass(sr, mf(r - 12), s.beat * 1.5, 0.4), bar)
        s.add(bass(sr, mf(r - 5), s.beat * 1.5, 0.3), bar, 2)
        s.add(kick(sr, 0.4), bar, 0)
        s.add(snare(sr, 0.25), bar, 1)
        s.add(kick(sr, 0.4), bar, 2)
        s.add(snare(sr, 0.25), bar, 3)
    y = s.buf.mean(axis=0)
    return np.resize(y, n)


MUSICS = {
    "mus_theme": mus_theme, "mus_matin": mus_matin, "mus_espoir": mus_espoir, "mus_marche": mus_marche,
    "mus_tension": mus_tension, "mus_nasse": mus_nasse, "mus_aube": mus_aube, "mus_fin": mus_fin,
    "mus_fin_sombre": mus_fin_sombre, "mus_jt": mus_jt, "mus_jt_intro": mus_jt_intro, "mus_echec": mus_echec,
    "mus_echec_intro": mus_echec_intro,
}


def main(names):
    for name, fn in AMBIENCES.items():
        if names and name not in names:
            continue
        save(name, fn(secs(SR_A, 32.0), SR_A), SR_A, rms_db=-20.0, q=1)
    for name, fn in MUSICS.items():
        if names and name not in names:
            continue
        save(name, fn(SR_M), SR_M, rms_db=-21.0, q=0)


if __name__ == "__main__":
    main(set(sys.argv[1:]))

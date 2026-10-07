"""Génère la deuxième vague de sons : répliques de la police et des manifestants (peur, gaz, colère...),
chants anti-police, sommations au mégaphone, radio, sirènes, moteurs, grenades lacrymogènes, LBD, matraques,
menottes, toux, pétards, barrières, voiture, etc.
Usage : python3 tools/build_audio2.py [voices2] [police] [chants2] [sfx2]   (tout par défaut)
Réutilise les outils de build_audio.py (Piper pour les voix, numpy pour la synthèse)."""
import os, sys, json, random
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import build_audio as B

RATE = B.RATE
rng = B.rng


def noise(n):
    return rng.standard_normal(n).astype(np.float32)


def tvec(dur):
    return np.arange(int(dur * RATE)) / RATE


def bandpass(x, f0, bw):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    g = np.exp(-0.5 * ((f - f0) / bw) ** 2)
    return np.fft.irfft(X * g, n).astype(np.float32)


def loopify(y, L, fade):
    y = y.copy()
    y[:fade] = y[:fade] * np.linspace(0, 1, fade) + y[L:L + fade] * np.linspace(1, 0, fade)
    return y[:L]


def radio_fx(x, hard=1.0):
    x = B.fft_filter(x, lo=380, hi=3100)
    x = np.tanh(B.norm(x) * 2.2 * hard)
    x = B.fft_filter(x, lo=400, hi=3200)
    n = len(x)
    t = np.arange(n) / RATE
    hiss = B.fft_filter(noise(n), lo=1500, hi=4500) * 0.035
    # bip de fin de transmission
    bip = np.zeros(int(0.12 * RATE), np.float32)
    tb = np.arange(len(bip)) / RATE
    bip = (np.sin(2 * np.pi * 1350 * tb) * 0.25 * np.minimum(1, tb / 0.005) * np.minimum(1, (0.12 - tb) / 0.01)).astype(np.float32)
    y = np.concatenate([bip * 0.6, x + hiss[:n], bip])
    return y


def megaphone_fx(x):
    x = B.fft_filter(B.pitch(x, 1.0), lo=420, hi=3400)
    x = np.tanh(B.norm(x) * 4.5)
    x = B.fft_filter(x, lo=480, hi=3600)
    return B.norm(B.reverb(x, 0.28, 0.9), 0.95)


# ------------------------------------------------------------------ voix
LINES_CIV = {
    "pain": ["Aïe !", "Ah !", "Aïe, ça fait mal !", "Ouch !"],
    "fear": ["Oh non !", "Courez !", "Vite, vite !", "Sauvez-vous !"],
    "gas": ["Ça pique !", "Mes yeux !", "J'étouffe !", "Ils gazent !", "Je vois plus rien !"],
    "police": ["C'est la police !", "Les CRS arrivent !", "Regardez, la police !", "Ils sont là !"],
    "anger": ["Dégagez !", "Honte à vous !", "Lâchez-nous !", "Pas de violence !", "Vous n'avez pas honte ?"],
    "defy": ["On reste là !", "On ne bouge pas !", "On ne recule pas !", "Tenez bon !"],
    "free": ["Libérez-le !", "Lâchez-le !", "Laissez-le partir !", "Relâchez-la !"],
    "help": ["Ça va ?", "Tiens, lève-toi !", "Je t'aide !", "Viens, viens !"],
    "retreat": ["Reculez !", "On recule !", "On s'en va !", "Allez, on se barre !"],
    "cold": ["Brrr, il fait froid.", "Ça caille ici.", "J'ai les mains gelées."],
    "throw": ["Tiens, prends ça !", "Tiens !", "Voilà pour toi !"],
    "arrested": ["Lâchez-moi !", "Je n'ai rien fait !", "Vous me faites mal !", "Arrêtez !"],
    "petard": ["C'est quoi ça ?", "Un pétard !", "Ça fait peur !"],
    "fireclose": ["Attention au feu !", "Reculez du feu !", "Ça va brûler !"],
    "vandal": ["Défonce-le !", "Vas-y, casse-le !", "Bien joué !"],
    "calm": ["Du calme, du calme !", "Restez calmes !", "On ne répond pas !", "Pas de panique !"],
    "tired": ["Je suis crevé.", "On marche depuis des heures.", "J'ai mal aux pieds."],
    "drink": ["Tu veux de l'eau ?", "Tiens, bois un coup.", "Il me reste un sandwich."],
}
LINES_COP = {
    "pol_order": ["Reculez !", "Dégagez !", "Circulez !", "Dispersez-vous !", "Reculez, reculez !", "On recule, allez !"],
    "pol_warn": ["Police ! Ne bougez plus !", "Arrêtez-vous !", "Stop ! Police !", "Dernière sommation !"],
    "pol_advance": ["On avance !", "Tenez la ligne !", "En ligne !", "Serrez les rangs !", "Avancez, avancez !"],
    "pol_charge": ["On charge !", "Chargez !", "Maintenant !", "Allez, allez, allez !"],
    "pol_gas": ["Gaz ! Gaz !", "Tir lacrymo !", "Lacrymo, feu !", "Masques !"],
    "pol_arrest": ["Au sol !", "Mains dans le dos !", "Vous êtes en état d'arrestation.", "Tu bouges plus !", "Menottes !", "Interpellation !"],
    "pol_hit": ["Aïe !", "Il m'a touché !", "Ils lancent des projectiles !", "Casque ! Casque !", "Je suis touché !"],
    "pol_retreat": ["Repli, repli !", "On se replie !", "On recule !", "Repli sur les véhicules !"],
    "pol_lbd": ["LBD en position !", "Je tire !", "Feu !", "Cible identifiée !"],
    "pol_spray": ["Je gaze !", "Dégage ou je gaze !", "Recule !"],
    "pol_idle": ["Ça va bouger.", "Restez groupés.", "On garde la position.", "Pas d'initiative.", "Attendez les ordres."],
    "pol_down": ["Officier à terre !", "Un collègue est à terre !", "On le sort !"],
    "pol_fire": ["Un véhicule brûle !", "Ils attaquent le véhicule !", "Protégez les véhicules !"],
}
LINES_RADIO = ["Reçu.", "Reçu, on tient la position.", "Renforts demandés.", "Ici Alpha, on avance.", "Compris, terminé.",
               "Ici Bravo, on a un début d'incendie.", "Manifestants nombreux, demandons renforts."]
SOMMATIONS = [
    "Attention. Cette manifestation n'est pas autorisée. Veuillez vous disperser immédiatement.",
    "Première sommation. Obéissance à la loi. Dispersez-vous.",
    "Deuxième sommation. Obéissance à la loi. Dispersez-vous.",
    "Dernière sommation. Nous allons faire usage de la force.",
    "Quittez les lieux. Dégagez la voie publique.",
    "Les forces de l'ordre vont procéder à l'évacuation de la place.",
]


def build_voices2(data):
    man = data.setdefault("voices", {})
    for vk in B.VOICES:
        for cat, lines in LINES_CIV.items():
            for i, t in enumerate(lines):
                x = B.tts(t, vk, ls=0.92, nscale=0.75, nw=0.9)
                loud = cat in ("pain", "fear", "gas", "anger", "defy", "free", "throw", "arrested", "fireclose", "vandal")
                x = B.shout(x, drive=2.4 if loud else 1.3, up=1.05 if loud else 1.0)
                name = f"v_{vk}_{cat}_{i}"
                B.save(name, B.reverb(x, 0.12, 0.6), env=True)
                man.setdefault(f"{vk}_{cat}", []).append(name)
        for cat, lines in LINES_COP.items():
            for i, t in enumerate(lines):
                x = B.tts(t, vk, ls=0.88, nscale=0.7, nw=0.85)
                x = B.shout(x, drive=3.0 if cat != "pol_idle" else 1.4, up=0.98 if vk != "f1" else 1.0)
                x = B.fft_filter(x, lo=160, hi=6500)
                name = f"v_{vk}_{cat}_{i}"
                B.save(name, B.reverb(x, 0.14, 0.7), env=True)
                man.setdefault(f"{vk}_{cat}", []).append(name)
        for i, t in enumerate(LINES_RADIO):
            x = B.tts(t, vk, ls=0.95, nscale=0.6, nw=0.7)
            name = f"v_{vk}_pol_radio_{i}"
            B.save(name, radio_fx(x), env=True)
            man.setdefault(f"{vk}_pol_radio", []).append(name)


def build_police(data):
    for i, t in enumerate(SOMMATIONS):
        x = B.tts(t, "m1", ls=1.05, nscale=0.6, nw=0.7)
        B.save(f"pol_mega_{i}", megaphone_fx(x), env=True)
    # clic de radio (début de transmission)
    n = int(0.09 * RATE)
    t = np.arange(n) / RATE
    x = (np.sin(2 * np.pi * 1700 * t) * 0.3 * np.exp(-t / 0.03) + B.fft_filter(noise(n), lo=800, hi=5000) * 0.1 * np.exp(-t / 0.02)).astype(np.float32)
    B.save("radio_squelch", B.norm(x, 0.5))


# ------------------------------------------------------------------ chants
CHANTS2 = {
    "chant_police": ("Tout le monde déteste la police !", 2.7, 5),
    "chant_justice": ("Pas de justice, pas de paix !", 2.3, 5),
    "chant_partout": ("Police partout, justice nulle part !", 3.0, 4),
    "chant_libere": ("Libérez nos camarades !", 2.3, 5),
    "chant_resiste": ("Résistance ! Résistance !", 2.2, 5),
}


def build_chants2(data):
    beats = data.setdefault("beats", {})
    for name, (text, period, reps) in CHANTS2.items():
        variants = [B.crowd_layer(text, 14, ls=1.0, spread=0.06) for _ in range(2)]
        plen = max(len(v) for v in variants) / RATE
        per = max(period, plen + 0.25)
        parts = []
        for r in range(reps):
            v = variants[r % 2] * (0.8 + 0.2 * min(1.0, r / 2.0))
            parts.append((int(r * per * RATE), v))
        y = B.mix(parts)
        y = y + B.mix([(0, B.roar(len(y) / RATE + 0.5, 0.05, attack=0.6, release=5.0))], len(y))
        y = B.norm(B.reverb(B.norm(y, 0.9), 0.28, 1.1), 0.92)
        B.save(name, y, env=True)
        beats[name] = B.onsets(y)
    # réactions de foule
    for name, (txt, n, extra_roar, ls) in {
        "crowd_boo": ("Ouuuh !", 16, 0.15, 1.8), "crowd_anger": ("Dégagez ! Honte !", 18, 0.25, 1.0),
        "crowd_gas": ("Ils gazent ! Ça pique !", 12, 0.12, 1.0), "crowd_free": ("Libérez-le !", 14, 0.2, 1.0),
        "crowd_gasp": ("Oh !", 12, 0.05, 1.2),
    }.items():
        y = B.crowd_layer(txt, n, ls=ls, spread=0.3, up_range=(0.88, 1.2))
        y = y + B.mix([(0, B.roar(len(y) / RATE + 0.8, extra_roar, attack=0.1, release=0.9))], len(y))
        B.save(name, B.norm(B.reverb(B.norm(y), 0.3, 1.2), 0.9))


# ------------------------------------------------------------------ bruitages
def metal_hit(freqs, decays, dur, amps=None, click=0.5, seed=0):
    r = np.random.default_rng(seed)
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    y = np.zeros(n, np.float32)
    for k, (f, d) in enumerate(zip(freqs, decays)):
        a = (amps[k] if amps else 1.0 / (k + 1))
        y += np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * a * np.exp(-t * d)
    y += B.fft_filter(r.standard_normal(n).astype(np.float32), lo=1500, hi=9000) * np.exp(-t * 90) * click
    return y.astype(np.float32)


def cough(f0, formants, bursts, seed):
    r = np.random.default_rng(seed)
    parts = []
    pos = 0
    inh = int(0.22 * RATE)
    ti = np.arange(inh) / RATE
    gasp = B.fft_filter(r.standard_normal(inh).astype(np.float32), lo=300, hi=3500) * np.sin(np.pi * np.minimum(1, ti / 0.22)) * 0.25
    parts.append((0, gasp))
    pos = inh + int(0.05 * RATE)
    for b in range(bursts):
        d = r.uniform(0.11, 0.17)
        n = int(d * RATE)
        t = np.arange(n) / RATE
        src = r.standard_normal(n).astype(np.float32) * 0.6
        pulse = np.sign(np.sin(2 * np.pi * f0 * (1 + 0.1 * r.uniform(-1, 1)) * t)) * 0.3
        src = src + pulse
        x = np.zeros(n, np.float32)
        for k, ff in enumerate(formants):
            x += bandpass(src, ff * r.uniform(0.9, 1.1), ff * 0.22) / (k + 1)
        env = np.minimum(1, t / 0.008) * np.exp(-t / (d * 0.45))
        x = x * env * (1.0 - 0.12 * b) * r.uniform(0.8, 1.0)
        parts.append((pos, x))
        pos += int((d + r.uniform(0.07, 0.14)) * RATE)
    y = B.mix(parts, pos + int(0.2 * RATE))
    return B.norm(B.fft_filter(y, lo=90, hi=7000), 0.8)


def build_sfx2(data):
    # --- sirène deux tons (boucle)
    L = int(2.2 * RATE)
    fade = RATE // 4
    n = L + fade
    t = np.arange(n) / RATE
    seg = 0.55
    f_hi, f_lo = 587.0, 440.0
    cyc = np.floor(t / seg).astype(int) % 2
    f = np.where(cyc == 0, f_hi, f_lo).astype(np.float64)
    # glissando court entre les deux tons
    k = int(0.03 * RATE)
    f = np.convolve(np.pad(f, (k, k), mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="valid")
    f *= 1 + 0.004 * np.sin(2 * np.pi * 6 * t)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    y = np.zeros(n, np.float64)
    for h in range(1, 9):
        y += np.sin(ph * h) / (h ** 1.1)
    y = np.tanh(y * 1.8).astype(np.float32)
    y = B.fft_filter(y, lo=250, hi=5200)
    y += bandpass(y, 1250, 250) * 0.35
    B.save("pol_siren_loop", loopify(B.norm(y, 0.85), L, fade))
    # --- sirène « hi-lo » rapide (véhicule qui roule vite)
    L = int(2.0 * RATE)
    n = L + fade
    t = np.arange(n) / RATE
    f = 560 + 320 * np.sin(2 * np.pi * t / 2.0 - np.pi / 2)  # montée et descente périodique
    ph = 2 * np.pi * np.cumsum(f) / RATE
    y = np.zeros(n, np.float64)
    for h in range(1, 8):
        y += np.sin(ph * h) / (h ** 1.2)
    y = np.tanh(y * 1.6).astype(np.float32)
    y = B.fft_filter(y, lo=250, hi=5200)
    B.save("pol_siren_wail", loopify(B.norm(y, 0.8), L, fade))
    # --- moteurs (boucles)
    for name, base, rough, dur in (("engine_idle", 26.0, 0.9, 3.0), ("engine_car", 38.0, 0.6, 3.0)):
        L = int(dur * RATE)
        n = L + fade
        t = np.arange(n) / RATE
        ph = 2 * np.pi * base * t
        y = np.zeros(n, np.float32)
        for h, a in ((1, 1.0), (2, 0.8), (3, 0.5), (4, 0.4), (5, 0.25), (6, 0.2), (8, 0.12)):
            y += (np.sin(ph * h + h) * a * (1.0 + 0.25 * np.sin(2 * np.pi * 0.7 * t + h))).astype(np.float32)
        y *= (1.0 + 0.3 * np.sign(np.sin(ph)) ** 2 * 0.0)
        y += B.fft_filter(noise(n), lo=50, hi=350) * 0.5 * rough
        y = np.tanh(y * 0.9)
        y = B.fft_filter(y, lo=30, hi=1800)
        B.save(name + "_loop", loopify(B.norm(y, 0.8), L, fade))
    # --- portières
    def thunk(dur, f1, f2, noise_amt, sd):
        n = int(dur * RATE); t = np.arange(n) / RATE
        r = np.random.default_rng(sd)
        y = np.sin(2 * np.pi * f1 * t) * np.exp(-t * 22) * 0.9 + np.sin(2 * np.pi * f2 * t) * np.exp(-t * 35) * 0.5
        y += B.fft_filter(r.standard_normal(n).astype(np.float32), lo=300, hi=4000) * np.exp(-t * 55) * noise_amt
        y += metal_hit([1900, 2700, 3600], [60, 80, 100], dur, [0.12, 0.08, 0.05], 0.0, sd) * 0.6
        return B.norm(y.astype(np.float32), 0.85)
    B.save("door_close", thunk(0.55, 95, 210, 0.6, 1))
    B.save("door_open", thunk(0.35, 130, 330, 0.35, 2) * 0.6)
    n = int(1.1 * RATE); t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=120, hi=1400) * np.minimum(1, t / 0.1) * np.minimum(1, (1.1 - t) / 0.2) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t))
    a0 = int(0.95 * RATE)
    y[a0:a0 + 1000] += (0.4 * np.sin(2 * np.pi * 120 * t[:1000])).astype(np.float32)
    B.save("door_slide", B.norm(y, 0.7))
    # --- lacrymo : tir du lanceur, chuintement, rebond de la grenade
    n = int(1.4 * RATE); t = np.arange(n) / RATE
    y = np.sin(2 * np.pi * 62 * t * (1 - 0.3 * t)) * np.exp(-t * 7) * 1.0
    y += B.fft_filter(noise(n), lo=100, hi=1800) * np.exp(-t * 11) * 0.9
    y += B.fft_filter(noise(n), lo=1500, hi=8000) * np.exp(-t * 50) * 0.5
    y += B.fft_filter(noise(n), lo=400, hi=3000) * np.minimum(1, t / 0.15) * np.exp(-t * 2.4) * 0.25
    B.save("gas_launch", B.norm(B.reverb(y.astype(np.float32), 0.25, 0.9), 0.95))
    L = int(3.0 * RATE); n = L + fade; t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=900, hi=8500) * (0.75 + 0.25 * np.sin(2 * np.pi * 3.1 * t + 1)) + B.fft_filter(noise(n), lo=120, hi=700) * 0.45
    B.save("gas_hiss_loop", loopify(B.norm(y, 0.7), L, fade))
    B.save("gas_clink", B.norm(metal_hit([780, 1330, 2140, 2900], [14, 20, 28, 35], 0.6, [1, 0.6, 0.4, 0.25], 0.8, 3), 0.8))
    # --- LBD
    n = int(1.0 * RATE); t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=1200, hi=9000) * np.exp(-t * 200) * 1.2
    y += np.sin(2 * np.pi * 140 * t * (1 - 0.5 * t)) * np.exp(-t * 30) * 0.9
    y += B.fft_filter(noise(n), lo=200, hi=2000) * np.exp(-t * 14) * 0.4
    B.save("lbd_shot", B.norm(B.reverb(y.astype(np.float32), 0.3, 0.8), 0.95))
    n = int(0.3 * RATE); t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=60, hi=900) * np.exp(-t * 28) * 1.0 + np.sin(2 * np.pi * 85 * t) * np.exp(-t * 24)
    B.save("lbd_hit", B.norm(y.astype(np.float32), 0.85))
    # --- matraque
    n = int(0.3 * RATE); t = np.arange(n) / RATE
    y = bandpass(noise(n), 1200, 700) * np.sin(np.pi * np.minimum(1, t / 0.28)) ** 2
    B.save("baton_swing", B.norm(y, 0.6))
    for i in range(2):
        n = int(0.4 * RATE); t = np.arange(n) / RATE
        r = np.random.default_rng(10 + i)
        y = np.sin(2 * np.pi * (170 + 20 * i) * t) * np.exp(-t * 26) * 0.9 + B.fft_filter(r.standard_normal(n).astype(np.float32), lo=200, hi=3500) * np.exp(-t * 60)
        B.save(f"baton_hit_{i}", B.norm(y.astype(np.float32), 0.85))
    B.save("baton_hit_shield", B.norm(metal_hit([620, 1140, 1760], [38, 55, 70], 0.3, [1, 0.5, 0.3], 0.9, 5), 0.8))
    for i in range(3):
        B.save(f"shield_tap_{i}", B.norm(metal_hit([540 + 40 * i, 980, 1500], [60, 90, 120], 0.18, [1, 0.5, 0.2], 0.7, 20 + i), 0.7))
    # --- gazeuse
    n = int(1.8 * RATE); t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=2200, hi=10000) * np.minimum(1, t / 0.05) * np.minimum(1, (1.8 - t) / 0.2) * (0.8 + 0.2 * np.sin(2 * np.pi * 14 * t))
    B.save("pepper_spray", B.norm(y, 0.75))
    # --- menottes
    n = int(1.1 * RATE)
    y = np.zeros(n, np.float32)
    for k, tt in enumerate((0.0, 0.11, 0.2, 0.52)):
        c = metal_hit([2500, 3700, 5200], [160, 190, 220], 0.12 if k < 3 else 0.35, [1, 0.5, 0.3], 1.0, 30 + k)
        p = int(tt * RATE)
        y[p:p + len(c)] += c * (1.0 if k < 3 else 1.4)
    B.save("cuff_click", B.norm(y, 0.8))
    # --- toux
    for i, (f0, form) in enumerate(((95, (520, 1500)), (110, (480, 1380)), (85, (560, 1650)))):
        B.save(f"cough_m_{i}", cough(f0, form, 3 + i, 40 + i))
    for i, (f0, form) in enumerate(((190, (700, 1900)), (210, (740, 2100)))):
        B.save(f"cough_f_{i}", cough(f0, form, 3 + i, 60 + i))
    # --- chute / corps
    n = int(0.5 * RATE); t = np.arange(n) / RATE
    y = np.sin(2 * np.pi * 60 * t * (1 - 0.4 * t)) * np.exp(-t * 14) + B.fft_filter(noise(n), lo=60, hi=700) * np.exp(-t * 18) * 0.9
    B.save("body_fall", B.norm(y.astype(np.float32), 0.85))
    # --- pétards
    n = int(1.6 * RATE); t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=1800, hi=10000) * np.exp(-t * 320) * 1.3 + B.fft_filter(noise(n), lo=500, hi=4000) * np.exp(-t * 90) * 0.5
    B.save("petard_small", B.norm(B.reverb(y.astype(np.float32), 0.35, 0.5), 0.9))
    n = int(2.4 * RATE); t = np.arange(n) / RATE
    y = np.sin(2 * np.pi * 80 * t * (1 - 0.3 * t)) * np.exp(-t * 18) * 1.0
    y += B.fft_filter(noise(n), lo=800, hi=9000) * np.exp(-t * 130) * 1.1 + B.fft_filter(noise(n), lo=150, hi=2500) * np.exp(-t * 28) * 0.7
    B.save("petard_medium", B.norm(B.reverb(y.astype(np.float32), 0.4, 1.3), 0.97))
    L = int(1.2 * RATE); n = L + fade; t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=2500, hi=9500) * 0.5
    sp = np.zeros(n, np.float32)
    for kk in range(70):
        p = rng.integers(0, n - 200); sp[p:p + 80] += noise(80) * rng.uniform(0.3, 1.0) * np.exp(-np.arange(80) / 14)
    y += B.fft_filter(sp, lo=3000) * 1.2
    B.save("petard_fuse", loopify(B.norm(y, 0.55), L, fade))
    # --- barrières
    hits = [(0.0, 1.0), (0.13, 0.7), (0.27, 0.5), (0.43, 0.35), (0.62, 0.22)]
    n = int(1.6 * RATE)
    y = np.zeros(n, np.float32)
    for k, (tt, a) in enumerate(hits):
        c = metal_hit([420 + 25 * k, 690, 1020, 1530, 2250], [9, 12, 16, 22, 30], 1.0, [1, 0.7, 0.5, 0.3, 0.2], 0.9, 70 + k)
        p = int(tt * RATE)
        y[p:p + len(c)] += c[: n - p] * a
    B.save("barrier_fall", B.norm(B.reverb(y, 0.2, 0.6), 0.95))
    B.save("barrier_hit", B.norm(metal_hit([430, 700, 1050, 1600], [14, 18, 24, 32], 0.8, [1, 0.6, 0.4, 0.25], 0.8, 80), 0.85))
    B.save("barrier_up", B.norm(metal_hit([320, 560, 900], [26, 34, 44], 0.4, [1, 0.5, 0.3], 0.6, 81), 0.8))
    L = int(1.5 * RATE); n = L + fade; t = np.arange(n) / RATE
    y = bandpass(noise(n), 1400, 800) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t)) + B.fft_filter(noise(n), lo=100, hi=500) * 0.4
    B.save("barrier_drag_loop", loopify(B.norm(y, 0.6), L, fade))
    # --- cône, panneau, boîte à journaux, lampadaire, poubelle renversée
    for i in range(2):
        n = int(0.5 * RATE); t = np.arange(n) / RATE
        r = np.random.default_rng(90 + i)
        y = np.sin(2 * np.pi * (260 + 40 * i) * t) * np.exp(-t * 24) * 0.8 + B.fft_filter(r.standard_normal(n).astype(np.float32), lo=300, hi=3000) * np.exp(-t * 50) * 0.5
        B.save(f"cone_hit_{i}", B.norm(y.astype(np.float32), 0.8))
    n = int(1.0 * RATE); t = np.arange(n) / RATE
    f = 300 * (1 - 0.5 * t / 1.0)
    y = np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.25 * np.exp(-t * 3) + metal_hit([600, 900, 1400], [4, 6, 9], 1.0, [0.5, 0.4, 0.3], 0.2, 95)
    B.save("sign_bend", B.norm(B.fft_filter(y.astype(np.float32), lo=150, hi=5000), 0.75))
    B.save("sign_fall", B.norm(metal_hit([210, 480, 880, 1500], [10, 14, 20, 28], 1.0, [1, 0.6, 0.4, 0.3], 0.9, 96), 0.9))
    B.save("news_box_hit", B.norm(metal_hit([140, 290, 560, 1100], [18, 26, 34, 44], 0.7, [1, 0.7, 0.4, 0.2], 0.8, 97), 0.9))
    n = int(0.9 * RATE); t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=1000, hi=9000) * np.exp(-t * 60) * 0.8
    for kk in range(20):
        p = int(rng.uniform(0.02, 0.6) * RATE)
        c = metal_hit([2600 + 900 * rng.random(), 4100 + 800 * rng.random()], [90, 120], 0.15, [1, 0.5], 0.3, 100 + kk)
        y[p:p + len(c)] += c * rng.uniform(0.15, 0.4)
    y += B.fft_filter(noise(n), lo=300, hi=3000) * np.exp(-t * 20) * (rng.random(n) > 0.97) * 1.6
    B.save("lamp_pop", B.norm(y.astype(np.float32), 0.85))
    n = int(1.6 * RATE); t = np.arange(n) / RATE
    y = np.zeros(n, np.float32)
    for k, tt in enumerate((0.0, 0.18, 0.4, 0.7, 1.0)):
        c = np.sin(2 * np.pi * (110 + 15 * k) * np.arange(int(0.3 * RATE)) / RATE) * np.exp(-np.arange(int(0.3 * RATE)) / RATE * 16) + B.fft_filter(noise(int(0.3 * RATE)), lo=100, hi=1800) * np.exp(-np.arange(int(0.3 * RATE)) / RATE * 22) * 0.8
        p = int(tt * RATE)
        y[p:p + len(c)] += (c * (1.0 - 0.17 * k)).astype(np.float32)
    B.save("bin_tip", B.norm(y, 0.9))
    # --- voiture
    for i in range(3):
        n = int(0.7 * RATE); t = np.arange(n) / RATE
        r = np.random.default_rng(110 + i)
        y = np.sin(2 * np.pi * (72 + 12 * i) * t * (1 - 0.2 * t)) * np.exp(-t * 11) * 1.0 + B.fft_filter(r.standard_normal(n).astype(np.float32), lo=300, hi=2500) * np.exp(-t * 35) * 0.6
        y += metal_hit([310 + 30 * i, 540, 870], [16, 22, 30], 0.7, [0.5, 0.3, 0.2], 0.0, 120 + i) * 0.7
        B.save(f"car_dent_{i}", B.norm(y.astype(np.float32), 0.9))
    B.save("car_door_bong", B.norm(metal_hit([95, 190, 330, 610], [14, 18, 26, 34], 0.9, [1, 0.8, 0.5, 0.3], 0.5, 130), 0.9))
    n = int(1.2 * RATE); t = np.arange(n) / RATE
    y = np.zeros(n, np.float32)
    for kk in range(90):
        p = int(abs(rng.normal(0.12, 0.22)) * RATE)
        if p < n - 200:
            c = noise(150) * np.exp(-np.arange(150) / 25)
            y[p:p + 150] += c * rng.uniform(0.2, 1.0)
    y = B.fft_filter(y, lo=2500, hi=10000) * 1.5 + B.fft_filter(noise(n), lo=200, hi=2500) * np.exp(-t * 40) * 0.8
    B.save("windshield_crack", B.norm(y.astype(np.float32), 0.85))
    n = int(1.0 * RATE); t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=1500, hi=9000) * np.minimum(1, t / 0.02) * np.exp(-t * 4.5) * 1.0 + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 10) * 0.5
    B.save("tire_pop", B.norm(y.astype(np.float32), 0.9))
    n = int(3.4 * RATE); t = np.arange(n) / RATE
    y = np.sin(2 * np.pi * 45 * t * (1 - 0.15 * t)) * np.exp(-t * 3.2) * 1.2
    y += B.fft_filter(noise(n), lo=60, hi=1400) * np.exp(-t * 2.4) * 1.0 + B.fft_filter(noise(n), lo=1000, hi=7000) * np.exp(-t * 18) * 0.7
    B.save("car_explosion", B.norm(B.reverb(y.astype(np.float32), 0.3, 1.8), 0.97))
    L = int(6 * RATE); n = L + fade; t = np.arange(n) / RATE
    y = B.fft_filter(noise(n), lo=40, hi=380) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.31 * t) * np.sin(2 * np.pi * 0.77 * t)) * 0.9
    y += B.fft_filter(noise(n), lo=300, hi=2500) * 0.18 * (0.8 + 0.2 * np.sin(2 * np.pi * 5.3 * t))
    sp = np.zeros(n, np.float32)
    for kk in range(180):
        p = rng.integers(0, n - 1500)
        ln = rng.integers(40, 500)
        sp[p:p + ln] += noise(ln) * rng.uniform(0.3, 1.0) * np.exp(-np.arange(ln) / (ln / 4))
    y += B.fft_filter(sp, lo=700, hi=8000) * 0.7
    B.save("fire_big_loop", loopify(B.norm(y, 0.9), L, fade))
    # --- cornemuse… non : grésillement radio en boucle
    L = int(2.0 * RATE); n = L + fade
    y = B.fft_filter(noise(n), lo=800, hi=4200) * 0.5 * (rng.random(n) > 0.2)
    B.save("radio_static_loop", loopify(B.norm(y, 0.35), L, fade))
    # --- gifle / coup de poing / bousculade
    n = int(0.3 * RATE); t = np.arange(n) / RATE
    B.save("punch", B.norm((np.sin(2 * np.pi * 110 * t) * np.exp(-t * 28) + B.fft_filter(noise(n), lo=150, hi=2500) * np.exp(-t * 55)).astype(np.float32), 0.8))
    B.save("shove", B.norm((B.fft_filter(noise(n), lo=80, hi=900) * np.exp(-t * 20)).astype(np.float32), 0.6))
    # --- canette
    B.save("can_clink", B.norm(metal_hit([1900, 2750, 3900], [30, 45, 60], 0.35, [1, 0.6, 0.35], 0.7, 140), 0.65))
    B.save("can_empty", B.norm(metal_hit([1100, 1850, 2600], [24, 32, 45], 0.45, [1, 0.5, 0.3], 0.5, 141), 0.6))
    # --- bouteille / sac qui tombe
    n = int(0.35 * RATE); t = np.arange(n) / RATE
    B.save("bag_drop", B.norm((B.fft_filter(noise(n), lo=80, hi=1100) * np.exp(-t * 20) + np.sin(2 * np.pi * 90 * t) * np.exp(-t * 28) * 0.7).astype(np.float32), 0.7))


GROUPS = {"voices2": build_voices2, "police": build_police, "chants2": build_chants2, "sfx2": build_sfx2}

if __name__ == "__main__":
    which = sys.argv[1:] or list(GROUPS)
    path = os.path.join(B.OUT, "audio.json")
    data = json.load(open(path)) if os.path.exists(path) else {}
    for g in which:
        print("==", g, flush=True)
        # une catégorie déjà générée ne doit pas être dupliquée dans le manifeste
        if g == "voices2":
            man = data.setdefault("voices", {})
            for k in list(man.keys()):
                cat = k.split("_", 1)[1]
                if cat in LINES_CIV or cat in LINES_COP or cat == "pol_radio":
                    del man[k]
        GROUPS[g](data)
        old_env = data.setdefault("env", {})
        old_env.update(B.ENV)
        json.dump(data, open(path, "w"))
    print("ok", len(os.listdir(B.OUT)), "fichiers")

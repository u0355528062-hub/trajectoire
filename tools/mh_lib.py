"""Outils pour fabriquer un personnage depuis les données CC0 de MakeHuman :
maillage de base, cibles de morphologie, squelette et poids de skinning -> glTF."""
import json, struct, os
import numpy as np

MH = os.environ.get("MH_DATA", "/home/user/makehumancommunity/makehuman/makehuman/data/")


def load_obj(path):
    V, VT, faces, groups = [], [], [], []  # faces: (group, [(v, vt), ...])
    cur = None
    for line in open(path):
        if line.startswith("v "):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("vt "):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith("g ") or line.startswith("o "):
            cur = line.split()[1]
        elif line.startswith("f "):
            idx = []
            for tok in line.split()[1:]:
                p = tok.split("/")
                idx.append((int(p[0]) - 1, int(p[1]) - 1 if len(p) > 1 and p[1] else 0))
            faces.append((cur, idx))
    return np.array(V), np.array(VT), faces


def load_target(name):
    path = MH + "targets/" + name
    d = []
    for line in open(path):
        if line.startswith("#") or not line.strip():
            continue
        p = line.split()
        if len(p) == 4:
            d.append([float(x) for x in p])
    return np.array(d).reshape(-1, 4)


def apply_targets(V, spec):
    """spec : liste de (nom_cible, poids)."""
    out = V.copy()
    for name, w in spec:
        if w == 0:
            continue
        t = load_target(name)
        out[t[:, 0].astype(int)] += t[:, 1:4] * w
    return out


def load_skeleton():
    return json.load(open(MH + "rigs/default.mhskel"))


def load_weights():
    return json.load(open(MH + "rigs/default_weights.mhw"))["weights"]


def triangulate(face_idx):
    tris = []
    for i in range(1, len(face_idx) - 1):
        tris.append((face_idx[0], face_idx[i], face_idx[i + 1]))
    return tris


def vertex_normals(P, tris):
    n = np.zeros_like(P)
    a, b, c = P[tris[:, 0]], P[tris[:, 1]], P[tris[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    ln[ln == 0] = 1
    return n / ln


class Gltf:
    def __init__(self):
        self.nodes, self.meshes, self.accessors, self.views = [], [], [], []
        self.buf = bytearray()
        self.skins = []
        self.materials = []

    def _view(self, data: bytes, target=None):
        while len(self.buf) % 4:
            self.buf.append(0)
        v = {"buffer": 0, "byteOffset": len(self.buf), "byteLength": len(data)}
        if target:
            v["target"] = target
        self.buf += data
        self.views.append(v)
        return len(self.views) - 1

    def accessor(self, arr, ctype, atype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        vi = self._view(arr.tobytes(), target)
        a = {"bufferView": vi, "componentType": ctype, "count": int(arr.shape[0]), "type": atype}
        if minmax:
            a["min"] = arr.min(axis=0).tolist()
            a["max"] = arr.max(axis=0).tolist()
        self.accessors.append(a)
        return len(self.accessors) - 1

    def add_mesh(self, name, P, N, UV, J, W, tris, color=None, material=0):
        attrs = {
            "POSITION": self.accessor(P.astype("<f4"), 5126, "VEC3", 34962, True),
            "NORMAL": self.accessor(N.astype("<f4"), 5126, "VEC3", 34962),
            "TEXCOORD_0": self.accessor(UV.astype("<f4"), 5126, "VEC2", 34962),
            "JOINTS_0": self.accessor(J.astype("<u2"), 5123, "VEC4", 34962),
            "WEIGHTS_0": self.accessor(W.astype("<f4"), 5126, "VEC4", 34962),
        }
        if color is not None:
            attrs["COLOR_0"] = self.accessor(color.astype("<f4"), 5126, "VEC4", 34962)
        idx = self.accessor(tris.astype("<u4").reshape(-1), 5125, "SCALAR", 34963)
        self.meshes.append({"name": name, "primitives": [{"attributes": attrs, "indices": idx, "material": material}]})
        return len(self.meshes) - 1

    def write(self, path, root_children, scene_nodes):
        doc = {
            "asset": {"version": "2.0", "generator": "blocus build_character"},
            "scene": 0,
            "scenes": [{"nodes": scene_nodes}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "skins": self.skins,
            "accessors": self.accessors,
            "bufferViews": self.views,
            "buffers": [{"byteLength": len(self.buf)}],
            "materials": self.materials or [{"name": "mat", "pbrMetallicRoughness": {"metallicFactor": 0}}],
        }
        js = json.dumps(doc).encode()
        while len(js) % 4:
            js += b" "
        binb = bytes(self.buf)
        while len(binb) % 4:
            binb += b"\0"
        out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb))
        out += struct.pack("<II", len(js), 0x4E4F534A) + js
        out += struct.pack("<II", len(binb), 0x004E4942) + binb
        open(path, "wb").write(out)

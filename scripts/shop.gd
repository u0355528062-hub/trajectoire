class_name Shop
extends Node3D
## Boutique de rez-de-chaussée envahissable : grande vitrine résistante (GlassPane), intérieur meublé selon le
## commerce (banque, boulangerie, pharmacie, supérette, boutique de vêtements, café). Une fois la vitrine brisée,
## les manifestants (et le joueur) entrent et cassent tout : chaque meuble se renverse, la marchandise vole.
## Repère : centré sur l'ouverture, façade en z = 0, l'intérieur vers -Z.

const SIGN_NAMES := {"banque": "BANQUE", "boulangerie": "BOULANGERIE", "pharmacie": "PHARMACIE", "superette": "SUPÉRETTE",
	"boutique": "MODE", "cafe": "CAFÉ"}

var kind := "boutique"
var width := 4.0
var depth := 6.0
var height := 3.7
var crowd: Crowd
var building: Node3D
var sign_color := "shop_black"
var lit := true
var seed_v := 0
var frontage := {}                # devanture (posée par l'immeuble) : style, couleur, position de l'enseigne, store

var pane: GlassPane
var items: Array = []             # ShopItem
var _light: OmniLight3D
var _ceiling: MeshInstance3D
static var _font: Font


func _ready() -> void:
	add_to_group("shops")
	add_to_group("breakable")        # le joueur voit l'invite « F » devant la vitrine
	_build_shell()
	_build_window()
	_build_sign()
	_furnish()
	# l'intérieur est praticable pour la grille de navigation (pilleurs, fuite par une vitrine brisée)
	var a := to_global(Vector3(-width * 0.5, 0, 0.2))
	var b := to_global(Vector3(width * 0.5, 0, -depth + 0.3))
	NavGrid.add_open(Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(a.x - b.x), absf(a.z - b.z))))
	if frontage.has("story"):
		MapStory.dress_shop(self, str(frontage["story"]))


func is_open() -> bool:
	return pane == null or pane.is_broken


func intact_items() -> Array:
	var out: Array = []
	for it in items:
		if is_instance_valid(it) and not (it as ShopItem).smashed and not (it as ShopItem).outside:
			out.append(it)
	return out


## Point devant la vitrine, sur le trottoir (monde)
func front_point(side := 0.0) -> Vector3:
	return to_global(Vector3(side * width * 0.3, 0.0, 0.9))


## Point juste derrière la vitrine, dans la boutique (monde)
func inside_point(t := 0.5, side := 0.0) -> Vector3:
	return to_global(Vector3(side * (width * 0.5 - 0.6), 0.0, -0.9 - t * (depth - 2.0)))


# ------------------------------------------------------------------ construction
func _m(key: String) -> Material:
	return ParisBuilding.mat(key)


func _box(parent: Node3D, key_or_mat: Variant, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = key_or_mat if key_or_mat is Material else _m(key_or_mat)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static var _cols := {}
static func col_mat(c: Color, rough := 0.7, emit := 0.0) -> StandardMaterial3D:
	var key := str(c) + str(rough) + str(emit)
	if not _cols.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if emit > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emit
		_cols[key] = m
	return _cols[key]


func _build_shell() -> void:
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_texture = load("res://assets/paris/tiles_a.png")
	floor_m.uv1_triplanar = true
	floor_m.uv1_scale = Vector3(0.7, 0.7, 0.7)
	floor_m.roughness = 0.35
	floor_m.metallic_specular = 0.6
	# damier patiné, teinté selon le commerce (jamais blanc pur : l'intérieur reste lisible derrière la vitre)
	floor_m.albedo_color = {"banque": Color(0.62, 0.6, 0.58), "boulangerie": Color(0.72, 0.6, 0.48), "cafe": Color(0.6, 0.48, 0.38)}.get(kind, Color(0.68, 0.66, 0.63))
	var wallc: Color = {"banque": Color(0.5, 0.53, 0.58), "boulangerie": Color(0.74, 0.58, 0.38), "pharmacie": Color(0.62, 0.72, 0.68),
		"superette": Color(0.66, 0.64, 0.58), "boutique": Color(0.58, 0.5, 0.48), "cafe": Color(0.42, 0.26, 0.16)}.get(kind, Color(0.6, 0.6, 0.6))
	var wm := col_mat(wallc, 0.85)
	var d := depth
	# soubassement en bois sombre et moulure haute sur les trois murs
	var wood := col_mat(Color(0.22, 0.13, 0.08), 0.55)
	var trim := col_mat(wallc.lightened(0.25), 0.7)
	_box(self, wood, Vector3(width - 0.2, 1.0, 0.04), Vector3(0, 0.5, -d + 0.12))
	_box(self, trim, Vector3(width - 0.2, 0.12, 0.08), Vector3(0, height - 0.3, -d + 0.14))
	for sx in [-1.0, 1.0]:
		_box(self, wood, Vector3(0.04, 1.0, d - 0.7), Vector3(sx * (width * 0.5 - 0.12), 0.5, -0.6 - (d - 0.7) * 0.5))
		_box(self, trim, Vector3(0.08, 0.12, d - 0.7), Vector3(sx * (width * 0.5 - 0.14), height - 0.3, -0.6 - (d - 0.7) * 0.5))
	_box(self, floor_m, Vector3(width, 0.04, d), Vector3(0, 0.02, -d * 0.5))
	_box(self, wm, Vector3(width, height, 0.1), Vector3(0, height * 0.5, -d + 0.05))
	_box(self, wm, Vector3(0.1, height, d - 0.55), Vector3(-width * 0.5 + 0.05, height * 0.5, -0.55 - (d - 0.55) * 0.5))
	_box(self, wm, Vector3(0.1, height, d - 0.55), Vector3(width * 0.5 - 0.05, height * 0.5, -0.55 - (d - 0.55) * 0.5))
	_box(self, col_mat(Color(0.78, 0.76, 0.72), 0.8), Vector3(width, 0.06, d), Vector3(0, height, -d * 0.5))
	# plafonnier lumineux (et vraie lumière pour les boutiques proches)
	_ceiling = _box(self, col_mat(Color(1.0, 0.92, 0.78), 0.5, 0.45), Vector3(width * 0.6, 0.03, 0.4), Vector3(0, height - 0.05, -d * 0.5))
	if lit:
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.9, 0.75)
		_light.light_energy = 0.32
		_light.omni_range = maxf(width, d) * 0.95
		_light.shadow_enabled = false
		_light.position = Vector3(0, height - 0.4, -d * 0.5)
		add_child(_light)
	# obstacles pour les manifestants qui entrent : cloisons et fond
	if crowd:
		for w in [[Vector3(-width * 0.5, 0, -d * 0.5), Vector2(0.12, d * 0.5)], [Vector3(width * 0.5, 0, -d * 0.5), Vector2(0.12, d * 0.5)],
				[Vector3(0, 0, -d), Vector2(width * 0.5, 0.12)]]:
			var mk := Node3D.new()
			mk.position = w[0]
			add_child(mk)
			crowd.add_obstacle(mk, w[1], Vector2.ZERO, false, false)


func _build_window() -> void:
	pane = GlassPane.new()
	pane.size = Vector2(width - 0.08, height - 1.1)
	pane.kind = "shop"
	pane.break_at = 260.0          # vitrine feuilletée : il faut s'y reprendre à plusieurs fois
	pane.slowmo = false
	pane.thick = 0.02
	pane.max_shards = 70
	pane.shard_step = 2.2
	pane.glass_color = Color(0.55, 0.7, 0.75, 0.12)
	pane.position = Vector3(0, 0.42 + (height - 1.1) * 0.5, -0.2)
	add_child(pane)
	pane.broken_event.connect(_on_broken)


func _on_broken(_p: Vector3) -> void:
	if crowd:
		crowd.on_event("shop_open", {"shop": self, "pos": front_point()})


func _build_sign() -> void:
	if frontage.is_empty():
		frontage = {"style": "boiserie", "color": Color(0.06, 0.22, 0.16), "sign_y": height + 0.3, "sign_z": 0.25, "sign_w": width + 0.3, "awning": false}
	var fr := frontage.duplicate()
	fr["xf"] = Transform3D()
	Shop.make_sign(self, kind, seed_v, fr, Vector3.ZERO)


# ------------------------------------------------------------------ enseignes et devantures (aussi pour les boutiques décoratives)
const KINDS := ["banque", "boulangerie", "pharmacie", "superette", "boutique", "cafe", "tabac", "fleuriste", "librairie", "opticien", "primeur", "coiffeur"]
const NAMES := {
	"banque": ["Crédit Parisien", "Banque du Commerce", "Caisse Lutèce"],
	"boulangerie": ["Boulangerie Martin", "Au Pain Doré", "Maison Lefèvre", "La Fournée", "Aux Délices de Lutèce"],
	"pharmacie": ["Pharmacie du Boulevard", "Pharmacie Centrale", "Pharmacie de la Place"],
	"superette": ["Marché Express", "Épicerie du Coin", "Proxi Marché", "Supérette 7/7"],
	"boutique": ["Atelier Margaux", "Maison Clément", "Les Filles du Faubourg", "Mode & Co"],
	"cafe": ["Café de la Mairie", "Le Saint-Jean", "Le Bistrot des Amis", "Brasserie du Boulevard", "Le Petit Comptoir"],
	"tabac": ["Le Balto", "Tabac de la Mairie", "Tabac Presse du Boulevard"],
	"fleuriste": ["Fleurs de Lise", "L'Atelier Floral", "Au Jardin de Paris"],
	"librairie": ["Librairie Les Mots Passants", "Le Livre Ouvert", "Librairie du Faubourg"],
	"opticien": ["Optique Lumière", "Lunettes & Cie"],
	"primeur": ["Primeur Chez Karim", "Fruits & Légumes"],
	"coiffeur": ["Coiffure Élégance", "Salon Ciseaux d'Or"],
}
const SUBTITLES := {"boulangerie": "PAIN · VIENNOISERIE · PÂTISSERIE", "cafe": "BRASSERIE · VINS · CAFÉ", "tabac": "PRESSE · LOTO",
	"fleuriste": "FLEURS · PLANTES", "librairie": "LIVRES · PAPETERIE", "primeur": "FRUITS · LÉGUMES"}


static func pick_kind(rng: RandomNumberGenerator) -> String:
	return KINDS[rng.randi() % KINDS.size()]


static func frontage_style(k: String, r: RandomNumberGenerator) -> String:
	match k:
		"banque":
			return "pierre"
		"pharmacie", "opticien", "superette":
			return "moderne"
		"boulangerie", "cafe", "librairie", "fleuriste":
			return "boiserie"
		_:
			return "boiserie" if r.randf() < 0.5 else "moderne"


static func frontage_color(k: String, st: String, r: RandomNumberGenerator) -> Color:
	match k:
		"pharmacie":
			return Color(0.12, 0.62, 0.32)
		"tabac":
			return Color(0.55, 0.06, 0.05)
		"banque":
			return Color(0.08, 0.15, 0.35)
	if st == "moderne":
		return [Color(0.9, 0.9, 0.88), Color(0.12, 0.35, 0.6), Color(0.85, 0.3, 0.1), Color(0.15, 0.15, 0.17), Color(0.6, 0.12, 0.35)][r.randi() % 5]
	return [Color(0.06, 0.2, 0.15), Color(0.3, 0.05, 0.07), Color(0.06, 0.1, 0.22), Color(0.04, 0.04, 0.045), Color(0.82, 0.78, 0.66),
		Color(0.42, 0.56, 0.62), Color(0.55, 0.42, 0.12), Color(0.36, 0.38, 0.4)][r.randi() % 8]


static func shop_name(k: String, sv: int) -> String:
	var lst: Array = NAMES.get(k, ["Boutique"])
	return lst[absi(sv) % lst.size()]


static func _lab(text: String, font: Font, size: int, px: float, col: Color, shaded := true) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font = font
	lab.font_size = size
	lab.pixel_size = px
	lab.modulate = col
	lab.outline_size = 0
	lab.shaded = shaded
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	lab.visibility_range_end = 90.0
	return lab


## Enseigne d'une devanture : nom en lettres dorées (boiserie), lettres lumineuses (moderne) ou gravées (pierre),
## lambrequin du store, croix de pharmacie, carotte de tabac. `pos` : centre de l'ouverture au sol (repère de `parent`).
static func make_sign(parent: Node3D, k: String, sv: int, fr: Dictionary, pos: Vector3) -> void:
	var xf: Transform3D = fr.get("xf", Transform3D())
	var basis := xf.basis
	var st: String = fr.get("style", "boiserie")
	var name: String = fr.get("name", shop_name(k, sv))
	var w: float = fr.get("sign_w", 4.0)
	var y: float = fr.get("sign_y", 4.0)
	var z: float = fr.get("sign_z", 0.25)
	var col: Color = fr.get("color", Color(0.1, 0.2, 0.15))
	var text := name.to_upper() if st != "boiserie" else name
	var font: Font = ParisBuilding.serif() if st != "moderne" else ParisBuilding.sans()
	var gold := Color(0.95, 0.78, 0.38)
	var tc: Color = gold
	if st == "moderne":
		tc = Color(1, 1, 1) if col.get_luminance() < 0.6 else Color(0.08, 0.08, 0.1)
	elif st == "pierre":
		tc = Color(0.62, 0.5, 0.22)
	elif col.get_luminance() > 0.5:
		tc = Color(0.12, 0.1, 0.08)
	var px := minf(0.0062, (w - 0.3) / maxf(float(text.length()) * 52.0, 1.0))
	var lab := _lab(text, font, 96, px, tc, st != "moderne")
	lab.position = pos + basis * Vector3(0, y + (0.06 if SUBTITLES.has(k) else 0.0), z)
	lab.basis = basis
	parent.add_child(lab)
	if SUBTITLES.has(k) and st == "boiserie":
		var sub := _lab(SUBTITLES[k], ParisBuilding.sans(), 48, minf(0.0032, (w - 0.6) / maxf(float(String(SUBTITLES[k]).length()) * 26.0, 1.0)), tc.darkened(0.1))
		sub.position = pos + basis * Vector3(0, y - 0.17, z)
		sub.basis = basis
		parent.add_child(sub)
	if fr.get("awning", false):
		var al := _lab(name.to_upper(), ParisBuilding.sans(), 64, minf(0.004, (w - 0.2) / maxf(float(name.length()) * 36.0, 1.0)), Color(0.96, 0.95, 0.9))
		al.position = pos + basis * Vector3(0, fr.get("awning_y", 3.0), fr.get("awning_z", 1.6))
		al.basis = basis
		parent.add_child(al)
	var r := RandomNumberGenerator.new()
	r.seed = sv
	var side := 1.0 if r.randf() < 0.5 else -1.0
	match k:
		"pharmacie":
			# croix verte lumineuse en drapeau
			var cr := Node3D.new()
			cr.position = pos + basis * Vector3(side * (w * 0.5 + 0.2), y + 0.6, 0.55)
			cr.basis = basis * Basis(Vector3.UP, PI * 0.5)
			parent.add_child(cr)
			var gm := col_mat(Color(0.1, 1.0, 0.3), 0.4, 3.0)
			for sz in [Vector3(0.6, 0.2, 0.1), Vector3(0.2, 0.6, 0.1)]:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = sz
				mi.mesh = bm
				mi.material_override = gm
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				cr.add_child(mi)
		"tabac":
			# la « carotte » rouge des bureaux de tabac
			var ca := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.36, 0.5, 0.14)
			ca.mesh = pm
			ca.material_override = col_mat(Color(0.85, 0.08, 0.06), 0.4, 1.2)
			ca.position = pos + basis * Vector3(side * (w * 0.5 + 0.2), y + 0.75, 0.5)
			ca.basis = basis * Basis(Vector3.UP, PI * 0.5)
			var ca2 := MeshInstance3D.new()
			ca2.mesh = pm
			ca2.material_override = ca.material_override
			ca2.rotation = Vector3(0, 0, PI)
			ca2.position = Vector3(0, -0.5, 0)
			ca.add_child(ca2)
			parent.add_child(ca)
			var tl := _lab("TABAC", ParisBuilding.sans(), 48, 0.0028, Color(1, 0.95, 0.85), false)
			tl.position = Vector3(0, -0.25, 0.075)
			ca.add_child(tl)


# ------------------------------------------------------------------ mobilier selon le commerce
func _item(pos: Vector3, size: Vector3, colr: Color, goods: Array, heavy := false, outside := false, shape := "") -> ShopItem:
	var it := ShopItem.new()
	it.outside = outside
	it.shape = shape
	it.position = pos
	it.size = size
	it.color = colr
	it.goods = goods
	it.heavy = heavy
	it.shop = self
	add_child(it)
	items.append(it)
	return it


func _furnish() -> void:
	var d := depth
	var hw := width * 0.5
	var bright := [Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.1), Color(0.15, 0.45, 0.85), Color(0.2, 0.65, 0.3), Color(0.9, 0.9, 0.88), Color(0.6, 0.25, 0.65)]
	match kind:
		"banque":
			_item(Vector3(0, 0, -d + 1.4), Vector3(width - 1.0, 1.1, 0.7), Color(0.75, 0.76, 0.8), [Color(0.95, 0.95, 0.9)])       # guichet
			_item(Vector3(-hw + 0.5, 0, -1.6), Vector3(0.7, 1.7, 0.5), Color(0.25, 0.27, 0.32), [Color(0.2, 0.85, 0.3)], true)      # distributeur
			_item(Vector3(hw - 0.6, 0, -2.4), Vector3(0.9, 0.75, 0.6), Color(0.35, 0.22, 0.12), [Color(0.95, 0.95, 0.9)])           # bureau
			_item(Vector3(hw - 0.5, 0, -1.2), Vector3(0.5, 0.9, 0.5), Color(0.1, 0.1, 0.12), [Color(0.1, 0.1, 0.12)])                # fauteuil
			_item(Vector3(-hw + 0.5, 0, -d + 2.6), Vector3(0.7, 1.6, 0.5), Color(0.25, 0.27, 0.32), [Color(0.2, 0.85, 0.3)], true)  # second distributeur
			_item(Vector3(0, 0, -2.0), Vector3(0.5, 1.2, 0.35), Color(0.12, 0.2, 0.45), [Color(0.95, 0.95, 0.9)])                    # présentoir à brochures
		"boulangerie":
			_item(Vector3(0, 0, -2.2), Vector3(width - 1.2, 1.05, 0.8), Color(0.92, 0.88, 0.8), [Color(0.78, 0.52, 0.22), Color(0.66, 0.4, 0.15)])
			_item(Vector3(0, 0, -d + 0.4), Vector3(width - 0.6, 2.2, 0.45), Color(0.45, 0.3, 0.16), [Color(0.82, 0.58, 0.26), Color(0.7, 0.45, 0.2)])
			_item(Vector3(hw - 0.45, 0, -1.2), Vector3(0.5, 1.0, 0.5), Color(0.3, 0.2, 0.12), [Color(0.95, 0.85, 0.2)])                # caisse
			_item(Vector3(-hw + 0.5, 0, -1.3), Vector3(0.6, 0.75, 0.6), Color(0.5, 0.35, 0.2), [Color(0.82, 0.58, 0.26)])            # étal
			_item(Vector3(-hw + 0.4, 0, -d + 1.5), Vector3(0.45, 0.9, 0.45), Color(0.85, 0.85, 0.82), [Color(0.95, 0.95, 0.95)])     # vitrine à gâteaux
		"pharmacie":
			_item(Vector3(0, 0, -2.4), Vector3(width - 1.4, 1.0, 0.7), Color(0.95, 0.96, 0.96), [Color(0.95, 0.95, 0.95), Color(0.2, 0.7, 0.4)])
			_item(Vector3(-hw + 0.35, 0, -d * 0.6), Vector3(0.45, 2.0, d * 0.5), Color(0.9, 0.92, 0.92), bright)
			_item(Vector3(hw - 0.35, 0, -d * 0.6), Vector3(0.45, 2.0, d * 0.5), Color(0.9, 0.92, 0.92), bright)
			_item(Vector3(0, 0, -d + 0.4), Vector3(width - 1.6, 2.1, 0.4), Color(0.88, 0.9, 0.9), bright)                               # rayonnage du fond
			_item(Vector3(-hw * 0.3, 0, -1.2), Vector3(0.5, 1.2, 0.5), Color(0.2, 0.6, 0.35), [Color(0.95, 0.95, 0.95), Color(0.85, 0.2, 0.15)])   # présentoir
			_item(Vector3(hw * 0.35, 0, -1.3), Vector3(0.4, 1.4, 0.4), Color(0.92, 0.92, 0.9), bright)                                   # tourniquet
		"superette":
			for i in 2:
				_item(Vector3(-hw * 0.4 + float(i) * hw * 0.8, 0, -d * 0.55), Vector3(0.6, 1.6, d * 0.5), Color(0.75, 0.75, 0.78), bright)
			_item(Vector3(hw - 0.5, 0, -1.5), Vector3(0.8, 1.0, 0.6), Color(0.3, 0.3, 0.32), [Color(0.95, 0.85, 0.2)])               # caisse
			_item(Vector3(0, 0, -d + 0.45), Vector3(width - 0.6, 2.0, 0.6), Color(0.85, 0.9, 0.95), [Color(0.9, 0.9, 1.0), Color(0.3, 0.5, 0.9)], true)   # frigo
			_item(Vector3(-hw + 0.45, 0, -1.2), Vector3(0.6, 0.9, 0.6), Color(0.55, 0.4, 0.25), [Color(0.9, 0.5, 0.1), Color(0.3, 0.7, 0.2)])     # cagettes
			_item(Vector3(0, 0, -1.0), Vector3(0.7, 1.1, 0.4), Color(0.8, 0.15, 0.1), [Color(0.95, 0.85, 0.2), Color(0.2, 0.3, 0.8)])            # présentoir promo
		"boutique":
			for i in 2:
				_item(Vector3(-hw * 0.45 + float(i) * hw * 0.9, 0, -d * 0.45), Vector3(1.2, 1.5, 0.4), Color(0.75, 0.72, 0.7), bright)  # portants
			_item(Vector3(0, 0, -d + 0.5), Vector3(width - 0.8, 2.1, 0.5), Color(0.92, 0.9, 0.86), bright)
			_item(Vector3(hw - 0.6, 0, -1.4), Vector3(0.4, 1.75, 0.35), Color(0.95, 0.94, 0.92), [Color(0.95, 0.95, 0.95)])          # mannequin
			_item(Vector3(-hw + 0.6, 0, -1.3), Vector3(0.4, 1.75, 0.35), Color(0.95, 0.94, 0.92), [Color(0.2, 0.2, 0.25)])            # mannequin
			_item(Vector3(0, 0, -1.6), Vector3(0.9, 0.85, 0.6), Color(0.3, 0.22, 0.16), bright)                                      # table de pliage
		"tabac", "librairie":
			_item(Vector3(0, 0, -d + 0.45), Vector3(width - 0.6, 2.1, 0.4), Color(0.35, 0.24, 0.15), bright)                          # rayonnages
			_item(Vector3(hw - 0.55, 0, -1.6), Vector3(0.7, 1.05, 0.6), Color(0.3, 0.2, 0.12), [Color(0.9, 0.85, 0.2)])             # comptoir
			_item(Vector3(-hw + 0.45, 0, -1.4), Vector3(0.55, 1.5, 0.45), Color(0.8, 0.8, 0.78), bright)                            # présentoir à journaux
			_item(Vector3(0, 0, -2.6), Vector3(1.1, 0.9, 0.7), Color(0.4, 0.28, 0.18), bright)                                      # table de livres
		"fleuriste", "primeur":
			_item(Vector3(0, 0, -d + 0.45), Vector3(width - 0.6, 1.5, 0.5), Color(0.45, 0.32, 0.2), [Color(0.85, 0.15, 0.2), Color(0.95, 0.75, 0.1), Color(0.3, 0.6, 0.2)])
			_item(Vector3(hw - 0.55, 0, -1.6), Vector3(0.7, 1.0, 0.6), Color(0.3, 0.3, 0.32), [Color(0.95, 0.85, 0.2)])              # caisse
			# étals sur le trottoir : cagettes, seaux de fleurs
			for i in 3:
				var ox := -hw + 0.6 + float(i) * (width - 1.2) / 2.0
				_item(Vector3(ox, 0, 1.05), Vector3(0.75, 0.8, 0.55), Color(0.62, 0.48, 0.3),
					[Color(0.9, 0.2, 0.15), Color(0.95, 0.7, 0.1), Color(0.35, 0.65, 0.2)] if kind == "primeur" else [Color(0.95, 0.4, 0.6), Color(0.96, 0.95, 0.92), Color(0.85, 0.1, 0.15)], false, true, "crate")
		"opticien", "coiffeur":
			_item(Vector3(-hw + 0.45, 0, -d * 0.55), Vector3(0.45, 2.0, d * 0.5), Color(0.92, 0.92, 0.9), [Color(0.1, 0.1, 0.12), Color(0.6, 0.4, 0.2)])
			_item(Vector3(hw - 0.45, 0, -d * 0.55), Vector3(0.45, 2.0, d * 0.5), Color(0.92, 0.92, 0.9), [Color(0.1, 0.1, 0.12), Color(0.8, 0.8, 0.85)])
			_item(Vector3(0, 0, -2.0), Vector3(0.9, 0.9, 0.55), Color(0.2, 0.2, 0.22), [Color(0.95, 0.95, 0.95)])
			_item(Vector3(0, 0, -d + 0.6), Vector3(width - 1.2, 1.1, 0.6), Color(0.85, 0.85, 0.82), [Color(0.2, 0.2, 0.2)])
		_:
			_item(Vector3(0, 0, -d + 0.6), Vector3(width - 0.8, 1.1, 0.7), Color(0.4, 0.26, 0.14), [Color(0.95, 0.95, 0.95), Color(0.5, 0.3, 0.1)])  # comptoir
			for i in 2:
				_item(Vector3(-hw * 0.45 + float(i) * hw * 0.9, 0, -2.0), Vector3(0.7, 0.75, 0.7), Color(0.3, 0.2, 0.12), [Color(0.9, 0.9, 0.9)])   # tables
				_item(Vector3(-hw * 0.45 + float(i) * hw * 0.9 + 0.55, 0, -2.0), Vector3(0.4, 0.9, 0.4), Color(0.18, 0.12, 0.08), [])            # chaises
			_item(Vector3(-hw + 0.4, 0, -d + 1.6), Vector3(0.45, 1.9, 0.45), Color(0.25, 0.15, 0.1), [Color(0.3, 0.6, 0.25), Color(0.6, 0.15, 0.15)])  # étagère à bouteilles
			if kind == "cafe" and not frontage.has("story"):
				# terrasse : guéridons et chaises cannées sur le trottoir
				for i in 2:
					var ox := -hw * 0.5 + float(i) * hw
					_item(Vector3(ox, 0, 1.3), Vector3(0.6, 0.74, 0.6), Color(0.75, 0.72, 0.65), [], false, true, "table")
					var ch1 := _item(Vector3(ox + 0.55, 0, 1.3), Vector3(0.42, 0.88, 0.42), Color(0.55, 0.4, 0.25), [], false, true, "chair")
					ch1.rotation.y = -PI * 0.5 + randf_range(-0.3, 0.3)
					var ch2 := _item(Vector3(ox - 0.55, 0, 1.3), Vector3(0.42, 0.88, 0.42), Color(0.55, 0.4, 0.25), [], false, true, "chair")
					ch2.rotation.y = PI * 0.5 + randf_range(-0.3, 0.3)


# ------------------------------------------------------------------ interactions
## Coup de pied dans la vitrine (les meubles, eux, sont dans le groupe « kickable »)
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	return pane != null and not pane.is_broken and pane.kick(point, dir, power)


## Encore quelque chose à casser ?
func has_loot() -> bool:
	return is_open() and not intact_items().is_empty()


## Contient ce point (intérieur de la boutique, monde) ?
func holds(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < width * 0.5 and l.z < 0.15 and l.z > -depth


## Un meuble vient d'être cassé : la lumière vacille, la foule s'emballe
func on_item_smashed(it: ShopItem) -> void:
	if _light and intact_items().size() <= items.size() / 2:
		var tw := create_tween()
		tw.tween_property(_light, "light_energy", 0.25, 0.4)
	if crowd:
		crowd.on_event("shop_smash", {"pos": it.global_position, "shop": self})

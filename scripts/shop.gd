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


func is_open() -> bool:
	return pane == null or pane.is_broken


func intact_items() -> Array:
	var out: Array = []
	for it in items:
		if is_instance_valid(it) and not (it as ShopItem).smashed:
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
	_ceiling = _box(self, col_mat(Color(1.0, 0.92, 0.78), 0.5, 1.2), Vector3(width * 0.6, 0.03, 0.4), Vector3(0, height - 0.05, -d * 0.5))
	if lit:
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.9, 0.75)
		_light.light_energy = 0.9
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
	if _font == null:
		_font = load("res://assets/fonts/PermanentMarker-Regular.ttf")
	var lab := Label3D.new()
	lab.text = SIGN_NAMES.get(kind, "BOUTIQUE")
	lab.font_size = 72
	lab.pixel_size = minf(0.0055, (width + 0.2) / maxf(float(lab.text.length()) * 46.0, 1.0))
	lab.modulate = Color(0.95, 0.8, 0.42)
	lab.outline_size = 0
	lab.shaded = true
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	lab.position = Vector3(0, height + 0.5, 0.135)
	add_child(lab)
	if kind == "pharmacie":
		# croix verte lumineuse en drapeau
		var cr := Node3D.new()
		cr.position = Vector3(width * 0.5 + 0.4, height + 0.9, 0.5)
		add_child(cr)
		var gm := col_mat(Color(0.1, 1.0, 0.3), 0.4, 3.0)
		_box(cr, gm, Vector3(0.5, 0.16, 0.08), Vector3.ZERO)
		_box(cr, gm, Vector3(0.16, 0.5, 0.08), Vector3.ZERO)


# ------------------------------------------------------------------ mobilier selon le commerce
func _item(pos: Vector3, size: Vector3, colr: Color, goods: Array, heavy := false) -> ShopItem:
	var it := ShopItem.new()
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
		_:
			_item(Vector3(0, 0, -d + 0.6), Vector3(width - 0.8, 1.1, 0.7), Color(0.4, 0.26, 0.14), [Color(0.95, 0.95, 0.95), Color(0.5, 0.3, 0.1)])  # comptoir
			for i in 2:
				_item(Vector3(-hw * 0.45 + float(i) * hw * 0.9, 0, -2.0), Vector3(0.7, 0.75, 0.7), Color(0.3, 0.2, 0.12), [Color(0.9, 0.9, 0.9)])   # tables
				_item(Vector3(-hw * 0.45 + float(i) * hw * 0.9 + 0.55, 0, -2.0), Vector3(0.4, 0.9, 0.4), Color(0.18, 0.12, 0.08), [])            # chaises
			_item(Vector3(-hw + 0.4, 0, -d + 1.6), Vector3(0.45, 1.9, 0.45), Color(0.25, 0.15, 0.1), [Color(0.3, 0.6, 0.25), Color(0.6, 0.15, 0.15)])  # étagère à bouteilles


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

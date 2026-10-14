class_name CrowdTheme
extends RefCounted
## Habillage de la foule selon le thème du chapitre (réglage « crowd.theme ») : « origine » garde les pancartes
## et la banderole d'origine ; « prix » les remplace par des textes sur la vie chère, écrits au marqueur sur du
## carton. Tout est fictif (loi, chiffres et slogans du monde de la campagne, docs/CAMPAGNE.md § 2).

const PRIX_SIGNS := [
	"GAZOLE\n2,79 €\nSALAIRES GELÉS",
	"LA BAGUETTE\nÀ 1,65 €\nÇA SUFFIT",
	"+38 %\nL'ÉLECTRICITÉ\nON SE CHAUFFE\nCOMMENT ?",
	"RETRAIT DE LA\nLOI DE\nSTABILITÉ",
	"LOYER, COURSES,\nFACTURES :\nON N'Y ARRIVE\nPLUS",
	"LA TVA\nC'EST NOUS\nQUI LA PAYONS",
	"RENDEZ-NOUS\nLE BOUCLIER\nTARIFAIRE",
	"LE 12 DU MOIS\nC'EST DÉJÀ\nLA FIN DU MOIS",
	"VIE CHÈRE\nVIE DURE",
	"ON VEUT VIVRE\nPAS SURVIVRE",
	"MON FRIGO\nEST EN GRÈVE",
	"PAS DE\n« PÉDAGOGIE »\nDES SALAIRES",
]
const PRIX_BANNER := "CONTRE LA VIE CHÈRE\nRETRAIT DE LA LOI DE STABILITÉ"
const BOARDS := [Color(0.71, 0.56, 0.38), Color(0.9, 0.89, 0.85), Color(0.93, 0.83, 0.32), Color(0.66, 0.52, 0.35)]
const INKS := [Color(0.06, 0.06, 0.07), Color(0.62, 0.06, 0.07), Color(0.08, 0.14, 0.42)]
const SIGN_W := 0.56                 # zone écrite de la pancarte (m)
const SIGN_H := 0.41

static var _font: Font
static var _board_mats := {}


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/PermanentMarker-Regular.ttf")
	return _font


## Remplace le visuel imprimé d'une pancarte (Props.sign_board) par un texte manuscrit sur carton.
## `i` choisit le texte, le carton et l'encre (même i -> même pancarte).
static func dress_sign(sign_root: Node3D, i: int) -> void:
	var board := sign_root.get_child(1) as Node3D if sign_root.get_child_count() > 1 else null
	if board == null or board.get_child_count() == 0:
		return
	var front := board.get_child(0) as MeshInstance3D
	if front == null:
		return
	var bi := i % BOARDS.size()
	if not _board_mats.has(bi):
		var m := StandardMaterial3D.new()
		m.albedo_color = BOARDS[bi]
		m.roughness = 0.95
		_board_mats[bi] = m
	front.material_override = _board_mats[bi]
	var text: String = PRIX_SIGNS[posmod(i, PRIX_SIGNS.size())]
	var lab := Label3D.new()
	lab.name = "Slogan"
	lab.font = font()
	lab.font_size = 64
	lab.text = text
	lab.line_spacing = -14.0
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.modulate = INKS[(i / BOARDS.size()) % INKS.size()] if bi != 0 else INKS[i % 2]
	lab.outline_size = 0
	lab.shaded = true
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	# taille : le texte tient dans le carton (largeur de la plus longue ligne, nombre de lignes)
	var lines := text.split("\n")
	var longest := 1
	for l in lines:
		longest = maxi(longest, l.length())
	var px_w := SIGN_W / (float(longest) * 64.0 * 0.68)
	var px_h := SIGN_H / (float(lines.size()) * 64.0 * 1.05)
	lab.pixel_size = minf(minf(px_w, px_h), 0.0024)
	lab.position = Vector3(0.0, 0.0, 0.0065)
	board.add_child(lab)


## Texture de banderole au thème (rendue une fois dans un SubViewport, enfant de `host`), ou null
static func banner_texture(host: Node, theme: String) -> Texture2D:
	if theme != "prix":
		return null
	var vp := SubViewport.new()
	vp.name = "BannerPaint"
	vp.size = Vector2i(1024, 320)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.92, 0.88)
	bg.size = Vector2(1024, 320)
	vp.add_child(bg)
	var lab := Label.new()
	lab.text = PRIX_BANNER
	lab.add_theme_font_override("font", font())
	lab.add_theme_font_size_override("font_size", 74)
	lab.add_theme_color_override("font_color", Color(0.66, 0.06, 0.07))
	lab.add_theme_constant_override("line_spacing", -18)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size = Vector2(1024, 320)
	vp.add_child(lab)
	host.add_child(vp)
	return vp.get_texture()

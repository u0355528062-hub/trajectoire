class_name ToolWheel
extends Control
## Roue de sélection des outils (maintenir TAB), à la manière des jeux en
## monde ouvert : on oriente la souris vers un secteur puis on relâche.

signal tool_chosen(tool_id: String)

const OUTER := 330.0
const INNER := 128.0
const GAP_DEG := 1.6

var current_tool := "mains"
var highlight := -1
## Outils utiles pour le patient en cours (petite pastille), optionnel.
var suggested: Array = []

var _cursor := Vector2.ZERO
var _anim := 0.0
var _hover_anim: PackedFloat32Array = PackedFloat32Array()
var _open := false
var _title_font: Font
var _body_font: Font
var _caption_font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_hover_anim.resize(ExamDB.TOOLS.size())
	_title_font = UITheme.font("display")
	_body_font = UITheme.font("regular")
	_caption_font = UITheme.spaced("bold", 2)


func open(tool_id: String) -> void:
	current_tool = tool_id
	highlight = ExamDB.tool_index(tool_id)
	_cursor = Vector2.ZERO
	_open = true
	visible = true
	Sfx.ui("wheel_open")


func close() -> String:
	_open = false
	var chosen := ""
	if highlight >= 0 and highlight < ExamDB.TOOLS.size():
		chosen = ExamDB.TOOLS[highlight]["id"]
	return chosen


func is_open() -> bool:
	return _open


## Mouvement relatif de la souris (souris capturée pendant l'ouverture).
func feed_motion(rel: Vector2) -> void:
	_cursor += rel
	if _cursor.length() > 180.0:
		_cursor = _cursor.normalized() * 180.0
	if _cursor.length() > 36.0:
		var n := ExamDB.TOOLS.size()
		var ang := fposmod(atan2(_cursor.x, -_cursor.y), TAU)
		var idx := int(round(ang / (TAU / n))) % n
		if idx != highlight:
			highlight = idx
			Sfx.ui("wheel_tick")


## Sélection au clavier ou à la molette.
func step(dir: int) -> void:
	var n := ExamDB.TOOLS.size()
	highlight = posmod(highlight + dir, n)
	Sfx.ui("wheel_tick")


func _process(delta: float) -> void:
	var target := 1.0 if _open else 0.0
	_anim = move_toward(_anim, target, delta * 7.0)
	if not _open and _anim <= 0.0:
		visible = false
	for i in _hover_anim.size():
		var t := 1.0 if i == highlight else 0.0
		_hover_anim[i] = move_toward(_hover_anim[i], t, delta * 9.0)
	queue_redraw()


func _draw() -> void:
	if _anim <= 0.0:
		return
	var vs := size
	var c := vs * 0.5
	var ease := 1.0 - pow(1.0 - _anim, 3.0)
	var scale_k := lerpf(0.86, 1.0, ease)
	var a := ease

	# Voile radial
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.02, 0.04, 0.55 * a))
	for k in range(6):
		var r := OUTER * scale_k * (1.25 + k * 0.18)
		draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.035 * a))

	var n := ExamDB.TOOLS.size()
	var seg := TAU / n
	for i in n:
		var t: Dictionary = ExamDB.TOOLS[i]
		var h := _hover_anim[i]
		var mid := i * seg
		var a0 := mid - seg * 0.5 + deg_to_rad(GAP_DEG)
		var a1 := mid + seg * 0.5 - deg_to_rad(GAP_DEG)
		var r_out := OUTER * scale_k + h * 16.0
		var r_in := INNER * scale_k + h * 6.0
		var pts := PackedVector2Array()
		var steps := 18
		for s in range(steps + 1):
			var ang := lerpf(a0, a1, float(s) / steps)
			pts.append(c + Vector2(sin(ang), -cos(ang)) * r_out)
		for s in range(steps, -1, -1):
			var ang2 := lerpf(a0, a1, float(s) / steps)
			pts.append(c + Vector2(sin(ang2), -cos(ang2)) * r_in)
		var is_current: bool = t["id"] == current_tool
		var base := Color(0.055, 0.08, 0.12, 0.88 * a)
		var hl := Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.92 * a)
		var fill := base.lerp(hl, h * 0.85)
		draw_colored_polygon(pts, fill)
		# Liseré
		var edge := Color(1, 1, 1, 0.08 * a).lerp(Color(UITheme.ACCENT, 1.0 * a), h)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, edge, 1.5 if h < 0.5 else 2.0, true)
		# Arc extérieur lumineux (outil actuellement équipé)
		if is_current:
			var arc := PackedVector2Array()
			for s in range(steps + 1):
				var ang3 := lerpf(a0 + 0.02, a1 - 0.02, float(s) / steps)
				arc.append(c + Vector2(sin(ang3), -cos(ang3)) * (r_out + 7.0))
			draw_polyline(arc, Color(UITheme.ACCENT, 0.95 * a), 4.0, true)
		# Icône
		var r_icon := (r_in + r_out) * 0.5
		var ic := c + Vector2(sin(mid), -cos(mid)) * r_icon
		var glyph := Icons.glyph(t["icon"])
		var fsize := int(lerpf(38.0, 46.0, h))
		var gsz := Icons.font().get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var icol := Color(0.86, 0.92, 0.98, a).lerp(Color(0.02, 0.1, 0.1, a), h)
		draw_string(Icons.font(), ic + Vector2(-gsz.x * 0.5, gsz.y * 0.32), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, icol)
		if t["id"] in suggested:
			var dot := c + Vector2(sin(mid), -cos(mid)) * (r_in + 14.0)
			draw_circle(dot, 4.0, Color(UITheme.WARNING, a))

	# Centre
	var cr := INNER * scale_k - 10.0
	draw_circle(c, cr, Color(0.035, 0.05, 0.08, 0.94 * a))
	draw_arc(c, cr, 0, TAU, 96, Color(1, 1, 1, 0.08 * a), 1.5, true)
	if highlight >= 0:
		var tsel: Dictionary = ExamDB.TOOLS[highlight]
		var cap := "OUTIL ÉQUIPÉ" if tsel["id"] == current_tool else "ÉQUIPER"
		_center_text(c + Vector2(0, -44), cap, _caption_font, 12, Color(UITheme.ACCENT, a))
		var name: String = tsel["name"]
		var fs := 25 if name.length() < 16 else 20
		_center_text(c + Vector2(0, -8), name, _title_font, fs, Color(1, 1, 1, a), cr * 1.8)
		_center_text(c + Vector2(0, 26), tsel["desc"], _body_font, 14, Color(UITheme.MUTED, a), cr * 1.75)
	# Aide
	var hint := "Relâchez  TAB  pour équiper   ·   Molette : outil suivant"
	_center_text(Vector2(c.x, c.y + OUTER * scale_k + 54), hint, _body_font, 15, Color(1, 1, 1, 0.55 * a))


func _center_text(pos: Vector2, text: String, f: Font, fs: int, col: Color, max_w: float = -1.0) -> void:
	var lines: PackedStringArray = [text]
	if max_w > 0.0 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		# Coupe en deux lignes au mot le plus proche du milieu.
		var words := text.split(" ")
		var best := 1
		var best_d := 1e9
		for i in range(1, words.size()):
			var l1 := " ".join(words.slice(0, i))
			var d := absf(f.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x - max_w * 0.5)
			if d < best_d:
				best_d = d
				best = i
		lines = [" ".join(words.slice(0, best)), " ".join(words.slice(best))]
	var lh := fs * 1.2
	var y0 := pos.y - (lines.size() - 1) * lh * 0.5
	for i in lines.size():
		var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(pos.x - w * 0.5, y0 + i * lh + fs * 0.35), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

class_name ObjectiveList
extends PanelContainer
## Liste des objectifs du chapitre (charte UiStyle), en haut à droite sous la jauge d'opinion : panneau d'encre,
## intitulé rouge, une ligne par objectif (case, texte, compteur, minuteur, barre d'avancement). Les objectifs
## facultatifs sont plus discrets et rangés en fin de liste. Atteint : la case se remplit de rouge, la coche se
## trace, la ligne s'éclaire puis se replie. Raté : croix rouge, secousse, puis repli. Le panneau s'efface
## quand il n'y a plus rien à faire.

const WIDTH := 340.0
const TEXT_W := 278.0
const LINGER_DONE := 2.6          # secondes avant le repli d'un objectif atteint
const LINGER_FAIL := 3.4

var _box: VBoxContainer
var _count: Label
var _rows: Array = []
var _alpha := 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.ink_panel(14.0, 8))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -24.0 - WIDTH
	offset_right = -24.0
	offset_top = 150.0
	offset_bottom = 150.0
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var t := UiStyle.label("OBJECTIFS", 12, UiStyle.RED, "caps")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_count = UiStyle.label("", 12, UiStyle.PAPER_MUTE, "caps")
	head.add_child(_count)
	var line := ColorRect.new()
	line.color = UiStyle.LINE
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_box)


func add_objective(o: Objective) -> void:
	var r := Row.new(o)
	_box.add_child(r)
	if not o.optional:
		# les objectifs principaux passent devant les facultatifs
		var at := 0
		for c in _box.get_children():
			if c != r and c is Row and not (c as Row).o.optional:
				at = c.get_index() + 1
		_box.move_child(r, mini(at, _box.get_child_count() - 1))
	_rows.append(r)


func clear_all() -> void:
	for r in _rows:
		if is_instance_valid(r):
			(r as Row).dismiss()


func _process(delta: float) -> void:
	var live := 0
	var main_left := 0
	for r in _rows.duplicate():
		if not is_instance_valid(r):
			_rows.erase(r)
			continue
		if not (r as Row).leaving:
			live += 1
			if (r as Row).o.is_active() and not (r as Row).o.optional:
				main_left += 1
	_count.text = "" if main_left <= 0 else ("%d EN COURS" % main_left)
	_alpha = UiStyle.damp(_alpha, 1.0 if live > 0 else 0.0, 8.0, delta)
	modulate.a = _alpha
	visible = _alpha > 0.01
	if not visible:
		size.y = 0.0


## Une ligne : case animée, texte, compteur / minuteur, barre d'avancement. Se replie (clip) en partant.
class Row extends Control:
	var o: Objective
	var leaving := false
	var _inner: HBoxContainer
	var _check: Check
	var _text: Label
	var _info: Label
	var _bar: Bar
	var _t := 0.0
	var _end_t := -1.0
	var _fold := 0.0               # 0 : dépliée, 1 : repliée
	var _flash := 0.0
	var _last_progress := 0

	func _init(obj: Objective) -> void:
		o = obj

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner = HBoxContainer.new()
		_inner.add_theme_constant_override("separation", 12)
		_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_inner)
		_check = Check.new()
		_check.row = self
		_check.custom_minimum_size = Vector2(20, 20)
		_check.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_top", 2)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(_check)
		_inner.add_child(pad)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(v)
		_text = UiStyle.label(o.text, 15 if not o.optional else 14, UiStyle.PAPER if not o.optional else UiStyle.PAPER_DIM, "semibold" if not o.optional else "regular")
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = ObjectiveList.TEXT_W
		v.add_child(_text)
		_info = UiStyle.label("", 11, UiStyle.PAPER_MUTE, "caps")
		v.add_child(_info)
		_bar = Bar.new()
		_bar.row = self
		_bar.custom_minimum_size = Vector2(ObjectiveList.TEXT_W, 3)
		v.add_child(_bar)
		_last_progress = o.progress
		_update_info()

	func dismiss() -> void:
		if not leaving:
			leaving = true
			_end_t = maxf(_end_t, 0.0)

	func _process(delta: float) -> void:
		_t += delta
		if o.progress != _last_progress:
			_last_progress = o.progress
			_flash = 0.6
			UiStyle.pop(_info, 1.18, 0.3)
		if not o.is_active() and _end_t < 0.0:
			_end_t = 0.0
			_flash = 1.0 if o.state == "done" else 0.7
		if _end_t >= 0.0:
			_end_t += delta
			var linger := ObjectiveList.LINGER_DONE if o.state == "done" else ObjectiveList.LINGER_FAIL
			if o.state == "cleared" or leaving and o.is_active():
				linger = 0.0
			if _end_t > linger:
				leaving = true
				_fold = minf(_fold + delta * 3.2, 1.0)
				if _fold >= 1.0:
					queue_free()
					return
		_flash = maxf(_flash - delta * 1.6, 0.0)
		# texte qui s'éteint une fois terminé
		var col := UiStyle.PAPER if not o.optional else UiStyle.PAPER_DIM
		if o.state == "done":
			col = UiStyle.PAPER_MUTE
		elif o.state == "failed":
			col = Color(UiStyle.RED, 0.75)
		_text.add_theme_color_override("font_color", col)
		_update_info()
		# entrée : glisse depuis la droite ; échec : secousse
		var appear := UiStyle.smooth(_t / 0.45)
		var shake := 0.0
		if o.state == "failed" and _end_t >= 0.0 and _end_t < 0.5:
			shake = sin(_end_t * 48.0) * 6.0 * (1.0 - _end_t / 0.5)
		_inner.position = Vector2((1.0 - appear) * 36.0 + shake, 4.0)
		_inner.size = Vector2(ObjectiveList.WIDTH - 28.0, 0.0)
		modulate.a = appear * (1.0 - _fold)
		var h := _inner.get_combined_minimum_size().y + 8.0
		custom_minimum_size = Vector2(ObjectiveList.WIDTH - 28.0, h * (1.0 - UiStyle.smooth(_fold)))
		queue_redraw()

	func _update_info() -> void:
		var parts: Array = []
		if o.optional:
			parts.append("FACULTATIF")
		match o.state:
			"done":
				parts.append("FAIT")
			"failed":
				parts.append({"timer": "RATÉ · TEMPS ÉCOULÉ", "tension": "RATÉ · ÇA A DÉGÉNÉRÉ"}.get(o.fail_reason, "RATÉ"))
			_:
				if o.target > 1:
					parts.append("%d / %d" % [o.progress, o.target])
				if o.kind() == "hold":
					parts.append("TENIR %d S" % ceili(maxf(float(o.spec.get("sec", 30.0)) - o.hold_t, 0.0)))
				var left := o.time_left()
				if left >= 0.0:
					parts.append("%d:%02d" % [int(left) / 60, int(left) % 60])
		_info.text = "  ·  ".join(parts)
		_info.visible = _info.text != ""
		var left2 := o.time_left()
		var urgent := o.is_active() and left2 >= 0.0 and left2 < 10.0 and o.kind() != "survive"
		_info.add_theme_color_override("font_color", UiStyle.YELLOW if urgent else (UiStyle.RED if o.state == "failed" else UiStyle.PAPER_MUTE))
		_bar.visible = o.is_active() and (o.target > 1 or o.kind() in ["hold", "survive"])

	func _draw() -> void:
		if _flash > 0.0:
			var c := UiStyle.PAPER if o.state != "failed" else UiStyle.RED
			draw_rect(Rect2(Vector2(-4, 0), Vector2(size.x + 8, size.y)), Color(c, 0.13 * _flash))

	## Temps écoulé depuis la fin (-1 : en cours)
	func end_time() -> float:
		return _end_t


## Case de l'objectif : contour (pointillé si facultatif), coche tracée en rouge, croix si raté,
## pastille qui bat quand un minuteur presse.
class Check extends Control:
	var row: Row

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var o := row.o
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var k := clampf(row.end_time() / 0.35, 0.0, 1.0) if row.end_time() >= 0.0 else 0.0
		match o.state:
			"done":
				var fill := Rect2(r.get_center() - r.size * 0.5 * UiStyle.smooth(k * 1.6), r.size * UiStyle.smooth(k * 1.6))
				draw_style_box(UiStyle.box(UiStyle.RED, 4), fill)
				var pts := [Vector2(0.22, 0.52), Vector2(0.43, 0.72), Vector2(0.8, 0.3)]
				var path := PackedVector2Array()
				var seg := k * 2.0
				for i in 3:
					var a: Vector2 = r.position + r.size * (pts[i] as Vector2)
					if i == 0:
						path.append(a)
						continue
					var prev: Vector2 = r.position + r.size * (pts[i - 1] as Vector2)
					var f := clampf(seg - float(i - 1), 0.0, 1.0)
					if f <= 0.0:
						break
					path.append(prev.lerp(a, f))
				if path.size() >= 2:
					draw_polyline(path, UiStyle.PAPER, 2.6, true)
			"failed":
				draw_style_box(UiStyle.box(Color(UiStyle.RED, 0.16), 4, UiStyle.RED, 2), r)
				var a := r.position + r.size * 0.27
				var b := r.position + r.size * 0.73
				var f1 := clampf(k * 2.0, 0.0, 1.0)
				var f2 := clampf(k * 2.0 - 1.0, 0.0, 1.0)
				draw_line(a, a.lerp(b, f1), UiStyle.RED, 2.4, true)
				var c := Vector2(b.x, a.y)
				var d := Vector2(a.x, b.y)
				if f2 > 0.0:
					draw_line(c, c.lerp(d, f2), UiStyle.RED, 2.4, true)
			_:
				if o.optional:
					_dashed_rect(r, UiStyle.PAPER_MUTE)
				else:
					draw_style_box(UiStyle.box(Color(0, 0, 0, 0), 4, UiStyle.PAPER_DIM, 2), r)
				var left := o.time_left()
				if left >= 0.0 and o.kind() != "survive":
					var urgent := left < 10.0
					var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * (0.012 if urgent else 0.005))
					draw_circle(r.get_center(), 3.0 + beat * 1.2, Color(UiStyle.YELLOW if urgent else UiStyle.PAPER_DIM, 0.55 + beat * 0.45))

	func _dashed_rect(r: Rect2, c: Color) -> void:
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], c, 1.6, 3.0)


## Barre d'avancement fine : piste pâle, remplissage rouge (crème si facultatif) amorti.
class Bar extends Control:
	var row: Row
	var _v := 0.0

	func _process(delta: float) -> void:
		_v = UiStyle.damp(_v, row.o.ratio(), 10.0, delta)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, h)), UiStyle.PAPER_FAINT)
		var c := UiStyle.RED if not row.o.optional else UiStyle.PAPER_DIM
		if row.o.kind() == "survive":
			c = UiStyle.PAPER_DIM
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _v, h)), c)

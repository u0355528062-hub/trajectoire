extends CanvasLayer
## Interface en jeu (charte UiStyle) : barre d'outils à icônes dessinées avec munitions, état de la
## séquence de tir, invites contextuelles (souris, F, E), pile de messages, aide des touches repliable
## qui s'efface seule, puce de vue, réticule de visée, vignettage et flou de visée.

const TOOL_NAMES := ["MAINS LIBRES", "MORTIER D'ARTIFICE", "PIERRES", "BRIQUET + DÉCHETS", "FUMIGÈNE", "PÉTARDS · PETITS", "PÉTARDS · MOYENS",
	"TÉLÉPHONE", "TRACTS", "AFFICHES + COLLE", "MÉGAPHONE", "BOMBE DE PEINTURE"]
const TOOL_HINTS := ["Molette ou 1 à 6 : choisir un outil", "Vise au clic droit : la trajectoire s'affiche", "Vise au clic droit, puis lance",
	"Dépose le journal (ou un déchet ramassé avec E), puis allume", "Craque-le, brandis-le, lance-le",
	"Allume la mèche, vise, lance… vite !", "Plus fort, plus long : fait craquer les vitres",
	"Cadre au clic droit · clic : photo · maintenu : filmer", "E devant un passant : lui tendre un tract",
	"Morris, panneau libre : autorisé · mur : amende", "Un slogan : la foule reprend si elle est là",
	"Maintiens le clic face au mur : vandalisme"]
const HELP_SECS := 12.0          # aide dépliée au départ, puis repliée
const CHIP_SECS := 7.0           # puce « H Commandes » visible encore un moment, puis effacée
const MAX_TOASTS := 3

var _slots: Array[ToolSlot] = []
var _slot_row: HBoxContainer
var _items: Array = [1, 2, 3, 4, 5, 6]     # outils autorisés (numéros d'objet), dans l'ordre des touches
var _help_tools: HBoxContainer
var _item := 1
var _hint: Label
var _shells: ShellRow
var _count: Label
var _cmax: Label
var _name: Label
var _status: Label
var _bar: ProgressBar
var _toasts: VBoxContainer
var _prompts: HBoxContainer
var _prompt: PanelContainer
var _prompt_row: HBoxContainer
var _kick_prompt: PanelContainer
var _kick_prompt_on := false
var _e_prompt: PanelContainer
var _e_label: Label
var _view_chip: PanelContainer
var _view_label: Label
var _view_tween: Tween
var _help: PanelContainer
var _help_body: Control
var _help_title: Label
var _help_state := 2             # 2 dépliée, 1 puce seule, 0 effacée
var _help_t := 0.0
var _help_tween: Tween
var _post: ColorRect
var _reticle: Reticle
var _crosshair: Control
var _aim_tween: Tween
var _ammo := 6
var _max := 6
var _selected := true
var _aim_on := false
var _player: Player
var _last_cp := ""
var _flares := 5
var _flares_max := 5
var _pet := [0, 12, 6]
var _pet_max := [0, 12, 6]


# =================================================================== dessins
## Case d'outil : icône vectorielle, numéro de touche, pastille de munitions.
## Sélectionnée : papier crème, ombre rouge décalée, légère élévation et rebond.
class ToolSlot extends Control:
	var index := 1           # touche (1..9)
	var item := 1            # numéro d'objet du joueur
	var icon: Texture2D
	var selected := false
	var count_text := ""
	var empty := false
	var sel_k := 0.0
	var bump := 0.0
	var _hl := 0.0

	func _init(key: int, it: int) -> void:
		index = key
		item = it
		icon = UiIcons.tex(UiIcons.tool_icon(it), 112)
		custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	const SLOT_SIZE := 76.0

	func _process(delta: float) -> void:
		var want := 1.0 if selected else 0.0
		var changed := false
		if absf(sel_k - want) > 0.001:
			sel_k = UiStyle.damp(sel_k, want, 14.0, delta)
			if absf(sel_k - want) < 0.002:
				sel_k = want
			changed = true
		if bump > 0.0:
			bump = maxf(bump - delta * 2.2, 0.0)
			changed = true
		if changed:
			queue_redraw()

	func _draw() -> void:
		var e := UiStyle.smooth(sel_k)
		var lift := -6.0 * e
		var r := Rect2(Vector2(0, lift), size)
		# fond : encre légère -> papier crème avec ombre rouge décalée
		if e > 0.01:
			var sh := UiStyle.box(Color(UiStyle.RED, e), 5)
			draw_style_box(sh, Rect2(r.position + Vector2(4, 4) * e, r.size))
		var bg := Color(UiStyle.PAPER, 0.045).lerp(UiStyle.PAPER, e)
		draw_style_box(UiStyle.box(bg, 5, Color(UiStyle.PAPER, 0.12 * (1.0 - e)), 1), r)
		# icône (rebond à la sélection)
		var k := 1.0 + 0.16 * sin(bump * PI) * bump
		var isz := 50.0 * k
		var c := r.get_center() + Vector2(0, -1)
		var mod := Color(1, 1, 1, 1).lerp(Color(1, 1, 1, 1), e)
		if e < 0.99:
			mod = Color(0.82, 0.8, 0.76, 0.62).lerp(Color.WHITE, e)
		if empty:
			mod = Color(mod.r, mod.g, mod.b, mod.a * 0.45)
		if icon:
			var aspect := float(icon.get_width()) / float(maxi(icon.get_height(), 1))
			draw_texture_rect(icon, Rect2(c - Vector2(isz * aspect, isz) * 0.5, Vector2(isz * aspect, isz)), false, mod)
		# numéro de touche
		var f := UiStyle.font("bold")
		draw_string(f, r.position + Vector2(7, 17), str(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.PAPER_MUTE.lerp(UiStyle.INK, e))
		# munitions
		if count_text != "":
			var fs := 13
			var tw := f.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pill := Rect2(r.end - Vector2(tw + 12, 19) - Vector2(3, 3), Vector2(tw + 12, 18))
			var pc := UiStyle.RED if empty else UiStyle.INK.lerp(UiStyle.INK, e)
			draw_style_box(UiStyle.box(Color(pc, 0.92 if not empty else 1.0), 3), pill)
			draw_string(f, pill.position + Vector2(6, 14), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.PAPER)


## Rangée d'obus du mortier : tubes rouges à bague crème, vides en pointillé
class ShellRow extends Control:
	var count := 6
	var maximum := 6
	var pulse := 0.0

	func _draw() -> void:
		var gap := 15.0
		var total := (maximum - 1) * gap
		var x0 := size.x - total - 6.0
		for i in maximum:
			var c := Vector2(x0 + i * gap, size.y * 0.5)
			var full := i < count
			var body := Rect2(c.x - 5, c.y - 9, 10, 18)
			if full:
				draw_rect(body, UiStyle.RED, true)
				draw_rect(Rect2(body.position, Vector2(10, 4)), UiStyle.PAPER, true)
				draw_rect(Rect2(c.x - 3, c.y - 2, 2, 8), Color(1, 1, 1, 0.3), true)
			else:
				draw_rect(body, Color(UiStyle.PAPER, 0.07), true)
				draw_rect(body, Color(UiStyle.PAPER, 0.28), false, 1.0)
			if i == count and pulse > 0.0:
				draw_circle(c, 6.0 + 14.0 * (1.0 - pulse), Color(UiStyle.YELLOW, pulse * 0.6), false, 2.0, true)


## Réticule de visée : quatre traits crème cernés d'encre, point rouge
class Reticle extends Control:
	var spread := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r0 := 10.0 + 10.0 * spread
		var r1 := r0 + 9.0
		for a in 4:
			var d := Vector2.from_angle(a * PI * 0.5 + PI * 0.25)
			draw_line(c + d * r0, c + d * r1, Color(UiStyle.INK, 0.7), 4.5, true)
			draw_line(c + d * r0, c + d * r1, UiStyle.PAPER, 2.0, true)
		draw_arc(c, r1 + 7.0, -PI * 0.15, PI * 0.15, 12, Color(UiStyle.PAPER, 0.35), 1.5, true)
		draw_arc(c, r1 + 7.0, PI * 0.85, PI * 1.15, 12, Color(UiStyle.PAPER, 0.35), 1.5, true)
		draw_circle(c, 4.0, Color(UiStyle.INK, 0.75), true, -1.0, true)
		draw_circle(c, 2.4, UiStyle.RED, true, -1.0, true)


# =================================================================== liaison
func bind(player: Player) -> void:
	player.item_changed.connect(_on_item)
	player.ammo_changed.connect(_on_ammo)
	player.message.connect(_toast_show)
	player.view_changed.connect(_on_view)
	player.stage_changed.connect(_on_stage)
	player.aim_changed.connect(_on_aim)
	player.near_breakable_changed.connect(func(n): _kick_prompt_on = n)
	player.flares_changed.connect(func(c, m):
		_flares = c
		_flares_max = m
		_refresh())
	player.petards_changed.connect(func(a, am, b, bm):
		_pet = [0, a, b]
		_pet_max = [0, am, bm]
		_refresh())
	player.kit_changed.connect(_refresh)
	player.tools_changed.connect(_build_slots)
	_player = player
	_build_slots(player.tool_items)
	_on_item(player.current_item)


func _ready() -> void:
	layer = 10
	UiStyle.apply_theme(get_tree())
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_post()
	_build_vignette(root)

	_reticle = Reticle.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.size = Vector2(90, 90)
	_reticle.position = Vector2(-45, -45)
	_reticle.pivot_offset = Vector2(45, 45)
	_reticle.modulate.a = 0.0
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle)
	_crosshair = Control.new()

	_build_dock(root)
	_build_help(root)
	_build_view_chip(root)

	_refresh()
	if not Settings.d["show_help"]:
		_set_help(0, false)


## Flou périphérique + aberration chromatique + vignettage, actifs seulement quand on vise
func _build_post() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psh := Shader.new()
	psh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d * vec2(aspect, 1.0));
	float edge = smoothstep(0.34, 1.0, r) * amount;
	float lod = edge * 2.4;
	vec2 ca = d * 0.006 * edge;
	vec3 col;
	col.r = textureLod(screen_tex, uv + ca, lod).r;
	col.g = textureLod(screen_tex, uv, lod).g;
	col.b = textureLod(screen_tex, uv - ca, lod).b;
	col *= 1.0 - smoothstep(0.35, 1.0, r) * 0.45 * amount;
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.18 * amount);
	COLOR = vec4(col, 1.0);
}"""
	var pm := ShaderMaterial.new()
	pm.shader = psh
	_post.material = pm
	_post.visible = false
	post_layer.add_child(_post)


## Vignettage léger permanent (un seul quad, très peu coûteux)
func _build_vignette(root: Control) -> void:
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.38, 0.98, length(uv * vec2(1.0, 0.85)));
	float b = smoothstep(0.62, 1.0, UV.y) * 0.22;
	COLOR = vec4(0.02, 0.016, 0.02, v * 0.45 + b);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	root.add_child(vig)


# ------------------------------------------------------------------ bas de l'écran
func _build_dock(root: Control) -> void:
	var dock := VBoxContainer.new()
	dock.name = "Dock"
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_bottom = -26
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override("separation", 12)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock)

	# messages (les plus récents en bas)
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(_toasts)

	# invites contextuelles
	_prompts = HBoxContainer.new()
	_prompts.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompts.add_theme_constant_override("separation", 10)
	_prompts.custom_minimum_size.y = 40
	_prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(_prompts)
	_kick_prompt = _make_prompt(["F"], "Coup de pied", UiStyle.YELLOW)
	_prompts.add_child(_kick_prompt)
	var er := UiStyle.key_row(["E"], "Poubelle", 15, UiStyle.PAPER)
	_e_label = er.get_child(er.get_child_count() - 1)
	_e_prompt = _wrap_prompt(er)
	_prompts.add_child(_e_prompt)
	_prompt_row = UiStyle.key_row(["CLIC DROIT"], "Maintenir pour viser", 15, UiStyle.PAPER)
	_prompt = _wrap_prompt(_prompt_row)
	_prompts.add_child(_prompt)

	# barre d'outils
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(center)
	var panel := PanelContainer.new()
	var ps := UiStyle.ink_panel(0.0, 8)
	ps.content_margin_left = 12
	ps.content_margin_right = 18
	ps.content_margin_top = 14
	ps.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", ps)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 8)
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_slot_row)
	_build_slots(_items)
	var sep := ColorRect.new()
	sep.color = UiStyle.LINE
	sep.custom_minimum_size = Vector2(1, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_m := MarginContainer.new()
	sep_m.add_theme_constant_override("margin_left", 8)
	sep_m.add_theme_constant_override("margin_right", 10)
	sep_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep_m.add_child(sep)
	row.add_child(sep_m)

	# fiche de l'outil : nom, munitions, conseil ou étape de la séquence de tir
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.custom_minimum_size = Vector2(290, 0)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	_name = UiStyle.label("MORTIER D'ARTIFICE", 14, UiStyle.PAPER_DIM, "caps")
	info.add_child(_name)
	var cnt := HBoxContainer.new()
	cnt.add_theme_constant_override("separation", 4)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(cnt)
	_count = UiStyle.label("6", 40, UiStyle.PAPER, "black")
	_count.add_theme_constant_override("line_spacing", -8)
	cnt.add_child(_count)
	_cmax = UiStyle.label("/ 6", 18, UiStyle.PAPER_MUTE, "bold")
	_cmax.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cnt.add_child(_cmax)
	_shells = ShellRow.new()
	_shells.custom_minimum_size = Vector2(110, 40)
	_shells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cnt.add_child(_shells)
	_hint = UiStyle.label("", 14, UiStyle.PAPER_MUTE, "regular")
	_hint.custom_minimum_size = Vector2(290, 0)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_hint)
	_status = UiStyle.label("", 14, UiStyle.YELLOW, "bold")
	_status.visible = false
	info.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(290, 4)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.add_theme_stylebox_override("background", UiStyle.box(Color(UiStyle.PAPER, 0.12), 2))
	_bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.YELLOW, 2))
	_bar.modulate.a = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_bar)


## Barre d'outils construite d'après les outils autorisés : touche k -> k-ième outil
func _build_slots(items: Array) -> void:
	_items = items.duplicate()
	for sl in _slots:
		sl.queue_free()
	_slots.clear()
	if _slot_row == null:
		return
	for k in mini(_items.size(), 9):
		var sl := ToolSlot.new(k + 1, int(_items[k]))
		_slots.append(sl)
		_slot_row.add_child(sl)
	_slot_row.visible = not _slots.is_empty()
	_refresh_help_keys()
	if _name:
		_refresh()


## Touches d'outils de l'aide (« 1 – n »)
func _refresh_help_keys() -> void:
	if _help_tools == null:
		return
	for c in _help_tools.get_children():
		c.queue_free()
	var n := mini(_items.size(), 9)
	if n <= 0:
		_help_tools.add_child(UiStyle.label("—", 13, UiStyle.PAPER_MUTE, "bold"))
		return
	_help_tools.add_child(UiStyle.keycap("1", 13))
	if n > 1:
		_help_tools.add_child(UiStyle.label("–", 13, UiStyle.PAPER_MUTE, "bold"))
		_help_tools.add_child(UiStyle.keycap(str(n), 13))


func _wrap_prompt(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UiStyle.ink_panel(0.0, 6)
	st.content_margin_left = 6
	st.content_margin_right = 14
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(content)
	p.modulate.a = 0.0
	p.visible = false
	return p


func _make_prompt(keys: Array, text: String, key_bg := UiStyle.PAPER) -> PanelContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in keys:
		h.add_child(UiStyle.keycap(k, 15, key_bg))
	var l := UiStyle.label(text, 16, UiStyle.PAPER, "semibold")
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return _wrap_prompt(h)


# ------------------------------------------------------------------ aide (haut gauche)
func _build_help(root: Control) -> void:
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", UiStyle.ink_panel(14.0, 8))
	_help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_help.offset_left = 24
	_help.offset_top = 22
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_help)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(UiStyle.keycap("H", 14))
	_help_title = UiStyle.label("COMMANDES", 13, UiStyle.PAPER_DIM, "caps")
	_help_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_help_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_help_title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 7)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_body = grid
	v.add_child(grid)
	var rows := [
		[["Z", "Q", "S", "D"], "Marcher  ·  MAJ courir"],
		[["ESPACE"], "Sauter  ·  C s'accroupir"],
		[["1", "6"], "Outils (ou molette)"],
		[["CLIC DROIT"], "Viser, brandir"],
		[["CLIC GAUCHE"], "Tirer, lancer, allumer"],
		[["F"], "Coup de pied"],
		[["E"], "Interagir  ·  maintenir : déplacer"],
		[["G"], "Appeler la foule"],
		[["TAB"], "Roue des gestes"],
		[["B", "N", "X", "T"], "Gestes rapides"],
		[["V"], "Vue 1re / 3e personne"],
		[["ÉCHAP"], "Menu, réglages"],
	]
	for r in rows:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 3)
		keys.alignment = BoxContainer.ALIGNMENT_END
		keys.custom_minimum_size.x = 112
		keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ks: Array = r[0]
		if ks.size() == 2 and ks[0] == "1":
			_help_tools = keys
			_refresh_help_keys()
			ks = []
		for i in ks.size():
			if ks.size() == 2 and ks[0] == "1":
				keys.add_child(UiStyle.keycap(ks[i], 13))
				if i == 0:
					var dash := UiStyle.label("–", 13, UiStyle.PAPER_MUTE, "bold")
					keys.add_child(dash)
			else:
				keys.add_child(UiStyle.keycap(ks[i], 13))
		grid.add_child(keys)
		var l := UiStyle.label(r[1], 15, UiStyle.PAPER_DIM, "regular")
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(l)


## Aide : 2 dépliée, 1 puce « H Commandes » seule, 0 effacée
func _set_help(state: int, animate := true) -> void:
	_help_state = state
	_help_t = 0.0
	if _help_tween:
		_help_tween.kill()
	if state == 2:
		_help_body.visible = true
		_help_title.text = "COMMANDES"
		_help.visible = true
	elif state == 1:
		_help_title.text = "COMMANDES"
		_help.visible = true
	if not animate:
		_help.modulate.a = 1.0 if state > 0 else 0.0
		_help.visible = state > 0
		_help_body.visible = state == 2
		_help_body.modulate.a = 1.0
		_help.reset_size()
		return
	_help_tween = create_tween()
	if state == 2:
		_help_body.modulate.a = 0.0
		_help.reset_size()
		_help_tween.tween_property(_help, "modulate:a", 1.0, 0.2)
		_help_tween.tween_property(_help_body, "modulate:a", 1.0, 0.25)
	elif state == 1:
		_help_tween.tween_property(_help_body, "modulate:a", 0.0, 0.35)
		_help_tween.tween_callback(func():
			_help_body.visible = false
			_help.reset_size())
		_help_tween.tween_property(_help, "modulate:a", 0.85, 0.2)
	else:
		_help_tween.tween_property(_help, "modulate:a", 0.0, 0.6)
		_help_tween.tween_callback(func():
			_help.visible = false
			_help_body.visible = false
			_help.reset_size())


# ------------------------------------------------------------------ puce de vue (haut droite)
func _build_view_chip(root: Control) -> void:
	_view_chip = PanelContainer.new()
	var st := UiStyle.ink_panel(0.0, 6)
	st.content_margin_left = 8
	st.content_margin_right = 14
	st.content_margin_top = 7
	st.content_margin_bottom = 7
	_view_chip.add_theme_stylebox_override("panel", st)
	_view_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_view_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_view_chip.offset_right = -24
	_view_chip.offset_top = 22
	_view_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_chip.modulate.a = 0.0
	root.add_child(_view_chip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_chip.add_child(h)
	h.add_child(UiStyle.keycap("V", 14))
	_view_label = UiStyle.label("TROISIÈME PERSONNE", 13, UiStyle.PAPER, "caps")
	_view_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_view_label)


# =================================================================== boucle
func _process(delta: float) -> void:
	# aide : dépliée quelques secondes, puis puce, puis rien
	if _help_state > 0:
		_help_t += delta
		if _help_state == 2 and _help_t > HELP_SECS:
			_set_help(1)
		elif _help_state == 1 and _help_t > CHIP_SECS:
			_set_help(0)
	_fade_prompt(_kick_prompt, _kick_prompt_on, delta)
	var cp: Array = _player.context_prompt() if _player else []
	if _prompt:
		var key := str(cp)
		if key != _last_cp:
			_last_cp = key
			_set_prompt(cp)
		var show := not cp.is_empty() and (_item != 1 or _ammo > 0) and _status.text == ""
		_fade_prompt(_prompt, show, delta)
	if _e_prompt and _player:
		var ep := _player.interact_prompt()
		if ep != "" and _e_label.text != ep:
			_e_label.text = ep
		_fade_prompt(_e_prompt, ep != "", delta)


## Apparition / disparition douce d'une invite ; masquée (sans place réservée) une fois invisible
func _fade_prompt(p: Control, on: bool, delta: float) -> void:
	if p == null:
		return
	if on and not p.visible:
		p.visible = true
		p.modulate.a = 0.0
		p.scale = Vector2(0.92, 0.92)
	if not p.visible:
		return
	p.pivot_offset = p.size * 0.5
	p.modulate.a = UiStyle.damp(p.modulate.a, 1.0 if on else 0.0, 12.0, delta)
	var s := UiStyle.damp(p.scale.x, 1.0 if on else 0.94, 14.0, delta)
	p.scale = Vector2(s, s)
	if not on and p.modulate.a < 0.02:
		p.visible = false


func _set_prompt(cp: Array) -> void:
	if cp.is_empty():
		return
	for c in _prompt_row.get_children():
		_prompt_row.remove_child(c)
		c.queue_free()
	for k in cp[0]:
		_prompt_row.add_child(UiStyle.keycap(k, 15))
	var sp := Control.new()
	sp.custom_minimum_size.x = 4
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_child(sp)
	var l := UiStyle.label(cp[1], 16, UiStyle.PAPER, "semibold")
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_row.add_child(l)
	_prompt.reset_size()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_set_help(0 if _help_state == 2 else 2)


func _refresh() -> void:
	_shells.count = _ammo
	_shells.maximum = _max
	_shells.queue_redraw()
	var n := 0
	var m := 0
	var infinite := false
	var kt: KitTool = _player.kit_tool(_item) if _player else null
	var empty_now := false
	match _item:
		1:
			n = _ammo
			m = _max
		2, 3:
			infinite = true
		4:
			n = _flares
			m = _flares_max
		5, 6:
			n = _pet[_item - 4]
			m = _pet_max[_item - 4]
	if _item == 0:
		_count.text = ""
		_cmax.text = ""
	elif kt != null:
		var cp := kt.count_pair()
		_count.text = str(cp[0])
		_cmax.text = str(cp[1])
		empty_now = kt.is_empty()
	elif infinite:
		_count.text = "∞"
		_cmax.text = ""
	else:
		_count.text = str(n)
		_cmax.text = "/ %d" % m if m > 0 else ""
		empty_now = n <= 0
	_count.add_theme_color_override("font_color", UiStyle.RED if empty_now else UiStyle.PAPER)
	for s in _slots:
		s.selected = _item == s.item
		var skt: KitTool = _player.kit_tool(s.item) if _player else null
		match s.item:
			1:
				s.count_text = str(_ammo)
				s.empty = _ammo <= 0
			4:
				s.count_text = str(_flares)
				s.empty = _flares <= 0
			5, 6:
				s.count_text = str(_pet[s.item - 4])
				s.empty = _pet[s.item - 4] <= 0
			_:
				s.count_text = skt.count_text() if skt else ""
				s.empty = skt.is_empty() if skt else false
		s.queue_redraw()
	_name.text = TOOL_NAMES[clampi(_item, 0, TOOL_NAMES.size() - 1)]
	_shells.visible = _item == 1
	_hint.text = TOOL_HINTS[clampi(_item, 0, TOOL_HINTS.size() - 1)]
	if _item == 0:
		var nn := mini(_items.size(), 9)
		_hint.text = "Molette ou 1 à %d : choisir un outil" % nn if nn > 1 else ("Molette ou 1 : prendre l'outil" if nn == 1 else "Mains libres")


func _on_item(i: int) -> void:
	_item = i
	_selected = i != 0
	_refresh()
	for sl in _slots:
		if sl.item == i:
			sl.bump = 1.0


func _on_ammo(count: int, maximum: int) -> void:
	_ammo = count
	_max = maximum
	_refresh()
	_shells.pulse = 1.0
	var tw := create_tween()
	tw.tween_method(func(v): _shells.pulse = v; _shells.queue_redraw(), 1.0, 0.0, 0.8)
	if _item == 1:
		UiStyle.pop(_count, 1.18, 0.3)
	if count == 0:
		_toast_show("Dernier obus")


## Étape de la séquence de tir du mortier (libellé + progression)
func _on_stage(label: String, progress: float) -> void:
	_status.text = label
	_bar.value = progress
	_status.visible = label != ""
	_hint.visible = label == ""
	_bar.modulate.a = 1.0 if label != "" else 0.0


func _on_aim(on: bool) -> void:
	if _aim_tween:
		_aim_tween.kill()
	_aim_on = on
	if on:
		_post.visible = true
		_reticle.scale = Vector2(1.35, 1.35)
	_aim_tween = create_tween().set_parallel(true)
	_aim_tween.tween_method(func(v): (_post.material as ShaderMaterial).set_shader_parameter("amount", v), 0.0 if on else 1.0, 1.0 if on else 0.0, 0.35)
	_aim_tween.tween_property(_reticle, "modulate:a", 1.0 if on else 0.0, 0.2)
	_aim_tween.tween_property(_reticle, "scale", Vector2.ONE if on else Vector2(1.2, 1.2), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not on:
		_aim_tween.chain().tween_callback(func(): _post.visible = false)


func _on_view(first_person: bool) -> void:
	_view_label.text = "PREMIÈRE PERSONNE" if first_person else "TROISIÈME PERSONNE"
	if _view_tween:
		_view_tween.kill()
	_view_chip.reset_size()
	_view_tween = create_tween()
	_view_tween.tween_property(_view_chip, "modulate:a", 1.0, 0.15)
	_view_tween.tween_interval(1.8)
	_view_tween.tween_property(_view_chip, "modulate:a", 0.0, 0.6)


# ------------------------------------------------------------------ messages
## Message en bas de l'écran : bandeau d'encre à liseré (rouge, ou jaune pour une alerte),
## empilé avec les précédents (3 au plus), effacé après le temps de lecture
func _toast_show(text: String) -> void:
	if _toasts == null or text == "":
		return
	# même message déjà affiché : on le relance
	for t in _toasts.get_children():
		if t.has_meta("text") and t.get_meta("text") == text and not t.get_meta("dying", false):
			_toast_life(t, text)
			UiStyle.pop(t, 1.06, 0.25)
			return
	var alert := _is_alert(text)
	var p := PanelContainer.new()
	var st := UiStyle.soft_shadow(UiStyle.box(UiStyle.INK_PANEL, 4), 0.3, 10, Vector2(0, 3))
	st.border_width_left = 5
	st.border_color = UiStyle.YELLOW if alert else UiStyle.RED
	st.content_margin_left = 16
	st.content_margin_right = 18
	st.content_margin_top = 8
	st.content_margin_bottom = 9
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.set_meta("text", text)
	var l := UiStyle.label(text, 18, UiStyle.PAPER, "semibold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	p.scale = Vector2(0.9, 0.9)
	p.resized.connect(func(): p.pivot_offset = p.size * 0.5)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_life(p, text)


func _toast_life(p: Control, text: String) -> void:
	if p.has_meta("life"):
		var old: Variant = p.get_meta("life")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := p.create_tween()
	tw.tween_interval(1.8 + float(text.length()) / 28.0)      # le temps de lire
	tw.tween_callback(func(): p.set_meta("dying", true))
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	p.set_meta("life", tw)


func _is_alert(text: String) -> bool:
	for w in ["CRS", "police", "Interpellation", "Plus de", "Trop tard", "Dernier", "Menotté", "Recherché", "Reculez"]:
		if text.contains(w):
			return true
	return false

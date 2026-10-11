class_name DialogueUI
extends CanvasLayer
## Dialogues de l'histoire : interprète les arbres de dialogue (format : docs/CAMPAGNE.md § « Format des dialogues »),
## affiche les répliques sous-titrées (nom du personnage, texte), joue la voix si elle existe
## (res://assets/voice/<_id>/<id de réplique>.ogg), fait parler le personnage d'histoire (StoryActor.talk) et
## présente les choix (souris ou touches 1-4, minuteur optionnel).
## VERSION SQUELETTE : présentation minimale ; le module Dialogues la remplace en gardant l'interface publique.

signal line_done
signal choice_made(index: int)

var director: ChapterDirector
var _label: Label
var _box: VBoxContainer
var _choice := -1
var _choosing := false


func bind(d: ChapterDirector) -> void:
	director = d


func _ready() -> void:
	layer = 40
	_label = Label.new()
	_label.anchor_left = 0.15
	_label.anchor_right = 0.85
	_label.anchor_top = 0.8
	_label.anchor_bottom = 0.95
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	_box = VBoxContainer.new()
	_box.anchor_left = 0.3
	_box.anchor_right = 0.7
	_box.anchor_top = 0.55
	_box.anchor_bottom = 0.8
	add_child(_box)


## Nom affiché d'un personnage
static func display_name(who: String) -> String:
	return str(CastLooks.look(who).get("name", who.capitalize()))


## Identifiant de réplique (sert au nom du fichier de voix) : "<nœud>_<index>" ; choix : "<nœud>_<index>_c<k>"
static func line_id(node: String, idx: int, choice := -1) -> String:
	return "%s_%d" % [node, idx] if choice < 0 else "%s_%d_c%d" % [node, idx, choice]


static func voice_path(dlg_id: String, lid: String) -> String:
	return "res://assets/voice/%s/%s.ogg" % [dlg_id, lid]


## Une réplique : sous-titre, voix éventuelle (opts.vo = chemin), le personnage parle ; attend la fin
func play_line(who: String, text: String, opts := {}) -> void:
	var a: StoryActor = director.cast.get_actor(who) if director and director.cast else null
	var dur := clampf(0.6 + text.length() * 0.055, 1.4, 9.0)
	if Campaign.autoplay:
		dur = 0.02
	if a:
		a.talk(dur)
		if opts.has("anim"):
			a.gesture(str(opts["anim"]), dur)
	_label.text = "%s : %s" % [display_name(who), text]
	await director.sleep(dur + float(opts.get("wait", 0.0)) * (0.1 if Campaign.autoplay else 1.0))
	_label.text = ""
	line_done.emit()


## Réplique courte non bloquante
func bark(who: String, text: String) -> void:
	_label.text = "%s : %s" % [display_name(who), text]


## Choix : renvoie l'index de l'option retenue
func choose(prompt: String, options: Array, timer := 0.0) -> int:
	if Campaign.autoplay:
		await director.sleep(0.02)
		return Campaign.auto_pick(options.size())
	for c in _box.get_children():
		c.queue_free()
	if prompt != "":
		var l := Label.new()
		l.text = prompt
		_box.add_child(l)
	_choice = -1
	_choosing = true
	for i in options.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, str(options[i])]
		var k := i
		b.pressed.connect(func() -> void: _choice = k)
		_box.add_child(b)
	var prev := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var t := 0.0
	while _choice < 0:
		await director.sleep(0.05)
		t += 0.05
		if timer > 0.0 and t >= timer:
			_choice = 0
	_choosing = false
	Input.mouse_mode = prev
	for c in _box.get_children():
		c.queue_free()
	choice_made.emit(_choice)
	return _choice


func _unhandled_input(e: InputEvent) -> void:
	if _choosing and e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			var n := _box.get_children().filter(func(c): return c is Button).size()
			if k - KEY_1 < n:
				_choice = k - KEY_1


# ------------------------------------------------------------------ interprète
## Joue l'arbre `dlg` depuis le nœud `node` ; renvoie l'"id" du dernier choix fait
func run(dlg: Dictionary, node := "start") -> String:
	var dlg_id := str(dlg.get("_id", "dlg"))
	var last := ""
	var cur := node
	var guard := 0
	while cur != "" and guard < 200:
		guard += 1
		if not dlg.has(cur):
			push_error("Dialogue %s : nœud inconnu « %s »" % [dlg_id, cur])
			return last
		var steps: Array = dlg[cur]
		var next := ""
		var i := 0
		while i < steps.size():
			var s: Dictionary = steps[i]
			if s.has("if") and not s.has("goto") and not cond(s["if"]):
				i += 1
				continue
			if s.has("text"):
				var who := str(s.get("who", "narrateur"))
				var o: Dictionary = s.duplicate()
				var vp := voice_path(dlg_id, line_id(cur, i))
				if ResourceLoader.exists(vp):
					o["vo"] = vp
				_apply(s)
				await play_line(who, str(s["text"]), o)
			elif s.has("choice"):
				var opts: Array = (s["choice"] as Array).filter(func(c): return not c.has("if") or cond(c["if"]))
				if opts.is_empty():
					i += 1
					continue
				var labels := opts.map(func(c): return str(c.get("text", "…")))
				var k := await choose(str(s.get("prompt", "")), labels, float(s.get("timer", 0.0)))
				var c: Dictionary = opts[clampi(k, 0, opts.size() - 1)]
				last = str(c.get("id", c.get("text", "")))
				_apply(c)
				if c.has("say"):
					var full_k: int = (s["choice"] as Array).find(c)
					var o2 := {"vo": voice_path(dlg_id, line_id(cur, i, full_k))}
					if not ResourceLoader.exists(o2["vo"]):
						o2.erase("vo")
					await play_line("sam", str(c["say"]), o2)
				if c.has("goto"):
					next = str(c["goto"])
					break
			elif s.has("goto"):
				if not s.has("if") or cond(s["if"]):
					next = str(s["goto"])
					break
				elif s.has("else"):
					next = str(s["else"])
					break
			elif s.has("end"):
				return last
			elif s.has("call"):
				var m := str(s["call"])
				if director.script_obj and director.script_obj.has_method(m):
					await director.script_obj.call(m)
				else:
					push_error("Dialogue %s : méthode « %s » absente du chapitre" % [dlg_id, m])
			elif s.has("wait"):
				await director.sleep(float(s["wait"]) * (0.1 if Campaign.autoplay else 1.0))
			else:
				_apply(s)
			i += 1
		cur = next
	return last


## Effets d'une étape ou d'une option : set (drapeaux), stats (jauges), rel (relations), news
func _apply(s: Dictionary) -> void:
	for k in (s.get("set", {}) as Dictionary):
		Campaign.set_flag(k, s["set"][k])
	for k in (s.get("stats", {}) as Dictionary):
		Campaign.add_stat(k, float(s["stats"][k]), "dialogue")
	for k in (s.get("rel", {}) as Dictionary):
		Campaign.rel_add(k, int(s["rel"][k]))
	if s.has("news") and director and director.news:
		director.news.push(str(s["news"]))


## Condition : "drapeau", "!drapeau", "stat:opinion>=40", "rel:karim<0", "flag:choix==valeur",
## ou un Array de conditions (toutes vraies)
static func cond(c: Variant) -> bool:
	if c is Array:
		for x in c:
			if not cond(x):
				return false
		return true
	var s := str(c).strip_edges()
	if s.begins_with("!"):
		return not cond(s.substr(1))
	if s.begins_with("stat:") or s.begins_with("rel:") or s.begins_with("flag:"):
		var body := s.substr(s.find(":") + 1)
		for op in [">=", "<=", "==", "!=", ">", "<"]:
			var p := body.find(op)
			if p > 0:
				var key := body.substr(0, p).strip_edges()
				var rhs := body.substr(p + op.length()).strip_edges()
				if s.begins_with("flag:"):
					var v := str(Campaign.flag(key, ""))
					return v == rhs if op == "==" else (v != rhs if op == "!=" else false)
				var lhs := Campaign.stat(key) if s.begins_with("stat:") else float(Campaign.rel_get(key))
				var r := float(rhs)
				match op:
					">=": return lhs >= r
					"<=": return lhs <= r
					"==": return is_equal_approx(lhs, r)
					"!=": return not is_equal_approx(lhs, r)
					">": return lhs > r
					"<": return lhs < r
		push_error("Dialogue : condition illisible « %s »" % s)
		return false
	return bool(Campaign.flag(s, false))

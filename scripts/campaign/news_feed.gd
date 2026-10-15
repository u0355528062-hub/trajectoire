class_name NewsFeed
extends CanvasLayer
## Actualités et écrans de fin : notifications d'actualité pendant le jeu (push : bandeau Canal Continu ;
## push_social : notification de téléphone du réseau Fil), bilan de fin de chapitre façon JT (NewsBilan),
## écran d'échec (NewsFailure : garde à vue…, recommencer / menu), fins de la campagne (NewsEnding).
## Textes : NewsTexts. En pilote automatique, chaque écran est construit puis validé seul (premier bouton).

signal closed
signal _answered(i: int)

var director: ChapterDirector
var ticker: NewsTicker
var screen: NewsScreen            # écran plein écran ouvert (null sinon)
var history: Array = []           # notifications poussées pendant le chapitre [{kind, title, text}]
var start_stats: Dictionary = {}  # jauges au début du chapitre (variations du bilan)


func bind(d: ChapterDirector) -> void:
	director = d


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_stats = Campaign.stats.duplicate()
	ticker = NewsTicker.new()
	ticker.name = "Ticker"
	add_child(ticker)


## Actualité de Canal Continu (bandeau)
func push(text: String) -> void:
	_push("tv", "EN DIRECT", text)


## Notification de téléphone (réseau social Fil)
func push_social(title: String, text: String) -> void:
	_push("phone", title, text)


func _push(kind: String, title: String, text: String) -> void:
	history.append({"kind": kind, "title": title, "text": text})
	if ticker:
		ticker.add(kind, title, text)


## Données du bilan du chapitre en cours (aussi utilisées par les tests et les captures)
func bilan_data(outcome := "ok") -> Dictionary:
	var def := Campaign.chapter_def()
	var id := str(def.get("id", ""))
	var op := Campaign.stat("opinion")
	var entries := Campaign.journal_of()
	var op0 := float(start_stats.get("opinion", op))
	var nxt := ""
	if not Campaign.is_last_chapter():
		var n: Dictionary = Story.CHAPTERS[Campaign.chapter + 1]
		nxt = "Prochain chapitre : %s" % str(n.get("title", ""))
	var ticks: Array = []
	for e in NewsTexts.highlights(entries, 6):
		ticks.append(str(e.get("text", "")))
	for h in history:
		if str(h["kind"]) == "tv":
			ticks.append(str(h["text"]))
	if ticks.is_empty():
		ticks.append("Loi de Stabilité : le texte entre en application le 1er avril")
	var date := str(def.get("date", ""))
	return {"id": id, "index": Campaign.chapter, "title": str(def.get("title", "")), "date": date.get_slice(" — ", 0),
		"outcome": outcome, "headline": NewsTexts.headline(id, op), "keyword": NewsTexts.keyword(id),
		"ticker": "   ·   ".join(ticks), "clock": "20:00",
		"lines": NewsTexts.anchor_lines(id, op, op - op0, Campaign.stat("mobilisation"), entries),
		"opinion": op, "opinion_start": op0, "poll": NewsTexts.poll(op),
		"mob": Campaign.stat("mobilisation"), "mob_start": float(start_stats.get("mobilisation", Campaign.stat("mobilisation"))),
		"repression": Campaign.stat("repression"), "notoriete": Campaign.stat("notoriete"),
		"highlights": NewsTexts.highlights(entries, 4),
		"posts": NewsTexts.social_posts(entries, op, Campaign.chapter * 7919 + Campaign.journal.size(), 2),
		"next": nxt}


## Bilan de fin de chapitre (await)
func show_bilan(outcome: String) -> void:
	var s := NewsBilan.new()
	s.data = bilan_data(outcome)
	await _show(s)


## Écran d'échec ; true = recommencer le chapitre, false = retour au menu
func show_failure(reason: String) -> bool:
	var s := NewsFailure.new()
	s.reason = reason
	var def := Campaign.chapter_def()
	s.chapter_label = "Chapitre %d · %s" % [Campaign.chapter, str(def.get("title", ""))]
	return await _show(s) == 0


## Fin de la campagne (await)
func show_ending(id: String) -> void:
	var s := NewsEnding.new()
	s.ending_id = id
	await _show(s)


## Fin atteinte selon l'état de la campagne : Story.ending_for_state() (BIBLE § 6, fin cachée « grève » comprise).
## Si l'épilogue a déjà annoncé une fin (drapeau fin_suggeree, calculé par la même règle), on la garde pour que
## l'écran de fin dise la même chose que le JT de l'épilogue.
static func pick_ending() -> String:
	var e := Story.ending_for_state()
	var said := str(Campaign.flag("fin_suggeree", ""))
	if NewsTexts.ENDINGS.has(said):
		return said
	return e if NewsTexts.ENDINGS.has(e) else "essoufflement"


## Ouvre un écran plein écran et attend la réponse (index du bouton)
func _show(s: NewsScreen) -> int:
	_close_screen()
	screen = s
	if ticker:
		ticker.visible = false
	add_child(s)
	s.answered.connect(func(i: int) -> void: _answered.emit(i))
	var prev := Input.mouse_mode
	var frozen := false
	var p: Player = director.player if director else null
	if p and is_instance_valid(p) and p.is_physics_processing():
		p.set_physics_process(false)
		frozen = true
	var answer := 0
	if Campaign.autoplay:
		await director.sleep(0.05)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		answer = await _answered
		Input.mouse_mode = prev
	if frozen and is_instance_valid(p):
		p.set_physics_process(true)
	_close_screen()
	if ticker:
		ticker.visible = true
	closed.emit()
	return answer


func _close_screen() -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null

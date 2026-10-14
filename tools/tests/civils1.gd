extends SceneTree
## Passants et habitants : des passants circulent sur les trottoirs (certains s'arrêtent pour regarder ou
## filmer) ; à partir du stade 2 ils s'en vont et sont moins nombreux ; une charge et un nuage de gaz les font
## fuir ; aucun n'entre dans un état de manifestant ni dans crowd.npcs ; la police n'en vise aucun ;
## des habitants apparaissent aux balcons et aux fenêtres et rentrent quand ça explose près d'eux.
var frame := 0
var main: Node
var crowd: Crowd
var police: Police
var ten: Tension
var civ: Civilians
var res: Residents
var max_walkers := 0
var max_res := 0
var res_balcony := 0
var res_high := 0
var stops := 0
var seen_stop := {}
var kinds := {}
var states_seen := {}
var bad_states := 0
var in_npcs := 0
var targeted := 0
var outside := 0
var travelled := 0.0
var last_pos := {}
var calm_count := 0.0
var calm_n := 0
var tense_count := 0.0
var tense_n := 0
var leaving_frac := 0.0
var charge_ok := -1
var gas_ok := -1
var res_retreat_before := 0
var errors: Array[String] = []
var watched: Passerby
var gassed_w: Passerby
const OK_STATES := ["walk", "stop", "flee", "gassed"]


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _process(_d: float) -> bool:
	frame += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: police = c
			if c is Tension: ten = c
			if c is Civilians: civ = c
			if c is Residents: res = c
		main.player.global_position = Vector3(-12, 0.05, 12)
		if civ == null or res == null:
			print("ÉCHEC : gestionnaires absents")
			quit()
			return false
	if civ == null:
		return false
	_observe()
	# phase 2 : la tension monte (stade 2 puis 3)
	if frame == 30 * 70:
		ten.set_value(0.45)
		print("[%ds] tension -> stade %d" % [frame / 30, police.stage])
	if frame == 30 * 95:
		ten.set_value(0.65)
	# charge de police sur un passant : il doit fuir
	if frame == 30 * 40:
		for w in civ.walkers:
			if w.state == "walk" and w.lead == null:
				watched = w
				break
		if watched:
			civ.on_event("police_charge", {"pos": watched.global_position + Vector3(6, 0, 0), "target": null})
	if frame == 30 * 41 and watched and is_instance_valid(watched):
		charge_ok = 1 if (watched.state == "flee" or watched.leaving) else 0
		print("charge : état du passant=%s fuite=%s" % [watched.state, watched.leaving])
	# nuage de gaz sur un passant
	if frame == 30 * 50:
		for w in civ.walkers:
			if w.state in ["walk", "stop"] and w != watched:
				gassed_w = w
				break
		if gassed_w:
			var g := GasCloud.new()
			g.crowd = crowd
			main.add_child(g)
			g.global_position = Vector3(gassed_w.global_position.x, 0, gassed_w.global_position.z)
	if frame == 30 * 54 and gassed_w and is_instance_valid(gassed_w):
		gas_ok = 1 if gassed_w.state in ["gassed", "flee"] else 0
		print("gaz : état du passant=%s" % gassed_w.state)
	# détonation près des habitants
	if frame == 30 * 60:
		res_retreat_before = res.retreated
		for r in res.residents:
			if r.state != "in":
				res.on_event("burst", {"pos": r.global_position + Vector3(0, -2, 3)})
				break
	if frame % 300 == 0:
		var st := {}
		for w in civ.walkers:
			st[w.state] = int(st.get(w.state, 0)) + 1
		var acts := {}
		for r in res.residents:
			var k := "%s/%s" % [r.state, r.activity]
			acts[k] = int(acts.get(k, 0)) + 1
		print("[%ds] st=%d passants=%d %s | habitants=%d %s" % [frame / 30, police.stage, civ.walkers.size(), st, res.residents.size(), acts])
	if frame == 30 * 125:
		_report()
		quit()
	return false


func _observe() -> void:
	max_walkers = maxi(max_walkers, civ.walkers.size())
	var leaving := 0
	var npc_ids := {}
	for n in crowd.npcs:
		npc_ids[n.get_instance_id()] = true
	for w in civ.walkers:
		if not is_instance_valid(w):
			continue
		kinds[w.kind] = true
		states_seen[w.state] = true
		if not (w.state in OK_STATES):
			bad_states += 1
		if npc_ids.has(w.get_instance_id()):
			in_npcs += 1
		if w.state == "stop" and not seen_stop.has(w):
			seen_stop[w] = true
			stops += 1
		var p := w.global_position
		var lim := Quartier.z_limits(p.x)
		if p.z < lim.x - 0.1 or p.z > lim.y + 0.1 or absf(p.x) > Quartier.BLVD_END:
			outside += 1
		if last_pos.has(w):
			travelled += (last_pos[w] as Vector3).distance_to(p)
		last_pos[w] = p
		if w.leaving:
			leaving += 1
	if police:
		for c in police.cops:
			if is_instance_valid(c) and is_instance_valid(c.target) and (c.target is Passerby or c.target is Resident):
				targeted += 1
	if frame > 30 * 10 and frame < 30 * 70:
		calm_count += civ.walkers.size()
		calm_n += 1
	if frame > 30 * 105:
		tense_count += civ.walkers.size()
		tense_n += 1
		if civ.walkers.size() > 0:
			leaving_frac += float(leaving) / civ.walkers.size()
	max_res = maxi(max_res, res.residents.size())
	for r in res.residents:
		if r.state == "idle" and r.kind == "balcony":
			res_balcony = maxi(res_balcony, 1)
		if r.global_position.y > 4.0:
			res_high += 1


func _report() -> void:
	var calm_avg := calm_count / maxf(calm_n, 1)
	var tense_avg := tense_count / maxf(tense_n, 1)
	var leave_avg := leaving_frac / maxf(tense_n, 1)
	print("passants : max=%d moyenne calme=%.1f moyenne tendue=%.1f (créés %d, retirés %d) types=%s" % [max_walkers, calm_avg, tense_avg, civ.spawned, civ.removed, kinds.keys()])
	print("arrêts pour regarder/filmer=%d, distance parcourue=%.0f m, états vus=%s" % [stops, travelled, states_seen.keys()])
	print("tendu : part des passants qui s'en vont=%.0f%%" % (leave_avg * 100.0))
	print("habitants : max=%d, au balcon=%s, créés=%d, rentrés=%d (dont après la détonation %d)" % [max_res, res_balcony > 0, res.spawned, res.retreated, res.retreated - res_retreat_before])
	print("contrôles : états de manifestant=%d, dans crowd.npcs=%d, ciblés par la police=%d, hors des trottoirs=%d" % [bad_states, in_npcs, targeted, outside])
	var ok := true
	var checks := {
		"des passants circulent": max_walkers >= 6 and travelled > 300.0,
		"certains s'arrêtent": stops >= 1,
		"moins de passants quand c'est tendu": tense_avg < calm_avg * 0.6,
		"ils s'en vont": leave_avg > 0.6 or tense_avg < 1.0,
		"fuite à la charge": charge_ok != 0,
		"fuite du gaz": gas_ok != 0,
		"jamais manifestants": bad_states == 0 and in_npcs == 0,
		"jamais ciblés": targeted == 0,
		"restent dans le quartier": outside == 0,
		"habitants aux balcons": max_res >= 3 and res_balcony > 0 and res_high > 0,
		"habitants qui rentrent": res.retreated - res_retreat_before >= 1,
	}
	for k in checks:
		print("  %s : %s" % [k, "ok" if checks[k] else "ÉCHEC"])
		ok = ok and checks[k]
	print("RÉSULTAT : %s" % ("OK" if ok else "ÉCHEC"))

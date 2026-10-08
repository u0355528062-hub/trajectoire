class_name Standoff
extends RefCounted
## Face-à-face avec la police. Dès que la ligne avance (stade « ÉCHAUFFOURÉES »), le cortège cesse de défiler et
## la foule fait front à distance : les plus déterminés au premier rang (banderole au centre), les autres derrière,
## les craintifs reculent à l'arrière. Les places suivent la ligne de police quand elle avance ou recule.

const GAPS := [0.0, 0.0, 13.0, 10.5, 9.0]     # distance du premier rang à la ligne, selon le stade
const ROW_DX := 1.45                           # écart entre deux rangs
const REAR_GAP := 27.0                         # distance de l'arrière-garde (craintifs, blessés, curieux)

var crowd: Crowd
var active := false
var slots := {}              # Npc -> Vector3 : place assignée dans la formation
var rows := {}               # Npc -> int : rang (0 = premier rang)
var rear := {}               # Npc -> true : se tient à l'arrière
var gap := 13.0
var center := Vector3.ZERO   # milieu du premier rang
var anger_avg := 0.0         # colère moyenne du front : les plus calmes tentent d'apaiser
var _t := 0.0


func _init(c: Crowd) -> void:
	crowd = c


func slot_of(n: Npc) -> Variant:
	return slots.get(n)


func row_of(n: Npc) -> int:
	return int(rows.get(n, -1))


func is_rear(n: Npc) -> bool:
	return rear.has(n)


## Un PNJ disparaît (interpellé) : on libère sa place
func forget(n: Npc) -> void:
	slots.erase(n)
	rows.erase(n)
	rear.erase(n)


## Place d'attente à l'arrière, au même niveau que la foule mais loin de la ligne
func rear_spot(n: Npc) -> Vector3:
	var pol := crowd.police
	var lx := pol.line_c.x if pol else 40.0
	var z := center.z + (float((n.idx * 37) % 21) - 10.0) * 1.15
	return crowd.clamp_area(Vector3(lx - REAR_GAP - float(n.idx % 4) * 1.6, 0.0, z))


func update(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var pol := crowd.police
	var st: int = pol.stage if pol else 0
	var was := active
	active = pol != null and st >= 2
	if not active:
		if was:
			slots.clear()
			rows.clear()
			rear.clear()
			for ch in crowd.chats():
				(ch as Dictionary)["center"] = (ch as Dictionary)["home"]
		return
	gap = GAPS[mini(st, GAPS.size() - 1)]
	var lx := pol.line_c.x
	var zc := clampf(pol.line_c.z, -12.0, 5.0)
	center = Vector3(lx - gap, 0.0, zc)
	# participants : cortège et black bloc
	var people: Array[Npc] = []
	for n in crowd.npcs:
		if n.role in ["march", "bloc"] and n.state not in ["arrested", "boarded"]:
			people.append(n)
	var front: Array[Npc] = []
	var back: Array[Npc] = []
	for n in people:
		# la colère donne du courage : un enragé tient le rang plus longtemps qu'un timide
		var limit := 0.5 + 0.45 * maxf(n.bold * 0.5 + n.anger * 0.6 - 0.3, 0.0)
		var scared := n.fear > limit or n.state in ["hit", "sprayed", "gassed"] or crowd.gas_near(n.global_position, 1.0) != null
		# pas de rang pour qui est blessé ou terrorisé ; on y revient une fois calmé (hystérésis)
		if rear.has(n) and n.fear > limit * 0.55:
			scared = true
		if scared:
			back.append(n)
			rear[n] = true
		else:
			rear.erase(n)
			front.append(n)
	for n in rear.keys():
		if not people.has(n):
			rear.erase(n)
	var tot := 0.0
	for n in front:
		tot += n.anger
	anger_avg = tot / float(maxi(front.size(), 1))
	# les plus déterminés devant ; les anciens du premier rang gardent un avantage (évite les chassés-croisés)
	var bonus := func(n: Npc) -> float:
		var d: float = n.bold * 0.55 + n.anger * 0.8 - n.fear * 1.1
		if n.role == "bloc":
			d += 0.6
		if n.prop in ["sign", "flare", "mortar"]:
			d += 0.15
		if int(rows.get(n, 9)) == 0:
			d += 0.35
		return d
	var scored: Array = []
	for n in front:
		scored.append([bonus.call(n), n])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var used := {}
	var assign := func(n: Npc, row: int, dz: float) -> void:
		slots[n] = Vector3(lx - gap - float(row) * ROW_DX, 0.0, zc + dz)
		rows[n] = row
		used[n] = true
	# banderole : deux porteurs à ~3 m l'un de l'autre, au centre du premier rang
	for n in front:
		if n.prop == "banner":
			assign.call(n, 0, -1.6 if n.slot.x < 0.0 else 1.6)
	var offs0 := [-3.0, 3.0, -4.4, 4.4, -5.8, 5.8, -7.2, 7.2, -8.6, 8.6]
	var offs1 := [0.0, -1.5, 1.5, -2.9, 2.9, -4.3, 4.3, -5.7, 5.7, -7.1, 7.1]
	var offs2 := [-0.7, 0.7, -2.2, 2.2, -3.6, 3.6, -5.0, 5.0, -6.4, 6.4]
	# le meneur au mégaphone juste derrière la banderole
	for n in front:
		if n.prop == "megaphone":
			assign.call(n, 1, 0.0)
			offs1.erase(0.0)
	var i0 := 0
	var i1 := 0
	var i2 := 0
	for e in scored:
		var n: Npc = e[1]
		if used.has(n):
			continue
		if i0 < offs0.size() and (i0 < 6 or i1 >= offs1.size()):
			assign.call(n, 0, offs0[i0])
			i0 += 1
		elif i1 < offs1.size():
			assign.call(n, 1, offs1[i1])
			i1 += 1
		elif i2 < offs2.size():
			assign.call(n, 2, offs2[i2])
			i2 += 1
		else:
			assign.call(n, 3, offs0[(i2 + i1) % offs0.size()] * 0.5)
	# les places sont recalées dans la zone des civils (obstacles compris)
	for n in slots.keys():
		if not people.has(n) or not used.has(n):
			slots.erase(n)
			rows.erase(n)
			continue
		slots[n] = crowd.clamp_area(slots[n])
	for n in back:
		slots.erase(n)
		rows.erase(n)
	# les groupes de discussion se reculent derrière le front, tournés vers la police
	var g := 0
	for ch in crowd.chats():
		(ch as Dictionary)["center"] = crowd.clamp_area(Vector3(lx - gap - 6.0 - float(g) * 2.2, 0.0, zc + (float(g) - 1.0) * 6.5))
		g += 1

class_name ParisSquare
extends RefCounted
## Square parisien (dans `Quartier.SQUARE`) : allées en stabilisé en croix, quatre plates-bandes de pelouse
## bordées d'arceaux verts bas, haies taillées, massifs de fleurs, deux arbres, bancs et un lampadaire.



static func build(ss: Streetscape, crowd: Crowd) -> void:
	var r := Quartier.SQUARE
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var ax := 0.9            # demi-largeur des allées
	var beds := [Rect2(x0 + 0.6, z0 + 0.5, cx - ax - 0.3 - x0 - 0.6, cz - 1.1 - z0 - 0.5),
		Rect2(cx + ax + 0.3, z0 + 0.5, x1 - 0.6 - cx - ax - 0.3, cz - 1.1 - z0 - 0.5),
		Rect2(x0 + 0.6, cz + 1.1 + 0.5, cx - ax - 0.3 - x0 - 0.6, z1 - 0.4 - cz - 1.6),
		Rect2(cx + ax + 0.3, cz + 1.1 + 0.5, x1 - 0.6 - cx - ax - 0.3, z1 - 0.4 - cz - 1.6)]
	var lawn := Streetscape.tmat("pelouse", "pelouse_a.png", "pelouse_n.png", Vector3.ONE, 0.92)
	var edge := Landmarks.m("pierre")
	var hoop_m := Landmarks.m("vert")
	var hedge := Landmarks.m("haie")
	var flowers := Landmarks.m("fleurs")
	var body := StaticBody3D.new()
	body.name = "Square"
	ss.add_child(body)
	var b := MeshBatch.new()
	var hb := MeshBatch.new()
	for i in beds.size():
		var bd: Rect2 = beds[i]
		var c := Vector3(bd.get_center().x, 0, bd.get_center().y)
		# pelouse légèrement bombée, bordurette de pierre
		b.ground_quad("pelouse", lawn, c + Vector3(0, 0.045, 0), bd.size, 0.0, Rect2(bd.position.x * 0.5, bd.position.y * 0.5, bd.size.x * 0.5, bd.size.y * 0.5), true)
		for e in [[Vector3(0, 0, -bd.size.y * 0.5), Vector3(bd.size.x + 0.1, 0.07, 0.06)], [Vector3(0, 0, bd.size.y * 0.5), Vector3(bd.size.x + 0.1, 0.07, 0.06)],
				[Vector3(-bd.size.x * 0.5, 0, 0), Vector3(0.06, 0.07, bd.size.y)], [Vector3(bd.size.x * 0.5, 0, 0), Vector3(0.06, 0.07, bd.size.y)]]:
			b.box("pierre", edge, e[1], c + (e[0] as Vector3) + Vector3(0, 0.035, 0))
		# arceaux verts bas tout autour (chaîne d'arches de 1 m)
		_hoops(hb, hoop_m, bd.grow(0.12))
		# haie taillée au fond des plates-bandes nord ; massif de fleurs ailleurs
		if i >= 2:
			var hz := bd.end.y - 0.35
			b.add("haie", hedge, MeshKit.rbox(Vector3(bd.size.x - 0.2, 0.85, 0.6), 0.18, 2), Transform3D(Basis(), Vector3(c.x, 0.47, hz)), 0, true)
			Landmarks._col_box(body, Vector3(bd.size.x - 0.2, 0.85, 0.6), Vector3(c.x, 0.43, hz))
		if i == 1 or i == 2:
			var fl := SphereMesh.new()
			fl.radius = 0.5
			fl.height = 1.0
			fl.radial_segments = 20
			fl.rings = 8
			var fz := c.z - (0.15 if i == 2 else 0.0)
			b.add("fleurs", flowers, fl, Transform3D(Basis.from_scale(Vector3(bd.size.x * 0.5, 0.28, minf(bd.size.y - 0.9, 1.1))), Vector3(c.x + (1.0 if i == 1 else -1.0), 0.04, fz)), 0, true)
		if crowd != null:
			var mk := Marker3D.new()
			body.add_child(mk)
			mk.position = c
			crowd.add_obstacle(mk, bd.size * 0.5 + Vector2(0.15, 0.15), Vector2.ZERO, false, true)
	b.commit(body, true, 0.0, "Plates-bandes")
	hb.commit(body, false, 90.0, "Arceaux")
	# deux arbres plus petits que les platanes du boulevard, feuillage plus clair
	for tp in [Vector2((beds[0] as Rect2).get_center().x - 1.2, (beds[0] as Rect2).get_center().y), Vector2((beds[3] as Rect2).get_center().x + 1.4, (beds[3] as Rect2).get_center().y - 0.25)]:
		var t := PlaneTree.plant(ss, Vector3(tp.x, 0, tp.y), ss._rng, ss._rng.randf_range(0.66, 0.76), Color(0.98, 1.06, 0.78), crowd)
		ss.trees.append(t)
		ss.count("arbre")
	# bancs le long de l'allée est-ouest, adossés aux plates-bandes
	for bp in [[Vector3((beds[0] as Rect2).get_center().x + 1.3, 0, (beds[0] as Rect2).end.y + 0.3), 0.0],
			[Vector3((beds[1] as Rect2).get_center().x - 1.0, 0, (beds[1] as Rect2).end.y + 0.3), 0.0],
			[Vector3((beds[3] as Rect2).get_center().x - 1.2, 0, (beds[3] as Rect2).position.y - 0.3), PI]]:
		ss.add_child(Landmarks.bench(bp[0], bp[1], false, crowd))
		ss.count("banc")
	var lamp := LampPost.new()
	lamp.crowd = crowd
	lamp.position = Vector3(cx - ax - 0.45, 0, cz + 1.25)
	ss.add_child(lamp)
	ss.count("lampadaire")


## Arceaux de 0,35 m de haut le long du contour d'un rectangle
static func _hoops(b: MeshBatch, mat: Material, r: Rect2) -> void:
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var e: Vector2 = corners[(i + 1) % 4]
		var L := a.distance_to(e)
		var n := maxi(1, int(round(L / 1.0)))
		for k in n:
			var p0 := a.lerp(e, float(k) / n)
			var p1 := a.lerp(e, float(k + 1) / n)
			var pts := PackedVector3Array()
			for j in 9:
				var t := float(j) / 8.0
				var q := p0.lerp(p1, t)
				pts.append(Vector3(q.x, sin(t * PI) * 0.33 + 0.02, q.y))
			b.add("arceau", mat, MeshKit.tube(pts, 0.011, 5, false), Transform3D.IDENTITY)

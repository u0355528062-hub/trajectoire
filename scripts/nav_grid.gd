class_name NavGrid
extends RefCounted
## Grille de navigation (A* C++ d'AStarGrid2D) sur la baseplate : obstacles fixes (abribus, véhicules garés,
## lampadaires...) rasterisés en cellules bloquées ; chemins lissés par visibilité directe.

const CELL := 0.7
var origin := Vector2(-52.0, -34.0)
var size := Vector2i(180, 100)
var astar := AStarGrid2D.new()


func _init() -> void:
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = origin
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()


func cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.z - origin.y) / CELL))


func world(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5) * CELL, 0.0, origin.y + (c.y + 0.5) * CELL)


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func clear() -> void:
	astar.fill_solid_region(astar.region, false)


## Rectangle orienté (centre monde, demi-dimensions locales x/z, lacet) élargi de `margin`
func block_box(center: Vector3, half: Vector2, yaw: float, margin := 0.45) -> void:
	var ext := half + Vector2(margin, margin)
	var rad := ext.length()
	var c0 := cell(center - Vector3(rad, 0, rad))
	var c1 := cell(center + Vector3(rad, 0, rad))
	var inv := Basis(Vector3.UP, yaw).inverse()
	for x in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
		for y in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
			var l := inv * (world(Vector2i(x, y)) - center)
			if absf(l.x) <= ext.x and absf(l.z) <= ext.y:
				astar.set_point_solid(Vector2i(x, y), true)


func block_circle(center: Vector3, radius: float, margin := 0.4) -> void:
	var r := radius + margin
	var c0 := cell(center - Vector3(r, 0, r))
	var c1 := cell(center + Vector3(r, 0, r))
	for x in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
		for y in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
			var w := world(Vector2i(x, y))
			if Vector2(w.x - center.x, w.z - center.z).length() <= r:
				astar.set_point_solid(Vector2i(x, y), true)


func is_free(p: Vector3) -> bool:
	var c := cell(p)
	return inside(c) and not astar.is_point_solid(c)


func _free_cell(c: Vector2i) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, size.x - 1), clampi(c.y, 0, size.y - 1))
	if not astar.is_point_solid(c):
		return c
	for r in range(1, 9):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if inside(n) and not astar.is_point_solid(n):
					var d := float(dx * dx + dy * dy)
					if d < bd:
						bd = d
						best = n
		if best.x >= 0:
			return best
	return c


func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var pa := Vector2(a)
	var pb := Vector2(b)
	var n := int(ceil(pa.distance_to(pb) * 2.0))
	for i in range(1, n):
		var q := pa.lerp(pb, float(i) / n)
		var c := Vector2i(roundi(q.x), roundi(q.y))
		if astar.is_point_solid(c):
			return false
		# évite de couper un coin de cellule bloquée
		var fx := Vector2i(floori(q.x), floori(q.y))
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			if inside(fx + o) and astar.is_point_solid(fx + o) and Vector2(fx + o).distance_to(q) < 0.55:
				return false
	return true


## Chemin lissé de `from` à `to` (le dernier point est exactement `to` si sa cellule est libre).
func path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var a := _free_cell(cell(from))
	var b := _free_cell(cell(to))
	var ids: Array[Vector2i] = astar.get_id_path(a, b)
	if ids.size() < 2:
		out.append(to)
		return out
	var i := 0
	while i < ids.size() - 1:
		var j := ids.size() - 1
		while j > i + 1 and not _clear_line(ids[i], ids[j]):
			j -= 1
		out.append(world(ids[j]))
		i = j
	if is_free(to):
		out[out.size() - 1] = to
	return out

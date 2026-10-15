class_name ObjectiveMarkers
extends Control
## Repères des objectifs à l'écran : losange cerné d'encre au-dessus du lieu (ou de la personne à qui parler),
## distance en mètres, onde qui pulse, anneau d'avancement pour une zone à tenir. Hors champ (ou derrière la
## caméra), une flèche au bord de l'écran indique la direction, avec la distance. Rouge pour un objectif
## principal, crème pour un facultatif. Le repère s'efface quand on est arrivé.

const MARGIN := 58.0
const ARRIVED := 3.0

var tracker: ObjectiveTracker


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


## Point d'écran d'un repère : [position, à l'écran ?, derrière ?] ; [] sans caméra
func project(cam: Camera3D, wp: Vector3) -> Array:
	var behind := cam.is_position_behind(wp)
	var sp := cam.unproject_position(wp)
	var vs := get_viewport_rect().size
	var on := not behind and sp.x > MARGIN and sp.x < vs.x - MARGIN and sp.y > MARGIN and sp.y < vs.y - MARGIN
	return [sp, on, behind]


func _draw() -> void:
	if tracker == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p: Player = tracker.director.player if tracker.director else null
	var origin := p.global_position if p and is_instance_valid(p) else cam.global_position
	var t := Time.get_ticks_msec() * 0.001
	for o in tracker.list:
		if not o.is_active():
			continue
		var base := tracker.marker_pos(o)
		if base == Vector3.INF:
			continue
		var wp := base + Vector3.UP * (2.25 if o.follow != "" else 1.4)
		var dist := Vector2(origin.x - base.x, origin.z - base.z).length()
		var zone := float(o.spec.get("radius", 4.0)) if o.kind() in ["reach", "hold"] else ARRIVED
		var fade := clampf((dist - minf(zone, ARRIVED) * 0.6) / 2.5, 0.0, 1.0)
		if o.kind() == "hold":
			fade = maxf(fade, 0.85)       # zone à tenir : on garde l'anneau d'avancement
		if fade <= 0.01:
			continue
		var col := UiStyle.RED if not o.optional else UiStyle.PAPER
		var pr := project(cam, wp)
		if pr[1]:
			_pin(pr[0], dist, col, fade, o, t)
		else:
			_edge(pr[0], pr[2], dist, col, fade, t)


func _pin(sp: Vector2, dist: float, col: Color, a: float, o: Objective, t: float) -> void:
	var s := clampf(1.15 - dist / 120.0, 0.75, 1.15)
	# onde
	var w := fmod(t * 0.6 + float(o.id.hash() % 100) * 0.01, 1.0)
	draw_arc(sp, (10.0 + w * 22.0) * s, 0.0, TAU, 32, Color(col, (1.0 - w) * 0.45 * a), 2.0, true)
	# losange cerné d'encre
	var r := 11.0 * s
	var outer := PackedVector2Array([sp + Vector2(0, -r - 3), sp + Vector2(r + 3, 0), sp + Vector2(0, r + 3), sp + Vector2(-r - 3, 0)])
	var inner := PackedVector2Array([sp + Vector2(0, -r), sp + Vector2(r, 0), sp + Vector2(0, r), sp + Vector2(-r, 0)])
	draw_colored_polygon(outer, Color(UiStyle.INK, 0.8 * a))
	draw_colored_polygon(inner, Color(col, a))
	draw_circle(sp, 3.2 * s, Color(UiStyle.INK, 0.85 * a))
	# pointe vers le sol
	draw_line(sp + Vector2(0, r + 4), sp + Vector2(0, r + 14 * s), Color(col, 0.7 * a), 2.0, true)
	if o.kind() == "hold":
		draw_arc(sp, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * o.ratio(), 40, Color(UiStyle.PAPER, a), 3.0, true)
	_text(sp + Vector2(0, r + 30 * s), _dist_txt(dist), a, 15)


func _edge(sp: Vector2, behind: bool, dist: float, col: Color, a: float, t: float) -> void:
	var c := get_viewport_rect().size * 0.5
	var dir := sp - c
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2.DOWN
	dir = dir.normalized()
	var hw := c.x - MARGIN
	var hh := c.y - MARGIN
	var k := minf(hw / maxf(absf(dir.x), 0.001), hh / maxf(absf(dir.y), 0.001))
	var pos := c + dir * k
	var bob := sin(t * 5.0) * 3.0
	var tip := pos + dir * (14.0 + bob)
	var side := Vector2(-dir.y, dir.x)
	var back := pos - dir * (6.0 - bob * 0.3)
	var tri_o := PackedVector2Array([tip + dir * 3.0, back + side * 15.0 - dir * 2.0, back - side * 15.0 - dir * 2.0])
	var tri := PackedVector2Array([tip, back + side * 11.0, back - side * 11.0])
	draw_colored_polygon(tri_o, Color(UiStyle.INK, 0.8 * a))
	draw_colored_polygon(tri, Color(col, a))
	_text(pos - dir * 26.0 + Vector2(0, 5), _dist_txt(dist), a, 14)


func _dist_txt(d: float) -> String:
	if d >= 1000.0:
		return "%.1f km" % (d / 1000.0)
	return "%d m" % int(round(d))


func _text(at: Vector2, s: String, a: float, fs: int) -> void:
	var f := UiStyle.font("bold")
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := at - Vector2(w * 0.5, 0)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(UiStyle.INK, 0.8 * a))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiStyle.PAPER, a))

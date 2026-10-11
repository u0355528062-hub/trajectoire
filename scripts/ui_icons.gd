class_name UiIcons
extends RefCounted
## Icônes vectorielles de l'interface, écrites en SVG (repère 64 × 64) et rastérisées à la volée à la
## taille voulue (avec mipmaps), puis mises en cache. Les icônes d'outils sont en couleurs de la charte
## (crème, rouge, jaune) ; les autres sont blanches, à teinter par modulate.

const C := "#F3ECDB"     # papier
const R := "#EC3326"     # rouge
const Y := "#FFD129"     # jaune
const K := "#100F11"     # encre

const _HEAD := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\" width=\"64\" height=\"64\">"
## Silhouette de base des pictogrammes de gestes (tête, tronc, jambes)
const _FIG := "<circle cx=\"32\" cy=\"12\" r=\"6.5\" fill=\"#fff\"/><path d=\"M32 21 V40 M32 40 L25 58 M32 40 L39 58\" stroke=\"#fff\" stroke-width=\"6.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/>"
const _ST := "stroke=\"#fff\" stroke-width=\"6.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\""

static var _cache := {}


## Corps SVG de chaque icône (sans l'en-tête)
static func _body(id: String) -> String:
	match id:
		# ---------------------------------------------------------------- outils
		"mortar":
			return ("<rect x=\"13\" y=\"53\" width=\"36\" height=\"7\" rx=\"2.5\" fill=\"C\"/>"
				+ "<g transform=\"rotate(16 30 44)\">"
				+ "<rect x=\"20\" y=\"16\" width=\"20\" height=\"38\" rx=\"2.5\" fill=\"R\"/>"
				+ "<rect x=\"20\" y=\"22\" width=\"20\" height=\"4.5\" fill=\"C\"/>"
				+ "<rect x=\"20\" y=\"43\" width=\"20\" height=\"3\" fill=\"C\" opacity=\"0.8\"/>"
				+ "<rect x=\"23.5\" y=\"29\" width=\"3.2\" height=\"11\" rx=\"1.6\" fill=\"#fff\" opacity=\"0.35\"/>"
				+ "<ellipse cx=\"30\" cy=\"16\" rx=\"10\" ry=\"3.6\" fill=\"K\" stroke=\"C\" stroke-width=\"2.2\"/></g>"
				+ "<g stroke=\"Y\" stroke-width=\"3.4\" stroke-linecap=\"round\">"
				+ "<path d=\"M41 8.5 L44.5 2.5\"/><path d=\"M46.5 13.5 L54 10.5\"/><path d=\"M35.5 8.5 L34.5 2.5\"/></g>")
		"stone":
			return ("<g stroke-linejoin=\"round\" stroke-width=\"2.5\">"
				+ "<path d=\"M44 15 L56 21 L44 27 L32 21 Z\" fill=\"#A39D92\" stroke=\"#A39D92\"/>"
				+ "<path d=\"M32 21 L44 27 L44 39 L32 33 Z\" fill=\"#857F76\" stroke=\"#857F76\"/>"
				+ "<path d=\"M44 27 L56 21 L56 33 L44 39 Z\" fill=\"#6B665F\" stroke=\"#6B665F\"/>"
				+ "<path d=\"M25 28 L41 36 L25 44 L9 36 Z\" fill=\"C\" stroke=\"C\"/>"
				+ "<path d=\"M9 36 L25 44 L25 59 L9 51 Z\" fill=\"#CFC6B3\" stroke=\"#CFC6B3\"/>"
				+ "<path d=\"M25 44 L41 36 L41 51 L25 59 Z\" fill=\"#ADA493\" stroke=\"#ADA493\"/></g>"
				+ "<path d=\"M14 47 l4 2 M30 52 l5 -2.5\" stroke=\"K\" stroke-opacity=\"0.3\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>")
		"fire":
			return ("<rect x=\"6\" y=\"40\" width=\"11\" height=\"18\" rx=\"2.5\" fill=\"R\"/>"
				+ "<rect x=\"7.5\" y=\"35.5\" width=\"8\" height=\"5.5\" rx=\"1.2\" fill=\"#BDB5A5\"/>"
				+ "<g transform=\"rotate(38 28 40)\">"
				+ "<rect x=\"18\" y=\"22\" width=\"18\" height=\"38\" rx=\"4\" fill=\"C\"/>"
				+ "<path d=\"M22 30 H32 M22 35 H32 M22 40 H29 M22 45 H32 M22 50 H30\" stroke=\"K\" stroke-opacity=\"0.45\" stroke-width=\"2\" stroke-linecap=\"round\"/>"
				+ "<ellipse cx=\"27\" cy=\"22\" rx=\"9\" ry=\"3\" fill=\"#D6CDBA\"/></g>"
				+ "<path d=\"M39 28 C29 23 31 12 36 3 C37.5 10 45 12 46 19.5 C46.8 24.5 43.5 28 39 28 Z\" fill=\"R\"/>"
				+ "<path d=\"M39 27 C35 24.5 35.5 18.5 37.5 14.5 C38.5 19 42.5 20 42 24 C41.6 26 40.5 27 39 27 Z\" fill=\"Y\"/>")
		"flare":
			return ("<circle cx=\"49\" cy=\"12\" r=\"7\" fill=\"C\" opacity=\"0.38\"/>"
				+ "<circle cx=\"56\" cy=\"5\" r=\"5\" fill=\"C\" opacity=\"0.25\"/>"
				+ "<circle cx=\"40\" cy=\"9\" r=\"5\" fill=\"C\" opacity=\"0.3\"/>"
				+ "<g transform=\"rotate(35 32 36)\">"
				+ "<rect x=\"25.5\" y=\"20\" width=\"13\" height=\"40\" rx=\"2.5\" fill=\"R\"/>"
				+ "<rect x=\"25.5\" y=\"27\" width=\"13\" height=\"3.6\" fill=\"C\"/>"
				+ "<rect x=\"28\" y=\"32\" width=\"3\" height=\"10\" rx=\"1.5\" fill=\"#fff\" opacity=\"0.35\"/>"
				+ "<rect x=\"24.5\" y=\"46\" width=\"15\" height=\"14\" rx=\"2.5\" fill=\"K\" stroke=\"C\" stroke-width=\"1.8\"/>"
				+ "<circle cx=\"32\" cy=\"17\" r=\"10\" fill=\"Y\" opacity=\"0.28\"/>"
				+ "<circle cx=\"32\" cy=\"18\" r=\"6\" fill=\"Y\"/><circle cx=\"32\" cy=\"18\" r=\"3\" fill=\"#fff\"/></g>")
		"petard_s":
			return ("<g transform=\"rotate(-22 32 50)\"><rect x=\"16\" y=\"27\" width=\"9.5\" height=\"25\" rx=\"2\" fill=\"R\"/>"
				+ "<rect x=\"16\" y=\"32\" width=\"9.5\" height=\"3\" fill=\"C\"/>"
				+ "<path d=\"M20.7 27 q-2.5 -5 1 -9\" stroke=\"C\" stroke-width=\"2.2\" fill=\"none\" stroke-linecap=\"round\"/></g>"
				+ "<g transform=\"rotate(22 32 50)\"><rect x=\"38.5\" y=\"27\" width=\"9.5\" height=\"25\" rx=\"2\" fill=\"R\"/>"
				+ "<rect x=\"38.5\" y=\"32\" width=\"9.5\" height=\"3\" fill=\"C\"/>"
				+ "<path d=\"M43.2 27 q2.5 -5 -1 -9\" stroke=\"C\" stroke-width=\"2.2\" fill=\"none\" stroke-linecap=\"round\"/></g>"
				+ "<rect x=\"27\" y=\"24\" width=\"10\" height=\"28\" rx=\"2\" fill=\"#F2493B\"/>"
				+ "<rect x=\"27\" y=\"29\" width=\"10\" height=\"3.2\" fill=\"C\"/>"
				+ "<rect x=\"29\" y=\"36\" width=\"2.4\" height=\"10\" rx=\"1.2\" fill=\"#fff\" opacity=\"0.35\"/>"
				+ "<path d=\"M32 24 q-3 -6 2 -11\" stroke=\"C\" stroke-width=\"2.2\" fill=\"none\" stroke-linecap=\"round\"/>"
				+ "<path d=\"M34.5 7 L35.7 10.8 L39.5 12 L35.7 13.2 L34.5 17 L33.3 13.2 L29.5 12 L33.3 10.8 Z\" fill=\"Y\"/>")
		"petard_m":
			return ("<rect x=\"19\" y=\"24\" width=\"24\" height=\"35\" rx=\"3\" fill=\"R\"/>"
				+ "<rect x=\"19\" y=\"31\" width=\"24\" height=\"5\" fill=\"C\"/>"
				+ "<rect x=\"19\" y=\"49\" width=\"24\" height=\"3\" fill=\"C\" opacity=\"0.8\"/>"
				+ "<rect x=\"23\" y=\"38.5\" width=\"3.5\" height=\"8\" rx=\"1.6\" fill=\"#fff\" opacity=\"0.35\"/>"
				+ "<ellipse cx=\"31\" cy=\"24\" rx=\"12\" ry=\"3.2\" fill=\"#B82519\"/>"
				+ "<path d=\"M31 24 C31 15 39 18 41 11\" stroke=\"C\" stroke-width=\"2.8\" fill=\"none\" stroke-linecap=\"round\"/>"
				+ "<path d=\"M42 2 L44 8 L50 10 L44 12 L42 18 L40 12 L34 10 L40 8 Z\" fill=\"Y\"/>")
		"hand":
			return ("<path d=\"M20 34 V18 a3.5 3.5 0 0 1 7 0 V30 V12 a3.5 3.5 0 0 1 7 0 V30 V15 a3.5 3.5 0 0 1 7 0 V32 V22 a3.5 3.5 0 0 1 7 0 V42 C48 52 42 58 34 58 C26 58 22 54 16 46 L10 38 a3.6 3.6 0 0 1 5.5 -4.6 Z\" fill=\"C\"/>")
		# ---------------------------------------------------------------- signalétique (blanc)
		"eye":
			return "<path d=\"M4 32 C14 15 50 15 60 32 C50 49 14 49 4 32 Z\" fill=\"none\" stroke=\"#fff\" stroke-width=\"5.5\" stroke-linejoin=\"round\"/><circle cx=\"32\" cy=\"32\" r=\"9.5\" fill=\"#fff\"/>"
		"siren":
			return ("<path d=\"M18 47 V35 a14 14 0 0 1 28 0 V47 Z\" fill=\"#fff\"/><rect x=\"12\" y=\"47\" width=\"40\" height=\"9\" rx=\"2.5\" fill=\"#fff\"/>"
				+ "<path d=\"M32 5 V12 M13 13 L17.5 17.5 M51 13 L46.5 17.5 M4 31 H10 M54 31 H60\" stroke=\"#fff\" stroke-width=\"4.5\" stroke-linecap=\"round\"/>")
		"gas":
			return ("<circle cx=\"21\" cy=\"36\" r=\"11\" fill=\"#fff\"/><circle cx=\"34\" cy=\"27\" r=\"14\" fill=\"#fff\"/><circle cx=\"47\" cy=\"37\" r=\"10\" fill=\"#fff\"/>"
				+ "<rect x=\"21\" y=\"36\" width=\"26\" height=\"11\" fill=\"#fff\"/>"
				+ "<path d=\"M16 55 H48\" stroke=\"#fff\" stroke-width=\"4.5\" stroke-linecap=\"round\" stroke-dasharray=\"6 7\"/>")
		"megaphone":
			return ("<path d=\"M8 27 H18 L42 14 V50 L18 37 H8 Z\" fill=\"#fff\" stroke=\"#fff\" stroke-width=\"3\" stroke-linejoin=\"round\"/>"
				+ "<path d=\"M18 38 L22 53 H29 L25 38\" fill=\"#fff\"/>"
				+ "<path d=\"M49 24 Q55 32 49 40 M54 18 Q63 32 54 46\" stroke=\"#fff\" stroke-width=\"4\" fill=\"none\" stroke-linecap=\"round\"/>")
		"fist":
			return ("<rect x=\"17\" y=\"10\" width=\"30\" height=\"26\" rx=\"7\" fill=\"#fff\"/>"
				+ "<rect x=\"22\" y=\"34\" width=\"20\" height=\"24\" rx=\"3\" fill=\"#fff\"/>"
				+ "<path d=\"M24.5 11 V21 M32 11 V21 M39.5 11 V21\" stroke=\"#000\" stroke-opacity=\"0.55\" stroke-width=\"2.5\" stroke-linecap=\"round\"/>")
		"mouse_l", "mouse_r", "mouse_wheel":
			var hl := ""
			if id == "mouse_l":
				hl = "<path d=\"M32 6 V25 H16 V23 C16 13 23 6 32 6 Z\" fill=\"R\"/>"
			elif id == "mouse_r":
				hl = "<path d=\"M32 6 V25 H48 V23 C48 13 41 6 32 6 Z\" fill=\"R\"/>"
			else:
				hl = "<rect x=\"28.5\" y=\"10\" width=\"7\" height=\"13\" rx=\"3.5\" fill=\"R\"/>"
			return (hl + "<rect x=\"14\" y=\"4\" width=\"36\" height=\"56\" rx=\"18\" fill=\"none\" stroke=\"K\" stroke-width=\"4\"/>"
				+ "<path d=\"M32 5 V25 M15 25 H49\" stroke=\"K\" stroke-width=\"3\"/>")
		"grab":
			return "<circle cx=\"32\" cy=\"32\" r=\"25\" fill=\"C\" stroke=\"K\" stroke-width=\"7\"/>"
		"grab_hl":
			return "<circle cx=\"32\" cy=\"32\" r=\"25\" fill=\"C\" stroke=\"R\" stroke-width=\"9\"/>"
		"chevron":
			return "<path d=\"M40 12 L20 32 L40 52\" stroke=\"#fff\" stroke-width=\"8\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/>"
		"check":
			return "<path d=\"M12 34 L26 48 L52 18\" stroke=\"#fff\" stroke-width=\"8\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/>"
		# ---------------------------------------------------------------- gestes (pictogrammes)
		"g_fist":
			return _FIG + "<path d=\"M32 24 L23 37 M32 24 L41 17 L43 8\" " + _ST + "/><circle cx=\"43.5\" cy=\"6\" r=\"5\" fill=\"#fff\"/>"
		"g_clap":
			return ("<circle cx=\"27\" cy=\"12\" r=\"6.5\" fill=\"#fff\"/><path d=\"M27 21 V40 M27 40 L21 58 M27 40 L34 58 M27 24 L38 31 L45 25 M27 24 L36 33 L45 28\" " + _ST + "/>"
				+ "<path d=\"M51 18 L55 14 M53 27 H59 M51 35 L55 39\" stroke=\"#fff\" stroke-width=\"3.5\" stroke-linecap=\"round\"/>")
		"g_dance":
			return ("<circle cx=\"36\" cy=\"11\" r=\"6.5\" fill=\"#fff\"/><path d=\"M34 20 L30 38 M33 24 L44 19 L49 9 M33 24 L22 28 L17 21 M30 38 L22 57 M30 38 L42 44 L44 57\" " + _ST + "/>"
				+ "<path d=\"M53 38 V27 L59 29\" stroke=\"#fff\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/><circle cx=\"50.5\" cy=\"38.5\" r=\"3.2\" fill=\"#fff\"/>")
		"g_wave":
			return _FIG + "<path d=\"M32 24 L23 37 M32 24 L44 24 L46 10\" " + _ST + "/><path d=\"M52 4 Q57 10 53 16 M57 2 Q63 10 58 19\" stroke=\"#fff\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"/>"
		"g_finger":
			return ("<rect x=\"17\" y=\"28\" width=\"30\" height=\"22\" rx=\"7\" fill=\"#fff\"/><rect x=\"27.5\" y=\"4\" width=\"9\" height=\"30\" rx=\"4.5\" fill=\"#fff\"/>"
				+ "<rect x=\"17\" y=\"23\" width=\"10\" height=\"12\" rx=\"5\" fill=\"#fff\"/><rect x=\"37\" y=\"24\" width=\"10\" height=\"11\" rx=\"5\" fill=\"#fff\"/>"
				+ "<rect x=\"22\" y=\"48\" width=\"20\" height=\"12\" rx=\"2\" fill=\"#fff\"/>"
				+ "<path d=\"M27 29 V36 M37 29 V36\" stroke=\"#000\" stroke-opacity=\"0.5\" stroke-width=\"2.2\" stroke-linecap=\"round\"/>")
		"g_point":
			return _FIG + "<path d=\"M32 24 L23 37 M32 24 L55 21\" " + _ST + "/><path d=\"M58 21 L62 21\" stroke=\"#fff\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
		"g_cheer":
			return _FIG + "<path d=\"M32 24 L22 15 L17 4 M32 24 L42 15 L47 4\" " + _ST + "/>"
		"g_hands":
			return (_FIG + "<path d=\"M32 24 L20 24 L18 10 M32 24 L44 24 L46 10\" " + _ST + "/>"
				+ "<circle cx=\"17.5\" cy=\"7\" r=\"4.6\" fill=\"#fff\"/><circle cx=\"46.5\" cy=\"7\" r=\"4.6\" fill=\"#fff\"/>")
	return "<circle cx=\"32\" cy=\"32\" r=\"20\" fill=\"#fff\"/>"


## Code SVG complet d'une icône
static func svg(id: String) -> String:
	var b := _body(id).replace("\"C\"", "\"" + C + "\"").replace("\"R\"", "\"" + R + "\"").replace("\"Y\"", "\"" + Y + "\"").replace("\"K\"", "\"" + K + "\"")
	return _HEAD + b + "</svg>"


## Texture d'une icône, rastérisée pour une hauteur d'environ `px` pixels (mise en cache)
static func tex(id: String, px := 64) -> Texture2D:
	var key := "%s@%d" % [id, px]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	var err := img.load_svg_from_string(svg(id), float(px) / 64.0)
	if err != OK or img.is_empty():
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Identifiant d'icône de chaque outil (1 à 6)
static func tool_icon(item: int) -> String:
	return ["hand", "mortar", "stone", "fire", "flare", "petard_s", "petard_m"][clampi(item, 0, 6)]


## Pictogramme de chaque geste de la roue (identifiant de Player.WHEEL)
static func gesture_icon(emote: String) -> String:
	return "g_" + emote

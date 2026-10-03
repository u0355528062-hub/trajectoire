class_name Glass
extends RefCounted
## Panneaux en verre dépoli (flou d'arrière-plan) pour l'interface.

static var _shader: Shader
static var _mats: Dictionary = {}


static func material(tint: Color = Color(0.035, 0.05, 0.085, 0.74), blur: float = 3.2) -> ShaderMaterial:
	var key := "%s_%.1f" % [tint.to_html(), blur]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = load("res://shaders/ui_glass.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("blur", blur)
	_mats[key] = m
	return m


## Style du panneau (à utiliser avec `material()`).
static func style(radius: int = 18, pad_h: int = 24, pad_v: int = 20, shadow: int = 26, border: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 1)
	s.border_color = Color(0, 1, 0, 1)
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	s.shadow_color = Color(0, 0, 1, 1)
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, 8)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


## Crée un PanelContainer en verre dépoli.
static func panel(radius: int = 18, pad_h: int = 24, pad_v: int = 20, tint: Color = Color(0.035, 0.05, 0.085, 0.74)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(radius, pad_h, pad_v))
	p.material = material(tint)
	return p


static func apply(p: Control, radius: int = 18, pad_h: int = 24, pad_v: int = 20, tint: Color = Color(0.035, 0.05, 0.085, 0.74)) -> void:
	p.add_theme_stylebox_override("panel", style(radius, pad_h, pad_v))
	p.material = material(tint)
